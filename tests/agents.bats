#!/usr/bin/env bats
# Frontmatter and wording rules AGENTS.md states for the Claude-format sources agents/*.md. Each
# rule is a check_* function on one file: silent with status 0 when the file obeys, else one
# `measured (limit)` line and status 1. Each rule's test runs its check on every agent and fails
# once listing `file: measured (limit)`; a fixture proves each check can fail.

load helpers

AGENTS_DIR="$BATS_TEST_DIRNAME/../agents"

# frontmatter <file>: the lines between the file's first two `---` lines.
frontmatter() {
  awk '$0 == "---" { if (open) exit; open = 1; next } open { print }' "$1"
}

# field <file> <key>: the value of the frontmatter's `<key>:` line.
field() {
  frontmatter "$1" | sed -n "s/^$2:[[:space:]]*//p" | head -n 1 | sed 's/[[:space:]]*$//'
}

# outcome <file>: the description up to and excluding `Brief:`, quotes removed.
outcome() {
  field "$1" description | sed 's/^"//; s/"$//; s/ Brief: .*$//'
}

# each_agent <check>: run <check> on every agents/*.md; fail once with every violation.
each_agent() {
  local f msg bad=""
  for f in "$AGENTS_DIR"/*.md; do
    [ -e "$f" ] || { echo "no agents/*.md found" >&2; return 1; }
    if ! msg=$("$1" "$f"); then
      bad="$bad${f##*/}: $msg"$'\n'
    fi
  done
  [ -z "$bad" ] && return 0
  printf '%s' "$bad" >&2
  return 1
}

check_required_keys() {
  local key missing=""
  for key in name description tools model; do
    [ -n "$(field "$1" "$key")" ] || missing="${missing:+$missing, }$key"
  done
  [ -z "$missing" ] && return 0
  echo "missing $missing (name, description, tools, model)"
  return 1
}

check_description_form() {
  local line n
  line=$(frontmatter "$1" | grep '^description:' | head -n 1)
  if ! printf '%s\n' "$line" | grep -Eq '^description:[[:space:]]*"([^"\\]|\\.)*"[[:space:]]*$'; then
    echo "description not one double-quoted line (single-line \"...\")"
    return 1
  fi
  n=$(printf '%s\n' "$line" | awk '{ print gsub(/Use when:/, "") }')
  [ "$n" -eq 1 ] || { echo "$n 'Use when:' (exactly 1)"; return 1; }
  n=$(printf '%s\n' "$line" | awk '{ print gsub(/\. Brief: /, "") }')
  [ "$n" -eq 1 ] && return 0
  echo "$n '. Brief: ' (exactly 1)"
  return 1
}

check_outcome_words() {
  local n
  n=$(outcome "$1" | awk '
    { for (i = 1; i <= NF; i++) if ($i ~ /[[:alnum:]]/) n++ }
    END { print n + 0 }')
  [ "$n" -le 35 ] && return 0
  echo "$n words (35)"
  return 1
}

check_trigger_count() {
  local n
  n=$(outcome "$1" | awk '{
    i = index($0, "Use when:")
    if (i == 0) { print 0; exit }
    t = substr($0, i + 9)
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

check_model_alias() {
  case $(field "$1" model) in
    haiku | sonnet | opus | fable) return 0 ;;
  esac
  echo "model $(field "$1" model) (haiku, sonnet, opus, or fable)"
  return 1
}

check_no_model_name() {
  local found
  found=$(outcome "$1" | grep -Eiow 'haiku|sonnet|opus|fable|gpt|gemini' | head -n 1)
  [ -z "$found" ] && return 0
  echo "names $found (no model names)"
  return 1
}

check_tool_names() {
  local tool bad=""
  for tool in $(field "$1" tools | sed 's/([^)]*)//g; s/,/ /g'); do
    case $tool in
      Agent | Read | Write | Edit | Grep | Glob | Bash | WebFetch | WebSearch | AskUserQuestion) ;;
      *) bad="${bad:+$bad, }$tool" ;;
    esac
  done
  [ -z "$bad" ] && return 0
  echo "tools $bad (Claude Code tool names)"
  return 1
}

