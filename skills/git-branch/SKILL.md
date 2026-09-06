---
name: git-branch
description: "Start a change on a correctly named branch off the latest default branch, in place or in its own worktree. Use when: starting a fix or feature, naming a branch, isolating parallel sessions or subagents."
argument-hint: "What the change is and the issue number if there is one; remote and default branch if not standard; whether this checkout must stay untouched"
---

# Git Branch

Branch off the latest upstream default branch. Never work on the default branch directly; one branch per logical change — in this checkout, or in its own worktree when the checkout must stay untouched.

## Starting State

```sh
git branch --show-current && git status --short
git rev-parse --path-format=absolute --show-toplevel   # <this-checkout>
git worktree list                                       # first line: <main-root>
```

Note the current branch and any dirty files. `<this-checkout>` ≠ `<main-root>` ⇒ already in a linked worktree: if it is this task's own (the path named in your dispatch), skip creation and report its path and branch; to isolate further tasks from inside it (parallel dispatches), use the worktree command below, which works from any checkout.

## Where

- **In place** — the default when the checkout is yours alone.
- **Own worktree** — when the checkout must stay untouched: it holds another session's dirty state, the work runs in parallel with other tasks or Coder subagents, or a plan is about to be executed. Created with `git worktree add` below.

## Naming

If the repo documents its own convention (CONTRIBUTING.md, recent merged PRs), follow that. Otherwise:

- Fixing one specific known issue → `issue/<number>` (e.g. `issue/1234`)
- Anything else → descriptive kebab-case with a type prefix, 2–4 words describing the change:

| Prefix      | Use for                           | Example                 |
| ----------- | --------------------------------- | ----------------------- |
| `fix/`      | Bug fix                           | `fix/nil-map-panic`     |
| `feat/`     | New feature or enhancement        | `feat/retry-backoff`    |
| `docs/`     | Documentation only                | `docs/install-steps`    |
| `refactor/` | Restructuring, no behavior change | `refactor/split-parser` |
| `test/`     | Adding or fixing tests            | `test/edge-cases`       |
| `chore/`    | Build, CI, deps, tooling          | `chore/bump-golangci`   |

## Branch

Fetch once — `<remote>` is `upstream` in a fork layout, `origin` in your own repo. Both commands use `--no-track`: a tracking upstream makes `git branch -d` refuse after a local merge (finish-branch).

```sh
git fetch <remote>
```

In place:

```sh
git checkout --no-track -b <branch> <remote>/<default-branch>
```

Own worktree, under `<main-root>/.worktrees/`:

```sh
git -C "<main-root>" check-ignore -q .worktrees || echo '/.worktrees' >> "$(git rev-parse --path-format=absolute --git-common-dir)/info/exclude"
git worktree add --no-track "<main-root>/.worktrees/<branch>" -b <branch> <remote>/<default-branch>
```

The exclude line keeps `.worktrees/` out of the repo without committing anything. The new worktree holds only committed files: copy ignored files the task needs (`.env`, local config) by hand and install dependencies fresh when there is a lockfile, then run the test suite once before changing anything. Failing baseline: ask whether to proceed; unattended, record it and continue.

Then continue with git-commit.

## Rules in a Worktree

- Run every command inside the worktree (`cd <path> && …` or `git -C <path>`) and edit only absolute paths under it — the main checkout and other worktrees belong to other sessions.
- Never `git stash` — the stash is shared by every worktree.
- One branch per worktree — git refuses to check out a branch another worktree already has.
- Commit before returning or handing off — uncommitted work is invisible elsewhere.
- `git worktree add` denied by a sandbox or permission prompt: say so; work in place only when nothing else shares the checkout, otherwise stop and report the blocker.
- When done, land with finish-branch, which returns the main root to the base branch and removes this worktree and its branch; commits, pushes, and PRs follow git-commit, git-push, and github-pr. A worktree left behind after its branch landed is a leak: once the task is over, `git worktree list` from the main root must no longer show it, and the `.worktrees/` directories it leaves empty (its `<prefix>/` dir, and `.worktrees/` itself after the last worktree) must be gone.
