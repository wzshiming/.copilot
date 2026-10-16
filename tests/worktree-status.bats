#!/usr/bin/env bats
# worktree-status.sh [-C p] [--base <ref>]: one line per worktree, then orphan:/prunable: lines.

load helpers

setup() { setup_fixture; }

@test "worktree-status.sh prints nothing and exits 0 outside a git repository" {
  mkdir -p "$BATS_TEST_TMPDIR/plain"
  run --separate-stderr "$SCRIPTS/worktree-status.sh" -C "$BATS_TEST_TMPDIR/plain"
  assert_status 0
  [ -z "$output" ]
}

@test "worktree-status.sh lists the main checkout alone as '<path>  master  main  clean  merged'" {
  run --separate-stderr "$SCRIPTS/worktree-status.sh" -C "$MAIN"
  assert_status 0
  assert_output_is "$MAIN_ROOT  master  main  clean  merged"
}

@test "worktree-status.sh adds one 'linked' line per linked worktree after the main line" {
  add_linked feat
  run --separate-stderr "$SCRIPTS/worktree-status.sh" -C "$MAIN"
  assert_status 0
  assert_output_is "$(printf '%s\n' \
    "$MAIN_ROOT  master  main  clean  merged" \
    "$WORKTREES/feat  feat  linked  clean  merged")"
}

@test "worktree-status.sh reports dirty:<N> with N the status --porcelain -uall line count" {
  add_linked feat
  printf 'edit\n' >> "$WORKTREES/feat/README.md"
  printf 'new\n' > "$WORKTREES/feat/new.txt"
  run --separate-stderr "$SCRIPTS/worktree-status.sh" -C "$MAIN"
  assert_status 0
  has_line "$WORKTREES/feat  feat  linked  dirty:2  merged"
}

@test "worktree-status.sh marks a branch with commits beyond origin/master as unmerged(origin/master)" {
  add_linked feat
  commit_file "$WORKTREES/feat" feat.txt "feat work"
  run --separate-stderr "$SCRIPTS/worktree-status.sh" -C "$MAIN"
  assert_status 0
  has_line "$WORKTREES/feat  feat  linked  clean  unmerged(origin/master)"
}

@test "worktree-status.sh marks the branch merged once a fetched origin/master contains its commits" {
  add_linked feat
  commit_file "$WORKTREES/feat" feat.txt "feat work"
  git -C "$WORKTREES/feat" push -q origin HEAD:master
  git -C "$MAIN" fetch -q
  run --separate-stderr "$SCRIPTS/worktree-status.sh" -C "$MAIN"
  assert_status 0
  has_line "$WORKTREES/feat  feat  linked  clean  merged"
}

@test "worktree-status.sh judges merged against --base <ref> instead of the default base" {
  add_linked feat
  commit_file "$WORKTREES/feat" feat.txt "feat work"
  run --separate-stderr "$SCRIPTS/worktree-status.sh" -C "$MAIN" --base feat
  assert_status 0
  has_line "$WORKTREES/feat  feat  linked  clean  merged"
}

@test "worktree-status.sh shows a detached worktree as detached@<7-char sha>" {
  exclude_worktrees
  git -C "$MAIN" worktree add -q --detach "$WORKTREES/det" origin/master
  run --separate-stderr "$SCRIPTS/worktree-status.sh" -C "$MAIN"
  assert_status 0
  has_line "$WORKTREES/det  detached@$(git -C "$MAIN" rev-parse origin/master | cut -c1-7)  linked  clean  merged"
}

@test "worktree-status.sh prints nobase when no default base can be derived and --base is not given" {
  init_repo "$BATS_TEST_TMPDIR/solo"
  run --separate-stderr "$SCRIPTS/worktree-status.sh" -C "$BATS_TEST_TMPDIR/solo"
  assert_status 0
  assert_output_is "$(main_root_of "$BATS_TEST_TMPDIR/solo")  master  main  clean  nobase"
}

