---
name: pr-ci-loop
description: "Use the PR's CI as the test run: watch, pull failing logs, fix, repeat. Use when: a PR's checks are failing, waiting on CI after a push, deciding whether to reproduce a CI failure locally."
argument-hint: "PR number and upstream repo"
---

# PR CI Loop

Once the PR is open, its CI is the merge gate: watch it instead of re-running the full suite locally after every push.

After creating the PR (or pushing new commits to it), watch the checks until they finish — no pipe, so the exit code survives (non-zero on failure):

```sh
gh pr checks <number> --repo <upstream> --watch --fail-fast --interval 30
```

On a failure, pull the log instead of rerunning anything locally:

```sh
gh pr checks <number> --repo <upstream> | cat                          # failing check → run/job URL
gh run view --job <job-id> --repo <upstream> --log-failed | tail -120  # failing tests + errors
```

Diagnose from the log first; reproduce a single failing test locally only when the log isn't enough. Fix, commit per git-commit, and push the follow-up to the same branch (don't amend + force-push mid-review unless the repo convention asks for squashed commits) — CI restarts on its own — then watch again. After 3 fix-and-push rounds without a green run, stop pushing and report the log excerpt with your diagnosis instead. If the fix invalidates anything the PR body claims, update it with `gh pr edit <number> --repo <upstream> --body-file <file>`. Once checks are green and the work is complete, drop the `[WIP]` prefix from the title (`gh pr edit <number> --repo <upstream> --title "<title>"`).
