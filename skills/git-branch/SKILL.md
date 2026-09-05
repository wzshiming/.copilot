---
name: git-branch
description: "Start a change on a correctly named branch off the latest default branch: starting-state check, fetch, `checkout -b`, naming convention (type prefix or `issue/<N>`). Use when: starting a fix or feature in a repo, naming a branch, branching off upstream in a fork layout."
argument-hint: "What the change is and the issue number if there is one; remote and default branch if not standard"
---

# Git Branch

Branch off the latest upstream default branch. Never work on the default branch directly; one branch per logical change.

Check the starting state first — note the current branch and any dirty files:

```sh
git branch --show-current && git status --short
```

If this checkout must stay untouched — it holds another session's dirty state, or the work runs in parallel with other tasks — create the branch in its own worktree with git-worktree instead of `git checkout -b` below, then continue with git-commit.

Fetch and branch from the latest default branch — `<remote>` is `upstream` in a fork layout, `origin` in your own repo:

```sh
git fetch <remote>
# --no-track: a tracking upstream makes `git branch -d` refuse after a local merge (finish-branch)
git checkout --no-track -b <branch> <remote>/<default-branch>
```

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
