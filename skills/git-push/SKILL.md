---
name: git-push
description: "Push a branch to the right remote: own repo vs fork layout, `gh auth`, rebase onto the live upstream base, `--force-with-lease --force-if-includes`, create a fork when missing, check write permission. Use when: pushing a branch before a PR, push rejected after a rebase, unsure whether to push to origin or a fork."
argument-hint: "Branch to push and whether the repo is your own or a fork layout, if known"
---

# Git Push

Push the branch to the remote a PR can be opened from: the canonical repo when you have write access, your fork otherwise.

Identify the repo layout and confirm auth first:

```sh
git --no-pager remote -v   # identify fork (origin) vs upstream layout
gh auth status             # confirm account and auth
```

`<base>` below is the branch the work split from, confirmed as in finish-branch: the plan, the conversation, or an open PR names it; otherwise ask — unattended, use the default branch and say so. The push target depends on whose repo it is:

## Your own repo (write access)

`origin` is the canonical repo — push the branch directly:

```sh
git push -u origin <branch>
```

## Someone else's repo (fork workflow)

Rebase onto the live upstream base first so the PR opens without conflicts. The fork's own copy of `<base>` is irrelevant — the PR compares against `upstream` — so never reset it remotely: `gh repo sync --force` hard-resets the fork's branch and destroys commits that exist only there.

```sh
git fetch upstream
git rebase upstream/<base>   # inside the branch's checkout or worktree
```

If the rebase hits conflicts, stop and resolve them locally before pushing: fix the files, `git add` them, then `git -c core.editor=true rebase --continue` — it keeps each commit's original message instead of opening an editor.

Then push to your fork (`origin`), never to `upstream`:

```sh
git push -u origin <branch>
```

If the branch was already pushed before the rebase, plain push is rejected — use `git push --force-with-lease --force-if-includes origin <branch>` (never bare `--force`): the lease alone is defeated by any background `git fetch origin`, and `--force-if-includes` additionally refuses when the remote branch gained commits you haven't integrated, such as maintainer edits.

If no fork exists yet:

```sh
gh repo fork --remote   # creates fork; sets origin = fork, upstream = canonical repo
git push -u origin <branch>
```

## Unsure which case?

Target the canonical repo explicitly — bare `gh repo view` may resolve to your fork and always report `ADMIN`:

```sh
gh repo view <upstream-owner>/<repo> --json viewerPermission -q .viewerPermission | cat
```

`WRITE`/`ADMIN` → push directly; `READ`/none → fork workflow.
