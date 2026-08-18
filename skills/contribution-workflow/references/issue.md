# Issue

Self-contained: deciding whether one is needed, filling the template, creating, linking, verifying.

## Decide whether an Issue is needed

A PR does not always need a companion Issue. Create one only when at least one applies:

- The user explicitly asked for an Issue
- CONTRIBUTING.md or the PR template requires a linked Issue
- The change is a feature or behavior change — many projects expect design discussion in an Issue before reviewing a PR
- The problem is worth tracking independently of the fix (affects other users/versions)

Small self-explanatory fixes (typo, docs, obvious one-liner) usually go as a standalone PR — skip the Issue.

Only create a new Issue if a duplicate search comes up empty — an existing open Issue should be referenced with `Fixes #<N>` instead:

```sh
gh search issues --repo <upstream> "<error keywords>" | head
```

Non-duplicate hits from this search are `Related to #<N>` candidates for the body (see below).

## Ordering

When both an Issue and a PR are planned, create the **Issue first**, so the PR body can include `Fixes #<N>` and auto-close it on merge.

If the PR already exists, create the Issue, then back-link from the PR:

```sh
gh pr edit <num> --repo <upstream> --body-file <updated-body>
```

## Fill the template

Templates live in `.github/ISSUE_TEMPLATE/*.md` and `*.yml` — pick the type matching the change (bug/feature); check `config.yml` for `blank_issues_enabled`. Read the template file in full first.

- Keep **every** section heading; never drop or reorder sections
- Delete HTML comments (`<!-- ... -->`); replace placeholders with real content
- Checkbox checklists (`- [ ]`): tick items actually done, leave others unticked
- If no template exists, write a plain body
- Faithful ≠ verbose: a sentence or two per section is normal; write per [writing-style.md](./writing-style.md)

Body content depends on the type:

- **Bug**: what is broken, why (root cause), user-visible impact, how to reproduce (versions, exact commands, actual vs expected output)
- **Feature**: motivation — the concrete use case it unblocks, proposed behavior, alternatives/workarounds considered

Beyond the type basics, cover these when they apply — fold each into the matching template section (don't invent headings); use as light structure only when no template; skip what doesn't apply:

- **Expected outcome**: observable behavior once done — what "done" looks like
- **Verification**: how anyone can confirm the result — commands to run or acceptance criteria
- **Scope & out of scope**: what this Issue covers, and what's explicitly excluded
- **Difficulties**: known tricky points — constraints, edge cases, why the obvious fix falls short
- **Depends on**: blocking Issues/PRs — `Depends on #<N>` / `Blocked by #<N>` (plain references, unlike `Fixes` they never auto-close anything)
- **Related**: non-blocking context — `Related to #<N>`, e.g. non-duplicate hits from the duplicate search

**Form-style templates (`.yml`)** can't be filled via `--body-file` field-by-field; replicate the form's headings in a markdown body, or fall back to `--web`.

## Create

Write the body to a temp file and pass `--body-file` — avoids shell quoting/escaping bugs:

```sh
gh issue create --repo <upstream> --title "<title>" \
  --body-file /tmp/<repo>-issue-body.md [--label <bug|enhancement>]
```

- Title: concise symptom statement for a bug, the requested capability for a feature — matching the tone of recent real issues in the repo
- Label: only if the repo uses contributor-set labels (check recent issues); templates often apply their own via `labels:`
- Don't self-assign or add milestone/project — that's the maintainers' call

## Verify and report

- Confirm the URL and echo it to the user
- Reread the body once as a stranger would — if anything sounds templated or overstated, edit it down (`gh issue edit <num> --repo <upstream>`)
- Stop after creating; don't post extra comments or ping maintainers
