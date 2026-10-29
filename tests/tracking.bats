#!/usr/bin/env bats
# .gitignore whitelist: no tracked file of this repository matches an ignore rule.

load helpers

# tracked_but_ignored: check-ignore over every tracked path, one ignored path per line;
# exit 1 with no output when none is ignored, exit 2 when git ls-files fails or lists no
# file (an empty listing would make check-ignore exit 1 vacuously). No -v: it also prints
# negated (!) matches and then exits 0; `git check-ignore --no-index -v <path>` names an
# offending path's pattern.
tracked_but_ignored() (
  set -o pipefail
  cd "$BATS_TEST_DIRNAME/.." || exit 2
  tracked=$BATS_TEST_TMPDIR/tracked
  git ls-files -z >"$tracked" || { echo "git ls-files failed" >&2; exit 2; }
  [ -s "$tracked" ] || { echo "git ls-files listed no file" >&2; exit 2; }
  git check-ignore --no-index -z --stdin <"$tracked" | tr '\0' '\n'
)

@test ".gitignore ignores no tracked file" {
  export GIT_CONFIG_GLOBAL=/dev/null
  export GIT_CONFIG_NOSYSTEM=1
  unset GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT
  run --separate-stderr tracked_but_ignored
  assert_status 1
  assert_output_is ""
  [ -z "$stderr" ] || { printf -- '--- unexpected stderr ---\n%s\n' "$stderr" >&2; return 1; }
}
