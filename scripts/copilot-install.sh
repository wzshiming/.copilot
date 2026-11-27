#!/bin/sh
# Generates the VS Code Copilot agents from the Claude-format sources; see --help.

prog=${0##*/}
usage="usage: $prog [-C <repo-path>] [--dest <dir>] [--check]
Writes one <dest>/<name>.agent.md per <repo-path>/agents/<name>.md (default
<repo-path>: the repository holding this script; default <dest>:
~/.copilot/agents): its frontmatter is the source's name, the description up to
'. Brief: ' and the rest of it as argument-hint, then copilot/<name>.yml; its
body is the source's with every '< claude' / '> copilot' pair of copilot/map
replaced literally, in file order. Prints 'written=<path>' or
'unchanged=<path>' per agent; with --check writes nothing and prints
'stale=<path>' instead of 'written='. Exit 1, writing nothing, when a source
lacks its name, Brief, or copilot/<name>.yml, a map entry matches no line,
Claude-only wording survives in a body, or --check finds a stale file; exit 2
on a usage error or a missing directory."

die() { printf '%s: %s\n' "$prog" "$1" >&2; exit 1; }
usage_error() { printf '%s: %s\n%s\n' "$prog" "$1" "$usage" >&2; exit 2; }

repo='' dest='' check=0
while [ $# -gt 0 ]; do
  case $1 in
    -C) [ $# -ge 2 ] || usage_error "-C needs a path"; repo=$2; shift ;;
    --dest) [ $# -ge 2 ] || usage_error "--dest needs a directory"; dest=$2; shift ;;
    --check) check=1 ;;
    --help) printf '%s\n' "$usage"; exit 0 ;;
    *) usage_error "unexpected argument $1" ;;
  esac
  shift
done

if [ -z "$repo" ]; then
  repo=$(dirname "$0")/..
fi
[ -d "$repo/agents" ] || usage_error "no such directory: $repo/agents"
[ -f "$repo/copilot/map" ] || usage_error "no such file: $repo/copilot/map"
[ -n "$dest" ] || dest=$HOME/.copilot/agents

tmp=$(mktemp -d) || die "mktemp failed"
trap 'rm -rf "$tmp"' EXIT

set -- "$repo"/agents/*.md
[ -e "$1" ] || die "no agents/*.md in $repo"

for src in "$@"; do
  name=${src##*/}
  name=${name%.md}
  [ -f "$repo/copilot/$name.yml" ] || die "$name: no copilot/$name.yml"
done

# One pass over the map and every source, so an entry's hits count across all agents.
awk -v out="$tmp" -v copilot="$repo/copilot" '
  function fail(msg) { printf "%s\n", msg > "/dev/stderr"; bad = 1 }
  # replace(s, from, to): every literal <from> in <s> becomes <to>; counts the hits in nhit.
  function replace(s, from, to,    i, r) {
    r = ""
    while ((i = index(s, from)) > 0) {
      r = r substr(s, 1, i - 1) to
      s = substr(s, i + length(from))
      nhit++
    }
    return r s
  }
  FNR == 1 { file++; fm = 0; base = FILENAME; sub(/.*\//, "", base); sub(/\.md$/, "", base) }
  file == 1 {
    if (substr($0, 1, 2) == "< ") { n++; from[n] = substr($0, 3); mapline[n] = FNR }
    else if (substr($0, 1, 2) == "> " && n > 0 && !(n in to)) to[n] = substr($0, 3)
    else if ($0 != "" && substr($0, 1, 1) != "#") fail("copilot/map:" FNR ": neither < nor > nor comment")
    next
  }
  FNR == 1 {
    target = out "/" base ".agent.md"
    name = ""; desc = ""; hint = ""
  }
  fm < 2 && $0 == "---" {
    fm++
    if (fm == 2) {
      if (name == "") fail(base ": no name")
      if (hint == "") fail(base ": description has no \". Brief: \"")
      if (hint ~ /: /) hint = "\"" hint "\""
      printf "---\nname: %s\ndescription: \"%s\"\nargument-hint: %s\n", name, desc, hint > target
      yml = copilot "/" base ".yml"
      while ((getline line < yml) > 0) print line > target
      close(yml)
      print "---" > target
    }
    next
  }
  fm == 1 {
    if ($0 ~ /^name:/) { name = $0; sub(/^name:[[:space:]]*/, "", name) }
    if ($0 ~ /^description:/) {
      desc = $0
      sub(/^description:[[:space:]]*"/, "", desc); sub(/"[[:space:]]*$/, "", desc)
      i = index(desc, ". Brief: ")
      if (i) { hint = substr(desc, i + 9); desc = substr(desc, 1, i) }
    }
    next
  }
  {
    s = $0
    for (k = 1; k <= n; k++) { nhit = 0; s = replace(s, from[k], to[k]); hits[k] += nhit }
    if (s ~ /AskUserQuestion|\.git\/agents|claude --agent|Agent tool|WebFetch|WebSearch|Brief:|(^|[^[:alnum:]])Bash([^[:alnum:]]|$)/)
      fail("agents/" base ".md:" FNR ": Claude-only wording survives the map")
    print s > target
  }
  END {
    for (k = 1; k <= n; k++) {
      if (!(k in to)) fail("copilot/map:" mapline[k] ": < without >")
      else if (!hits[k]) fail("copilot/map:" mapline[k] ": matches no line")
    }
    exit bad
  }
' "$repo/copilot/map" "$@" || die "refused; nothing written"

stale=0
for src in "$@"; do
  name=${src##*/}
  name=${name%.md}
  if [ -f "$dest/$name.agent.md" ] && cmp -s "$tmp/$name.agent.md" "$dest/$name.agent.md"; then
    printf 'unchanged=%s\n' "$dest/$name.agent.md"
  elif [ "$check" -eq 1 ]; then
    printf 'stale=%s\n' "$dest/$name.agent.md"
    stale=1
  else
    mkdir -p "$dest" || die "cannot create $dest"
    cp "$tmp/$name.agent.md" "$dest/$name.agent.md" || die "cannot write $dest/$name.agent.md"
    printf 'written=%s\n' "$dest/$name.agent.md"
  fi
done
exit "$stale"
