#!/bin/sh
# Create <main-root>/.worktrees/<branch> on a new branch; see --help.

prog=${0##*/}
usage="usage: $prog [-C <repo-path>] <branch> [<base-ref>]
Creates <main-root>/.worktrees/<branch> checked out on the new branch <branch>
starting at <base-ref>; without <base-ref> it fetches the remote (upstream, else
origin) and starts at that remote's default branch. Prints worktree=, branch=,
base=, base_sha=, main_root= and state=created|exists; a branch already checked
out in its own .worktrees directory is reported, not touched. Refuses (exit 1)
when the branch exists elsewhere, the directory is taken, or no base can be
inferred; exit 2 on a usage error."

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

list=$(git -C "$path" worktree list --porcelain 2>/dev/null) || die "not a git repository: $path"
main_root=$(printf '%s\n' "$list" | sed -n '1s/^worktree //p')
[ -n "$main_root" ] || die "cannot determine the main worktree of $path"
expected=$main_root/.worktrees/$branch

# path of the worktree registered on branch $1, empty when none
branch_worktree() {
  git -C "$main_root" worktree list --porcelain | awk -v b="refs/heads/$1" '
    /^worktree / { p = substr($0, 10) }
    $0 == "branch " b { print p; exit }'
}

if [ -n "$base" ]; then
  git -C "$main_root" rev-parse --verify --quiet "$base^{commit}" >/dev/null \
    || die "base ref '$base' does not resolve to a commit"
else
  # upstream wins over origin
  remote=$(git -C "$main_root" remote | grep -x -e upstream -e origin | sort -r | head -n 1)
  [ -n "$remote" ] || die "no upstream or origin remote: pass an explicit <base-ref>"
  git -C "$main_root" fetch -q "$remote" || die "fetch from $remote failed"
  ref=$(git -C "$main_root" symbolic-ref "refs/remotes/$remote/HEAD" 2>/dev/null) \
    || die "no default branch known for $remote: pass an explicit <base-ref>"
  base=${ref#refs/remotes/}
fi

if git -C "$main_root" show-ref --verify --quiet "refs/heads/$branch"; then
  wt=$(branch_worktree "$branch")
  [ "$wt" = "$expected" ] || die "branch '$branch' already exists${wt:+ (checked out at $wt)}"
  state=exists
else
  [ ! -e "$expected" ] || die "$expected exists without branch '$branch': run worktree-remove.sh --orphans first"
  if ! git -C "$main_root" check-ignore -q .worktrees 2>/dev/null; then
    exclude="$(git -C "$main_root" rev-parse --path-format=absolute --git-common-dir)/info/exclude"
    mkdir -p "${exclude%/exclude}" || die "cannot create ${exclude%/exclude}"
    grep -qx '/\.worktrees' "$exclude" 2>/dev/null || printf '/.worktrees\n' >>"$exclude" || die "cannot write $exclude"
  fi
  git -C "$main_root" worktree add -q --no-track "$expected" -b "$branch" "$base" >/dev/null \
    || die "git worktree add failed"
  wt=$(branch_worktree "$branch")
  state=created
fi

base_sha=$(git -C "$main_root" merge-base "$base" "$branch" 2>/dev/null)
printf 'worktree=%s\nbranch=%s\nbase=%s\nbase_sha=%s\nmain_root=%s\nstate=%s\n' \
  "$wt" "$branch" "$base" "$base_sha" "$main_root" "$state"
