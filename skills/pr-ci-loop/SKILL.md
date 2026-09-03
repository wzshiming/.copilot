---
name: pr-ci-loop
description: "Use the PR's CI as the test run: watch checks after each push, pull the failing job log, diagnose from the log, push a follow-up fix, repeat. Use when: a PR's checks are failing, waiting on CI after a push, deciding whether to reproduce a CI failure locally."
argument-hint: "PR number and upstream repo"
---

# PR CI Loop

Don't run the project's test suites locally — the PR's CI is the source of truth.

Run this before any `git`/`gh` command (re-run in each new shell) so commands fail fast instead of hanging on credential prompts, editors, or pagers:

```sh
export GIT_TERMINAL_PROMPT=0 GIT_EDITOR=true GH_PROMPT_DISABLED=1 GH_PAGER=cat GH_NO_UPDATE_NOTIFIER=1;
```

After creating the PR (or pushing new commits to it), watch the checks until they finish:

```sh
gh pr checks <number> --repo <upstream> --watch --interval 30 2>&1 | tail -5
```

On a failure, pull the log instead of rerunning anything locally:

```sh
gh pr checks <number> --repo <upstream>                                # failing check → run/job URL
gh run view --job <job-id> --repo <upstream> --log-failed | tail -120  # failing tests + errors
```

Diagnose from the log first; reproduce a single failing test locally only when the log isn't enough. Fix and push a follow-up commit to the same branch (don't amend + force-push mid-review unless the repo convention asks for squashed commits) — CI restarts on its own — then watch again. If the fix invalidates anything the PR body claims, update it with `gh pr edit`.
