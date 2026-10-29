#!/usr/bin/env bats
# Frontmatter rules AGENTS.md states for agents/*.agent.md. Each rule is a check_* function on one
# file, reading only its first `---`...`---` block: silent with status 0 when the file obeys, else
# one `measured (limit)` line and status 1. Each rule's test runs its check on every agent and
# fails once listing `file: measured (limit)`; a heredoc fixture proves each check can fail.

load helpers

AGENTS_DIR="$BATS_TEST_DIRNAME/../agents"

# frontmatter <file>: the lines between the file's first two `---` lines.
frontmatter() {
  awk '$0 == "---" { if (open) exit; open = 1; next } open { print }' "$1"
}

# description_value <file>: the description's text, its enclosing double quotes removed.
description_value() {
  frontmatter "$1" | sed -n 's/^description:[[:space:]]*//p' | head -n 1 |
    sed 's/^"//; s/"[[:space:]]*$//'
}

# model_names <file>...: every `model` list value with ` (copilot)` removed, one per line, sorted.
model_names() {
  local f
  for f in "$@"; do
    frontmatter "$f" | sed -n 's/^model:[[:space:]]*//p'
  done | awk -F'"' '{
    for (i = 2; i <= NF; i += 2) { v = $i; sub(/ \(copilot\)$/, "", v); if (v != "") print v }
  }' | sort -u
}

# agent_names <file>...: every `name:` value, one per line.
agent_names() {
  local f
  for f in "$@"; do
    frontmatter "$f" | sed -n 's/^name:[[:space:]]*//p' | sed 's/[[:space:]]*$//'
  done
}

# has_word <text> <word>: <word> occurs in <text> with no alphanumeric on either side.
has_word() {
  local esc
  esc=$(printf '%s\n' "$2" | sed 's/[][\.*^$+?(){}|]/\\&/g')
  printf '%s\n' "$1" | grep -Eq -- "(^|[^[:alnum:]])${esc}([^[:alnum:]]|$)"
}

# each_agent <check>: run <check> on every agents/*.agent.md; fail once with every violation.
each_agent() {
  local f msg bad=""
  for f in "$AGENTS_DIR"/*.agent.md; do
    [ -e "$f" ] || { echo "no agents/*.agent.md found" >&2; return 1; }
    if ! msg=$("$1" "$f"); then
      bad="$bad${f##*/}: $msg"$'\n'
    fi
  done
  [ -z "$bad" ] && return 0
  printf '%s' "$bad" >&2
  return 1
}

check_required_keys() {
  local fm key missing=""
  fm=$(frontmatter "$1")
  for key in name description argument-hint model agents; do
    if ! printf '%s\n' "$fm" | grep -q "^$key:"; then
      missing="${missing:+$missing, }$key"
    fi
  done
  [ -z "$missing" ] && return 0
  echo "missing $missing (name, description, argument-hint, model, agents)"
  return 1
}

check_description_form() {
  local line uses
  line=$(frontmatter "$1" | grep '^description:' | head -n 1)
  if ! printf '%s\n' "$line" | grep -Eq '^description:[[:space:]]*"([^"\\]|\\.)*"[[:space:]]*$'; then
    echo "description not one double-quoted line (single-line \"...\")"
    return 1
  fi
  uses=$(printf '%s\n' "$line" | awk '{ print gsub(/Use when:/, "") }')
  [ "$uses" -eq 1 ] && return 0
  echo "$uses 'Use when:' (exactly 1)"
  return 1
}

