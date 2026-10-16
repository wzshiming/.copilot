#!/usr/bin/env bats
# worktree-add.sh [-C p] <branch> [<base-ref>]: create <main-root>/.worktrees/<branch>.

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

@test "worktree-add.sh refuses with 'exists' when the branch exists without a worktree" {
  git -C "$MAIN" branch --no-track feat origin/master
  run --separate-stderr "$SCRIPTS/worktree-add.sh" -C "$MAIN" feat
  assert_status 1
  [[ "$stderr" == *exists* ]]
  [ ! -e "$WORKTREES/feat" ]
  [ -z "$(worktree_of_branch feat)" ]
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

@test "worktree-add.sh --help prints usage to stdout and exits 0" {
  run --separate-stderr "$SCRIPTS/worktree-add.sh" --help
  assert_status 0
  [ -n "$output" ]
}
