# Branch

Branch off the latest upstream default branch. Never work on the default branch directly; one branch per logical change.

Check the starting state first — note the current branch and any dirty files:

```sh
git branch --show-current && git status --short
```

Fetch and branch from the latest default branch — `<remote>` is `upstream` in a fork layout, `origin` in your own repo:

```sh
git fetch <remote>
git checkout -b <branch> <remote>/<default-branch>
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
