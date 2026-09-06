---
name: finish-branch
description: "Land a finished branch (PR, fast-forward merge, or keep), return main root to base, remove worktree; discarding never offered. Use when: implementation complete and tests pass, deciding how to land agent work, post-merge worktree cleanup."
argument-hint: "Branch or worktree to finish, its base branch if known, and whether a PR is wanted"
---

# Finish Branch

Integrate a finished branch the way the user chooses, then leave the main root on its base branch and remove the worktree git-branch created — the task is not finished while its worktree folder, an emptied `.worktrees/` directory, or its branch is still around.

## Steps

1. **Verify** — run the full suite on the exact tree you are about to integrate (verification-before-completion). Red: report and stop — the options come after green.

2. **Detect** — before any `cd`, capture where you are:

   ```sh
   git rev-parse --path-format=absolute --show-toplevel   # <worktree-path>
   git worktree list                                       # first line: <main-root>
   git branch --show-current
   ```

   `<worktree-path>` ≠ `<main-root>` ⇒ linked worktree, and the main root belongs to other sessions. Empty branch ⇒ detached HEAD: name the work first with `git switch -c <branch>`, then continue as a normal branch.

3. **Base** — the plan, the conversation, or an open PR names it; otherwise ask "this split from `<default-branch>` — correct?". The tracking upstream is not the base. Never merge into a guessed base.

4. **Choose** — present exactly these three options and wait for the answer:
   1. Push and open a PR via git-commit → git-push → github-pr; keep the worktree while the PR is open, and clean up as soon as `gh pr view <number> --repo <upstream> --json state -q .state | cat` prints `MERGED`.
   2. Merge locally, fast-forward only, so the landed tree is exactly the verified one:
      - Precondition: the main root is clean (`git -C <main-root> status --porcelain` prints nothing) and on `<base>`. When the branch is checked out in the main root itself, `git switch <base>` gets it there; a linked worktree's main root belongs to other sessions — dirty or on another branch ⇒ stop and ask instead of switching it.
      - `git -C <main-root> pull --ff-only` (skip when `<base>` has no upstream), then `git -C <main-root> merge --ff-only <branch>`.
      - Refused merge ⇒ `<base>` moved since the split: rebase the branch onto `<base>` — in its worktree, or in the main root after `git switch <branch>` — resolving conflicts as in git-push, re-run the suite on the rebased tree, return the main root to `<base>`, and retry.
      - Nothing was pushed, so any red result is fully recoverable. Then clean up.
   3. Keep as-is: report branch and path.

   Discarding is never offered. Only when the user asks for it explicitly, show branch, commits, and path and require the typed word `discard`. Unattended (subagent or Autopilot): option 1 if the task asked for a PR, otherwise option 3 — and report which.

5. **Clean up** — mandatory after option 2, a merged PR, or a confirmed discard. Leave the main root on `<base>`, remove the worktree folder and the `.worktrees/` directories it leaves empty (its `<prefix>/` dir, and `.worktrees/` itself after the last worktree), and delete the branch, in this order; `cd` out of the worktree first — its directory disappears under you. After a merged PR, `git -C <main-root> pull --ff-only` first so `<base>` holds the merge.

   ```sh
   cd "<main-root>"
   git branch --show-current                                 # <base>; if the branch itself is checked out here (no worktree): git switch <base>
   git worktree remove <worktree-path> && git worktree prune
   find .worktrees -maxdepth 1 -type d -empty -delete        # emptied <prefix>/, then .worktrees/ itself after the last worktree; never descends into live worktrees
   git branch -d <branch>   # -D only for a confirmed discard, a squash-merged PR, or a branch that `git branch --merged <base>` lists
   git worktree list && git branch --list <branch>           # <worktree-path> gone; no output for the branch
   [ ! -d .worktrees ] || ls -A .worktrees                   # other tasks' live worktrees only; no output once the last one is gone
   ```

   Report the result: main root on `<base>` at `<commit>`, worktree and its emptied `.worktrees/` directories removed, branch deleted. `-d` refusing with "not yet merged to `<remote>/…`" only reflects a tracking upstream on the branch; when `git branch --merged <base>` lists it, `-D` is safe. Removal refused ⇒ files exist only there: show `git -C <worktree-path> status --porcelain -uall` and ask whether to commit them, move them out, or delete them. Never `--force` on your own initiative. Option 3 skips this step: the worktree stays until the branch is landed later.
