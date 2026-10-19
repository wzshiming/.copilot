#!/usr/bin/env bats
# worktree-remove.sh [-C p] <branch> [--base <ref>] [--force-delete-branch] | [-C p] --orphans
#                    | [-C p] --merged <ref> <namespace>

load helpers

setup() { setup_fixture; }

# lock_path: the per-repo lock both worktree scripts take, in MAIN's common git dir.
lock_path() {
  printf '%s/worktree-scripts.lock\n' "$(git -C "$MAIN" rev-parse --path-format=absolute --git-common-dir)"
}

# hold_lock <pid>: leave the lock behind as a holder running as <pid> would.
hold_lock() { printf '%s\n' "$1" > "$(lock_path)"; }

# dead_pid: pid of a child that has already exited, so kill -0 fails on it.
dead_pid() { sh -c 'echo $$'; }

# branch_with_commit <branch> [<start>]: <branch> off <start> (default master) with one commit
# of its own and no worktree, made in MAIN, which ends back on master.
branch_with_commit() {
  git -C "$MAIN" checkout -q -b "$1" "${2:-master}"
  commit_file "$MAIN" "$(printf '%s\n' "$1" | tr / -).txt" "$1 work"
  git -C "$MAIN" checkout -q master
}

merged_output() { printf '%s\n' "worktrees_removed=$1" "branches_deleted=$2" "branches_kept=$3"; }

@test "worktree-remove.sh removes a clean worktree, its emptied parents up to .worktrees, and the merged branch" {
  add_linked feat/a/b
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" -C "$MAIN" feat/a/b
  assert_status 0
  assert_output_is "$(printf '%s\n' "removed=$WORKTREES/feat/a/b" "branch=deleted")"
  [ ! -e "$WORKTREES/feat/a/b" ]
  [ ! -e "$WORKTREES/feat/a" ]
  [ ! -e "$WORKTREES/feat" ]
  [ ! -e "$WORKTREES" ]
  [ -z "$(worktree_of_branch feat/a/b)" ]
  fails branch_exists feat/a/b
}

@test "worktree-remove.sh refuses a dirty worktree with 'dirty', listing its files, and leaves everything in place" {
  add_linked feat
  printf 'new\n' > "$WORKTREES/feat/new.txt"
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" -C "$MAIN" feat
  assert_status 1
  [[ "$stderr" == *dirty* ]]
  [[ "$stderr" == *new.txt* ]]
  [ -f "$WORKTREES/feat/new.txt" ]
  [ "$(worktree_of_branch feat)" = "$WORKTREES/feat" ]
  branch_exists feat
}

@test "worktree-remove.sh refuses the branch checked out in the main checkout with 'main checkout'" {
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" -C "$MAIN" master
  assert_status 1
  [[ "$stderr" == *"main checkout"* ]]
  [ -f "$MAIN/README.md" ]
  [ "$(worktree_of_branch master)" = "$MAIN_ROOT" ]
  branch_exists master
}

@test "worktree-remove.sh force-deletes a branch that -d refuses but origin/master already contains" {
  add_linked feat
  commit_file "$WORKTREES/feat" feat.txt "feat work"
  git -C "$WORKTREES/feat" push -q origin HEAD:master
  git -C "$MAIN" fetch -q
  fails git -C "$MAIN" merge-base --is-ancestor feat master
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" -C "$MAIN" feat
  assert_status 0
  assert_output_is "$(printf '%s\n' "removed=$WORKTREES/feat" "branch=deleted")"
  fails branch_exists feat
}

@test "worktree-remove.sh removes the worktree but keeps an unmerged branch as kept-unmerged" {
  add_linked feat
  commit_file "$WORKTREES/feat" feat.txt "feat work"
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" -C "$MAIN" feat
  assert_status 0
  assert_output_is "$(printf '%s\n' "removed=$WORKTREES/feat" "branch=kept-unmerged")"
  [ ! -e "$WORKTREES/feat" ]
  [ -z "$(worktree_of_branch feat)" ]
  branch_exists feat
}

