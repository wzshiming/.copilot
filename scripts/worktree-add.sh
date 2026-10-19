#!/bin/sh
# Create or attach <main-root>/.worktrees/<branch>; see --help.

prog=${0##*/}
usage="usage: $prog [-C <repo-path>] <branch> [<base-ref>]
Creates <main-root>/.worktrees/<branch> checked out on the new branch <branch>
starting at <base-ref>; without <base-ref> it fetches the remote (upstream, else
origin) and starts at that remote's default branch. A branch that exists with
no worktree is attached there instead, without a fetch or an inferred base.
Prints worktree=, branch=, base=, base_sha=, main_root= and
state=created|attached|exists (base= and base_sha= empty when attaching without
<base-ref>); a branch already checked out in its own .worktrees directory is
reported, not touched. Runs under <git-common-dir>/worktree-scripts.lock,
waiting up to 10 s for another worktree script on the repository. Refuses
(exit 1) when the branch is checked out elsewhere, the directory is taken, no
base can be inferred, or the lock stays held; exit 2 on a usage error."

die() { printf '%s: %s\n' "$prog" "$1" >&2; exit 1; }
usage_error() { printf '%s: %s\n%s\n' "$prog" "$1" "$usage" >&2; exit 2; }

path=. branch='' base='' nargs=0
while [ $# -gt 0 ]; do
  case $1 in
    -C) [ $# -ge 2 ] || usage_error "-C needs a path"; path=$2; shift ;;
    --help) printf '%s\n' "$usage"; exit 0 ;;
    -*) usage_error "unknown option $1" ;;
    *)
      nargs=$((nargs + 1))
      case $nargs in 1) branch=$1 ;; 2) base=$1 ;; *) usage_error "too many arguments" ;; esac ;;
  esac
  shift
done
[ -n "$branch" ] || usage_error "missing <branch>"
git check-ref-format --branch "$branch" >/dev/null 2>&1 || usage_error "invalid branch name '$branch'"

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
expected=$main_root/.worktrees/$branch
# a branch whose worktree directory vanished is attached again, not reported as exists
git -C "$main_root" worktree prune

# path of the worktree registered on branch $1, empty when none
branch_worktree() {
  git -C "$main_root" worktree list --porcelain | awk -v b="refs/heads/$1" '
    /^worktree / { p = substr($0, 10) }
    $0 == "branch " b { print p; exit }'
}

if git -C "$main_root" show-ref --verify --quiet "refs/heads/$branch"; then
  wt=$(branch_worktree "$branch")
  if [ "$wt" = "$expected" ]; then state=exists
  elif [ -n "$wt" ]; then die "branch '$branch' already exists (checked out at $wt)"
  else state=attached
  fi
else
  state=created
fi

if [ -n "$base" ]; then
  git -C "$main_root" rev-parse --verify --quiet "$base^{commit}" >/dev/null \
    || die "base ref '$base' does not resolve to a commit"
elif [ "$state" != attached ]; then
  # upstream wins over origin
  remote=$(git -C "$main_root" remote | grep -x -e upstream -e origin | sort -r | head -n 1)
  [ -n "$remote" ] || die "no upstream or origin remote: pass an explicit <base-ref>"
  git -C "$main_root" fetch -q "$remote" || die "fetch from $remote failed"
  ref=$(git -C "$main_root" symbolic-ref "refs/remotes/$remote/HEAD" 2>/dev/null) \
    || die "no default branch known for $remote: pass an explicit <base-ref>"
  base=${ref#refs/remotes/}
fi

if [ "$state" != exists ]; then
  [ ! -e "$expected" ] || die "$expected exists without branch '$branch': run worktree-remove.sh --orphans first"
  if ! git -C "$main_root" check-ignore -q .worktrees 2>/dev/null; then
    exclude=$common/info/exclude
    mkdir -p "${exclude%/exclude}" || die "cannot create ${exclude%/exclude}"
    grep -qx '/\.worktrees' "$exclude" 2>/dev/null || printf '/.worktrees\n' >>"$exclude" || die "cannot write $exclude"
  fi
  if [ "$state" = created ]; then
    git -C "$main_root" worktree add -q --no-track "$expected" -b "$branch" "$base" >/dev/null
  else
    git -C "$main_root" worktree add -q "$expected" "$branch" >/dev/null
  fi || die "git worktree add failed"
  wt=$(branch_worktree "$branch")
fi

base_sha=''
[ -z "$base" ] || base_sha=$(git -C "$main_root" merge-base "$base" "$branch" 2>/dev/null)
printf 'worktree=%s\nbranch=%s\nbase=%s\nbase_sha=%s\nmain_root=%s\nstate=%s\n' \
  "$wt" "$branch" "$base" "$base_sha" "$main_root" "$state"
