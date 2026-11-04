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

- `chat.subagents.allowInvocationsFromSubagents`: lets dispatched _Reviewer_ and _Challenger_ run their own _Executor_ and _Reviewer_ subagents; every command of theirs routes through _Executor_, so review stops working without it
- The model keys pin VS Code's built-in subagents (Explore, search) to _Scout_'s primary model; the `github.copilot.chat.searchSubagent.model` key takes a Copilot model id, core `chat.*.defaultModel` takes `<name> (<vendor>)`
- VS Code's built-in execution subagent (tool `executionSubagent` in the `execute` set, configured by `github.copilot.chat.executionSubagent.*`) is not used: _Executor_ is this repo's execution subagent, and the three agents that keep a terminal — _Scout_, _Executor_, and _Coder_ — name their `execute/<tool>` entries instead of the set
