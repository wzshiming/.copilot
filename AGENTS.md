# AGENTS.md

Personal agent and skills repository — Markdown docs only, no application code.

## Structure

Only `.github/`, `skills/`, `agents/`, dotfiles, root Markdown docs, `LICENSE`, and `Makefile` are tracked; everything else at the root is local runtime state excluded by the `.gitignore` whitelist.

### Skills

- Each skill lives in `skills/<name>/SKILL.md` with YAML frontmatter (`name`, `description`, `argument-hint`).
- `name` must match the folder name; quote `description` values containing colons.
- Each skill is self-contained in its SKILL.md. Split a multi-step flow into separate skills and refer to them by plain name in body text (there is no `skills:` frontmatter).

### Agents

- Each agent lives in `agents/<name>.agent.md` with YAML frontmatter. Every agent has `name`, `description`, `argument-hint`, `model` (fallback list), `target`, and `agents` (dispatchable subagents); `tools`, `user-invocable`, `disable-model-invocation`, and `handoffs` are used where applicable.
- `handoffs` link user-invocable agents along meaningful transitions only and are all manual — never set `send: true`: Autopilot auto-fires the first `send` handoff after every response and can loop agents. Prompts are inserted verbatim (no `${…}` substitution) into the same session, so they name only what is handed over plus facts the target cannot see (e.g. ledger paths); the target agent's body supplies the method.
- The body holds only the agent's role, workflow, and rules.
- Challenger, Examiner, and Reviewer share one verbatim `## Constraints` block (Scout carries its auto-approval bullet); there is no include mechanism, so edit every copy together.

## Checks

- `make check` — Prettier format check + markdownlint (run before committing).
- `make format` — auto-format all Markdown.
- CI (`.github/workflows/ci.yml`) runs `make check` on pushes to `master` and on all PRs.

## Conventions

- Keep docs minimal: SKILL.md holds only the workflow and its commands; agent bodies hold only orchestration and necessary info — never rules the harness base prompt already states.
- Skills and model-invocable agents (no `disable-model-invocation: true`) carry concrete "Use when:" trigger phrases in `description` — that is the discovery surface. Every `description` is at most 35 words: one role clause, then `Use when:` with up to three triggers. Keep model names out of descriptions; they live in `model:` and the body.
- Keep shell snippets auto-approvable and self-contained: no `export …;` preambles or `VAR=… cmd` prefixes, no zsh-only syntax; shell variables only in steps that need approval anyway. Guards are flags, not environment: `-m`/`-F` and `--no-edit`/`--ff-only` instead of `GIT_EDITOR`, `-c core.editor=true rebase --continue`, `git --no-pager`, a flag for every value `gh` would prompt for, and a pipe (`| cat` or a filter) on `gh` output (it pages whenever the shell sets `PAGER`). Credential prompts need no guard: agent terminals carry VS Code's `GIT_ASKPASS` or `GIT_TERMINAL_PROMPT=0`.
- Testing policy across skills: baseline once per worktree (git-worktree), tests for the change while implementing (test-driven-development), no full-suite requirement per commit (git-commit), the PR's CI as the merge gate (pr-ci-loop), one full run on the exact tree before landing (finish-branch).
