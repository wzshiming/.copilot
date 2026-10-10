# .copilot

My personal .copilot

## VS Code settings

The agents assume these user settings; `settings.json` is outside this repo's tracked whitelist, so they are recorded here:

```json
{
  "chat.subagents.allowInvocationsFromSubagents": true,
  "chat.exploreAgent.defaultModel": "Claude Haiku 5.5 (copilot)",
  "github.copilot.chat.executionSubagent.model": "claude-haiku-5.5",
  "github.copilot.chat.searchSubagent.model": "claude-haiku-5.5"
}
```

- `chat.subagents.allowInvocationsFromSubagents`: lets dispatched _Coder_, _Reviewer_, and _Challenger_ run their own _Scout_ and _Examiner_ subagents
- The model keys pin VS Code's built-in subagents (execution, Explore, search) to _Scout_'s primary model; the two `github.copilot.chat.*Subagent.model` keys take a Copilot model id, core `chat.*.defaultModel` takes `<name> (<vendor>)`
