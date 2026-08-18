# AGENTS.md

Personal agent skills repository — Markdown docs only, no application code.

## Structure

- Each skill lives in `skills/<name>/SKILL.md` with YAML frontmatter (`name`, `description`, `argument-hint`).
- `name` must match the folder name; quote `description` values containing colons.
- Detailed steps go in `skills/<name>/references/*.md`, linked from a task index in SKILL.md and loaded on demand.

## Checks

- `npm run check` — Prettier format check + markdownlint (run before committing).
- `npm run format` — auto-format all Markdown.

## Conventions

- Keep docs minimal: SKILL.md holds only the workflow overview and task index; references hold only orchestration-critical detail.
- Write descriptions with concrete "Use when:" trigger phrases — they are the discovery surface.
