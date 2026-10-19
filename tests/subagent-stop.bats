#!/usr/bin/env bats
# hooks/subagent-stop.sh: the SubagentStop hook. From the harness's JSON on stdin it blocks once
# while coder/<id>'s worktree is dirty (stop_hook_active false or missing), otherwise removes the
# worktree through ../scripts/worktree-remove.sh, keeping an unmerged branch, and answers {}.

load helpers

STOP="$BATS_TEST_DIRNAME/../hooks/subagent-stop.sh"
ID=toolu_013kvbdxArmPYR7tEYE7NSjw
BR="coder/$ID"
DIRTY_REASON="is dirty: commit your own files through Executor or discard them, then finish"

setup() {
  setup_fixture
  WT="$WORKTREES/$BR"
}

# dirty_worktree: coder/<id>'s worktree with one modified and one untracked file; PORCELAIN holds its status
dirty_worktree() {
  add_linked "$BR"
  printf 'edit\n' >> "$WT/README.md"
  printf 'new\n' > "$WT/new.txt"
  PORCELAIN=$(git -C "$WT" status --porcelain -uall)
}

@test "subagent-stop.sh removes a clean worktree without commits, deletes its branch, and answers {}" {
  add_linked "$BR"
  run_hook "$STOP" "$(hook_input SubagentStop "$ID" "$MAIN" false)"
  assert_status 0
  assert_output_is '{}'
  [ ! -e "$WT" ]
  [ -z "$(worktree_of_branch "$BR")" ]
  fails branch_exists "$BR"
}

@test "subagent-stop.sh removes a clean worktree with a commit and keeps its branch" {
  add_linked "$BR"
  commit_file "$WT" work.txt "work"
  run_hook "$STOP" "$(hook_input SubagentStop "$ID" "$MAIN" false)"
  assert_status 0
  assert_output_is '{}'
  [ ! -e "$WT" ]
  [ -z "$(worktree_of_branch "$BR")" ]
  branch_exists "$BR"
}

@test "subagent-stop.sh blocks a dirty worktree with its status lines and the dirty reason, touching nothing" {
  dirty_worktree
  run_hook "$STOP" "$(hook_input SubagentStop "$ID" "$MAIN" false)"
  assert_status 0
  assert_hook_json hookSpecificOutput.hookEventName SubagentStop
  assert_hook_json hookSpecificOutput.decision block
  assert_hook_json hookSpecificOutput.reason "$(printf '%s\n%s' "$PORCELAIN" "worktree $WT on branch $BR $DIRTY_REASON")"
  [ "$(git -C "$WT" status --porcelain -uall)" = "$PORCELAIN" ]
  [ "$(cat "$WT/new.txt")" = new ]
  [ "$(worktree_of_branch "$BR")" = "$WT" ]
  branch_exists "$BR"
}

@test "subagent-stop.sh answers {} and leaves a dirty worktree in place when stop_hook_active is true" {
  dirty_worktree
  run_hook "$STOP" "$(hook_input SubagentStop "$ID" "$MAIN" true)"
  assert_status 0
  assert_output_is '{}'
  [ "$(git -C "$WT" status --porcelain -uall)" = "$PORCELAIN" ]
  [ "$(worktree_of_branch "$BR")" = "$WT" ]
  branch_exists "$BR"
}

@test "subagent-stop.sh blocks a dirty worktree when the stop_hook_active key is missing" {
  dirty_worktree
  run_hook "$STOP" "$(hook_input SubagentStop "$ID" "$MAIN")"
  assert_status 0
  assert_hook_json hookSpecificOutput.decision block
  [ "$(worktree_of_branch "$BR")" = "$WT" ]
}

@test "subagent-stop.sh answers {} for an agent_id whose branch does not exist" {
  before=$(git -C "$MAIN" worktree list --porcelain)
  run_hook "$STOP" "$(hook_input SubagentStop "$ID" "$MAIN" false)"
  assert_status 0
  assert_output_is '{}'
  [ "$(git -C "$MAIN" worktree list --porcelain)" = "$before" ]
}

@test "subagent-stop.sh deletes a branch left without a worktree and answers {}" {
  git -C "$MAIN" branch --no-track "$BR" HEAD
  run_hook "$STOP" "$(hook_input SubagentStop "$ID" "$MAIN" false)"
  assert_status 0
  assert_output_is '{}'
  fails branch_exists "$BR"
}

@test "subagent-stop.sh answers {} when cwd is not a git repository" {
  mkdir "$BATS_TEST_TMPDIR/plain"
  run_hook "$STOP" "$(hook_input SubagentStop "$ID" "$BATS_TEST_TMPDIR/plain" false)" "$BATS_TEST_TMPDIR/plain"
  assert_status 0
  assert_output_is '{}'
}

@test "subagent-stop.sh answers {} on empty stdin" {
  run_hook "$STOP" ''
  assert_status 0
  assert_output_is '{}'
}

@test "subagent-stop.sh removes the worktree subagent-start.sh created for agent_id 'a/b c'" {
  run_hook "$HOOKS/subagent-start.sh" "$(hook_input SubagentStart 'a/b c' "$MAIN")"
  assert_status 0
  [ "$(worktree_of_branch coder/a-b-c)" = "$WORKTREES/coder/a-b-c" ]
  run_hook "$STOP" "$(hook_input SubagentStop 'a/b c' "$MAIN" false)"
  assert_status 0
  assert_output_is '{}'
  [ ! -e "$WORKTREES/coder/a-b-c" ]
  [ -z "$(worktree_of_branch coder/a-b-c)" ]
}

@test "subagent-stop.sh is executable" {
  [ -x "$STOP" ]
}
