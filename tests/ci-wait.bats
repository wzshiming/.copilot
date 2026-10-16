#!/usr/bin/env bats
# ci-wait.sh <pr-number> <owner/repo> [--deadline <min>] [--interval <s>]: poll a PR's
# checks until they conclude. gh is the fake in tests/mock (see its header): each test
# lays out checks.N / joblog.<id> files under $GH_MOCK_DIR and never sleeps between polls.

load helpers

SCRIPT="$BATS_TEST_DIRNAME/../scripts/ci-wait.sh"
LINK=https://github.com/o/r/actions/runs/1/job
POLL='pr checks 7 --repo o/r --json bucket,name,link --jq .[] | [.bucket, .name, .link] | @tsv'
TABLE_LINE='X  build  1m2s  https://github.com/o/r/actions/runs/1/job/555'
PROGRESS='^t=[0-9]+:[0-9]{2} pass=[0-9]+ fail=[0-9]+ pending=[0-9]+ skipped=[0-9]+$'

# a script that never concludes must not hold the suite for the default deadline
setup_file() { export BATS_TEST_TIMEOUT=30; }

setup() {
  export GH_MOCK_DIR="$BATS_TEST_TMPDIR/gh"
  mkdir -p "$GH_MOCK_DIR"
  PATH="$BATS_TEST_DIRNAME/mock:$PATH"
  printf '%s\n' 'All checks were successful' "$TABLE_LINE" > "$GH_MOCK_DIR/table"
}

