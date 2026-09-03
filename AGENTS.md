# AGENTS.md

Personal agent and skills repository — Markdown docs only, no application code.

## Structure

Only `.github/`, `skills/`, `agents/`, and dotfiles are tracked (plus root docs and `package.json`); everything else at the root is local runtime state excluded by the `.gitignore` whitelist.

### Skills

- Each skill lives in `skills/<name>/SKILL.md` with YAML frontmatter (`name`, `description`, `argument-hint`).
- `name` must match the folder name; quote `description` values containing colons.
- Detailed steps go in `skills/<name>/references/*.md`, linked from a task index in SKILL.md and loaded on demand.

### Agents

- Each agent lives in `agents/<name>.agent.md` with YAML frontmatter. Every agent has `name`, `description`, `argument-hint`, `model` (fallback list), `target`, and `agents` (dispatchable subagents); `tools`, `user-invocable`, `disable-model-invocation`, and `handoffs` are used where applicable.
- `handoffs` link user-invocable agents along meaningful transitions only and are all manual — never set `send: true`: Autopilot auto-fires the first `send` handoff after every response and can loop agents. Prompts are inserted verbatim (no `${…}` substitution) into the same session, so they name only what is handed over plus facts the target cannot see (e.g. ledger paths); the target agent's body supplies the method.
- The body holds only the agent's role, workflow, and rules.

## Checks

- `npm run check` — Prettier format check + markdownlint (run before committing).
- `npm run format` — auto-format all Markdown.
- CI (`.github/workflows/ci.yml`) runs `npm run check` on pushes to `master` and on all PRs.

## Conventions

- Keep docs minimal: SKILL.md holds only the workflow overview and task index; references hold only orchestration-critical detail; agent bodies hold only orchestration and necessary info.
- Write descriptions with concrete "Use when:" trigger phrases — they are the discovery surface.
