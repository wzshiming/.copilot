#!/usr/bin/env bats
# worktree-add.sh [-C p] <branch> [<base-ref>]: create or attach <main-root>/.worktrees/<branch>.

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

@test "worktree-add.sh creates .worktrees/<branch> from origin/master and prints the six result lines" {
  run --separate-stderr "$SCRIPTS/worktree-add.sh" -C "$MAIN" feat
  assert_status 0
  assert_output_is "$(printf '%s\n' \
    "worktree=$WORKTREES/feat" \
    "branch=feat" \
    "base=origin/master" \
    "base_sha=$(git -C "$MAIN" rev-parse origin/master)" \
    "main_root=$MAIN_ROOT" \
    "state=created")"
  [ -d "$WORKTREES/feat" ]
  [ "$(worktree_of_branch feat)" = "$WORKTREES/feat" ]
  branch_exists feat
  [ "$(git -C "$MAIN" rev-parse feat)" = "$(git -C "$MAIN" rev-parse origin/master)" ]
}

@test "worktree-add.sh creates the branch with no upstream configured even though it starts at a remote-tracking ref" {
  run --separate-stderr "$SCRIPTS/worktree-add.sh" -C "$MAIN" feat
  assert_status 0
  fails git -C "$MAIN" config branch.feat.merge
}

@test "worktree-add.sh reports state=exists and changes nothing when the branch's worktree is at the conventional path" {
  add_linked feat
  list_before=$(git -C "$MAIN" worktree list --porcelain)
  run --separate-stderr "$SCRIPTS/worktree-add.sh" -C "$MAIN" feat
  assert_status 0
  assert_output_is "$(printf '%s\n' \
    "worktree=$WORKTREES/feat" \
    "branch=feat" \
    "base=origin/master" \
    "base_sha=$(git -C "$MAIN" merge-base origin/master feat)" \
    "main_root=$MAIN_ROOT" \
    "state=exists")"
  [ "$(git -C "$MAIN" worktree list --porcelain)" = "$list_before" ]
  [ "$(git -C "$MAIN" rev-parse feat)" = "$(git -C "$MAIN" rev-parse origin/master)" ]
}

@test "worktree-add.sh attaches a branch that exists without a worktree and prints state=attached with an empty base" {
  git -C "$MAIN" branch --no-track feat origin/master
  run --separate-stderr "$SCRIPTS/worktree-add.sh" -C "$MAIN" feat
  assert_status 0
  assert_output_is "$(printf '%s\n' \
    "worktree=$WORKTREES/feat" \
    "branch=feat" \
    "base=" \
    "base_sha=" \
    "main_root=$MAIN_ROOT" \
    "state=attached")"
  [ "$(worktree_of_branch feat)" = "$WORKTREES/feat" ]
  [ "$(git -C "$WORKTREES/feat" rev-parse HEAD)" = "$(git -C "$MAIN" rev-parse feat)" ]
}

@test "worktree-add.sh does not fetch when attaching an existing branch" {
  git -C "$MAIN" branch --no-track feat origin/master
  before=$(git -C "$MAIN" rev-parse origin/master)
  advance_origin master
  run --separate-stderr "$SCRIPTS/worktree-add.sh" -C "$MAIN" feat
  assert_status 0
  has_line "state=attached"
  [ "$(git -C "$MAIN" rev-parse origin/master)" = "$before" ]
}

@test "worktree-add.sh attaching with an explicit base-ref reports it and the merge-base as base_sha" {
  git -C "$MAIN" branch --no-track feat origin/master
  advance_origin master
  git -C "$MAIN" fetch -q
  [ "$(git -C "$MAIN" rev-parse origin/master)" != "$(git -C "$MAIN" rev-parse feat)" ]
  run --separate-stderr "$SCRIPTS/worktree-add.sh" -C "$MAIN" feat origin/master
  assert_status 0
  assert_output_is "$(printf '%s\n' \
    "worktree=$WORKTREES/feat" \
    "branch=feat" \
    "base=origin/master" \
    "base_sha=$(git -C "$MAIN" merge-base origin/master feat)" \
    "main_root=$MAIN_ROOT" \
    "state=attached")"
}

@test "worktree-add.sh refuses to attach into an unregistered directory at the path and names --orphans" {
  git -C "$MAIN" branch --no-track feat origin/master
  mkdir -p "$WORKTREES/feat"
  printf 'junk\n' > "$WORKTREES/feat/junk.txt"
  run --separate-stderr "$SCRIPTS/worktree-add.sh" -C "$MAIN" feat
  assert_status 1
  [[ "$stderr" == *--orphans* ]]
  [ "$(ls -A "$WORKTREES/feat")" = "junk.txt" ]
  [ -z "$(worktree_of_branch feat)" ]
}

