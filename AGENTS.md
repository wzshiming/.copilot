# AGENTS.md

Personal agents repository — agent definitions plus the scripts they run, no application code.

## Structure

Only `.github/`, `agents/`, `scripts/`, `tests/`, the dotfiles `.gitignore` lists, root Markdown docs, `LICENSE`, and `Makefile` are tracked; everything else at the root is local runtime state excluded by the `.gitignore` whitelist.

### Scripts

- Each script lives in `scripts/<name>.sh` as POSIX sh (`#!/bin/sh`, clean under `shellcheck -s sh`), called as `~/.copilot/scripts/<name>.sh [-C <repo-path>] <args>`; the lock block `take_lock` is identical in `scripts/worktree-add.sh` and `scripts/worktree-remove.sh` and is edited in both together.
- A script never prompts, reads no environment variable as configuration, and never forces; an unmet precondition makes it refuse and say why.
- Exit codes: `0` done, `1` refused or failed, `2` usage error; a script's `--help` may define more (`ci-wait.sh`: `3` still pending at the deadline); results print as `key=value` lines, a listing (`worktree-status.sh`) as one line per item, a watcher as one progress line per poll plus the final table; `--help` prints one paragraph.
- Tests live in `tests/<name>.bats` (bats-core); reusable fake commands live in `tests/mock/<cmd>`, clean under `shellcheck -s sh`, never as stubs written inside a single `.bats` file.

### Agents

- Each agent lives in `agents/<name>.agent.md` with YAML frontmatter. Every agent has `name`, `description`, `argument-hint`, `model` (fallback list), and `agents` (dispatchable subagents); `tools`, `user-invocable`, `disable-model-invocation`, and `handoffs` are used where applicable.
- `handoffs` link user-invocable agents along meaningful transitions only and are all manual — never set `send: true`: Autopilot auto-fires the first `send` handoff after every response and can loop agents. Prompts are inserted verbatim (no `${…}` substitution) into the same session, so they name only what is handed over plus facts the target cannot see (e.g. ledger paths); the target agent's body supplies the method.
- Challenger and Reviewer share one verbatim `## Constraints` block and the quoted fit question; Coder, Orchestrator, and that block share the Executor-dispatch sentence; Scout and Executor share the auto-approval bullet; Planner and Detailer share the Modules rule; Planner, Orchestrator, and Challenger share the Language rule and the Parallel dispatch rule — there is no include mechanism, so edit every copy together.

## Checks

- `make check` — Prettier format check + markdownlint + shellcheck + bats, the full suite.
- `make format-check` — Prettier check on Markdown.
- `make lint` — markdownlint on Markdown + `shellcheck -s sh` on `scripts/*.sh` and `tests/mock/*` + `shellcheck -s bash` on `tests/helpers.bash`; `.bats` files are not shellchecked.
- `make test` — bats-core on `tests/*.bats`.
- `make format` — Prettier rewrites Markdown.
- These targets, or the commands they run on specific files, may run locally without asking.
- CI (`.github/workflows/ci.yml`) runs `make check` on `ubuntu-latest` and `macos-latest` for pushes to `master` and all PRs.

## Conventions

