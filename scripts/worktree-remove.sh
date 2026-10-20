#!/bin/sh
# Remove a branch's worktree and branch, clear orphan directories, or sweep merged branches; see --help.

prog=${0##*/}
usage="usage: $prog [-C <repo-path>] <branch> [--base <ref>] [--force-delete-branch]
       $prog [-C <repo-path>] --orphans
       $prog [-C <repo-path>] --merged <ref> <namespace>
Removes the clean worktree of <branch> (never the main checkout or a dirty one),
prunes, clears parent directories left empty under .worktrees, then deletes the
branch when git agrees, when <base> (--base, else the remote's default branch)
contains it, or always with --force-delete-branch; prints removed=<path>|none
and branch=deleted|kept-unmerged|kept. --orphans deletes each unregistered
non-empty directory under .worktrees whose files are all blobs the repository
already has, keeps and lists the others, prunes, clears empty directories, and
prints orphans_removed= and orphans_kept=. --merged prunes, then for every
branch under <namespace>/ (never <ref>'s own branch) that <ref> contains by
ancestry or by patch equivalence (git cherry) removes its clean registered
worktree and deletes the branch, keeps and lists on stderr the others (unmerged,
dirty worktree, main checkout, worktree remove failed), and prints
worktrees_removed=, branches_deleted= and branches_kept=. Every form runs under
<git-common-dir>/worktree-scripts.lock, waiting up to 10 s for another worktree
script on the repository. Exit 0 once <branch>'s removal is done whatever
branch= says; 1 when refused, when the lock stays held, or when --orphans or
--merged kept anything; 2 on a usage error."

die() { printf '%s: %s\n' "$prog" "$1" >&2; exit 1; }
usage_error() { printf '%s: %s\n%s\n' "$prog" "$1" "$usage" >&2; exit 2; }

path=. branch='' base='' force='' orphans='' merged='' ref='' namespace=''
while [ $# -gt 0 ]; do
  case $1 in
    -C) [ $# -ge 2 ] || usage_error "-C needs a path"; path=$2; shift ;;
    --base) [ $# -ge 2 ] || usage_error "--base needs a ref"; base=$2; shift ;;
    --force-delete-branch) force=1 ;;
    --orphans) orphans=1 ;;
    --merged)
      [ $# -ge 3 ] || usage_error "--merged needs <ref> and <namespace>"
      merged=1 ref=$2 namespace=$3; shift 2 ;;
    --help) printf '%s\n' "$usage"; exit 0 ;;
    -*) usage_error "unknown option $1" ;;
    *) [ -z "$branch" ] || usage_error "too many arguments"; branch=$1 ;;
  esac
  shift
done
if [ -n "$merged" ]; then
  [ -z "$branch$base$force$orphans" ] || usage_error "--merged takes no branch and no other option"
  git -C "$path" check-ref-format --branch "$namespace" >/dev/null 2>&1 || usage_error "invalid namespace '$namespace'"
elif [ -n "$orphans" ]; then
  [ -z "$branch$base$force" ] || usage_error "--orphans takes no branch and no other option"
else
  [ -n "$branch" ] || usage_error "missing <branch>"
  git -C "$path" check-ref-format --branch "$branch" >/dev/null 2>&1 || usage_error "invalid branch name '$branch'"
fi

# Serialize the worktree scripts on one repository: <git-common-dir>/worktree-scripts.lock
# names the holder's pid; it is created by hard link so it is never seen empty, a lock whose
# pid is dead is reclaimed by rename (one waiter's rename wins), and the wait gives up after 10 s.
take_lock() {
  common=$(git -C "$path" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) \
    || die "not a git repository: $path"
  lock=$common/worktree-scripts.lock
  mine=$lock.$$
  printf '%s\n' "$$" >"$mine" || die "cannot write $mine"
  waited=0
  while ! ln "$mine" "$lock" 2>/dev/null; do
    holder=$(cat "$lock" 2>/dev/null)
    if [ -n "$holder" ] && ! kill -0 "$holder" 2>/dev/null; then
      if mv "$lock" "$mine.stale" 2>/dev/null; then
        if [ "$(cat "$mine.stale" 2>/dev/null)" = "$holder" ]; then rm -f "$mine.stale"
        else ln "$mine.stale" "$lock" 2>/dev/null; rm -f "$mine.stale"
        fi
      fi
    elif [ "$waited" -ge 10 ]; then
      rm -f "$mine"
      die "lock $lock held by pid $holder: another worktree script is running; retry"
    else
      sleep 1
      waited=$((waited + 1))
    fi
  done
  rm -f "$mine"
  trap 'rm -f "$lock"' EXIT
  trap 'exit 1' HUP INT TERM
}

take_lock
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

if [ -n "$merged" ]; then
  git -C "$main_root" rev-parse --verify --quiet "$ref^{commit}" >/dev/null \
    || die "ref '$ref' does not resolve to a commit"
  git -C "$main_root" worktree prune
  own=$(git -C "$main_root" rev-parse --symbolic-full-name "$ref" 2>/dev/null)
  registered=$(git -C "$main_root" worktree list --porcelain)
  removed=0 deleted=0 kept=0

  # 0 when $ref contains branch $1 by ancestry or every commit of $1 is patch-equivalent to one in $ref
  contained() {
    git -C "$main_root" merge-base --is-ancestor "$1" "$ref" 2>/dev/null && return 0
    _cherry=$(git -C "$main_root" cherry "$ref" "$1" 2>/dev/null) || return 1
    ! printf '%s\n' "$_cherry" | grep -q '^+'
  }

  keep() { printf '%s: kept %s (%s)\n' "$prog" "$1" "$2" >&2; kept=$((kept + 1)); }

  candidates=$(git -C "$main_root" for-each-ref --format='%(refname)' "refs/heads/$namespace/")
  if [ -n "$candidates" ]; then
    while IFS= read -r _r; do
      [ "$_r" != "$own" ] || continue
      b=${_r#refs/heads/}
      if ! contained "$b"; then keep "$b" unmerged; continue; fi
      wt=$(printf '%s\n' "$registered" | awk -v b="$_r" '
        /^worktree / { p = substr($0, 10) }
        $0 == "branch " b { print p; exit }')
      if [ -n "$wt" ]; then
        if [ "$wt" = "$main_root" ]; then keep "$b" "main checkout"; continue; fi
        if [ -n "$(git -C "$wt" status --porcelain -uall 2>/dev/null)" ]; then keep "$b" "dirty worktree"; continue; fi
        if ! git -C "$main_root" worktree remove "$wt"; then keep "$b" "worktree remove failed"; continue; fi
        clear_parents "$wt"
        removed=$((removed + 1))
      fi
      git -C "$main_root" branch -D "$b" >/dev/null || die "git branch -D $b failed"
      deleted=$((deleted + 1))
    done <<EOF
$candidates
EOF
  fi
  printf 'worktrees_removed=%s\nbranches_deleted=%s\nbranches_kept=%s\n' "$removed" "$deleted" "$kept"
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
