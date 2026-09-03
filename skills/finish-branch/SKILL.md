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
   git rev-parse --path-format=absolute --show-toplevel --git-dir --git-common-dir
   git branch --show-current
   ```

   git-dir ≠ common-dir ⇒ linked worktree: `WORKTREE_PATH` is the toplevel and the main root is the first `worktree` line of `git worktree list --porcelain`. Empty branch ⇒ detached HEAD (externally managed): name the work first with `git switch -c <branch>`, then continue as a normal branch.

3. **Base** — the plan, the conversation, or an open PR names it; otherwise ask "this split from `<default-branch>` — correct?". The tracking upstream is not the base. Never merge into a guessed base.

4. **Choose** — present exactly these three options and wait for the answer:
   1. Push and open a PR via git-commit → git-push → github-pr; keep the worktree while the PR is open.
   2. Merge locally: from the main root `git checkout <base> && git pull && git merge <branch>`, re-run the suite on the merged result, then clean up. A red merged result stops everything — nothing was pushed, so it is fully recoverable.
   3. Keep as-is: report branch and path.

   Discarding is never offered. Only when the user asks for it explicitly, show branch, commits, and path and require the typed word `discard`. Unattended (subagent or Autopilot): option 1 if the task asked for a PR, otherwise option 3 — and report which.

5. **Clean up** — only after option 2, a confirmed discard, or a merged PR, and only for worktrees under `.worktrees/` (ours); worktrees created by a harness (VS Code sessions, Copilot app, `copilot -w`) are removed by that harness. From the main root:

   ```sh
   git worktree remove "$WORKTREE_PATH" && git worktree prune
   git branch -d <branch>   # -D only for a confirmed discard or a squash-merged PR
   ```

   Removal refused ⇒ files exist only there: show `git -C "$WORKTREE_PATH" status --porcelain -uall` and ask whether to commit them, move them out, or delete them. Never `--force` on your own initiative.