# checks <n> <bucket> <name> <link>...: the TSV the n-th poll answers with
checks() {
  local n=$1
  shift
  : > "$GH_MOCK_DIR/checks.$n"
  while [ $# -gt 0 ]; do
    printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$GH_MOCK_DIR/checks.$n"
    shift 3
  done
}

# gh_fails <n> <text>: the n-th poll prints <text> on stderr, nothing on stdout, exits 1
gh_fails() { printf '%s\n' "$2" > "$GH_MOCK_DIR/checks.$1.stderr"; }

no_checks() { gh_fails "$1" "no checks reported on the 'feat' branch"; }

# run_wait [<option>...]: wait on PR 7 of o/r without sleeping between polls
run_wait() { run --separate-stderr "$SCRIPT" 7 o/r --interval 0 "$@"; }

# line_index <exact>: index of the first stdout line equal to <exact>, else the line count
line_index() {
  local i
  for i in "${!lines[@]}"; do
    [ "${lines[i]}" = "$1" ] && { printf '%s\n' "$i"; return 0; }
  done
  printf '%s\n' "${#lines[@]}"
}

# progress_line <i> 'pass=<N> fail=<N> pending=<N> skipped=<N>': stdout line <i> reports those counts
progress_line() {
  local re="^t=[0-9]+:[0-9]{2} $2\$"
  [[ "${lines[$1]-}" =~ $re ]] && return 0
  printf 'line %s is "%s", expected t=<mm>:<ss> %s\n' "$1" "${lines[$1]-}" "$2" >&2
  return 1
}

# gh_calls <regex>: number of recorded gh calls whose arguments match <regex>
gh_calls() {
  [ -e "$GH_MOCK_DIR/calls.log" ] || { printf '0\n'; return 0; }
  grep -c -e "$1" "$GH_MOCK_DIR/calls.log" || true
}

@test "ci-wait.sh exits 0 once every check passes, with one progress line per poll, the final table and no job logs" {
  checks 1 pending build "$LINK/555" pending test "$LINK/556"
  checks 2 pass build "$LINK/555" pass test "$LINK/556"
  run_wait
  assert_status 0
  [ "$(count_lines_matching '^t=')" -eq 2 ]
  has_line "$TABLE_LINE"
  [ "$(gh_calls '^run view')" -eq 0 ]
  [ -z "$stderr" ]
}

@test "ci-wait.sh exits 1 on a failed check after the final table, then '--- <name> (job <id>) ---' and that job's failed log" {
  checks 1 fail build "$LINK/555" pass test "$LINK/556"
  printf 'step 3 exploded\n' > "$GH_MOCK_DIR/joblog.555"
  run_wait
  assert_status 1
  has_line "$TABLE_LINE"
  has_line '--- build (job 555) ---'
  has_line 'step 3 exploded'
  [ "$(line_index "$TABLE_LINE")" -lt "$(line_index '--- build (job 555) ---')" ]
  [ "$(gh_calls 'run view --job 555')" -eq 1 ]
  [ -z "$stderr" ]
}

@test "ci-wait.sh exits 1 at once when a check failed while others are still pending, fetching only the failed job's log" {
  checks 1 fail build "$LINK/555" pending test "$LINK/556"
  run_wait --deadline 0
  assert_status 1
  has_line '--- build (job 555) ---'
  [ "$(gh_calls '^run view')" -eq 1 ]
}

@test "ci-wait.sh counts a cancelled check as failed and exits 1 with its log" {
  checks 1 cancel deploy "$LINK/777"
  run_wait
  assert_status 1
  progress_line 0 'pass=0 fail=1 pending=0 skipped=0'
  has_line '--- deploy (job 777) ---'
  has_line 'log for job 777'
}

@test "ci-wait.sh prints a header and log for every failed check" {
  checks 1 fail build "$LINK/555" pass test "$LINK/556" cancel deploy "$LINK/777"
  run_wait
  assert_status 1
  has_line '--- build (job 555) ---'
  has_line '--- deploy (job 777) ---'
  [ "$(gh_calls '^run view')" -eq 2 ]
}

@test "ci-wait.sh prints 'no job log for <name>' and fetches nothing when a failed check's link has no /job/<digits>" {
  checks 1 fail lint https://ci.example.com/builds/abc
  run_wait
  assert_status 1
  has_line 'no job log for lint'
  [ "$(gh_calls '^run view')" -eq 0 ]
}

@test "ci-wait.sh prints only the last 120 lines of a failed job's log" {
  checks 1 fail build "$LINK/555"
  seq -f 'log line %g' 1 130 > "$GH_MOCK_DIR/joblog.555"
  run_wait
  assert_status 1
  [ "$(count_lines_matching '^log line ')" -eq 120 ]
  has_line 'log line 11'
  has_line 'log line 130'
}

@test "ci-wait.sh keeps a check name containing spaces intact in its log header" {
  checks 1 fail 'test (ubuntu-latest)' "$LINK/556"
  run_wait
  assert_status 1
  has_line '--- test (ubuntu-latest) (job 556) ---'
}

@test "ci-wait.sh counts a skipping check as skipped and still concludes green" {
  checks 1 pass build "$LINK/555" skipping docs "$LINK/556"
  run_wait
  assert_status 0
  progress_line 0 'pass=1 fail=0 pending=0 skipped=1'
  has_line "$TABLE_LINE"
}

@test "ci-wait.sh exits 3 at the deadline with one 'pending: <name>' line per pending check and no final table" {
  checks 1 pass build "$LINK/555" pending test "$LINK/556" pending lint "$LINK/557"
  run_wait --deadline 0
  assert_status 3
  has_line 'pending: test'
  has_line 'pending: lint'
  [ "$(count_lines_matching '^pending: ')" -eq 2 ]
  [ "$(count_lines_matching '^t=')" -eq 1 ]
  [[ "$output" != *"$TABLE_LINE"* ]]
}

@test "ci-wait.sh treats 'no checks reported' as a poll with zero checks: all counts 0, keeps polling, nothing on stderr" {
  no_checks 1
  checks 2 pass build "$LINK/555"
  run_wait
  assert_status 0
  progress_line 0 'pass=0 fail=0 pending=0 skipped=0'
  [ "$(count_lines_matching '^t=')" -eq 2 ]
  [ -z "$stderr" ]
}

@test "ci-wait.sh exits 3 with 'pending: no checks reported' when no checks appear before the deadline" {
  no_checks 1
  run_wait --deadline 0
  assert_status 3
  has_line 'pending: no checks reported'
}

@test "ci-wait.sh exits 2 forwarding gh's stderr, with no progress line, when gh fails for any other reason" {
  gh_fails 1 'GraphQL: Could not resolve to a PullRequest with the number of 999.'
  run --separate-stderr "$SCRIPT" 999 o/r --interval 0
  assert_status 2
  [[ "$stderr" == *'GraphQL: Could not resolve to a PullRequest with the number of 999.'* ]]
  [ "$(count_lines_matching '^t=')" -eq 0 ]
}

@test "ci-wait.sh treats an unknown bucket value as pending" {
  checks 1 weird lint "$LINK/555"
  run_wait --deadline 0
  assert_status 3
  progress_line 0 'pass=0 fail=0 pending=1 skipped=0'
  has_line 'pending: lint'
}

@test "ci-wait.sh counts pass, fail, pending and skipping checks into their own counters" {
  checks 1 pass build "$LINK/555" fail test "$LINK/556" pending lint "$LINK/557" skipping docs "$LINK/558"
  run_wait
  assert_status 1
  progress_line 0 'pass=1 fail=1 pending=1 skipped=1'
}

@test "ci-wait.sh prints exactly one progress line per poll, each 't=<mm>:<ss> pass=<N> fail=<N> pending=<N> skipped=<N>'" {
  checks 1 pending build "$LINK/555"
  checks 2 pending build "$LINK/555"
  checks 3 pass build "$LINK/555"
  run_wait
  assert_status 0
  [ "$(gh_calls '--json')" -eq 3 ]
  [ "$(count_lines_matching '^t=')" -eq 3 ]
  for l in "${lines[@]:0:3}"; do
    [[ "$l" =~ $PROGRESS ]]
  done
}

@test "ci-wait.sh calls gh only as the TSV poll, the plain 'pr checks <pr> --repo <repo>' table and 'run view --job <id> --repo <repo> --log-failed'" {
  checks 1 pending build "$LINK/555"
  checks 2 fail build "$LINK/555"
  run_wait
  assert_status 1
  expected=$(printf '%s\n' "$POLL" "$POLL" 'pr checks 7 --repo o/r' 'run view --job 555 --repo o/r --log-failed')
  actual=$(cat "$GH_MOCK_DIR/calls.log")
  [ "$actual" = "$expected" ] || {
    printf -- '--- expected gh calls ---\n%s\n--- actual ---\n%s\n' "$expected" "$actual" >&2
    return 1
  }
}

@test "ci-wait.sh exits 2 with usage on stderr and nothing on stdout when given no arguments" {
  run --separate-stderr "$SCRIPT"
  assert_status 2
  [ -n "$stderr" ]
  [ -z "$output" ]
}

@test "ci-wait.sh exits 2 when the PR number is not decimal digits" {
  run --separate-stderr "$SCRIPT" 7a o/r --interval 0
  assert_status 2
  [ -n "$stderr" ]
}

@test "ci-wait.sh exits 2 when the repository is not of the form owner/repo" {
  run --separate-stderr "$SCRIPT" 7 repo --interval 0
  assert_status 2
  [ -n "$stderr" ]
}

@test "ci-wait.sh exits 2 on an unknown option" {
  run --separate-stderr "$SCRIPT" 7 o/r --bogus
  assert_status 2
  [ -n "$stderr" ]
}

@test "ci-wait.sh exits 2 when --deadline is not a number" {
  run --separate-stderr "$SCRIPT" 7 o/r --deadline soon
  assert_status 2
  [ -n "$stderr" ]
}

@test "ci-wait.sh --help prints usage naming --deadline and --interval to stdout and exits 0" {
  run --separate-stderr "$SCRIPT" --help
  assert_status 0
  [[ "$output" == *--deadline* ]]
  [[ "$output" == *--interval* ]]
  [ -z "$stderr" ]
}
