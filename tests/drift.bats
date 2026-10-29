#!/usr/bin/env bats
# Shared text that AGENTS.md says is copied verbatim, with no include mechanism: each test
# extracts every copy into $BATS_TEST_TMPDIR/<group>/<source path> and diffs them, so a
# failure names both files and shows the drift. An empty extract fails (a renamed anchor
# never passes vacuously). Extraction is anchored on headings and labels, never line numbers.

REPO="$BATS_TEST_DIRNAME/.."

# extract_section <file> <section>: the lines after `## <section>` up to the next `## `.
extract_section() {
  awk -v sec="## $2" '
    $0 == sec { in_sec = 1; next }
    in_sec && /^## / { exit }
    in_sec { print }
  ' "$REPO/$1"
}

# extract_item <file> <section> <label>: within `## <section>`, the first list item matching
# `^- <label>` (an ERE) plus its continuation lines indented two spaces; the item ends at the
# next `- ` item, a blank line, or a heading.
extract_item() {
  awk -v sec="## $2" -v label="^- $3" '
    $0 == sec { in_sec = 1; next }
    !in_sec { next }
    /^## / { exit }
    taking && /^  / { print; next }
    taking { exit }
    $0 ~ label { taking = 1; print }
  ' "$REPO/$1"
}

# extract_take_lock <file>: from the `# Serialize the worktree scripts` comment through the
# first following line that starts with `}`.
extract_take_lock() {
  awk '
    /^# Serialize the worktree scripts/ { taking = 1 }
    taking { print }
    taking && /^}/ { exit }
  ' "$REPO/$1"
}

# extract_fit <file>: the first double-quoted question starting `does this fit`, unquoted.
extract_fit() {
  awk '{
    i = index($0, "\"does this fit")
    if (i) {
      rest = substr($0, i + 1)
      j = index(rest, "\"")
      if (j) { print substr(rest, 1, j - 1); exit }
    }
  }' "$REPO/$1"
}

# keep <group> <file>: store stdin as <file>'s copy for <group>; an empty copy fails.
keep() {
  local out="$BATS_TEST_TMPDIR/$1/$2"
  mkdir -p "${out%/*}"
  cat >"$out"
  if [ ! -s "$out" ]; then
    echo "empty extract for $1 from $2: its anchor is missing or renamed" >&2
    return 1
  fi
}

# assert_same <group> <file> <file>...: every kept copy of <group> equals the first one.
assert_same() {
  local group=$1 first=$2 other rc=0
  shift 2
  for other in "$@"; do
    if ! diff -u "$BATS_TEST_TMPDIR/$group/$first" "$BATS_TEST_TMPDIR/$group/$other"; then
      echo "drift in $group: $first and $other differ; edit every copy together" >&2
      rc=1
    fi
  done
  return "$rc"
}

@test "Challenger and Reviewer share one ## Constraints body" {
  extract_section agents/challenger.agent.md Constraints | keep constraints agents/challenger.agent.md
  extract_section agents/reviewer.agent.md Constraints | keep constraints agents/reviewer.agent.md
  assert_same constraints agents/challenger.agent.md agents/reviewer.agent.md
}

@test "Challenger and Reviewer quote the same fit question" {
  extract_fit agents/challenger.agent.md | keep fit agents/challenger.agent.md
  extract_fit agents/reviewer.agent.md | keep fit agents/reviewer.agent.md
  assert_same fit agents/challenger.agent.md agents/reviewer.agent.md
}

@test "Coder, Orchestrator, Challenger, and Reviewer share the Executor-dispatch sentence" {
  local f
  for f in coder:Rules orchestrator:Rules challenger:Constraints reviewer:Constraints; do
    extract_item "agents/${f%%:*}.agent.md" "${f#*:}" '(Commands: )?[Ee]very command —' \
      | sed -E 's/^- (Commands: )?[Ee]very command/every command/' \
      | keep executor-dispatch "agents/${f%%:*}.agent.md"
  done
  assert_same executor-dispatch agents/coder.agent.md agents/orchestrator.agent.md \
    agents/challenger.agent.md agents/reviewer.agent.md
}

@test "Scout and Executor share the auto-approval bullet" {
  extract_item agents/scout.agent.md Constraints 'Write auto-approvable commands:' \
    | keep auto-approval agents/scout.agent.md
  extract_item agents/executor.agent.md Constraints 'Write auto-approvable commands:' \
    | keep auto-approval agents/executor.agent.md
  assert_same auto-approval agents/scout.agent.md agents/executor.agent.md
}

@test "Planner and Detailer share the Modules rule" {
  extract_item agents/planner.agent.md Rules 'Modules:' | keep modules agents/planner.agent.md
  extract_item agents/detailer.agent.md Rules 'Modules:' | keep modules agents/detailer.agent.md
  assert_same modules agents/planner.agent.md agents/detailer.agent.md
}

@test "Planner, Orchestrator, and Challenger share the Language rule" {
  local a
  for a in planner orchestrator challenger; do
    extract_item "agents/$a.agent.md" Rules 'Language:' | keep language "agents/$a.agent.md"
  done
  assert_same language agents/planner.agent.md agents/orchestrator.agent.md \
    agents/challenger.agent.md
}

@test "Planner, Orchestrator, and Challenger share the Parallel dispatch rule" {
  local a
  for a in planner orchestrator challenger; do
    extract_item "agents/$a.agent.md" Rules 'Parallel dispatch:' \
      | keep parallel-dispatch "agents/$a.agent.md"
  done
  assert_same parallel-dispatch agents/planner.agent.md agents/orchestrator.agent.md \
    agents/challenger.agent.md
}

@test "worktree-add.sh and worktree-remove.sh share the take_lock block" {
  extract_take_lock scripts/worktree-add.sh | keep take_lock scripts/worktree-add.sh
  extract_take_lock scripts/worktree-remove.sh | keep take_lock scripts/worktree-remove.sh
  assert_same take_lock scripts/worktree-add.sh scripts/worktree-remove.sh
}