@test "worktree-add.sh prunes first, so a branch whose worktree directory vanished is attached again instead of reported as exists" {
  add_linked feat
  rm -rf "$WORKTREES/feat"
  run --separate-stderr "$SCRIPTS/worktree-add.sh" -C "$MAIN" feat
  assert_status 0
  has_line "state=attached"
  [ -d "$WORKTREES/feat" ]
  [ "$(worktree_of_branch feat)" = "$WORKTREES/feat" ]
}

@test "worktree-add.sh refuses with 'exists' when the branch's worktree is registered elsewhere" {
  git -C "$MAIN" worktree add -q --no-track "$BATS_TEST_TMPDIR/elsewhere" -b feat origin/master
  run --separate-stderr "$SCRIPTS/worktree-add.sh" -C "$MAIN" feat
  assert_status 1
  [[ "$stderr" == *exists* ]]
  [ ! -e "$WORKTREES/feat" ]
  [ -n "$(worktree_of_branch feat)" ]
  [ "$(worktree_of_branch feat)" != "$WORKTREES/feat" ]
}

@test "worktree-add.sh refuses and names worktree-remove.sh --orphans when an unregistered directory occupies the path" {
  mkdir -p "$WORKTREES/feat"
  printf 'junk\n' > "$WORKTREES/feat/junk.txt"
  run --separate-stderr "$SCRIPTS/worktree-add.sh" -C "$MAIN" feat
  assert_status 1
  [[ "$stderr" == *"worktree-remove.sh --orphans"* ]]
  [ "$(ls -A "$WORKTREES/feat")" = "junk.txt" ]
  [ "$(cat "$WORKTREES/feat/junk.txt")" = "junk" ]
  fails branch_exists feat
}

@test "worktree-add.sh appends /.worktrees to info/exclude exactly once across runs" {
  run git -C "$MAIN" check-ignore -q .worktrees
  [ "$status" -eq 1 ]
  run "$SCRIPTS/worktree-add.sh" -C "$MAIN" feat-1
  assert_status 0
  run "$SCRIPTS/worktree-add.sh" -C "$MAIN" feat-2
  assert_status 0
  git -C "$MAIN" check-ignore -q .worktrees
  [ "$(grep -cx '/\.worktrees' "$MAIN/.git/info/exclude")" -eq 1 ]
}

@test "worktree-add.sh branches from an explicit base-ref and reports its sha" {
  advance_origin other
  git -C "$MAIN" fetch -q
  [ "$(git -C "$MAIN" rev-parse origin/other)" != "$(git -C "$MAIN" rev-parse origin/master)" ]
  run --separate-stderr "$SCRIPTS/worktree-add.sh" -C "$MAIN" feat origin/other
  assert_status 0
  has_line "base=origin/other"
  has_line "base_sha=$(git -C "$MAIN" rev-parse origin/other)"
  [ "$(git -C "$MAIN" rev-parse feat)" = "$(git -C "$MAIN" rev-parse origin/other)" ]
}

@test "worktree-add.sh does not fetch when a base-ref is given" {
  before=$(git -C "$MAIN" rev-parse origin/master)
  advance_origin master
  run --separate-stderr "$SCRIPTS/worktree-add.sh" -C "$MAIN" feat master
  assert_status 0
  [ "$(git -C "$MAIN" rev-parse origin/master)" = "$before" ]
}

@test "worktree-add.sh fetches before resolving the default base" {
  advance_origin master
  run --separate-stderr "$SCRIPTS/worktree-add.sh" -C "$MAIN" feat
  assert_status 0
  has_line "base_sha=$(git -C "$ORIGIN" rev-parse master)"
}

@test "worktree-add.sh refuses an unresolvable base-ref" {
  run --separate-stderr "$SCRIPTS/worktree-add.sh" -C "$MAIN" feat origin/nope
  assert_status 1
  fails branch_exists feat
  [ ! -e "$WORKTREES/feat" ]
}

@test "worktree-add.sh refuses when no base-ref is given and the repository has no remote" {
  init_repo "$BATS_TEST_TMPDIR/solo"
  run --separate-stderr "$SCRIPTS/worktree-add.sh" -C "$BATS_TEST_TMPDIR/solo" feat
  assert_status 1
  fails git -C "$BATS_TEST_TMPDIR/solo" show-ref --verify -q refs/heads/feat
}

