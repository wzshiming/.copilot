---
name: finish-branch
description: "Land a finished branch — push and open a PR, merge locally, or keep it as-is — then remove only the worktrees we created; discarding is never offered unprompted. Use when: implementation on a branch or worktree is complete and tests pass, deciding how to land agent work, cleaning up a task worktree after its PR merged."
argument-hint: "Branch or worktree to finish, its base branch if known, and whether a PR is wanted"
---

# Finish Branch

Integrate a finished branch the way the user chooses and remove only the worktrees git-worktree created.

## Steps

1. **Verify** — run the full suite on the exact tree you are about to integrate (verification-before-completion). Red: report and stop — the options come after green.

2. **Detect** — before any `cd`, capture where you are:

   ```sh
   git rev-parse --path-format=absolute --show-toplevel   # <worktree-path>
   git worktree list                                       # first line: <main-root>
   git branch --show-current
   ```

   `<worktree-path>` ≠ `<main-root>` ⇒ linked worktree, and the main root belongs to other sessions. Empty branch ⇒ detached HEAD (externally managed): name the work first with `git switch -c <branch>`, then continue as a normal branch.

3. **Base** — the plan, the conversation, or an open PR names it; otherwise ask "this split from `<default-branch>` — correct?". The tracking upstream is not the base. Never merge into a guessed base.

4. **Choose** — present exactly these three options and wait for the answer:
   1. Push and open a PR via git-commit → git-push → github-pr; keep the worktree while the PR is open.
   2. Merge locally, fast-forward only, so the landed tree is exactly the verified one. The main root must be clean (`git -C <main-root> status --porcelain` prints nothing) and on `<base>`: when the branch is checked out in the main root itself, `git switch <base>` gets it there; a linked worktree's main root belongs to other sessions — if it is dirty or on another branch, stop and ask instead of switching it. Then `git -C <main-root> pull --ff-only` (skip when `<base>` has no upstream) and `git -C <main-root> merge --ff-only <branch>`. A refused merge means `<base>` moved since the split: rebase the branch onto `<base>` — in its worktree, or in the main root after `git switch <branch>` — resolving conflicts as in git-push, re-run the suite on the rebased tree, return the main root to `<base>`, and retry. Nothing was pushed, so any red result is fully recoverable. Then clean up.
   3. Keep as-is: report branch and path.

   Discarding is never offered. Only when the user asks for it explicitly, show branch, commits, and path and require the typed word `discard`. Unattended (subagent or Autopilot): option 1 if the task asked for a PR, otherwise option 3 — and report which.

5. **Clean up** — only after option 2, a confirmed discard, or a merged PR, and only for worktrees under `.worktrees/` (ours); worktrees created by a harness (VS Code sessions, Copilot app, `copilot -w`) are removed by that harness. From the main root:

   ```sh
   git worktree remove <worktree-path> && git worktree prune
   git branch -d <branch>   # -D only for a confirmed discard, a squash-merged PR, or a branch that `git branch --merged <base>` lists
   ```

   `-d` refusing with "not yet merged to `<remote>/…`" only reflects a tracking upstream on the branch; when `git branch --merged <base>` lists it, `-D` is safe. Removal refused ⇒ files exist only there: show `git -C <worktree-path> status --porcelain -uall` and ask whether to commit them, move them out, or delete them. Never `--force` on your own initiative.