@test "worktree-status.sh reports each topmost unregistered non-empty directory under .worktrees as 'orphan: <abs>'" {
  add_linked feat/x
  mkdir -p "$WORKTREES/feat/old" "$WORKTREES/stale/sub"
  printf 'x\n' > "$WORKTREES/feat/old/f.txt"
  printf 'x\n' > "$WORKTREES/stale/sub/f.txt"
  run --separate-stderr "$SCRIPTS/worktree-status.sh" -C "$MAIN"
  assert_status 0
  has_line "orphan: $WORKTREES/feat/old"
  has_line "orphan: $WORKTREES/stale"
  [ "$(count_lines_matching '^orphan: ')" -eq 2 ]
}

@test "worktree-status.sh does not report empty unregistered directories as orphans" {
  add_linked feat
  mkdir -p "$WORKTREES/empty" "$WORKTREES/hollow/deeper"
  run --separate-stderr "$SCRIPTS/worktree-status.sh" -C "$MAIN"
  assert_status 0
  [ "$(count_lines_matching '^orphan: ')" -eq 0 ]
}

@test "worktree-status.sh lists a registered worktree whose directory vanished as 'prunable: <path>' and not as a worktree line" {
  add_linked feat
  rm -rf "$WORKTREES/feat"
  run --separate-stderr "$SCRIPTS/worktree-status.sh" -C "$MAIN"
  assert_status 0
  assert_output_is "$(printf '%s\n' \
    "$MAIN_ROOT  master  main  clean  merged" \
    "prunable: $WORKTREES/feat")"
}

@test "worktree-status.sh caps output at 40 lines, the last being '+<N> more'" {
  exclude_worktrees
  for i in $(seq 1 45); do
    mkdir -p "$WORKTREES/stale-$i"
    printf 'x\n' > "$WORKTREES/stale-$i/f.txt"
  done
  run --separate-stderr "$SCRIPTS/worktree-status.sh" -C "$MAIN"
  assert_status 0
  [ "${#lines[@]}" -eq 40 ]
  [ "${lines[39]}" = "+7 more" ]
}

@test "worktree-status.sh worktree lines follow '<path>  <ref>  main|linked  clean|dirty:<N>  merged|unmerged(<base>)|nobase'" {
  add_linked feat
  commit_file "$WORKTREES/feat" feat.txt "feat work"
  printf 'new\n' > "$WORKTREES/feat/new.txt"
  run --separate-stderr "$SCRIPTS/worktree-status.sh" -C "$MAIN"
  assert_status 0
  [ "${#lines[@]}" -eq 2 ]
  re='^/[^ ]+  [^ ]+  (main|linked)  (clean|dirty:[1-9][0-9]*)  (merged|unmerged\([^)]+\)|nobase)$'
  for l in "${lines[@]}"; do
    [[ "$l" =~ $re ]]
  done
}

@test "worktree-status.sh exits 2 with usage on stderr for an unknown option" {
  run --separate-stderr "$SCRIPTS/worktree-status.sh" -C "$MAIN" --bogus
  assert_status 2
  [ -n "$stderr" ]
}

@test "worktree-status.sh --help prints usage to stdout and exits 0" {
  run --separate-stderr "$SCRIPTS/worktree-status.sh" --help
  assert_status 0
  [ -n "$output" ]
}

@test "worktree-status.sh leaves .git/index of every scanned worktree untouched (no optional locks) when a tracked file has a fresh mtime" {
  add_linked feat
  feat_index=$(git -C "$WORKTREES/feat" rev-parse --path-format=absolute --git-path index)
  # A fresh mtime makes git status refresh its stat cache and rewrite the index unless optional locks are off.
  touch -t 203001011200 "$MAIN/README.md" "$WORKTREES/feat/README.md"
  before=$(cksum "$MAIN/.git/index" "$feat_index")
  run --separate-stderr "$SCRIPTS/worktree-status.sh" -C "$MAIN"
  assert_status 0
  assert_output_is "$(printf '%s\n' \
    "$MAIN_ROOT  master  main  clean  merged" \
    "$WORKTREES/feat  feat  linked  clean  merged")"
  [ "$(cksum "$MAIN/.git/index" "$feat_index")" = "$before" ]
}
