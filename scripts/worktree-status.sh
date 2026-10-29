#!/bin/sh
# One line per worktree, then orphan: and prunable: lines; see --help.

prog=${0##*/}
usage="usage: $prog [-C <repo-path>] [--base <ref>]
Prints one line per registered worktree of the repository containing <repo-path>
(default: the current directory) as
'<path>  <branch>|detached@<sha7>  main|linked  clean|dirty:<n>  merged|unmerged(<base>)|nobase'
where merged means <base> (--base, else the remote's default branch) contains
the worktree HEAD, then 'orphan: <dir>' for each unregistered non-empty
directory under .worktrees and 'prunable: <path>' for each registration whose
directory is gone, capped at 40 lines. Read-only; prints nothing outside a
repository; exit 1, printing nothing, when the base ref does not resolve or git
fails; exit 2 on a usage error or a missing directory."

die() { printf '%s: %s\n' "$prog" "$1" >&2; exit 1; }
usage_error() { printf '%s: %s\n%s\n' "$prog" "$1" "$usage" >&2; exit 2; }

path=. base=''
while [ $# -gt 0 ]; do
  case $1 in
    -C) [ $# -ge 2 ] || usage_error "-C needs a path"; path=$2; shift ;;
    --base) [ $# -ge 2 ] || usage_error "--base needs a ref"; base=$2; shift ;;
    --help) printf '%s\n' "$usage"; exit 0 ;;
    *) usage_error "unexpected argument $1" ;;
  esac
  shift
done

[ -d "$path" ] || usage_error "no such directory: $path"
git -C "$path" rev-parse --git-dir >/dev/null 2>&1 || exit 0
list=$(git -C "$path" worktree list --porcelain) || die "git worktree list failed in $path"
main_root=$(printf '%s\n' "$list" | sed -n '1s/^worktree //p')
registered=$(printf '%s\n' "$list" | sed -n 's/^worktree //p')

if [ -n "$base" ]; then
  git -C "$main_root" rev-parse --verify --quiet "$base^{commit}" >/dev/null \
    || die "base ref '$base' does not resolve to a commit"
else
  # upstream wins over origin
  remote=$(git -C "$main_root" remote 2>/dev/null | grep -x -e upstream -e origin | sort -r | head -n 1)
  if [ -n "$remote" ] && ref=$(git -C "$main_root" symbolic-ref "refs/remotes/$remote/HEAD" 2>/dev/null); then
    base=${ref#refs/remotes/}
    git -C "$main_root" rev-parse --verify --quiet "$base^{commit}" >/dev/null \
      || die "base ref '$base' does not resolve to a commit; pass --base"
  fi
fi

# worktree | parent | other: how $1 relates to the registered worktree paths
relation() {
  _rel=other
  while IFS= read -r _p; do
    case $_p in
      "$1") _rel=worktree; break ;;
      "$1"/*) _rel=parent ;;
    esac
  done <<EOF
$registered
EOF
  printf '%s\n' "$_rel"
}

# one 'orphan: <dir>' line per topmost unregistered non-empty directory under $1
orphans() {
  for _c in "$1"/* "$1"/.[!.]* "$1"/..?*; do
    if [ ! -d "$_c" ] || [ -L "$_c" ]; then continue; fi
    case "$(relation "$_c")" in
      parent) orphans "$_c" ;;
      other) [ -z "$(find "$_c" -type f -print | head -n 1)" ] || printf 'orphan: %s\n' "$_c" ;;
    esac
  done
}

# the line for the porcelain entry just read, skipped when prunable
entry() {
  [ -n "$_wt" ] || return 0
  if [ -z "$_prunable" ]; then
    _d=$(git -C "$_wt" --no-optional-locks status --porcelain -uall 2>/dev/null | wc -l | tr -d ' ')
    if [ "$_d" -gt 0 ]; then _d="dirty:$_d"; else _d=clean; fi
    if [ -z "$base" ]; then _m=nobase
    else
      _rc=0
      git -C "$main_root" merge-base --is-ancestor "$_head" "$base" || _rc=$?
      case $_rc in
        0) _m=merged ;;
        1) _m="unmerged($base)" ;;
        *) die "cannot compare $_wt with base '$base'" ;;
      esac
    fi
    printf '%s  %s  %s  %s  %s\n' "$_wt" "$_ref" "$_kind" "$_d" "$_m"
  fi
  _wt='' _head='' _ref='' _prunable='' _kind=linked
}

entries() {
  _wt='' _head='' _ref='' _prunable='' _kind=main
  while IFS= read -r _line; do
    case $_line in
      "worktree "*) _wt=${_line#worktree } ;;
      "HEAD "*) _head=${_line#HEAD } ;;
      "branch "*) _ref=${_line#branch refs/heads/} ;;
      detached) _ref="detached@$(printf '%.7s' "$_head")" ;;
      prunable*) _prunable=1 ;;
      "") entry ;;
    esac
  done <<EOF
$list
EOF
  entry
}

report() {
  entries
  if [ -d "$main_root/.worktrees" ]; then orphans "$main_root/.worktrees"; fi
  printf '%s\n' "$list" | awk '/^worktree / { p = substr($0, 10) } /^prunable/ { print "prunable: " p }'
}

# captured first: sh has no pipefail, so a die inside report must stop the
# script before anything reaches stdout
out=$(report) || exit 1
[ -n "$out" ] || exit 0
printf '%s\n' "$out" | awk '
  NR <= 39 { print; next }
  NR == 40 { held = $0; next }
  END { if (NR > 40) print "+" (NR - 39) " more"; else if (NR == 40) print held }'
