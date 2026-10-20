# shellcheck shell=sh
# Sourced by hooks/subagent-*.sh: the hook event's fields, the branch name, JSON output escaping,
# the orphan sweep.

# json_string <key> <json> [strict]: the first string value of "<key>" in the object <json> with
# the escapes \" \\ \/ decoded; exit 1 when absent. With a third argument any other escape also
# counts as absent, without one it stays raw.
json_string() {
  printf '%s\n' "$2" | LC_ALL=C awk -v key="$1" -v strict="${3:-}" '
    { s = s $0 " " }
    END {
      if (s !~ /^[ \t\r]*[{]/ || !match(s, "\"" key "\"[ \t\r]*:[ \t\r]*\"")) exit 1
      n = length(s)
      for (i = RSTART + RLENGTH; i <= n; i++) {
        c = substr(s, i, 1)
        if (c == "\"") { print out; exit 0 }
        if (c == "\\") {
          d = substr(s, ++i, 1)
          if (d == "\"" || d == "\\" || d == "/") c = d
          else if (strict != "") exit 1
          else c = c d
        }
        out = out c
      }
      exit 1
    }'
}

# json_true <key> <json>: 0 when "<key>" in the object <json> is the literal true
json_true() {
  printf '%s\n' "$2" | LC_ALL=C awk -v key="$1" '
    { s = s $0 " " }
    END { exit !(s ~ /^[ \t\r]*[{]/ && s ~ ("\"" key "\"[ \t\r]*:[ \t\r]*true[ \t\r]*[,}]")) }'
}

# component: stdin with bytes outside [A-Za-z0-9_-] turned into -, runs of - squeezed, trimmed at both ends
component() {
  LC_ALL=C sed 's/[^A-Za-z0-9_-]/-/g; s/--*/-/g; s/^-//; s/-$//'
}

# branch_name <agent_type> <agent_id>: <lowercased type component>/<id component>, validity being the caller's check
branch_name() {
  printf '%s/%s\n' "$(printf '%s' "$1" | LC_ALL=C tr '[:upper:]' '[:lower:]' | component)" "$(printf '%s' "$2" | component)"
}

# json_escape <string>: the body of a JSON string without quotes or a trailing newline — \\ \" \n \t \r
# escaped, other C0 control bytes dropped, everything else raw
json_escape() {
  printf '%s' "$1" | LC_ALL=C awk '
    BEGIN { ORS = ""; for (i = 1; i < 32; i++) ctl = ctl sprintf("%c", i) }
    NR > 1 { print "\\n" }
    {
      n = length($0)
      for (i = 1; i <= n; i++) {
        c = substr($0, i, 1)
        if (c == "\\") print "\\\\"
        else if (c == "\"") print "\\\""
        else if (c == "\t") print "\\t"
        else if (c == "\r") print "\\r"
        else if (index(ctl, c) == 0) print c
      }
    }'
}

# sweep_orphans <repo>: delete the unregistered directories of known blobs under <repo>'s .worktrees
# through the sourcing hook's $scripts/worktree-remove.sh --orphans, its output on stderr and its
# exit ignored; nothing without an executable script
# shellcheck disable=SC2154
sweep_orphans() {
  if [ -f "$scripts/worktree-remove.sh" ] && [ -x "$scripts/worktree-remove.sh" ]; then
    "$scripts/worktree-remove.sh" -C "$1" --orphans >&2 || :
  fi
}
