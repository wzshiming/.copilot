---
name: git-commit
description: "Commit one logical change with a minimal diff and a message matching the repo's history: pre-commit build/lint check, stage specific paths, convention from `git log`, DCO sign-off. Use when: committing a fix, writing a commit message, deciding what to stage."
argument-hint: "What changed and why; the repo's commit convention or DCO requirement if already known"
---

# Git Commit

Commit one logical change with a minimal diff and a message that matches the repo's history.

Run this before `git commit` (re-run in each new shell) so a commit without `-m`/`-F` fails fast instead of hanging in an editor:

```sh
export GIT_EDITOR=true;
```

## Pre-commit checks

- Verify the change compiles / passes vet or lint BEFORE committing (trust the compiler, not stale IDE diagnostics)
- Don't run test suites locally — the PR's CI is the source of truth; push and watch it per pr-ci-loop. Run a single test locally only to reproduce a CI failure the logs can't explain
- Check `git --no-pager diff` — the diff must contain **only** the fix: no drive-by reformatting, import reshuffling, or whitespace churn in untouched lines
- Check `git status --short` — never commit unrelated files; stage specific paths, not `git add -A`

## Message and body

Infer the message convention from recent history and match it (e.g. conventional commits, scope style):

```sh
git --no-pager log --oneline -10   # subject convention
git --no-pager log -3              # body style, DCO sign-offs
```

- Subject: imperative, ≤ ~70 chars, in the project's language (usually English) even when the conversation isn't
- Body (if the repo's log shows one): 1–3 plain sentences on root cause and approach — written like a note to a reviewer, not a changelog. The diff shows _what_ changed; say _why_, anchored in facts (exact error text, `#<N>`, a commit hash); mention a test only if you ran it
- No bullets, bold, emoji, or filler ("This commit introduces…", "comprehensive", "robust")
- Add `-s` (Signed-off-by) if CONTRIBUTING.md or recent commits show DCO sign-offs
- One logical change = one commit; don't split a small fix into staged "progress" commits
