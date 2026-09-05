---
name: github-pr
description: "Open a pull request the way the repo expects: faithful template, cross-fork creation, Issue linking, verification. Use when: creating a PR from a pushed branch, opening a cross-fork PR, linking a PR to an Issue."
argument-hint: "Branch, upstream repo, related Issue number if any, and whether the work is still WIP"
---

# Pull Request

Prerequisites: the branch is pushed (git-push); a related Issue, if warranted, exists first (github-issue) so `Fixes #<N>` links at creation.

An open PR for the same fix: stop and tell the user — commenting there may beat a duplicate PR. Closed PRs don't block, but a merged one may mean the fix already landed — check `upstream/<base>`:

```sh
gh search prs --repo <upstream> --state open "<error keywords>" | head
```

## Fill the template

Templates live in `.github/PULL_REQUEST_TEMPLATE.md`, `.github/PULL_REQUEST_TEMPLATE/*.md`, `docs/pull_request_template.md`, or the repo root. Read the template in full first.

- Keep every section heading; never drop or reorder sections
- Delete HTML comments (`<!-- ... -->`); replace placeholders with real content
- Tick checklist items (`- [ ]`) actually done; leave the rest unticked
- Fill repo-specific directives the template asks for (e.g. `/kind bug`, `release-note` block)
- No template: write a plain body. Faithful ≠ verbose — a sentence or two per section is normal

Body by type — **bug fix**: what was broken, why (root cause), user-visible impact, how the fix works; **feature**: motivation (the concrete use case) and how the design works.

## Voice

Applies to the body and to any follow-up comment the user asks for.

- First person, plain and direct: one line on how you hit it, then the substance; write in the project's language (usually English) even when the conversation isn't
- Match the register of 2–3 recently merged PRs (`gh pr list --repo <upstream> --state merged --limit 3 | cat`) — mirror their length and tone; default short — a one-line fix gets a one-paragraph body, a sentence per template section
- Paste only real output — exact error text, versions, commands and test runs you actually ran; say so if you didn't run something; never invent repro steps or logs. The diff speaks for itself: explain _why_ (root cause or design), anchored in file/line, error text, versions, commit hashes — don't restate the change line by line
- The PR explains the change; the Issue states the problem — the two bodies shouldn't read as copies. No bold, emoji, or headings the template didn't ask for; no filler openers ("This PR aims to…", "comprehensive", "robust"); optional sections get "N/A"/"NONE", not invented content; admit real uncertainty ("might be my config — happy to be corrected")

## Create (cross-fork)

Body from a temp file via `--body-file` — avoids shell quoting bugs:

```sh
gh pr create --repo <upstream> --head <fork-owner>:<branch> --base <base> \
  --title "<same convention as commit message>" --body-file /tmp/<repo>-pr-body.md
```

- `<base>` is the branch the work split from, confirmed as in finish-branch; unattended, use the default branch and say so
- Never push to upstream; the PR goes cross-fork via `--head`
- Own repo with write access (pushed directly, per git-push): drop `--repo` and `--head`
- Title: imperative, ≤ ~70 chars, same convention as the commit subjects (`git --no-pager log --oneline -10`)
- Unfinished work: create anyway to use CI as the test run — `WIP:` title prefix, removed with `gh pr edit --title` when ready
- `Fixes #<N>` only for an Issue the PR fully resolves (auto-closes on merge); partial or context → `Part of #<N>` / `Related to #<N>`; no Issue → drop any `Fixes` placeholder
- Don't self-assign, @-mention or request reviewers, or add milestone/project — the maintainers' call

## Verify and report

- Confirm the URL and echo it to the user
- Watch CI to completion per pr-ci-loop and report the final status
- If the body says `Fixes #N`, `gh pr view <num> --repo <upstream> --json closingIssuesReferences --jq '.closingIssuesReferences[].number' | cat` must print N
- Reread the body as a stranger would; edit anything templated or overstated down: `gh pr edit <num> --repo <upstream> --body-file <file>`
- Stop after creating; don't post extra comments on your own PR
