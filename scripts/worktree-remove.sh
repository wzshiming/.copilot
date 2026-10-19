#!/bin/sh
# Remove a branch's worktree and branch, or clear orphan directories; see --help.

prog=${0##*/}
usage="usage: $prog [-C <repo-path>] <branch> [--base <ref>] [--force-delete-branch]
       $prog [-C <repo-path>] --orphans
Removes the clean worktree of <branch> (never the main checkout or a dirty one),
prunes, clears parent directories left empty under .worktrees, then deletes the
branch when git agrees, when <base> (--base, else the remote's default branch)
contains it, or always with --force-delete-branch; prints removed=<path>|none
and branch=deleted|kept-unmerged|kept. --orphans deletes each unregistered
non-empty directory under .worktrees whose files are all blobs the repository
already has, keeps and lists the others, prunes, clears empty directories, and
prints orphans_removed= and orphans_kept=. Exit 1 when refused or anything is
kept, 2 on a usage error."

die() { printf '%s: %s\n' "$prog" "$1" >&2; exit 1; }
usage_error() { printf '%s: %s\n%s\n' "$prog" "$1" "$usage" >&2; exit 2; }

path=. branch='' base='' force='' orphans=''
while [ $# -gt 0 ]; do
  case $1 in
    -C) [ $# -ge 2 ] || usage_error "-C needs a path"; path=$2; shift ;;
    --base) [ $# -ge 2 ] || usage_error "--base needs a ref"; base=$2; shift ;;
    --force-delete-branch) force=1 ;;
    --orphans) orphans=1 ;;
    --help) printf '%s\n' "$usage"; exit 0 ;;
    -*) usage_error "unknown option $1" ;;
    *) [ -z "$branch" ] || usage_error "too many arguments"; branch=$1 ;;
  esac
  shift
done
if [ -n "$orphans" ]; then
  [ -z "$branch$base$force" ] || usage_error "--orphans takes no branch and no other option"
else
  [ -n "$branch" ] || usage_error "missing <branch>"
  git check-ref-format --branch "$branch" >/dev/null 2>&1 || usage_error "invalid branch name '$branch'"
fi

list=$(git -C "$path" worktree list --porcelain 2>/dev/null) || die "not a git repository: $path"
main_root=$(printf '%s\n' "$list" | sed -n '1s/^worktree //p')
[ -n "$main_root" ] || die "cannot determine the main worktree of $path"
wtroot=$main_root/.worktrees

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

# each topmost unregistered non-empty directory under $1, one per line
orphan_dirs() {
  for _c in "$1"/* "$1"/.[!.]* "$1"/..?*; do
    if [ ! -d "$_c" ] || [ -L "$_c" ]; then continue; fi
    case "$(relation "$_c")" in
      parent) orphan_dirs "$_c" ;;
      other) [ -z "$(find "$_c" -type f -print | head -n 1)" ] || printf '%s\n' "$_c" ;;
    esac
  done
}

# 0 when every file under $1 is a blob of the repository (the .git gitfile aside); the others go to stderr
all_known() {
  _files=$(find "$1" ! -type d -print)
  _ok=0
  [ -n "$_files" ] || return 0
  while IFS= read -r _f; do
    case $_f in */.git) if [ -f "$_f" ] && [ ! -L "$_f" ]; then continue; fi ;; esac
    if [ -f "$_f" ] && [ ! -L "$_f" ] && _sha=$(git -C "$main_root" hash-object -- "$_f" 2>/dev/null) \
      && git -C "$main_root" cat-file -e "$_sha" 2>/dev/null; then continue; fi
    printf '%s: unknown file %s\n' "$prog" "$_f" >&2
    _ok=1
  done <<EOF
$_files
EOF
  return "$_ok"
}

# rmdir every directory left empty under $1 bottom-up, $1 included, never inside a registered worktree
clear_empty() {
  for _c in "$1"/* "$1"/.[!.]* "$1"/..?*; do
    if [ ! -d "$_c" ] || [ -L "$_c" ]; then continue; fi
    [ "$(relation "$_c")" = worktree ] || clear_empty "$_c"
  done
  rmdir "$1" 2>/dev/null || :
}

# rmdir the directories left empty above worktree $1, up to and including .worktrees
clear_parents() {
  _d=$(dirname "$1")
  while :; do
    case $_d in "$wtroot" | "$wtroot"/*) ;; *) return 0 ;; esac
    rmdir "$_d" 2>/dev/null || return 0
    _d=$(dirname "$_d")
  done
}

if [ -n "$orphans" ]; then
  registered=$(printf '%s\n' "$list" | sed -n 's/^worktree //p')
  removed=0 kept=0
  found=$(orphan_dirs "$wtroot")
  if [ -n "$found" ]; then
    while IFS= read -r _o; do
      if all_known "$_o"; then
        case $_o in "$wtroot"/?*) rm -rf -- "$_o" ;; esac
        removed=$((removed + 1))
      else
        printf '%s: kept %s (unknown files)\n' "$prog" "$_o" >&2
        kept=$((kept + 1))
      fi
    done <<EOF
$found
EOF
  fi
  git -C "$main_root" worktree prune
  registered=$(git -C "$main_root" worktree list --porcelain | sed -n 's/^worktree //p')
  clear_empty "$wtroot"
  printf 'orphans_removed=%s\norphans_kept=%s\n' "$removed" "$kept"
  exit $((kept > 0))
fi

git -C "$main_root" show-ref --verify --quiet "refs/heads/$branch" || die "no such branch '$branch'"
if [ -n "$base" ]; then
  git -C "$main_root" rev-parse --verify --quiet "$base^{commit}" >/dev/null \
    || die "base ref '$base' does not resolve to a commit"
fi
wt=$(printf '%s\n' "$list" | awk -v b="refs/heads/$branch" '
  /^worktree / { p = substr($0, 10) }
  $0 == "branch " b { print p; exit }')
removed=none
if [ -n "$wt" ]; then
  [ "$wt" != "$main_root" ] || die "branch '$branch' is checked out in the main checkout $main_root, which is never removed"
  dirty=$(git -C "$wt" status --porcelain -uall 2>/dev/null)
  if [ -n "$dirty" ]; then
    printf '%s\n' "$dirty" >&2
    die "worktree $wt is dirty: commit or discard the changes above first"
  fi
  git -C "$main_root" worktree remove "$wt" || die "git worktree remove $wt failed"
  git -C "$main_root" worktree prune
  clear_parents "$wt"
  removed=$wt
fi

if [ -n "$force" ]; then
  git -C "$main_root" branch -D "$branch" >/dev/null || die "git branch -D $branch failed"
  result=deleted
elif git -C "$main_root" branch -d "$branch" >/dev/null 2>&1; then
  result=deleted
else
  if [ -z "$base" ]; then
    # upstream wins over origin
    remote=$(git -C "$main_root" remote 2>/dev/null | grep -x -e upstream -e origin | sort -r | head -n 1)
    [ -n "$remote" ] && ref=$(git -C "$main_root" symbolic-ref "refs/remotes/$remote/HEAD" 2>/dev/null) && base=${ref#refs/remotes/}
  fi
  if [ -z "$base" ]; then result=kept
  elif git -C "$main_root" merge-base --is-ancestor "$branch" "$base" 2>/dev/null; then
    git -C "$main_root" branch -D "$branch" >/dev/null || die "git branch -D $branch failed"
    result=deleted
  else result='kept-unmerged'
  fi
fi
printf 'removed=%s\nbranch=%s\n' "$removed" "$result"