- Agents orchestrate, Executor executes: a body holds its flow plus only its role's knowledge; the git/gh workflow lives only in Executor's Rules (a Coder's worktree created and released through its Worktree rule), each fixed multi-command flow is a script in `scripts/`, and dispatchers name a git/gh step by its intent alone (the Coder's `worktree` and `release` dispatches among them), the exceptions being Coder's own `git add`/`git commit` and `git restore`/`rm` (its Constraints and Approach); no body restates the harness base prompt.
- Agent bodies open with one sentence in normal case, `You are the <role>: <mission>.` — no shouted words.
- Agent body sections are H2 only, one per name, in this order and only when needed: Input, Constraints, Approach (a subagent's checklist) or Workflow (the Orchestrator's and Planner's phase loop), Rules, Output Format.
- List items are fragments or single sentences without a terminal period — split an item rather than write two sentences in it; only Workflow phase items are paragraphs with a bold `**Phase**:` label and full punctuation, every other label is plain `Label:`.
- Emphasis: `_Agent_` italics for agent names, bold only for Workflow phase names — their labels and references back to them — and a body's key-fact line (`**Ledger**`, `**Current plan**`), backticks for paths and commands, `#tool:` for tools; a list's lead-in sentence ends with a colon.
- Descriptions: at most 35 words, shorter preferred; one outcome clause (what it does, not its steps), then `Use when:` with up to three comma- or semicolon-separated triggers specific to the task; no model names; a dispatch-only agent's description names no dispatcher or dispatchee, a user-invocable agent's may name the agents whose handoffs feed it (`agents/*.agent.md` frontmatter).
- Shell: auto-approvable and self-contained; a fixed flow is one script call, approvable whole; no `export …;` preamble or `VAR=… cmd` prefix and no zsh-only syntax; guards are flags, not environment; `gh` output piped; watchers included in the foreground rather than redirected (Executor's Constraints and Rules, the shared auto-approval bullet).
- Testing: the full suite runs on CI as the merge gate and local runs stay targeted — the baseline is the start commit's CI result, else one local run, and a local full run comes only before a landing to no PR or when CI is unreachable (Executor's CI and Landing rules, `scripts/ci-wait.sh`).
- Execution: only Scout (side-effect-free reads) and Executor run terminal commands, each naming its `execute/<tool>` entries instead of the `execute` set; Coder, Orchestrator, Reviewer, and Challenger dispatch Executor by its `argument-hint`, one dispatch per step; destructive commands only when named (Executor's Constraints and Rules, the shared Executor-dispatch sentence).
- Implementation: the Orchestrator classifies each stage as a tests/implementation pair or one Coder and records its contract and file split in the ledger (its Execute); a Coder creates and releases its worktree through Executor, so its part exists only as the branch it reports (Executor's Worktree rule, Coder's Worktree and Release steps); Executor joins, lands, and cleans up by branch, combining only by rebase and fast-forward, never a merge commit (its Join and Landing rules, `scripts/worktree-*.sh`).
- Review: the review requirement is the user's choice among review gates as the Orchestrator schedules them (the default), one review gate before landing only, or none; Reviewer runs at the gates only and Challenger only when the user asks or a gate fails three Reviewer rounds (Orchestrator's Intake and Verify, Planner's Alignment).
- Design: Planner and Detailer design from the whole by criteria that live only in the Modules rule; the Orchestrator decomposes the design; Coder implements the contract, reporting rather than writing a patch or restructuring the plan did not foresee; Reviewer and Challenger ask the fit question against the plan's decisions and criteria (their Approach).
- Planning: the Planner's Outline, approved by the user, is the only plan format, and the Orchestrator's Detailers detail each wave, every Module Detail becoming the ledger's stage contract (their Output Formats are the single home of both; Orchestrator's Intake and Advance); the Orchestrator alone lists Detailer in `agents`, and Detailer dispatches only Scout.
- Dispatch interface across agents: `argument-hint` is the single home of what a dispatch must carry; `## Input` restates it with semantics and adds nothing; a dispatcher's brief adds only what the hint cannot know and never describes the target's method; no body describes another agent's mechanics (Orchestrator's `Stage dispatches:` rule).
- Dispatch policy across agents: subagent dispatches needing none of one another's results or side effects form one batch issued in one tool-call block; a dispatch issued after another has returned runs alone; each body names its batches (the shared `Parallel dispatch:` rule).
- Language: Planner, Orchestrator, and Challenger share one `Language:` rule — replies and questions (options included) in the user's language, read from the user's own messages and never from a handoff prompt, naming anything referred to (stages, modules, waves, review gates, decisions, findings) by what it is, never by the plan's, the ledger's, or their own numbers or labels; nothing else is bound to it; commits, issues, and PR text keep the project's language (Coder's Commit step, Executor's PR and Issue rules).