check_description_words() {
  local n
  n=$(description_value "$1" | awk '
    { for (i = 1; i <= NF; i++) if ($i ~ /[[:alnum:]]/) n++ }
    END { print n + 0 }')
  [ "$n" -le 35 ] && return 0
  echo "$n words (35)"
  return 1
}

check_trigger_count() {
  local n
  n=$(description_value "$1" | awk '{
    i = index($0, "Use when:")
    if (i == 0) { print 0; exit }
    t = substr($0, i + 9)
    sub(/\.[[:space:]]*$/, "", t)
    k = split(t, seg, /[,;]/)
    n = 0
    for (j = 1; j <= k; j++) if (seg[j] ~ /[^[:space:]]/) n++
    print n
    exit
  }')
  [ "${n:-0}" -le 3 ] && return 0
  echo "$n triggers (3)"
  return 1
}

check_no_model_name() {
  local desc name found=""
  desc=$(description_value "$1")
  while IFS= read -r name; do
    if [ -n "$name" ] && has_word "$desc" "$name"; then
      found="${found:+$found, }$name"
    fi
  done <<EOF
$(model_names "$AGENTS_DIR"/*.agent.md "$1")
EOF
  [ -z "$found" ] && return 0
  echo "names $found (no model names)"
  return 1
}

check_no_send_true() {
  local hits
  hits=$(frontmatter "$1" | grep -c '^[[:space:]]*send:[[:space:]]*true' || true)
  [ "$hits" -eq 0 ] && return 0
  echo "$hits send: true (0)"
  return 1
}

check_dispatch_only_names_no_agent() {
  local fm self desc name found=""
  fm=$(frontmatter "$1")
  if ! printf '%s\n' "$fm" | grep -Eq '^user-invocable:[[:space:]]*false[[:space:]]*$'; then
    return 0
  fi
  self=$(printf '%s\n' "$fm" | sed -n 's/^name:[[:space:]]*//p' | sed 's/[[:space:]]*$//')
  desc=$(description_value "$1")
  while IFS= read -r name; do
    if [ -n "$name" ] && [ "$name" != "$self" ] && has_word "$desc" "$name"; then
      found="${found:+$found, }$name"
    fi
  done <<EOF
$(agent_names "$AGENTS_DIR"/*.agent.md)
EOF
  [ -z "$found" ] && return 0
  echo "names $found (no other agent names)"
  return 1
}

setup() { FIXTURE="$BATS_TEST_TMPDIR/fixture.agent.md"; }

@test "every agent's frontmatter has name, description, argument-hint, model, and agents" {
  each_agent check_required_keys
}

@test "every agent's description is one double-quoted line with exactly one 'Use when:'" {
  each_agent check_description_form
}

@test "every agent's description is at most 35 words" {
  each_agent check_description_words
}

@test "every agent's description has at most 3 triggers after 'Use when:'" {
  each_agent check_trigger_count
}

@test "no agent's description names a model from any agent's model list" {
  [ -n "$(model_names "$AGENTS_DIR"/*.agent.md)" ]
  each_agent check_no_model_name
}

@test "no agent's frontmatter sets send: true" {
  each_agent check_no_send_true
}

@test "no dispatch-only agent's description names another agent" {
  each_agent check_dispatch_only_names_no_agent
}

@test "a well-formed fixture passes every check" {
  cat > "$FIXTURE" <<'EOF'
---
name: Fixture
description: "Does one thing for tests — nothing more. Use when: checking a rule, proving a fixture."
argument-hint: Anything
model: ["Auto (copilot)"]
user-invocable: false
agents: []
handoffs:
  - label: Go
    agent: Planner
    prompt: "Go."
    send: false
---

# Fixture
EOF
  local check
  for check in check_required_keys check_description_form check_description_words \
    check_trigger_count check_no_model_name check_no_send_true check_dispatch_only_names_no_agent; do
    run "$check" "$FIXTURE"
    assert_status 0
  done
}

@test "check_required_keys rejects a frontmatter missing agents:" {
  cat > "$FIXTURE" <<'EOF'
---
name: Fixture
description: "Does one thing. Use when: testing."
argument-hint: Anything
model: ["Auto (copilot)"]
---
EOF
  run check_required_keys "$FIXTURE"
  assert_status 1
  assert_output_is "missing agents (name, description, argument-hint, model, agents)"
}

@test "check_description_form rejects a description without 'Use when:'" {
  cat > "$FIXTURE" <<'EOF'
---
name: Fixture
description: "Does one thing for tests."
argument-hint: Anything
model: ["Auto (copilot)"]
agents: []
---
EOF
  run check_description_form "$FIXTURE"
  assert_status 1
  assert_output_is "0 'Use when:' (exactly 1)"
}

@test "check_description_words rejects a 36-word description" {
  cat > "$FIXTURE" <<'EOF'
---
name: Fixture
description: "Fixture outcome clause — Use when: a b c d e f g h i j k l m n o p q r s t u v w x y z aa bb cc dd ee."
argument-hint: Anything
model: ["Auto (copilot)"]
agents: []
---
EOF
  run check_description_words "$FIXTURE"
  assert_status 1
  assert_output_is "36 words (35)"
}

@test "check_trigger_count rejects 4 triggers after 'Use when:'" {
  cat > "$FIXTURE" <<'EOF'
---
name: Fixture
description: "Does one thing. Use when: one case, another case; a third case, a fourth case."
argument-hint: Anything
model: ["Auto (copilot)"]
agents: []
---
EOF
  run check_trigger_count "$FIXTURE"
  assert_status 1
  assert_output_is "4 triggers (3)"
}

@test "check_no_model_name rejects a description naming a model" {
  cat > "$FIXTURE" <<'EOF'
---
name: Fixture
description: "Wraps Claude Fable 5.1 calls. Use when: testing."
argument-hint: Anything
model: ["Auto (copilot)"]
agents: []
---
EOF
  run check_no_model_name "$FIXTURE"
  assert_status 1
  assert_output_is "names Claude Fable 5.1 (no model names)"
}

@test "check_no_send_true rejects send: true under a handoff" {
  cat > "$FIXTURE" <<'EOF'
---
name: Fixture
description: "Does one thing. Use when: testing."
argument-hint: Anything
model: ["Auto (copilot)"]
agents: []
handoffs:
  - label: Go
    agent: Planner
    prompt: "Go."
    send: true
---
EOF
  run check_no_send_true "$FIXTURE"
  assert_status 1
  assert_output_is "1 send: true (0)"
}

@test "check_dispatch_only_names_no_agent rejects a dispatch-only description naming Executor" {
  cat > "$FIXTURE" <<'EOF'
---
name: Fixture
description: "Hands commands to Executor. Use when: testing."
argument-hint: Anything
model: ["Auto (copilot)"]
user-invocable: false
agents: ["Executor"]
---
EOF
  run check_dispatch_only_names_no_agent "$FIXTURE"
  assert_status 1
  assert_output_is "names Executor (no other agent names)"
}
