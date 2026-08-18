# PR

Self-contained: filling the template, creating cross-fork, linking the Issue, verifying.

Prerequisites: the branch is pushed (per [push.md](./push.md)). If a related Issue is warranted, create it first per [issue.md](./issue.md) so `Fixes #<N>` links at creation time.

Check for an existing PR for the same fix first — if one exists, stop and tell the user; commenting there may beat a duplicate PR:

```sh
gh search prs --repo <upstream> "<error keywords>" | head
```

## Fill the template

Templates live in `.github/PULL_REQUEST_TEMPLATE.md`, `.github/PULL_REQUEST_TEMPLATE/*.md`, `docs/pull_request_template.md`, or the repo root. Read the template file in full first.

- Keep **every** section heading; never drop or reorder sections
- Delete HTML comments (`<!-- ... -->`); replace placeholders with real content
- Checkbox checklists (`- [ ]`): tick items actually done, leave others unticked
- Fill repo-specific directives the template asks for (e.g. `/kind bug`, `release-note` block)
- If no template exists, write a plain body
- Faithful ≠ verbose: a sentence or two per section is normal; write per [writing-style.md](./writing-style.md)

Body content depends on the type — **bug fix**: what was broken, why (root cause), user-visible impact, how the fix works; **feature**: motivation (the concrete use case it unblocks) and how the design works.

## Create (cross-fork)

Write the body to a temp file and pass `--body-file` — avoids shell quoting/escaping bugs:

```sh
gh pr create --repo <upstream> --head <fork-owner>:<branch> --base <default-branch> \
  --title "<same convention as commit message>" --body-file /tmp/<repo>-pr-body.md
```

- Never push to upstream; the PR goes cross-fork via `--head`
- Own repo with write access (branch pushed directly, per [push.md](./push.md)): drop `--repo` and `--head`
- Title: reuse the commit message convention observed in `git log`
- If there is a related Issue (new or existing), set `Fixes #<N>` in the body with the real number; if none, drop any `Fixes #<N>` placeholder
- Don't self-assign, request reviewers, or add milestone/project — that's the maintainers' call

## CI is the test run

Don't run the project's test suites locally — the PR's CI is the source of truth. After creating the PR (or pushing new commits to it), watch the checks until they finish; `GH_PAGER=cat` avoids getting stuck in a pager:

```sh
GH_PAGER=cat gh pr checks <number> --watch --interval 30 2>&1 | tail -5
```

On a failure, pull the log instead of rerunning anything locally:

```sh
GH_PAGER=cat gh pr checks <number>                    # failing check → run/job URL
gh run view --job <job-id> --log-failed | tail -120   # failing tests + errors
```

Diagnose from the log first; reproduce a single failing test locally only when the log isn't enough. Fix and push a follow-up commit to the same branch (don't amend + force-push mid-review unless the repo convention asks for squashed commits) — CI restarts on its own — then watch again. If the fix invalidates anything the PR body claims, update it with `gh pr edit`.

## Verify and report

- Confirm the URL and echo it to the user
- Watch CI to completion (see "CI is the test run") and report the final check status
- If the body references an Issue, check `Fixes #N` actually links (visible in PR sidebar via `gh pr view`)
- Reread the body once as a stranger would — if anything sounds templated or overstated, edit it down (`gh pr edit <num> --repo <upstream>`)
- Stop after creating; don't post extra comments on your own PR or ping maintainers for review
