#!/bin/sh
# SubagentStop hook: block once while the subagent's worktree is dirty, otherwise remove it.
# Reads the hook event from stdin, prints one JSON object, exits 0 on every path.

# shellcheck source-path=SCRIPTDIR
here=$(dirname "$0")
# shellcheck source=lib.sh
. "$here/lib.sh"
scripts=$here/../scripts

# pass: no decision, exit 0
pass() {
  printf '{}\n'
  exit 0
}

input=$(cat)
repo=$(json_string cwd "$input" strict) || repo=''
[ -n "$repo" ] || repo=$PWD
agent_id=$(json_string agent_id "$input") || pass
agent_type=$(json_string agent_type "$input") || pass
branch=$(branch_name "$agent_type" "$agent_id")
git check-ref-format --branch "$branch" >/dev/null 2>&1 || pass
list=$(git -C "$repo" worktree list --porcelain 2>/dev/null) || pass

wt=$(printf '%s\n' "$list" | awk -v b="refs/heads/$branch" '
  /^worktree / { p = substr($0, 10) }
  $0 == "branch " b { print p; exit }')
if [ -n "$wt" ] && [ -d "$wt" ] && ! json_true stop_hook_active "$input"; then
  dirty=$(git -C "$wt" status --porcelain -uall 2>/dev/null)
  if [ -n "$dirty" ]; then
    reason="$dirty
worktree $wt on branch $branch is dirty: commit your own files through Executor or discard them, then finish"
    printf '{"hookSpecificOutput":{"hookEventName":"SubagentStop","decision":"block","reason":"%s"}}\n' \
      "$(json_escape "$reason")"
    exit 0
  fi
fi

"$scripts/worktree-remove.sh" -C "$repo" "$branch" >&2
pass
