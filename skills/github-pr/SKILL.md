---
name: github-pr
description: "Open a pull request the way the repo expects: duplicate PR check, faithful template filling (`/kind`, `release-note`, checklists), cross-fork `gh pr create --body-file`, `WIP:` titles, `Fixes #N` linking, post-create verification. Use when: creating a PR from a pushed branch, filling a PR template, opening a cross-fork PR, linking a PR to an Issue."
argument-hint: "Branch, upstream repo, related Issue number if any, and whether the work is still WIP"
---

# Pull Request

Fill the PR template faithfully, create the PR cross-fork, link the Issue, and verify the result.

Run this before any `gh` command (re-run in each new shell) so commands fail fast instead of hanging on prompts or pagers:

```sh
export GH_PROMPT_DISABLED=1 GH_PAGER=cat GH_NO_UPDATE_NOTIFIER=1;
```

Prerequisites: the branch is pushed (per git-push). If a related Issue is warranted, create it first per github-issue so `Fixes #<N>` links at creation time.

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
- Faithful ≠ verbose: a sentence or two per section is normal

Body content depends on the type — **bug fix**: what was broken, why (root cause), user-visible impact, how the fix works; **feature**: motivation (the concrete use case it unblocks) and how the design works.

## Voice

Applies to the body and to any follow-up comment the user asks for.

- First person, plain and direct: one line of how you ran into it, then the change; write in the project's language (usually English) even when the conversation isn't
- Match the register of 2–3 recently merged PRs (`gh pr list --repo <upstream> --state merged --limit 3`) — mirror their length and tone. Default short: a one-line fix gets a one-paragraph body (a sentence per template section), not five sections of prose
- The diff speaks for itself: explain _why_ (root cause or design, approach) instead of restating the change line by line; anchor claims in file/line, exact error text, versions, commit hashes
- Paste only real output — test runs and logs you actually produced; if you didn't run it, say so
- The PR explains the change; the Issue states the problem — don't paste one body into the other
- Don't bullet-point everything; no bold keywords, emoji, or headings the template didn't ask for; no filler ("This PR introduces/aims to…", "Additionally", "comprehensive", "robust", "seamlessly"); optional sections get "N/A"/"NONE", not invented content
- Admit real uncertainty ("not sure this is the best place for the check — happy to move it")

## Create (cross-fork)

Write the body to a temp file and pass `--body-file` — avoids shell quoting/escaping bugs:

```sh
gh pr create --repo <upstream> --head <fork-owner>:<branch> --base <default-branch> \
  --title "<same convention as commit message>" --body-file /tmp/<repo>-pr-body.md
```

- Never push to upstream; the PR goes cross-fork via `--head`
- Own repo with write access (branch pushed directly, per git-push): drop `--repo` and `--head`
- Title: imperative, ≤ ~70 chars, same convention as the commit subjects (`git --no-pager log --oneline -10`)
- Unfinished work: create the PR anyway to use its CI as the test run — prefix the title with `WIP:`, then remove the prefix (`gh pr edit --title`) once it's ready for review
- If there is a related Issue (new or existing), set `Fixes #<N>` in the body with the real number; if none, drop any `Fixes #<N>` placeholder
- Don't self-assign, @-mention or request reviewers, or add milestone/project — that's the maintainers' call

## Verify and report

- Confirm the URL and echo it to the user
- Watch CI to completion per pr-ci-loop and report the final check status
- If the body references an Issue, check `Fixes #N` actually links (visible in PR sidebar via `gh pr view <num> --repo <upstream>`)
- Reread the body once as a stranger would — if anything sounds templated or overstated, edit it down (`gh pr edit <num> --repo <upstream>`)
- Stop after creating; don't post extra comments on your own PR
