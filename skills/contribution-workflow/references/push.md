# Push

Identify the repo layout and confirm auth first:

```sh
git --no-pager remote -v   # identify fork (origin) vs upstream layout
gh auth status             # confirm account and auth
```

The push target depends on whose repo it is:

## Your own repo (write access)

`origin` is the canonical repo — push the branch directly:

```sh
git push -u origin <branch>
```

## Someone else's repo (fork workflow)

First force-sync the fork's default branch with upstream to avoid PR conflicts (the fork is often stale):

```sh
gh repo sync <fork-owner>/<repo> --force   # overwrite fork's default branch with upstream's
git fetch origin
git rebase origin/<default-branch> <branch>   # rebase feature branch onto the fresh base
```

Only the fork's default branch is overwritten — the feature branch is untouched. If the rebase hits conflicts, stop and resolve them locally before pushing.

Then push to your fork (`origin`), never to `upstream`:

```sh
git push -u origin <branch>
```

If the branch was already pushed before the rebase, plain push is rejected — use `git push --force-with-lease` (never bare `--force`).

If no fork exists yet:

```sh
gh repo fork --remote   # creates fork; sets origin = fork, upstream = canonical repo
git push -u origin <branch>
```

## Unsure which case?

Target the canonical repo explicitly — bare `gh repo view` may resolve to your fork and always report `ADMIN`:

```sh
gh repo view <upstream-owner>/<repo> --json viewerPermission -q .viewerPermission
```

`WRITE`/`ADMIN` → push directly; `READ`/none → fork workflow.
