# Shared by every tests/*.bats: the assertions serve all of them, the fixture only the
# worktree-*.sh tests — a bare origin seeded with one commit on master, and a clone MAIN
# whose origin/HEAD points at origin/master.
# Paths are compared as git prints them (macOS /var -> /private/var).

bats_require_minimum_version 1.5.0

SCRIPTS="$BATS_TEST_DIRNAME/../scripts"

setup_fixture() {
  export GIT_CONFIG_GLOBAL=/dev/null
  export GIT_CONFIG_NOSYSTEM=1
  ORIGIN="$BATS_TEST_TMPDIR/origin.git"
  MAIN="$BATS_TEST_TMPDIR/main"
  git init -q --bare -b master "$ORIGIN"
  init_repo "$BATS_TEST_TMPDIR/seed"
  git -C "$BATS_TEST_TMPDIR/seed" push -q "$ORIGIN" master
  git clone -q "$ORIGIN" "$MAIN"
  set_identity "$MAIN"
  MAIN_ROOT=$(main_root_of "$MAIN")
  WORKTREES="$MAIN_ROOT/.worktrees"
}

# init_repo <path>: standalone repository on master with one commit and no remote.
init_repo() {
  git init -q -b master "$1"
  set_identity "$1"
  commit_file "$1" README.md "init"
}

set_identity() {
  git -C "$1" config user.name "Tester"
  git -C "$1" config user.email "tester@example.com"
}

# commit_file <repo> <relpath> <message>: append <message> to <relpath> and commit it.
commit_file() {
  mkdir -p "$1/$(dirname "$2")"
  printf '%s\n' "$3" >> "$1/$2"
  git -C "$1" add -- "$2"
  git -C "$1" commit -q -m "$3"
}

# advance_origin <branch>: from a throwaway clone, add one commit on <branch>
# (created from master when origin lacks it) and push it; MAIN's refs stay untouched.
advance_origin() {
  local pusher="$BATS_TEST_TMPDIR/pusher"
  rm -rf "$pusher"
  git clone -q "$ORIGIN" "$pusher"
  set_identity "$pusher"
  if git -C "$pusher" rev-parse -q --verify "origin/$1" >/dev/null; then
    git -C "$pusher" checkout -q "$1"
  else
    git -C "$pusher" checkout -q -b "$1" master
  fi
  commit_file "$pusher" "$1.txt" "advance $1"
  git -C "$pusher" push -q origin "$1"
}

# main_root_of <path>: first path of `git worktree list --porcelain`, as git prints it.
main_root_of() {
  git -C "$1" worktree list --porcelain | sed -n '1s/^worktree //p'
}

# worktree_of_branch <branch>: path MAIN registers for <branch>, empty when none.
worktree_of_branch() {
  git -C "$MAIN" worktree list --porcelain | awk -v want="branch refs/heads/$1" '
    /^worktree / { path = substr($0, 10) }
    $0 == want { print path }'
}

branch_exists() {
  git -C "$MAIN" show-ref --verify -q "refs/heads/$1"
}

# exclude_worktrees: what worktree-add.sh does before creating, so MAIN's status stays clean.
exclude_worktrees() {
  local exclude="$MAIN/.git/info/exclude"
  mkdir -p "${exclude%/*}"
  grep -qx '/\.worktrees' "$exclude" 2>/dev/null || printf '/.worktrees\n' >> "$exclude"
}

# add_linked <branch> [<start>]: register <branch> at the conventional path with plain git.
add_linked() {
  exclude_worktrees
  git -C "$MAIN" worktree add -q --no-track "$WORKTREES/$1" -b "$1" "${2:-origin/master}"
}

# lock_path: the per-repo lock both worktree scripts take, in MAIN's common git dir.
lock_path() {
  printf '%s/worktree-scripts.lock\n' "$(git -C "$MAIN" rev-parse --path-format=absolute --git-common-dir)"
}

# hold_lock <pid>: leave the lock behind as a holder running as <pid> would.
hold_lock() { printf '%s\n' "$1" > "$(lock_path)"; }

# dead_pid: pid of a child that has already exited, so kill -0 fails on it.
dead_pid() { sh -c 'echo $$'; }