@test "worktree-remove.sh removes the worktree but keeps an unmerged branch as kept when there is no remote and no --base" {
  add_linked feat
  commit_file "$WORKTREES/feat" feat.txt "feat work"
  git -C "$MAIN" remote remove origin
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" -C "$MAIN" feat
  assert_status 0
  assert_output_is "$(printf '%s\n' "removed=$WORKTREES/feat" "branch=kept")"
  [ ! -e "$WORKTREES/feat" ]
  branch_exists feat
}

@test "worktree-remove.sh deletes an unmerged branch when --base <ref> contains it" {
  add_linked feat
  commit_file "$WORKTREES/feat" feat.txt "feat work"
  git -C "$MAIN" branch integration feat
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" -C "$MAIN" feat --base integration
  assert_status 0
  assert_output_is "$(printf '%s\n' "removed=$WORKTREES/feat" "branch=deleted")"
  fails branch_exists feat
}

@test "worktree-remove.sh --force-delete-branch deletes an unmerged branch" {
  add_linked feat
  commit_file "$WORKTREES/feat" feat.txt "feat work"
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" -C "$MAIN" feat --force-delete-branch
  assert_status 0
  assert_output_is "$(printf '%s\n' "removed=$WORKTREES/feat" "branch=deleted")"
  fails branch_exists feat
}

@test "worktree-remove.sh reports removed=none for a branch without a worktree and still deletes it" {
  git -C "$MAIN" branch --no-track feat origin/master
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" -C "$MAIN" feat
  assert_status 0
  assert_output_is "$(printf '%s\n' "removed=none" "branch=deleted")"
  fails branch_exists feat
}

@test "worktree-remove.sh exits 1 for a branch that does not exist" {
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" -C "$MAIN" nosuch
  assert_status 1
  [ -z "$output" ]
}

@test "worktree-remove.sh --orphans deletes an orphan whose regular files are all known blobs, skipping its .git file" {
  exclude_worktrees
  mkdir -p "$WORKTREES/stale/docs"
  cp "$MAIN/README.md" "$WORKTREES/stale/docs/README.md"
  printf 'gitdir: %s\n' "$MAIN/.git/worktrees/stale" > "$WORKTREES/stale/.git"
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" -C "$MAIN" --orphans
  assert_status 0
  assert_output_is "$(printf '%s\n' "orphans_removed=1" "orphans_kept=0")"
  [ ! -e "$WORKTREES/stale" ]
  [ ! -e "$WORKTREES" ]
}

@test "worktree-remove.sh --orphans keeps an orphan holding an unknown file and names it on stderr with 'unknown'" {
  exclude_worktrees
  mkdir -p "$WORKTREES/stale"
  cp "$MAIN/README.md" "$WORKTREES/stale/README.md"
  printf 'not in any commit\n' > "$WORKTREES/stale/notes.txt"
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" -C "$MAIN" --orphans
  assert_status 1
  assert_output_is "$(printf '%s\n' "orphans_removed=0" "orphans_kept=1")"
  [[ "$stderr" == *unknown* ]]
  [[ "$stderr" == *notes.txt* ]]
  [ -f "$WORKTREES/stale/notes.txt" ]
  [ -f "$WORKTREES/stale/README.md" ]
}

@test "worktree-remove.sh --orphans prunes vanished worktrees and removes empty directories including .worktrees" {
  add_linked feat
  rm -rf "$WORKTREES/feat"
  mkdir -p "$WORKTREES/hollow/deeper"
  [ "$(worktree_of_branch feat)" = "$WORKTREES/feat" ]
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" -C "$MAIN" --orphans
  assert_status 0
  assert_output_is "$(printf '%s\n' "orphans_removed=0" "orphans_kept=0")"
  [ -z "$(worktree_of_branch feat)" ]
  [ ! -e "$WORKTREES" ]
}

@test "worktree-remove.sh exits 2 when a branch and --orphans are both given" {
  add_linked feat
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" -C "$MAIN" feat --orphans
  assert_status 2
  [ -n "$stderr" ]
  [ -d "$WORKTREES/feat" ]
  branch_exists feat
}