@test "worktree-add.sh with -C inside a linked worktree still roots the new worktree at the main checkout" {
  add_linked feat
  run --separate-stderr "$SCRIPTS/worktree-add.sh" -C "$WORKTREES/feat" feat-2
  assert_status 0
  has_line "worktree=$WORKTREES/feat-2"
  has_line "main_root=$MAIN_ROOT"
  [ "$(worktree_of_branch feat-2)" = "$WORKTREES/feat-2" ]
}

@test "worktree-add.sh leaves the main checkout's HEAD and status untouched" {
  printf 'edit\n' >> "$MAIN/README.md"
  printf 'new\n' > "$MAIN/untracked.txt"
  head_before="$(git -C "$MAIN" symbolic-ref HEAD) $(git -C "$MAIN" rev-parse HEAD)"
  status_before=$(git -C "$MAIN" status --porcelain)
  [ -n "$status_before" ]
  run --separate-stderr "$SCRIPTS/worktree-add.sh" -C "$MAIN" feat
  assert_status 0
  [ "$(git -C "$MAIN" symbolic-ref HEAD) $(git -C "$MAIN" rev-parse HEAD)" = "$head_before" ]
  [ "$(git -C "$MAIN" status --porcelain)" = "$status_before" ]
}

@test "worktree-add.sh exits 2 for a branch name git check-ref-format rejects" {
  run --separate-stderr "$SCRIPTS/worktree-add.sh" -C "$MAIN" 'bad..name'
  assert_status 2
  [ ! -e "$WORKTREES" ]
}

@test "worktree-add.sh exits 2 with usage on stderr when the branch argument is missing" {
  run --separate-stderr "$SCRIPTS/worktree-add.sh" -C "$MAIN"
  assert_status 2
  [ -n "$stderr" ]
  [ -z "$output" ]
}

@test "worktree-add.sh exits 2 with usage on stderr for an unknown option" {
  run --separate-stderr "$SCRIPTS/worktree-add.sh" -C "$MAIN" --bogus feat
  assert_status 2
  [ -n "$stderr" ]
  [ ! -e "$WORKTREES" ]
}

@test "worktree-add.sh gives up after 10 s on a lock held by a live pid, naming the pid, and leaves the lock and the repository untouched" {
  hold_lock $$
  t0=$(date +%s)
  run --separate-stderr "$SCRIPTS/worktree-add.sh" -C "$MAIN" feat
  assert_status 1
  [[ "$stderr" == *"lock "*" held by pid $$: another worktree script is running; retry"* ]]
  [ "$(cat "$(lock_path)")" = "$$" ]
  fails branch_exists feat
  [ ! -e "$WORKTREES/feat" ]
  [ $(( $(date +%s) - t0 )) -ge 10 ]
}

@test "worktree-add.sh reclaims a lock whose pid is dead and removes it on exit" {
  hold_lock "$(dead_pid)"
  run --separate-stderr "$SCRIPTS/worktree-add.sh" -C "$MAIN" feat
  assert_status 0
  has_line "state=created"
  [ ! -e "$(lock_path)" ]
}

@test "worktree-add.sh waits for a live lock holder and proceeds once the lock is released" {
  lock=$(lock_path)
  t0=$(date +%s)
  # a holder: its own pid in the lock for 2 s, then released
  sh -c 'printf "%s\n" $$ > "$1.tmp" && mv "$1.tmp" "$1"; sleep 2; rm -f "$1"' sh "$lock" 3>&- >/dev/null 2>&1 &
  holder=$!
  until [ -e "$lock" ]; do sleep 0.1; done
  run --separate-stderr "$SCRIPTS/worktree-add.sh" -C "$MAIN" feat
  t1=$(date +%s)
  wait "$holder"
  assert_status 0
  has_line "state=created"
  [ $((t1 - t0)) -ge 2 ]
  [ ! -e "$lock" ]
}

@test "worktree-add.sh releases the lock when it refuses a branch checked out elsewhere" {
  git -C "$MAIN" worktree add -q --no-track "$BATS_TEST_TMPDIR/elsewhere" -b feat origin/master
  hold_lock "$(dead_pid)"
  run --separate-stderr "$SCRIPTS/worktree-add.sh" -C "$MAIN" feat
  assert_status 1
  [[ "$stderr" == *exists* ]]
  [ ! -e "$(lock_path)" ]
}

@test "worktree-add.sh --help prints usage to stdout and exits 0" {
  run --separate-stderr "$SCRIPTS/worktree-add.sh" --help
  assert_status 0
  [ -n "$output" ]
}

@test "worktree-add.sh --help mentions attaching and the lock in one paragraph" {
  run --separate-stderr "$SCRIPTS/worktree-add.sh" --help
  assert_status 0
  [[ "$output" == *attach* ]]
  [[ "$output" == *lock* ]]
  [[ "$output" != *$'\n\n'* ]]
}
