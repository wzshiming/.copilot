#!/usr/bin/env bats
# hooks/subagent-start.sh: the SubagentStart hook. From the harness's JSON on stdin it creates
# .worktrees/coder/<id> on coder/<id> at the cwd repository's HEAD through ../scripts/worktree-add.sh
# and answers one JSON object whose additionalContext is four fact lines, else `no worktree: <reason>`.

load helpers

START="$BATS_TEST_DIRNAME/../hooks/subagent-start.sh"
ID=toolu_013kvbdxArmPYR7tEYE7NSjw

setup() {
  setup_fixture
  HEAD_SHA=$(git -C "$MAIN" rev-parse HEAD)
}

# facts <branch> [<repo>]: the four lines Start injects for <branch> created from <repo>'s HEAD
facts() {
  local repo=${2:-$MAIN} root
  root=$(main_root_of "$repo")
  printf 'worktree=%s\nbranch=%s\nbase_sha=%s\nmain_root=%s' \
    "$root/.worktrees/$1" "$1" "$(git -C "$repo" rev-parse HEAD)" "$root"
}

# context_is <expected>: the last run's additionalContext is <expected>
context_is() { assert_hook_json hookSpecificOutput.additionalContext "$1"; }

@test "subagent-start.sh answers the four fact lines in one JSON line and creates .worktrees/coder/<id> at HEAD, the main checkout untouched" {
  run_hook "$START" "$(hook_input SubagentStart "$ID" "$MAIN")"
  assert_status 0
  assert_output_is "$(printf '{"hookSpecificOutput":{"hookEventName":"SubagentStart","additionalContext":"worktree=%s\\nbranch=%s\\nbase_sha=%s\\nmain_root=%s"}}' \
    "$WORKTREES/coder/$ID" "coder/$ID" "$HEAD_SHA" "$MAIN_ROOT")"
  [ "$(worktree_of_branch "coder/$ID")" = "$WORKTREES/coder/$ID" ]
  [ "$(git -C "$MAIN" rev-parse "coder/$ID")" = "$HEAD_SHA" ]
  [ "$(git -C "$MAIN" symbolic-ref HEAD)" = refs/heads/master ]
  [ -z "$(git -C "$MAIN" status --porcelain)" ]
}

@test "subagent-start.sh bases the worktree on the checkout's HEAD without fetching after origin moved on" {
  advance_origin master
  run_hook "$START" "$(hook_input SubagentStart "$ID" "$MAIN")"
  assert_status 0
  context_is "$(facts "coder/$ID")"
  [ "$(git -C "$MAIN" rev-parse "coder/$ID")" = "$HEAD_SHA" ]
  [ "$(git -C "$MAIN" rev-parse origin/master)" = "$HEAD_SHA" ]
  [ "$(git -C "$ORIGIN" rev-parse master)" != "$HEAD_SHA" ]
}

@test "subagent-start.sh uses the JSON cwd, spaces included, over the process cwd" {
  init_repo "$BATS_TEST_TMPDIR/with space"
  run_hook "$START" "$(hook_input SubagentStart "$ID" "$BATS_TEST_TMPDIR/with space")" "$MAIN"
  assert_status 0
  context_is "$(facts "coder/$ID" "$BATS_TEST_TMPDIR/with space")"
  [ -d "$BATS_TEST_TMPDIR/with space/.worktrees/coder/$ID" ]
  [ ! -e "$WORKTREES" ]
  fails branch_exists "coder/$ID"
}

@test "subagent-start.sh falls back to the process cwd when the input has no cwd key" {
  run_hook "$START" "$(hook_input SubagentStart "$ID")" "$MAIN"
  assert_status 0
  context_is "$(facts "coder/$ID")"
  [ "$(worktree_of_branch "coder/$ID")" = "$WORKTREES/coder/$ID" ]
}

