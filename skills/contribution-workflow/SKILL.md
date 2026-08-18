---
name: contribution-workflow
description: "End-to-end open-source contribution flow: commit a fix on a new branch, push to fork, create a PR (and a linked Issue when the project requires one) following the repo templates. Use when: submit fix upstream, create pull request from fork, fill PR/issue template, link issue to PR (Fixes #N)."
argument-hint: "Describe the fix and whether you need branch/commit, PR, Issue, or all"
---

# Contribution Workflow

Submit a local fix to an upstream repo the way maintainers expect: correct branch/commit conventions, template-faithful PR and Issue bodies, and proper cross-linking.

## When to Use

- A fix exists locally (or was just made) and needs to be committed on a new branch and submitted upstream
- User asks to "create a PR following the project template"
- Fork-based workflow: `origin` = personal fork, `upstream` = canonical repo

## Task Index

Load each reference only when performing that task; skip tasks that don't apply. Read `CONTRIBUTING.md` (repo root, `.github/`, or `docs/`) early — it drives branch rules, tests, DCO, and whether an Issue is required.

| Task              | Load                                | Covers                                                                                                                                                                                                           |
| ----------------- | ----------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Branch            | [branch.md](./references/branch.md) | Starting-state check, branch naming                                                                                                                                                                              |
| Commit            | [commit.md](./references/commit.md) | Pre-commit verification, minimal-diff check, commit convention from `git log`, DCO sign-off                                                                                                                      |
| Push              | [push.md](./references/push.md)     | Remotes (fork vs upstream), `gh auth`, push target: own repo vs fork, force-sync fork with upstream, creating a fork if missing                                                                                  |
| Issue (if needed) | [issue.md](./references/issue.md)   | Duplicate search, whether an Issue is needed at all, Issue-before-PR ordering, filling `.md`/`.yml` issue templates, `gh issue create`, verification                                                             |
| PR                | [pr.md](./references/pr.md)         | Duplicate PR search, filling the PR template (`/kind`, `release-note`, checklists), cross-fork `gh pr create`, `Fixes #N` linking, CI watch-and-fix loop (`gh pr checks --watch`), verification, final tone pass |

Shared reference: [writing-style.md](./references/writing-style.md) — voice and length rules for all written output (commit messages, Issue/PR bodies); loaded from commit, Issue, and PR.
