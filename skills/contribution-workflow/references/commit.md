# Commit

## Pre-commit checks

- Verify the change compiles / passes vet or lint BEFORE committing (trust the compiler, not stale IDE diagnostics)
- Don't run test suites locally — the PR's CI is the source of truth; push and watch it per the CI section of [pr.md](./pr.md). Run a single test locally only to reproduce a CI failure the logs can't explain
- Check `git --no-pager diff` — the diff must contain **only** the fix: no drive-by reformatting, import reshuffling, or whitespace churn in untouched lines
- Check `git status --short` — never commit unrelated files; stage specific paths, not `git add -A`

## Message and body

Voice and length rules: [writing-style.md](./writing-style.md).

Infer the message convention from recent history and match it (e.g. conventional commits, scope style):

```sh
git --no-pager log --oneline -10   # subject convention
git --no-pager log -3              # body style, DCO sign-offs
```

- Body (if the repo's log shows one): 1–3 plain sentences on root cause and approach — written like a note to a reviewer, not a changelog
- Add `-s` (Signed-off-by) if CONTRIBUTING.md or recent commits show DCO sign-offs
- One logical change = one commit; don't split a small fix into staged "progress" commits
