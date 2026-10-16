# .copilot

My personal .copilot

## VS Code settings

The agents assume these user settings; `settings.json` is outside this repo's tracked whitelist, so they are recorded here:

```json
{
  "chat.subagents.allowInvocationsFromSubagents": true,
  "chat.exploreAgent.defaultModel": "Claude Haiku 5.5 (copilot)",
  "github.copilot.chat.searchSubagent.model": "claude-haiku-5.5"
}
```

- `chat.subagents.allowInvocationsFromSubagents`: lets dispatched _Coder_, _Reviewer_, _Challenger_, _Examiner_, and _Detailer_ run their own _Scout_, _Examiner_, and _Executor_ subagents; every command routes through _Executor_, so the agents stop working without it
- The model keys pin VS Code's built-in subagents (Explore, search) to _Scout_'s primary model; the `github.copilot.chat.searchSubagent.model` key takes a Copilot model id, core `chat.*.defaultModel` takes `<name> (<vendor>)`
- VS Code's built-in execution subagent (tool `executionSubagent` in the `execute` set, configured by `github.copilot.chat.executionSubagent.*`) is not used: _Executor_ is this repo's execution subagent, and the two agents that keep a terminal name their `execute/<tool>` entries instead of the set

## Hooks

Two hooks of the Local harness are registered in the frontmatter `hooks:` of the agents they serve, so with this repo cloned at `~/.copilot` they run in every Local-harness session that runs one of those agents — mostly the subagents dispatched by _Orchestrator_, _Planner_, or each other, in any window or workspace — and not in sessions of the default agent or of VS Code's built-in subagents; they need `chat.useHooks` (on by default) and a trusted workspace:

- `PreToolUse` (`hooks/pre-tool-use.mjs`, on _Executor_ and _Scout_, the two agents that keep a terminal): auto-approves a single `~/.copilot/scripts/<name>.sh` call with no suffix and no pipe, and denies every form of `git stash`, saying that the stash is shared by all worktrees of a repository; a script call with an `&& …` suffix or a pipe just gets the normal approval prompt, not an error
- `SubagentStart` (`hooks/subagent-start.mjs`, on the seven dispatchable agents — every agent but _Planner_ and _Orchestrator_, which never run as subagents): hands a starting subagent the `worktree-status.sh` listing of the repository around the session's cwd, only when that repository has a linked worktree or a leftover or stale registration
- Known gaps: git wrapped in `sh -c`, `eval`, `xargs`, `env`, `exec`, or `sudo`, shell aliases, and `{ …; }` or `if` compound forms pass the hook unseen — the guardrail is not a sandbox, and _Executor_'s "never `git stash`" stays the primary rule
- `"chat.useHooks": false` turns the hooks off
- The harness reads the agent files from `~/.copilot/agents/` and the hook files from `~/.copilot/hooks/`, so a merged change takes effect only after `git pull --ff-only` on `master` in the main checkout
