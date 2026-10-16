#!/usr/bin/env bats
# worktree-remove.sh [-C p] <branch> [--base <ref>] [--force-delete-branch] | [-C p] --orphans

load helpers

setup() { setup_fixture; }

@test "worktree-remove.sh removes a clean worktree, its emptied parents up to .worktrees, and the merged branch" {
  add_linked feat/a/b
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" -C "$MAIN" feat/a/b
  assert_status 0
  assert_output_is "$(printf '%s\n' "removed=$WORKTREES/feat/a/b" "branch=deleted")"
  [ ! -e "$WORKTREES/feat/a/b" ]
  [ ! -e "$WORKTREES/feat/a" ]
  [ ! -e "$WORKTREES/feat" ]
  [ ! -e "$WORKTREES" ]
  [ -z "$(worktree_of_branch feat/a/b)" ]
  fails branch_exists feat/a/b
}

@test "worktree-remove.sh refuses a dirty worktree with 'dirty', listing its files, and leaves everything in place" {
  add_linked feat
  printf 'new\n' > "$WORKTREES/feat/new.txt"
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" -C "$MAIN" feat
  assert_status 1
  [[ "$stderr" == *dirty* ]]
  [[ "$stderr" == *new.txt* ]]
  [ -f "$WORKTREES/feat/new.txt" ]
  [ "$(worktree_of_branch feat)" = "$WORKTREES/feat" ]
  branch_exists feat
}

@test "worktree-remove.sh refuses the branch checked out in the main checkout with 'main checkout'" {
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" -C "$MAIN" master
  assert_status 1
  [[ "$stderr" == *"main checkout"* ]]
  [ -f "$MAIN/README.md" ]
  [ "$(worktree_of_branch master)" = "$MAIN_ROOT" ]
  branch_exists master
}

@test "worktree-remove.sh force-deletes a branch that -d refuses but origin/master already contains" {
  add_linked feat
  commit_file "$WORKTREES/feat" feat.txt "feat work"
  git -C "$WORKTREES/feat" push -q origin HEAD:master
  git -C "$MAIN" fetch -q
  fails git -C "$MAIN" merge-base --is-ancestor feat master
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" -C "$MAIN" feat
  assert_status 0
  assert_output_is "$(printf '%s\n' "removed=$WORKTREES/feat" "branch=deleted")"
  fails branch_exists feat
}

@test "worktree-remove.sh removes the worktree but keeps an unmerged branch as kept-unmerged" {
  add_linked feat
  commit_file "$WORKTREES/feat" feat.txt "feat work"
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" -C "$MAIN" feat
  assert_status 0
  assert_output_is "$(printf '%s\n' "removed=$WORKTREES/feat" "branch=kept-unmerged")"
  [ ! -e "$WORKTREES/feat" ]
  [ -z "$(worktree_of_branch feat)" ]
  branch_exists feat
}

@test "worktree-remove.sh removes the worktree but keeps an unmerged branch as kept when there is no remote and no --base" {
  add_linked feat
  commit_file "$WORKTREES/feat" feat.txt "feat work"
  git -C "$MAIN" remote remove origin
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" -C "$MAIN" feat
  assert_status 0
  assert_output_is "$(printf '%s\n' "removed=$WORKTREES/feat" "branch=kept")"
  [ ! -e "$WORKTREES/feat" ]
  branch_exists feat
}

@test "worktree-remove.sh deletes an unmerged branch when --base <ref> contains it" {
  add_linked feat
  commit_file "$WORKTREES/feat" feat.txt "feat work"
  git -C "$MAIN" branch integration feat
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" -C "$MAIN" feat --base integration
  assert_status 0
  assert_output_is "$(printf '%s\n' "removed=$WORKTREES/feat" "branch=deleted")"
  fails branch_exists feat
}

@test "worktree-remove.sh --force-delete-branch deletes an unmerged branch" {
  add_linked feat
  commit_file "$WORKTREES/feat" feat.txt "feat work"
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" -C "$MAIN" feat --force-delete-branch
  assert_status 0
  assert_output_is "$(printf '%s\n' "removed=$WORKTREES/feat" "branch=deleted")"
  fails branch_exists feat
}

@test "worktree-remove.sh reports removed=none for a branch without a worktree and still deletes it" {
  git -C "$MAIN" branch --no-track feat origin/master
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" -C "$MAIN" feat
  assert_status 0
  assert_output_is "$(printf '%s\n' "removed=none" "branch=deleted")"
  fails branch_exists feat
}

@test "worktree-remove.sh exits 1 for a branch that does not exist" {
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" -C "$MAIN" nosuch
  assert_status 1
  [ -z "$output" ]
}

@test "worktree-remove.sh --orphans deletes an orphan whose regular files are all known blobs, skipping its .git file" {
  exclude_worktrees
  mkdir -p "$WORKTREES/stale/docs"
  cp "$MAIN/README.md" "$WORKTREES/stale/docs/README.md"
  printf 'gitdir: %s\n' "$MAIN/.git/worktrees/stale" > "$WORKTREES/stale/.git"
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" -C "$MAIN" --orphans
  assert_status 0
  assert_output_is "$(printf '%s\n' "orphans_removed=1" "orphans_kept=0")"
  [ ! -e "$WORKTREES/stale" ]
  [ ! -e "$WORKTREES" ]
}

@test "worktree-remove.sh --orphans keeps an orphan holding an unknown file and names it on stderr with 'unknown'" {
  exclude_worktrees
  mkdir -p "$WORKTREES/stale"
  cp "$MAIN/README.md" "$WORKTREES/stale/README.md"
  printf 'not in any commit\n' > "$WORKTREES/stale/notes.txt"
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" -C "$MAIN" --orphans
  assert_status 1
  assert_output_is "$(printf '%s\n' "orphans_removed=0" "orphans_kept=1")"
  [[ "$stderr" == *unknown* ]]
  [[ "$stderr" == *notes.txt* ]]
  [ -f "$WORKTREES/stale/notes.txt" ]
  [ -f "$WORKTREES/stale/README.md" ]
}

@test "worktree-remove.sh --orphans prunes vanished worktrees and removes empty directories including .worktrees" {
  add_linked feat
  rm -rf "$WORKTREES/feat"
  mkdir -p "$WORKTREES/hollow/deeper"
  [ "$(worktree_of_branch feat)" = "$WORKTREES/feat" ]
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" -C "$MAIN" --orphans
  assert_status 0
  assert_output_is "$(printf '%s\n' "orphans_removed=0" "orphans_kept=0")"
  [ -z "$(worktree_of_branch feat)" ]
  [ ! -e "$WORKTREES" ]
}

@test "worktree-remove.sh exits 2 when a branch and --orphans are both given" {
  add_linked feat
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" -C "$MAIN" feat --orphans
  assert_status 2
  [ -n "$stderr" ]
  [ -d "$WORKTREES/feat" ]
  branch_exists feat
}

@test "worktree-remove.sh exits 2 with usage on stderr when neither a branch nor --orphans is given" {
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" -C "$MAIN"
  assert_status 2
  [ -n "$stderr" ]
  [ -z "$output" ]
}

@test "worktree-remove.sh exits 2 with usage on stderr for an unknown option" {
  add_linked feat
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" -C "$MAIN" feat --bogus
  assert_status 2
  [ -n "$stderr" ]
  [ -d "$WORKTREES/feat" ]
}

@test "worktree-remove.sh --help prints usage to stdout and exits 0" {
  run --separate-stderr "$SCRIPTS/worktree-remove.sh" --help
  assert_status 0
  [ -n "$output" ]
}
