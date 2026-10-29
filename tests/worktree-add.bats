#!/usr/bin/env bats
# worktree-add.sh [-C p] <branch> [<base-ref>]: create or attach <main-root>/.worktrees/<branch>.

load helpers

setup() { setup_fixture; }

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

@test "worktree-add.sh reports state=exists with an empty base, does not fetch, and changes nothing when the branch's worktree is at the conventional path" {
  add_linked feat
  list_before=$(git -C "$MAIN" worktree list --porcelain)
  origin_before=$(git -C "$MAIN" rev-parse origin/master)
  advance_origin master
  run --separate-stderr "$SCRIPTS/worktree-add.sh" -C "$MAIN" feat
  assert_status 0
  assert_output_is "$(printf '%s\n' \
    "worktree=$WORKTREES/feat" \
    "branch=feat" \
    "base=" \
    "base_sha=" \
    "main_root=$MAIN_ROOT" \
    "state=exists")"
  [ "$(git -C "$MAIN" rev-parse origin/master)" = "$origin_before" ]
  [ "$(git -C "$MAIN" worktree list --porcelain)" = "$list_before" ]
  [ "$(git -C "$MAIN" rev-parse feat)" = "$origin_before" ]
}

@test "worktree-add.sh reports state=exists in a repository with no remote at all" {
  solo="$BATS_TEST_TMPDIR/solo"
  init_repo "$solo"
  solo_root=$(main_root_of "$solo")
  git -C "$solo" worktree add -q "$solo_root/.worktrees/feat" -b feat
  run --separate-stderr "$SCRIPTS/worktree-add.sh" -C "$solo" feat
  assert_status 0
  has_line "worktree=$solo_root/.worktrees/feat"
  has_line "state=exists"
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

@test "worktree-add.sh infers the base from upstream's default branch over origin's" {
  upstream="$BATS_TEST_TMPDIR/upstream.git"
  git init -q --bare -b main "$upstream"
  git -C "$BATS_TEST_TMPDIR/seed" push -q "$upstream" master:main
  git -C "$MAIN" remote add upstream "$upstream"
  git -C "$MAIN" fetch -q upstream
  git -C "$MAIN" remote set-head upstream main
  run --separate-stderr "$SCRIPTS/worktree-add.sh" -C "$MAIN" feat
  assert_status 0
  has_line "base=upstream/main"
  has_line "base_sha=$(git -C "$MAIN" rev-parse upstream/main)"
  [ "$(git -C "$MAIN" rev-parse feat)" = "$(git -C "$MAIN" rev-parse upstream/main)" ]
}

@test "worktree-add.sh refuses with 'fetch from origin failed' when origin is unreachable and leaves no branch, worktree, or lock" {
  git -C "$MAIN" remote set-url origin "$BATS_TEST_TMPDIR/nowhere.git"
  run --separate-stderr "$SCRIPTS/worktree-add.sh" -C "$MAIN" feat
  assert_status 1
  [[ "$stderr" == *"fetch from origin failed"* ]]
  fails branch_exists feat
  [ ! -e "$WORKTREES/feat" ]
  [ ! -e "$(lock_path)" ]
  [ -z "$(lock_entries)" ]
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

@test "worktree-add.sh called from a deleted working directory still validates the branch through -C and creates the worktree" {
  run --separate-stderr from_deleted_cwd "$SCRIPTS/worktree-add.sh" -C "$MAIN" feat origin/master
  assert_status 0
  has_line "state=created"
  [ "$(worktree_of_branch feat)" = "$WORKTREES/feat" ]
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

@test "worktree-add.sh exits 1 naming 'not a git repository' when -C is a directory outside any repository" {
  plain="$BATS_TEST_TMPDIR/plain"
  mkdir "$plain"
  run --separate-stderr "$SCRIPTS/worktree-add.sh" -C "$plain" feat
  assert_status 1
  [[ "$stderr" == *"not a git repository"* ]]
  [ -z "$output" ]
  [ -z "$(ls -A "$plain")" ]
}

@test "worktree-add.sh exits 2 naming 'no such directory' when the -C path does not exist" {
  missing="$BATS_TEST_TMPDIR/missing"
  run --separate-stderr "$SCRIPTS/worktree-add.sh" -C "$missing" feat
  assert_status 2
  [[ "$stderr" == *"no such directory"* ]]
  [ -z "$output" ]
  [ ! -e "$missing" ]
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

@test "worktree-add.sh gives up after ten 1 s sleeps on a lock held by a live pid, naming the pid, and leaves the lock and the repository untouched" {
  lock=$(lock_path)
  log="$BATS_TEST_TMPDIR/sleep.log"
  hold_lock $$
  run --separate-stderr with_fake_sleep "$log" "$SCRIPTS/worktree-add.sh" -C "$MAIN" feat
  assert_status 1
  [ "$stderr" = "worktree-add.sh: lock $lock held by pid $$: another worktree script is running; retry" ]
  assert_full_lock_wait "$log"
  [ "$(cat "$lock/pid")" = "$$" ]
  [ "$(ls -A "$lock")" = pid ]
  [ "$(lock_entries)" = "$lock" ]
  fails branch_exists feat
  [ ! -e "$WORKTREES/feat" ]
}

@test "worktree-add.sh treats a lock directory whose pid file is not written yet as held and leaves it untouched" {
  lock=$(lock_path)
  log="$BATS_TEST_TMPDIR/sleep.log"
  mkdir "$lock"
  run --separate-stderr with_fake_sleep "$log" "$SCRIPTS/worktree-add.sh" -C "$MAIN" feat
  assert_status 1
  assert_full_lock_wait "$log"
  [ -d "$lock" ]
  [ -z "$(ls -A "$lock")" ]
  [ "$(lock_entries)" = "$lock" ]
  fails branch_exists feat
}

@test "worktree-add.sh reclaims a lock whose pid is dead and leaves no lock entry on exit" {
  hold_lock "$(dead_pid)"
  run --separate-stderr "$SCRIPTS/worktree-add.sh" -C "$MAIN" feat
  assert_status 0
  has_line "state=created"
  [ ! -e "$(lock_path)" ]
  [ -z "$(lock_entries)" ]
}

@test "worktree-add.sh waits while a live holder keeps the lock and proceeds once it is released" {
  lock=$(lock_path)
  "$BATS_TEST_DIRNAME/mock/lock-holder" "$lock" 1.5 3>&- >/dev/null 2>&1 &
  holder=$!
  await_lock_holder "$holder"
  t0=$(date +%s)
  run --separate-stderr "$SCRIPTS/worktree-add.sh" -C "$MAIN" feat
  t1=$(date +%s)
  holder_status=0
  wait "$holder" || holder_status=$?
  assert_status 0
  has_line "state=created"
  [ "$holder_status" -eq 0 ]
  [ $((t1 - t0)) -ge 1 ]
  [ ! -e "$lock" ]
  [ -z "$(lock_entries)" ]
}

@test "worktree-add.sh run three times in parallel on distinct branches creates all three worktrees and leaves no lock entry" {
  pids=()
  for b in par-1 par-2 par-3; do
    "$SCRIPTS/worktree-add.sh" -C "$MAIN" "$b" origin/master 3>&- >"$BATS_TEST_TMPDIR/$b.out" 2>&1 &
    pids+=("$!")
  done
  failed=0
  for p in "${pids[@]}"; do wait "$p" || failed=$((failed + 1)); done
  [ "$failed" -eq 0 ] || { cat "$BATS_TEST_TMPDIR"/par-*.out >&2; return 1; }
  for b in par-1 par-2 par-3; do
    [ "$(worktree_of_branch "$b")" = "$WORKTREES/$b" ]
  done
  [ -z "$(lock_entries)" ]
}

@test "worktree-add.sh run three times in parallel against a lock whose pid is dead all succeed and leave no lock entry" {
  hold_lock "$(dead_pid)"
  pids=()
  for b in par-1 par-2 par-3; do
    "$SCRIPTS/worktree-add.sh" -C "$MAIN" "$b" origin/master 3>&- >"$BATS_TEST_TMPDIR/$b.out" 2>&1 &
    pids+=("$!")
  done
  failed=0
  for p in "${pids[@]}"; do wait "$p" || failed=$((failed + 1)); done
  [ "$failed" -eq 0 ] || { cat "$BATS_TEST_TMPDIR"/par-*.out >&2; return 1; }
  for b in par-1 par-2 par-3; do
    [ "$(worktree_of_branch "$b")" = "$WORKTREES/$b" ]
  done
  [ -z "$(lock_entries)" ]
}

@test "worktree-add.sh exits 1 on SIGTERM while waiting and leaves the live holder's lock and pid file as they were, with no litter" {
  lock=$(lock_path)
  hold_lock $$
  "$SCRIPTS/worktree-add.sh" -C "$MAIN" feat 3>&- >"$BATS_TEST_TMPDIR/add.out" 2>&1 &
  waiter=$!
  await_sleeping "$waiter"
  kill -TERM "$waiter"
  waiter_status=0
  wait "$waiter" || waiter_status=$?
  [ "$waiter_status" -eq 1 ] || { printf 'waiter exited %s\n' "$waiter_status" >&2; cat "$BATS_TEST_TMPDIR/add.out" >&2; return 1; }
  [ "$(cat "$lock/pid")" = "$$" ]
  [ "$(ls -A "$lock")" = pid ]
  [ "$(lock_entries)" = "$lock" ]
  fails branch_exists feat
  [ ! -e "$WORKTREES/feat" ]
}

@test "worktree-add.sh releases the lock when it refuses a branch checked out elsewhere" {
  git -C "$MAIN" worktree add -q --no-track "$BATS_TEST_TMPDIR/elsewhere" -b feat origin/master
  hold_lock "$(dead_pid)"
  run --separate-stderr "$SCRIPTS/worktree-add.sh" -C "$MAIN" feat
  assert_status 1
  [[ "$stderr" == *exists* ]]
  [ ! -e "$(lock_path)" ]
  [ -z "$(lock_entries)" ]
}

@test "worktree-add.sh --help prints usage to stdout and exits 0" {
  run --separate-stderr "$SCRIPTS/worktree-add.sh" --help
  assert_status 0
  [ -n "$output" ]
}

@test "worktree-add.sh --help mentions info/exclude, attaching, and the lock in one paragraph with nothing on stderr" {
  run --separate-stderr "$SCRIPTS/worktree-add.sh" --help
  assert_status 0
  [ -z "$stderr" ]
  [[ "$output" == *info/exclude* ]]
  [[ "$output" == *attach* ]]
  [[ "$output" == *lock* ]]
  [[ "$output" != *$'\n\n'* ]]
}