check_no_copilot_wording() {
  local n
  n=$(grep -cE '#tool:|/memories/|\(copilot\)|argument-hint|handoff' "$1" || true)
  [ "$n" -eq 0 ] && return 0
  echo "$n lines of Copilot-only wording (0; it belongs in copilot/)"
  return 1
}

setup() { FIXTURE="$BATS_TEST_TMPDIR/fixture.md"; }

# fixture <description> [<tools> [<model> [<body line>]]]
fixture() {
  printf -- '---\nname: Fixture\ndescription: "%s"\ntools: %s\nmodel: %s\n---\n\n# Fixture\n\n%s\n' \
    "$1" "${2-Read, Agent(Scout, Coder)}" "${3-haiku}" "${4-}" > "$FIXTURE"
}

@test "every agent's frontmatter has name, description, tools, and model" {
  each_agent check_required_keys
}

@test "every agent's description is one double-quoted line with one 'Use when:' and one Brief" {
  each_agent check_description_form
}

@test "every agent's description is at most 35 words before Brief" {
  each_agent check_outcome_words
}

@test "every agent's description has at most 3 triggers after 'Use when:'" {
  each_agent check_trigger_count
}

@test "every agent's model is a Claude Code alias" {
  each_agent check_model_alias
}

@test "no agent's description names a model" {
  each_agent check_no_model_name
}

@test "every agent's tools are Claude Code tool names" {
  each_agent check_tool_names
}

@test "no agent carries Copilot-only wording" {
  each_agent check_no_copilot_wording
}

@test "a well-formed fixture passes every check" {
  fixture "Does one thing for tests. Use when: checking a rule, proving a fixture. Brief: Anything"
  local check
  for check in check_required_keys check_description_form check_outcome_words \
    check_trigger_count check_model_alias check_no_model_name check_tool_names \
    check_no_copilot_wording; do
    run "$check" "$FIXTURE"
    assert_status 0
  done
}

@test "check_required_keys rejects a frontmatter missing tools" {
  fixture "Does one thing. Use when: testing. Brief: Anything" ""
  run check_required_keys "$FIXTURE"
  assert_status 1
  assert_output_is "missing tools (name, description, tools, model)"
}

@test "check_description_form rejects a description without Brief" {
  fixture "Does one thing. Use when: testing."
  run check_description_form "$FIXTURE"
  assert_status 1
  assert_output_is "0 '. Brief: ' (exactly 1)"
}

@test "check_outcome_words rejects 36 words before Brief" {
  fixture "Fixture outcome clause — Use when: a b c d e f g h i j k l m n o p q r s t u v w x y z aa bb cc dd ee. Brief: Anything"
  run check_outcome_words "$FIXTURE"
  assert_status 1
  assert_output_is "36 words (35)"
}

@test "check_trigger_count rejects 4 triggers and ignores commas in Brief" {
  fixture "Does one thing. Use when: one case, another case; a third case, a fourth case. Brief: a, b"
  run check_trigger_count "$FIXTURE"
  assert_status 1
  assert_output_is "4 triggers (3)"
}

@test "check_model_alias rejects a Copilot model name" {
  fixture "Does one thing. Use when: testing. Brief: Anything" "Read" '["Auto (copilot)"]'
  run check_model_alias "$FIXTURE"
  assert_status 1
  assert_output_is 'model ["Auto (copilot)"] (haiku, sonnet, opus, or fable)'
}

@test "check_no_model_name rejects a description naming a model" {
  fixture "Wraps Opus calls. Use when: testing. Brief: Anything"
  run check_no_model_name "$FIXTURE"
  assert_status 1
  assert_output_is "names Opus (no model names)"
}

@test "check_tool_names rejects a Copilot tool name" {
  fixture "Does one thing. Use when: testing. Brief: Anything" "Read, vscode/memory"
  run check_tool_names "$FIXTURE"
  assert_status 1
  assert_output_is "tools vscode/memory (Claude Code tool names)"
}

@test "check_no_copilot_wording rejects a #tool: reference in the body" {
  fixture "Does one thing. Use when: testing. Brief: Anything" "Read" haiku \
    "- Ask via #tool:vscode/askQuestions"
  run check_no_copilot_wording "$FIXTURE"
  assert_status 1
  assert_output_is "1 lines of Copilot-only wording (0; it belongs in copilot/)"
}
