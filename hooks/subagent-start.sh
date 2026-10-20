#!/bin/sh
# SubagentStart hook: create the subagent's worktree from the repo's HEAD and inject its facts.
# Reads the hook event from stdin, prints one JSON object, exits 0 on every path.

# shellcheck source-path=SCRIPTDIR
here=$(dirname "$0")
# shellcheck source=lib.sh
. "$here/lib.sh"
scripts=$here/../scripts

# no_worktree <reason>: report why none was created, exit 0
no_worktree() {
  printf '{"hookSpecificOutput":{"hookEventName":"SubagentStart","additionalContext":"%s"}}\n' \
    "$(json_escape "no worktree: $1")"
  exit 0
}

input=$(cat)
repo=$(json_string cwd "$input" strict) || repo=''
[ -n "$repo" ] || repo=$PWD
agent_id=$(json_string agent_id "$input") || no_worktree 'hook input has no agent_id'
agent_type=$(json_string agent_type "$input") || no_worktree 'hook input has no agent_type'
branch=$(branch_name "$agent_type" "$agent_id")
git check-ref-format --branch "$branch" >/dev/null 2>&1 || no_worktree "agent_id '$agent_id' yields no valid branch name"
git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || no_worktree "$repo is not a git repository"
sha=$(git -C "$repo" rev-parse --verify 'HEAD^{commit}' 2>/dev/null) || no_worktree "$repo has no commit at HEAD"
if [ ! -f "$scripts/worktree-add.sh" ] || [ ! -x "$scripts/worktree-add.sh" ]; then
  no_worktree "$scripts/worktree-add.sh is missing or not executable"
fi
sweep_orphans "$repo"

errfile=$(mktemp)
out=$("$scripts/worktree-add.sh" -C "$repo" "$branch" "$sha" 2>"$errfile")
rc=$?
cat "$errfile" >&2
message=$(sed -n '/./{p;q;}' "$errfile")
rm -f "$errfile"
[ "$rc" -eq 0 ] || no_worktree "${message:-worktree-add.sh exited $rc without a message}"

context=$(printf '%s\n' "$out" | awk -F= '
  { v[$1] = substr($0, length($1) + 2) }
  END { printf "worktree=%s\nbranch=%s\nbase_sha=%s\nmain_root=%s\n", v["worktree"], v["branch"], v["base_sha"], v["main_root"] }')
printf '{"hookSpecificOutput":{"hookEventName":"SubagentStart","additionalContext":"%s"}}\n' "$(json_escape "$context")"
exit 0