@test "worktree-remove.sh exits 2 with usage on stderr when neither a branch nor --orphans is given" {
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" -C "$MAIN"
  assert_status 2
  [ -n "$stderr" ]
  [ -z "$output" ]
}

@test "worktree-remove.sh exits 2 with usage on stderr for an unknown option" {
  add_linked feat
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" -C "$MAIN" feat --bogus
  assert_status 2
  [ -n "$stderr" ]
  [ -d "$WORKTREES/feat" ]
}

@test "worktree-remove.sh --help prints usage to stdout and exits 0" {
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" --help
  assert_status 0
  [ -n "$output" ]
}

@test "worktree-remove.sh --help mentions --merged and the lock in one paragraph" {
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" --help
  assert_status 0
  [[ "$output" == *--merged* ]]
  [[ "$output" == *lock* ]]
  [[ "$output" != *$'\n\n'* ]]
}

@test "worktree-remove.sh --merged deletes a flattened pair whose commits master carries only as cherry-picks" {
  git -C "$MAIN" checkout -q -b coder/t master
  commit_file "$MAIN" t.txt "t1"
  git -C "$MAIN" checkout -q -b coder/i master
  commit_file "$MAIN" i.txt "i1"
  git -C "$MAIN" merge -q --no-ff -m "merge coder/t" coder/t
  git -C "$MAIN" checkout -q master
  # -x: a copy with the same patch but a different sha, even within the same second
  git -C "$MAIN" cherry-pick -x coder/t >/dev/null
  git -C "$MAIN" cherry-pick -x coder/i~1 >/dev/null
  fails git -C "$MAIN" merge-base --is-ancestor coder/t master
  fails git -C "$MAIN" merge-base --is-ancestor coder/i master
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" -C "$MAIN" --merged master coder
  assert_status 0
  assert_output_is "$(merged_output 0 2 0)"
  fails branch_exists coder/t
  fails branch_exists coder/i
}

@test "worktree-remove.sh --merged keeps a branch with a commit of its own as 'unmerged' and exits 1" {
  branch_with_commit coder/x
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" -C "$MAIN" --merged master coder
  assert_status 1
  assert_output_is "$(merged_output 0 0 1)"
  [[ "$stderr" == *"kept coder/x (unmerged)"* ]]
  branch_exists coder/x
}

@test "worktree-remove.sh --merged keeps a contained branch whose worktree is dirty as 'dirty worktree' and leaves the files" {
  add_linked coder/d
  printf 'new\n' > "$WORKTREES/coder/d/new.txt"
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" -C "$MAIN" --merged master coder
  assert_status 1
  assert_output_is "$(merged_output 0 0 1)"
  [[ "$stderr" == *"kept coder/d (dirty worktree)"* ]]
  [ -f "$WORKTREES/coder/d/new.txt" ]
  [ "$(worktree_of_branch coder/d)" = "$WORKTREES/coder/d" ]
  branch_exists coder/d
}

@test "worktree-remove.sh --merged keeps the branch of the main checkout as 'main checkout'" {
  git -C "$MAIN" checkout -q -b coder/m
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" -C "$MAIN" --merged master coder
  assert_status 1
  assert_output_is "$(merged_output 0 0 1)"
  [[ "$stderr" == *"kept coder/m (main checkout)"* ]]
  [ -f "$MAIN/README.md" ]
  [ "$(worktree_of_branch coder/m)" = "$MAIN_ROOT" ]
  branch_exists coder/m
}

@test "worktree-remove.sh --merged removes a contained branch's clean worktree, deletes the branch, and clears .worktrees" {
  add_linked coder/w
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" -C "$MAIN" --merged master coder
  assert_status 0
  assert_output_is "$(merged_output 1 1 0)"
  [ ! -e "$WORKTREES" ]
  [ -z "$(worktree_of_branch coder/w)" ]
  fails branch_exists coder/w
}

