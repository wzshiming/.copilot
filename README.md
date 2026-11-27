# .claude

My personal agents for Claude Code, with generated copies for VS Code Copilot.

## Install

Clone as `~/.claude`; the `.gitignore` whitelist keeps Claude Code's own state out of the repository. With an existing `~/.claude`:

```sh
git -C ~/.claude init
git -C ~/.claude remote add origin <this repository>
git -C ~/.claude fetch origin
git -C ~/.claude checkout master
```

## Claude Code

`agents/*.md` load as user-level subagents. The three entry points run as the main agent, which is what makes their `Agent(...)` allowlists apply:

```sh
claude --agent Planner
claude --agent Orchestrator
claude --agent Challenger
```

- A plan file and a task ledger live in the working repository's `.git/agents/`; a finished _Planner_ session names the plan file for the _Orchestrator_ session to adopt
- Review nests three levels below the main agent (_Orchestrator_ → _Challenger_ → _Reviewer_ → _Executor_), Claude Code's default limit
- The agents call the scripts as `~/.claude/scripts/<name>.sh`; allow them once in `~/.claude/settings.json`, which is outside this repo's tracked whitelist:

```json
{
  "permissions": {
    "allow": ["Bash(~/.claude/scripts/*)"]
  }
}
```

## VS Code Copilot

Copilot does not read `~/.claude/agents` reliably, and its frontmatter (tool names, model lists, `agents`, `handoffs`) differs, so its agents are generated:

```sh
~/.claude/scripts/copilot-install.sh
```

It writes `~/.copilot/agents/<name>.agent.md` from `agents/<name>.md`, `copilot/<name>.yml`, and `copilot/map`; rerun it after every pull, or with `--check` to see whether the installed copies are stale.

The generated agents assume these user settings:

```json
{
  "chat.subagents.allowInvocationsFromSubagents": true,
  "chat.exploreAgent.defaultModel": "Claude Haiku 5.5 (copilot)",
  "github.copilot.chat.searchSubagent.model": "claude-haiku-5.5"
}
```

- `chat.subagents.allowInvocationsFromSubagents`: lets dispatched _Reviewer_ and _Challenger_ run their own _Executor_ and _Reviewer_ subagents; every command of theirs routes through _Executor_, so review stops working without it
- The model keys pin VS Code's built-in subagents (Explore, search) to _Scout_'s primary model; the `github.copilot.chat.searchSubagent.model` key takes a Copilot model id, core `chat.*.defaultModel` takes `<name> (<vendor>)`
- VS Code's built-in execution subagent (tool `executionSubagent` in the `execute` set, configured by `github.copilot.chat.executionSubagent.*`) is not used: _Executor_ is this repo's execution subagent, and the three agents that keep a terminal — _Scout_, _Executor_, and _Coder_ — name their `execute/<tool>` entries instead of the set
