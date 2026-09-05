---
name: git-worktree
description: "Isolate a task in its own worktree and branch so sessions never collide; harness-native or plain git. Use when: work must not disturb the current checkout, parallel sessions or Coder subagents, before executing a plan."
argument-hint: "Branch or task name, base branch if not the default, and whether you already sit in a worktree"
---

# Git Worktree

One working directory and branch per task, so parallel sessions never touch each other's files or the main checkout.

## Detect

```sh
git rev-parse --path-format=absolute --git-dir --git-common-dir
```

Two different lines ⇒ you are already in a linked worktree. If it is this task's own (created by the harness for this session, or the path named in your dispatch), skip creation and report its path and branch; to isolate further tasks from inside it (parallel dispatches), continue with the git fallback, which works from any checkout. `git rev-parse --show-superproject-working-tree` printing a path ⇒ inside a submodule; treat it as a normal checkout.

## Prefer the Harness's Native Option

These are user-side actions an agent mid-session cannot trigger: tell the user, or fall back to git.

- Copilot CLI: `/worktree <branch>` (or `/worktree <task text>` to name the branch from the task), `/new-worktree <branch>` for a fresh conversation, `copilot -w <name>` at startup — the session moves into the worktree.
- VS Code Agents window: tick **New Worktree** and choose the base branch when starting the session (not available in the Chat view or with the Local harness).
- VS Code Chat view, Local harness, dispatched subagent: no native option — use the git fallback.

## Git Fallback

`<main-root>` is the path on the first line of `git worktree list` — the main working tree, also when run from inside a linked worktree.

```sh
git fetch <remote>
git -C "<main-root>" check-ignore -q .worktrees || echo '/.worktrees' >> "$(git rev-parse --path-format=absolute --git-common-dir)/info/exclude"
# --no-track: otherwise branch -d after a local merge checks <remote>/<default-branch> and refuses
git worktree add --no-track "<main-root>/.worktrees/<branch>" -b <branch> <remote>/<default-branch>
```

- `<remote>` is `upstream` in a fork layout, `origin` otherwise; name the branch per git-branch.
- The exclude file keeps `.worktrees/` out of the repo without committing anything.
- The new worktree holds only committed files: copy ignored files the task needs (`.env`, local config) by hand and install dependencies fresh.

## Setup and Baseline

Install dependencies if a lockfile is present, then run the test suite once before changing anything. Failing baseline: ask whether to proceed; unattended, record it and continue.

## Rules

- Run every command inside the worktree (`cd <path> && …` or `git -C <path>`) and edit only absolute paths under it — the main checkout and other worktrees belong to other sessions.
- Never `git stash` — the stash is shared by every worktree.
- One branch per worktree — git refuses to check out a branch another worktree already has.
- Commit before returning or handing off — uncommitted work is invisible elsewhere.
- `git worktree add` denied by a sandbox or permission prompt: say so; work in place only when nothing else shares the checkout, otherwise stop and report the blocker.
- When done, land with finish-branch, which returns the main root to the base branch and removes this worktree and its branch; commits, pushes, and PRs follow git-commit, git-push, and github-pr. A worktree left behind after its branch landed is a leak: `git worktree list` from the main root must show only the main root once the task is over.
