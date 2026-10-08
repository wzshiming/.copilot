# AGENTS.md

Personal agent and skills repository — Markdown docs only, no application code.

## Structure

Only `.github/`, `skills/`, `agents/`, dotfiles, root Markdown docs, `LICENSE`, and `Makefile` are tracked; everything else at the root is local runtime state excluded by the `.gitignore` whitelist.

### Skills

- Each skill lives in `skills/<name>/SKILL.md` with YAML frontmatter (`name`, `description`, `argument-hint`).
- `name` must match the folder name; quote `description` values containing colons.
- Each skill is self-contained in its SKILL.md. Split a multi-step flow into separate skills and refer to them by plain name in body text (there is no `skills:` frontmatter).

### Agents

- Each agent lives in `agents/<name>.agent.md` with YAML frontmatter. Every agent has `name`, `description`, `argument-hint`, `model` (fallback list), and `agents` (dispatchable subagents); `tools`, `user-invocable`, `disable-model-invocation`, and `handoffs` are used where applicable.
- `handoffs` link user-invocable agents along meaningful transitions only and are all manual — never set `send: true`: Autopilot auto-fires the first `send` handoff after every response and can loop agents. Prompts are inserted verbatim (no `${…}` substitution) into the same session, so they name only what is handed over plus facts the target cannot see (e.g. ledger paths); the target agent's body supplies the method.
- The body holds only the agent's role, workflow, and rules.
- Challenger, Examiner, and Reviewer share one verbatim `## Constraints` block (Scout carries its auto-approval bullet); there is no include mechanism, so edit every copy together.

## Checks

- `make check` — Prettier format check + markdownlint.
- `make format` — auto-format all Markdown.
- Local Markdown checks and formatting (these targets or their pinned `npx` commands on specific files) may run without asking.
- CI (`.github/workflows/ci.yml`) runs `make check` on pushes to `master` and on all PRs.

## Conventions

- Keep docs minimal: SKILL.md holds only the workflow and its commands; agent bodies hold only orchestration and necessary info — never rules the harness base prompt already states.
- Agent bodies open with one sentence in normal case, `You are the <role>: <mission>.` (Examiner, one of three in parallel, says `a <role>`) — no shouted words.
- Agent body sections are H2 only, one per name, in this order and only when needed: Input, Constraints, Approach (a subagent's checklist) or Workflow (the Orchestrator's and Planner's phase loop), Rules, Output Format.
- List items are fragments or single sentences without a terminal period — split an item rather than write two sentences in it; only Workflow phase items are paragraphs with a bold `**Phase**:` label and full punctuation, every other label is plain `Label:`.
- Emphasis: `_Agent_` italics for agent names, bold only for Workflow phase names — their labels and references back to them — and a body's key-fact line (`**Ledger**`, `**Current plan**`), backticks for paths and commands, `#tool:` for tools, skills by plain name; a list's lead-in sentence ends with a colon.
- Skills and model-invocable agents (no `disable-model-invocation: true`) carry concrete "Use when:" trigger phrases in `description` — that is the discovery surface. Every `description` is at most 35 words, shorter preferred: one outcome clause (what it does, not its steps), then `Use when:` with up to three triggers specific to the task rather than universal ones. Keep model names out of descriptions; they live in `model:` and the body.
- Keep shell snippets auto-approvable and self-contained: no `export …;` preambles or `VAR=… cmd` prefixes, no zsh-only syntax; shell variables only in steps that need approval anyway. Guards are flags, not environment: `-m`/`-F` and `--no-edit`/`--ff-only` instead of `GIT_EDITOR`, `-c core.editor=true rebase --continue`, `git --no-pager`, a flag for every value `gh` would prompt for, and a pipe (`| cat` or a filter) on `gh` output (it pages whenever the shell sets `PAGER`). Credential prompts need no guard: agent terminals carry VS Code's `GIT_ASKPASS` or `GIT_TERMINAL_PROMPT=0`.
- Testing policy across skills: baseline once per worktree (git-branch), tests for the change while implementing (test-driven-development), no full-suite requirement per commit (git-commit), the PR's CI as the merge gate (pr-ci-loop), one full run on the exact tree before landing (finish-branch).
- Design policy across agents: every change is designed from the whole — the existing design is restructured so the change reads as designed in from the start, never a patch bolted on (special case, flag, wrapper, duplicated path, suppressed symptom); a compatibility layer (shim, adapter, dual path) needs an explicit compatibility requirement, stated by the user or plan or established from codebase facts such as a published API or external callers, and recorded; working code is the floor, not the bar; the restructuring a change needs is in scope, unrelated tidying stays scope creep. Planner designs it, Coder and Orchestrator implement it, Reviewer, Challenger, and Examiner judge it; edit every copy together.
