---
name: pr-ci-loop
description: "Use the PR's CI as the test run. Use when: a PR's checks are failing, waiting on CI after a push, deciding whether to reproduce a CI failure locally."
argument-hint: "PR number and upstream repo"
---

# PR CI Loop

The PR's CI runs the full suite and is the merge gate: a tree is verified by CI as soon as it is on a PR, so locally run only the targeted tests the change touches, never the full suite again after a push.

After creating the PR (or pushing new commits to it), watch the checks until they finish:

```sh
gh pr checks <number> --repo <upstream> --watch --fail-fast --interval 30 | cat
```

The pipe does two jobs: with stdout not a TTY, gh reprints the table each interval instead of opening an alternate screen, and that output every 30 s keeps an agent terminal from being moved to the background after 5 silent minutes — so never redirect the watch to a file. Read the outcome from the final table (pass, fail, or pending per check), not from the exit code. Right after a push, `no checks reported on the '<branch>' branch` means Actions has not registered the run yet: `sleep 30` and watch again.

Wait 30 minutes by default, or until the deadline the dispatch sets; checks still pending then are reported as pending, and the dispatcher decides whether to keep waiting or fall back to a local full run. When CI is unreachable — the tree is on no PR, a fork PR's workflows await maintainer approval, or no check appeared by the deadline — fall back to one local full run.

On a failure, pull the log instead of rerunning anything locally:

```sh
gh pr checks <number> --repo <upstream> | cat                          # failing check → run/job URL
gh run view --job <job-id> --repo <upstream> --log-failed | tail -120  # failing tests + errors
```

Diagnose from the log first; reproduce a single failing test locally only when the log isn't enough. Fix, commit per git-commit, and push the follow-up to the same branch (don't amend + force-push mid-review unless the repo convention asks for squashed commits) — CI restarts on its own — then watch again. After 3 fix-and-push rounds without a green run, stop pushing and report the log excerpt with your diagnosis instead. If the fix invalidates anything the PR body claims, update it with `gh pr edit <number> --repo <upstream> --body-file <file>`. Once checks are green and the work is complete, drop the `[WIP]` prefix from the title (`gh pr edit <number> --repo <upstream> --title "<title>"`).