@test "subagent-start.sh decodes the escaped double quote, backslash, and slash in cwd and re-escapes the quote and backslash in its answer" {
  repo="$BATS_TEST_TMPDIR/q\"b\\s p"
  init_repo "$repo"
  escaped=$(json_escape "$repo")
  escaped=${escaped//\//\\/}
  run_hook "$START" "{\"hook_event_name\":\"SubagentStart\",\"cwd\":\"$escaped\",\"agent_id\":\"$ID\",\"agent_type\":\"Coder\"}"
  assert_status 0
  context_is "$(facts "coder/$ID" "$repo")"
  [[ "$output" == *'\"'* ]]
  [[ "$output" == *'\\'* ]]
  [ -d "$repo/.worktrees/coder/$ID" ]
}

@test "subagent-start.sh treats a cwd written with a \\u escape as absent and falls back to the process cwd" {
  init_repo "$BATS_TEST_TMPDIR/other"
  escaped=$(printf '%s' "$BATS_TEST_TMPDIR/other" | sed 's,/,\\u002F,g')
  run_hook "$START" "{\"hook_event_name\":\"SubagentStart\",\"cwd\":\"$escaped\",\"agent_id\":\"$ID\",\"agent_type\":\"Coder\"}" "$MAIN"
  assert_status 0
  context_is "$(facts "coder/$ID")"
  [ "$(worktree_of_branch "coder/$ID")" = "$WORKTREES/coder/$ID" ]
  [ ! -e "$BATS_TEST_TMPDIR/other/.worktrees" ]
}

@test "subagent-start.sh treats a cwd written with a \\n escape as absent and falls back to the process cwd" {
  run_hook "$START" "{\"hook_event_name\":\"SubagentStart\",\"cwd\":\"/tmp/x\\nelse\",\"agent_id\":\"$ID\",\"agent_type\":\"Coder\"}" "$MAIN"
  assert_status 0
  context_is "$(facts "coder/$ID")"
  [ "$(worktree_of_branch "coder/$ID")" = "$WORKTREES/coder/$ID" ]
}

@test "subagent-start.sh reads pretty-printed input with its keys in any order like the compact form" {
  json=$(cat <<EOF
{
  "agent_type" : "Coder",
  "timestamp": "2026-10-20T10:00:00.000Z",
  "cwd" :  "$MAIN",
  "transcript_path": "/tmp/transcript.jsonl",
  "agent_id":
    "$ID",
  "session_id": "c3d1e7a0-5b2f-4c8e-9a1d-7f6e5d4c3b2a",
  "hook_event_name": "SubagentStart"
}
EOF
)
  run_hook "$START" "$json"
  assert_status 0
  context_is "$(facts "coder/$ID")"
  [ "$(worktree_of_branch "coder/$ID")" = "$WORKTREES/coder/$ID" ]
}

@test "subagent-start.sh maps agent_id 'a/b c.d:e' to branch coder/a-b-c-d-e" {
  run_hook "$START" "$(hook_input SubagentStart 'a/b c.d:e' "$MAIN")"
  assert_status 0
  context_is "$(facts coder/a-b-c-d-e)"
  [ "$(worktree_of_branch coder/a-b-c-d-e)" = "$WORKTREES/coder/a-b-c-d-e" ]
}

@test "subagent-start.sh answers 'no worktree' for agent_id '///', which yields no branch name, and creates nothing" {
  run_hook "$START" "$(hook_input SubagentStart '///' "$MAIN")"
  assert_status 0
  context_is "no worktree: agent_id '///' yields no valid branch name"
  [ ! -e "$WORKTREES" ]
  [ -z "$(git -C "$MAIN" branch --list 'coder/*')" ]
}

@test "subagent-start.sh answers 'no agent_id' on empty stdin" {
  run_hook "$START" ''
  assert_status 0
  context_is "no worktree: hook input has no agent_id"
  [ ! -e "$WORKTREES" ]
}

@test "subagent-start.sh answers 'no agent_id' when the input is not an object" {
  run_hook "$START" '[1]'
  assert_status 0
  context_is "no worktree: hook input has no agent_id"
  [ ! -e "$WORKTREES" ]
}

@test "subagent-start.sh answers 'no agent_type' when the input lacks it" {
  run_hook "$START" "{\"hook_event_name\":\"SubagentStart\",\"cwd\":\"$MAIN\",\"agent_id\":\"$ID\"}"
  assert_status 0
  context_is "no worktree: hook input has no agent_type"
  [ ! -e "$WORKTREES" ]
}

@test "subagent-start.sh answers '<cwd> is not a git repository' for a plain directory" {
  mkdir "$BATS_TEST_TMPDIR/plain"
  run_hook "$START" "$(hook_input SubagentStart "$ID" "$BATS_TEST_TMPDIR/plain")"
  assert_status 0
  context_is "no worktree: $BATS_TEST_TMPDIR/plain is not a git repository"
}

@test "subagent-start.sh answers '<cwd> has no commit at HEAD' for a repository with an unborn HEAD" {
  git init -q -b master "$BATS_TEST_TMPDIR/unborn"
  run_hook "$START" "$(hook_input SubagentStart "$ID" "$BATS_TEST_TMPDIR/unborn")"
  assert_status 0
  context_is "no worktree: $BATS_TEST_TMPDIR/unborn has no commit at HEAD"
  [ ! -e "$BATS_TEST_TMPDIR/unborn/.worktrees" ]
}

@test "subagent-start.sh relays worktree-add.sh's refusal when coder/<id> is already checked out elsewhere" {
  git -C "$MAIN" worktree add -q --no-track "$BATS_TEST_TMPDIR/elsewhere" -b "coder/$ID" HEAD
  elsewhere=$(worktree_of_branch "coder/$ID")
  run_hook "$START" "$(hook_input SubagentStart "$ID" "$MAIN")"
  assert_status 0
  context_is "no worktree: worktree-add.sh: branch 'coder/$ID' already exists (checked out at $elsewhere)"
  [ ! -e "$WORKTREES" ]
}

@test "subagent-start.sh answers that ../scripts/worktree-add.sh is missing when a copy of hooks/ has no sibling scripts/" {
  mkdir "$BATS_TEST_TMPDIR/copy"
  cp -R "$HOOKS" "$BATS_TEST_TMPDIR/copy/hooks"
  run_hook "$BATS_TEST_TMPDIR/copy/hooks/subagent-start.sh" "$(hook_input SubagentStart "$ID" "$MAIN")"
  assert_status 0
  context=$(hook_json hookSpecificOutput.additionalContext)
  [[ "$context" == "no worktree: "*"/copy/hooks/../scripts/worktree-add.sh is missing or not executable" ]]
  [ ! -e "$WORKTREES" ]
}

@test "subagent-start.sh and subagent-stop.sh are executable" {
  [ -x "$HOOKS/subagent-start.sh" ]
  [ -x "$HOOKS/subagent-stop.sh" ]
}