@test "worktree-remove.sh --merged touches only branches under <namespace>/" {
  git -C "$MAIN" branch coder/a master
  git -C "$MAIN" branch other/y master
  git -C "$MAIN" branch coderx/z master
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" -C "$MAIN" --merged master coder
  assert_status 0
  assert_output_is "$(merged_output 0 1 0)"
  fails branch_exists coder/a
  branch_exists other/y
  branch_exists coderx/z
}

@test "worktree-remove.sh --merged never deletes or counts the ref's own branch inside the namespace" {
  branch_with_commit coder/x
  git -C "$MAIN" branch coder/a master
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" -C "$MAIN" --merged coder/x coder
  assert_status 0
  assert_output_is "$(merged_output 0 1 0)"
  branch_exists coder/x
  fails branch_exists coder/a
}

@test "worktree-remove.sh --merged prints three zero counts and exits 0 when the namespace has no branch" {
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" -C "$MAIN" --merged master coder
  assert_status 0
  assert_output_is "$(merged_output 0 0 0)"
}

@test "worktree-remove.sh --merged exits 2 when the namespace is missing" {
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" -C "$MAIN" --merged master
  assert_status 2
  [[ "$stderr" == *"--merged needs <ref> and <namespace>"* ]]
  [ -z "$output" ]
}

@test "worktree-remove.sh --merged exits 2 when a branch is given with it and deletes nothing" {
  git -C "$MAIN" branch coder/a master
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" -C "$MAIN" --merged master coder feat
  assert_status 2
  [[ "$stderr" == *"--merged takes no branch and no other option"* ]]
  branch_exists coder/a
}

@test "worktree-remove.sh --merged exits 2 when --orphans is given with it" {
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" -C "$MAIN" --merged master coder --orphans
  assert_status 2
  [[ "$stderr" == *"takes no branch and no other option"* ]]
  [ -z "$output" ]
}

@test "worktree-remove.sh --merged exits 2 naming a namespace git check-ref-format rejects" {
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" -C "$MAIN" --merged master 'bad..ns'
  assert_status 2
  [[ "$stderr" == *bad..ns* ]]
  [ -z "$output" ]
}

@test "worktree-remove.sh --merged exits 1 for an unresolvable ref and deletes nothing" {
  git -C "$MAIN" branch coder/a master
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" -C "$MAIN" --merged nope coder
  assert_status 1
  [ -z "$output" ]
  branch_exists coder/a
}

@test "worktree-remove.sh gives up after 10 s on a lock held by a live pid, naming the pid, and leaves the lock and the worktree untouched" {
  add_linked feat
  hold_lock $$
  t0=$(date +%s)
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" -C "$MAIN" feat
  assert_status 1
  [[ "$stderr" == *"lock "*" held by pid $$: another worktree script is running; retry"* ]]
  [ "$(cat "$(lock_path)")" = "$$" ]
  [ -d "$WORKTREES/feat" ]
  [ "$(worktree_of_branch feat)" = "$WORKTREES/feat" ]
  branch_exists feat
  [ $(( $(date +%s) - t0 )) -ge 10 ]
}

@test "worktree-remove.sh <branch> reclaims a lock whose pid is dead and removes it on exit" {
  add_linked feat
  hold_lock "$(dead_pid)"
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" -C "$MAIN" feat
  assert_status 0
  has_line "branch=deleted"
  [ ! -e "$(lock_path)" ]
}

@test "worktree-remove.sh --orphans reclaims a lock whose pid is dead and removes it on exit" {
  hold_lock "$(dead_pid)"
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" -C "$MAIN" --orphans
  assert_status 0
  has_line "orphans_kept=0"
  [ ! -e "$(lock_path)" ]
}

@test "worktree-remove.sh --merged reclaims a lock whose pid is dead and removes it on exit" {
  hold_lock "$(dead_pid)"
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" -C "$MAIN" --merged master coder
  assert_status 0
  has_line "branches_kept=0"
  [ ! -e "$(lock_path)" ]
}

@test "worktree-remove.sh releases the lock when it refuses the main checkout's branch" {
  hold_lock "$(dead_pid)"
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" -C "$MAIN" master
  assert_status 1
  [[ "$stderr" == *"main checkout"* ]]
  [ ! -e "$(lock_path)" ]
}
