---
name: github-issue
description: "Decide whether a GitHub Issue is needed and file one maintainers accept. Use when: filing a bug or feature request upstream, a PR template requires a linked Issue, linking `Fixes #N`."
argument-hint: "The bug or feature to report, the upstream repo, and whether a PR exists or will follow"
---

# GitHub Issue

## Decide whether an Issue is needed

Create one only when at least one applies:

- The user asked for an Issue
- CONTRIBUTING.md or the PR template requires a linked Issue
- A feature or behavior change — projects often expect design discussion in an Issue before reviewing a PR
- The problem is worth tracking independently of the fix (affects other users/versions)

Small self-explanatory fixes (typo, docs, obvious one-liner) skip the Issue.

Create only if the duplicate search is empty; otherwise reference the existing Issue — `Fixes #<N>` when the PR fully resolves it, `Part of #<N>` when it doesn't:

```sh
gh search issues --repo <upstream> "<error keywords>" | head
```

Non-duplicate hits become `Related to #<N>` candidates for the body.

## Ordering

Issue first, so the PR body can say `Fixes #<N>` and auto-close it on merge. If the PR already exists, create the Issue, then back-link from the PR:

```sh
gh pr edit <num> --repo <upstream> --body-file <updated-body>
```

## Fill the template

Templates live in `.github/ISSUE_TEMPLATE/*.md` and `*.yml` — pick the matching type (bug/feature); check `config.yml` for `blank_issues_enabled`. Read the template in full first.

- Keep every section heading; never drop or reorder sections
- Delete HTML comments (`<!-- ... -->`); replace placeholders with real content
- Tick checklist items (`- [ ]`) actually done; leave the rest unticked
- No template: write a plain body. Faithful ≠ verbose — a sentence or two per section is normal

Body by type — **bug**: what is broken, user-visible impact, how to reproduce (versions, exact commands, actual vs expected); **feature**: motivation (the concrete use case it unblocks), proposed behavior, alternatives/workarounds considered.

Fold these into the matching template section when they apply (don't invent headings; skip the rest):

- **Expected outcome**: what "done" looks like
- **Verification**: how anyone confirms it — commands or acceptance criteria
- **Scope & out of scope**: what's covered, what's explicitly excluded
- **Difficulties**: constraints, edge cases, why the obvious fix falls short
- **Depends on**: `Depends on #<N>` / `Blocked by #<N>` — plain references that never auto-close
- **Related**: `Related to #<N>`, e.g. non-duplicate search hits

`.yml` form templates can't be filled field-by-field via `--body-file`: replicate their headings in a markdown body, or fall back to `--web`.

## Voice

Applies to the body and to any follow-up comment the user asks for.

- First person, plain and direct: one line on how you hit it, then the substance; write in the project's language (usually English) even when the conversation isn't
- Match the register of recent Issues in the repo (`gh issue list --repo <upstream> --state all --limit 5 | cat`) — mirror their length and tone
- Paste only real output — exact error text, versions, commands and test runs you actually ran; say so if you didn't run something; never invent repro steps or logs
- The Issue states the problem or use case; root cause and fix approach belong in the PR — the two bodies shouldn't read as copies. No bold, emoji, or headings the template didn't ask for; no filler openers ("This issue aims to…", "comprehensive", "robust"); optional sections get "N/A"/"NONE", not invented content; admit real uncertainty ("might be my config — happy to be corrected")

## Create

Body from a temp file via `--body-file` — avoids shell quoting bugs:

```sh
gh issue create --repo <upstream> --title "<title>" \
  --body-file /tmp/<repo>-issue-body.md [--label <bug|enhancement>]
```

- Title: concise symptom (bug) or requested capability (feature), in the tone of recent real issues
- Label only if the repo uses contributor-set labels (check recent issues); templates often apply their own via `labels:`
- Don't self-assign, @-mention maintainers, or add milestone/project — the maintainers' call

## Verify and report

- Confirm the URL and echo it to the user
- Reread the body as a stranger would; edit anything templated or overstated down: `gh issue edit <num> --repo <upstream> --body-file <file>`
- Stop after creating; don't post extra comments
