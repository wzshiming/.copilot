---
name: git-worktree
description: "Isolate a task in its own git worktree and branch so parallel sessions, Coder subagents, and the main checkout never touch each other's files; prefer the harness's native worktree option, fall back to plain git. Use when: starting work that must not disturb the current checkout, running several agent sessions or Coder subagents on one repo in parallel, the main checkout holds another session's dirty state, before executing an implementation plan."
argument-hint: "Branch or task name, base branch if not the default, and whether you already sit in a worktree"
---

# Git Worktree

Give each task its own working directory and branch so parallel sessions cannot touch each other's files or the main checkout.

## Detect

```sh
git rev-parse --path-format=absolute --git-dir --git-common-dir
```

Two different lines mean you are already in a linked worktree: skip creation and report its path and branch. If `git rev-parse --show-superproject-working-tree` prints a path you are inside a submodule — treat it as a normal checkout.

## Prefer the Harness's Native Option

These are user-side actions; an agent already mid-session cannot trigger them — tell the user, or fall back to git.

| Harness                                               | Option                                                                                                                                                                                                      |
| ----------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Copilot CLI                                           | `/worktree <branch>` (or `/worktree <task text>` to name the branch from the task), `/new-worktree <branch>` for a fresh conversation, `copilot -w <name>` at startup — the session moves into the worktree |
| VS Code Agents window                                 | Tick **New Worktree** and choose the base branch when starting the session (not available in the Chat view or with the Local harness)                                                                       |
| VS Code Chat view, Local harness, dispatched subagent | No native option — use the git fallback below                                                                                                                                                               |

## Git Fallback

```sh
GIT_TERMINAL_PROMPT=0 git fetch <remote>   # fail fast instead of hanging on a credential prompt
git check-ignore -q "$(git rev-parse --show-toplevel)/.worktrees" || echo '/.worktrees' >> "$(git rev-parse --path-format=absolute --git-common-dir)/info/exclude"
# --no-track: otherwise branch -d after a local merge checks <remote>/<default-branch> and refuses
git worktree add --no-track "$(git rev-parse --show-toplevel)/.worktrees/<branch>" -b <branch> <remote>/<default-branch>
```

- `<remote>` is `upstream` in a fork layout, `origin` otherwise; name the branch per git-branch.
- The exclude file keeps `.worktrees/` out of the repo without committing anything.
- The new worktree holds only committed files: copy ignored files the task needs (`.env`, local config) by hand and install dependencies fresh.

## Setup and Baseline

Install dependencies if a lockfile is present, then run the test suite once before changing anything. Failing baseline: ask whether to proceed; unattended, record it and continue.

## Rules

- Run every command inside the worktree (`cd <path> && …` or `git -C <path>`) and edit only absolute paths under it — the main checkout and other worktrees belong to other sessions.
- Never `git stash`: the stash is shared by every worktree of the repo.
- One branch per worktree — git refuses to check out a branch another worktree already has.
- Commit to the branch before returning or handing off; uncommitted work in a worktree is invisible elsewhere.
- If `git worktree add` is denied by a sandbox or permission prompt, say so and work in place.
- When the work is done, land it with finish-branch; commits, pushes, and PRs follow git-commit, git-push, and github-pr.