# fails <cmd...>: succeed only when the command fails (a bare `!` is not caught mid-test).
fails() {
  if "$@"; then return 1; else return 0; fi
}

assert_status() {
  [ "$status" -eq "$1" ] && return 0
  printf 'expected exit %s, got %s\n--- stdout ---\n%s\n--- stderr ---\n%s\n' \
    "$1" "$status" "$output" "${stderr-}" >&2
  return 1
}

assert_output_is() {
  [ "$output" = "$1" ] && return 0
  printf -- '--- expected stdout ---\n%s\n--- actual stdout ---\n%s\n' "$1" "$output" >&2
  return 1
}

# has_line <exact>: succeed when stdout contains <exact> as a whole line.
has_line() {
  local l
  for l in "${lines[@]}"; do
    [ "$l" = "$1" ] && return 0
  done
  printf 'missing line: %s\n--- stdout ---\n%s\n' "$1" "$output" >&2
  return 1
}

# count_lines_matching <regex>: number of stdout lines matching <regex>.
count_lines_matching() {
  printf '%s\n' "${lines[@]}" | grep -c -- "$1" || true
}

# --- hooks/subagent-*.sh tests: the hooks dir of this checkout, harness-shaped input,
# a runner, and a reader of the JSON answer (node comes along with npx bats).

HOOKS="$BATS_TEST_DIRNAME/../hooks"

# json_escape <text>: <text> as the body of a JSON string, backslash and double quote escaped.
json_escape() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  printf '%s' "$s"
}

# hook_input <event> <agent_id> [cwd] [guard]: the harness's payload for <event> with
# agent_type Coder; the cwd key only when <cwd> is given, stop_hook_active only when
# <guard> (raw JSON, normally the literal true or false) is given.
hook_input() {
  local cwd='' guard=''
  [ -z "${3-}" ] || cwd=$(printf ',"cwd":"%s"' "$(json_escape "$3")")
  [ -z "${4-}" ] || guard=",\"stop_hook_active\":$4"
  printf '{"hook_event_name":"%s","session_id":"c3d1e7a0-5b2f-4c8e-9a1d-7f6e5d4c3b2a","transcript_path":"/tmp/transcript.jsonl","timestamp":"2026-10-20T10:00:00.000Z"%s,"agent_id":"%s","agent_type":"Coder"%s}' \
    "$1" "$cwd" "$(json_escape "$2")" "$guard"
}

# in_dir <dir> <cmd...>: run <cmd> with <dir> as its working directory.
in_dir() ( cd "$1" && shift && "$@" )

# run_hook <hook> <json> [cwd]: `run --separate-stderr` the hook at path <hook> with <json>
# on stdin (empty <json> = empty stdin) from the process cwd <cwd>, MAIN by default.
run_hook() {
  printf '%s' "$2" > "$BATS_TEST_TMPDIR/hook-input.json"
  run --separate-stderr in_dir "${3:-$MAIN}" "$1" < "$BATS_TEST_TMPDIR/hook-input.json"
}

# hook_json <dotted.path>: the field at <dotted.path> of the last run's stdout, which must be
# exactly one JSON object; a string prints raw, anything else as JSON.
hook_json() {
  node -e '
    var raw = process.argv[1], path = process.argv[2], v;
    function fail(why) { console.error("hook_json: " + why + ": " + JSON.stringify(raw)); process.exit(1); }
    try { v = JSON.parse(raw); } catch (e) { fail("stdout is not one JSON value"); }
    if (v === null || typeof v !== "object" || Array.isArray(v)) fail("stdout is not a JSON object");
    path.split(".").forEach(function (key) {
      if (v === null || typeof v !== "object" || !(key in v)) fail("no " + path);
      v = v[key];
    });
    process.stdout.write(typeof v === "string" ? v : JSON.stringify(v));
  ' -- "$output" "$1"
}

# assert_hook_json <dotted.path> <expected>: that field of the last run's stdout is <expected>.
assert_hook_json() {
  local actual
  actual=$(hook_json "$1") || return 1
  [ "$actual" = "$2" ] && return 0
  printf -- '--- expected %s ---\n%s\n--- actual ---\n%s\n' "$1" "$2" "$actual" >&2
  return 1
}
