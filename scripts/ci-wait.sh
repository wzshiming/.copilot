#!/bin/sh
# Wait for a pull request's CI to conclude, reporting progress; see --help.

prog=${0##*/}
deadline=30 interval=30
usage="usage: $prog <pr-number> <owner/repo> [--deadline <minutes>] [--interval <seconds>]
Polls the pull request's checks through gh every <seconds> (default $interval) and
prints one 't=mm:ss pass= fail= pending= skipped=' line per round until every
check has concluded or <minutes> (default $deadline) have passed since the start.
Exit 0 with the check table once every check passed or skipped; exit 1 with
the table and the tail of each failed or cancelled job's log; exit 3 with one
'pending: <name>' line per unfinished check at the deadline; exit 2 on a usage
error or when gh fails."

usage_error() { printf '%s: %s\n%s\n' "$prog" "$1" "$usage" >&2; exit 2; }

pr='' repo='' nargs=0
while [ $# -gt 0 ]; do
  case $1 in
    --deadline) [ $# -ge 2 ] || usage_error "--deadline needs a number of minutes"; deadline=$2; shift ;;
    --interval) [ $# -ge 2 ] || usage_error "--interval needs a number of seconds"; interval=$2; shift ;;
    --help) printf '%s\n' "$usage"; exit 0 ;;
    -*) usage_error "unknown option $1" ;;
    *)
      nargs=$((nargs + 1))
      case $nargs in 1) pr=$1 ;; 2) repo=$1 ;; *) usage_error "too many arguments" ;; esac ;;
  esac
  shift
done
[ -n "$pr" ] || usage_error "missing <pr-number>"
[ -n "$repo" ] || usage_error "missing <owner/repo>"
case $pr in *[!0-9]*) usage_error "invalid pull request number '$pr'" ;; esac
case $repo in
  ?*/?*) case $repo in */*/*) usage_error "invalid repository '$repo': expected owner/repo" ;; esac ;;
  *) usage_error "invalid repository '$repo': expected owner/repo" ;;
esac
case $deadline in '' | *[!0-9]*) usage_error "--deadline needs a whole number of minutes, got '$deadline'" ;; esac
case $interval in '' | *[!0-9]*) usage_error "--interval needs a whole number of seconds, got '$interval'" ;; esac

errfile=$(mktemp) || exit 1
trap 'rm -f "$errfile"' EXIT
tab=$(printf '\t')
nl='
'

# gh pages on a TTY whenever PAGER is set
table() { gh pr checks "$pr" --repo "$repo" | cat; }

start=$(date +%s)
while :; do
  if ! out=$(gh pr checks "$pr" --repo "$repo" --json bucket,name,link --jq '.[] | [.bucket, .name, .link] | @tsv' 2>"$errfile") \
    && [ -z "$out" ] && ! grep -q 'no checks reported' "$errfile"; then
    cat "$errfile" >&2
    exit 2
  fi
  pass=0 fail=0 pending=0 skipped=0 failed='' waiting=''
  if [ -n "$out" ]; then
    while IFS=$tab read -r bucket name link; do
      case $bucket in
        pass) pass=$((pass + 1)) ;;
        fail | cancel) fail=$((fail + 1)); failed="$failed$name$tab$link$nl" ;;
        skipping) skipped=$((skipped + 1)) ;;
        *) pending=$((pending + 1)); waiting="${waiting}pending: $name$nl" ;;
      esac
    done <<EOF
$out
EOF
  fi
  elapsed=$(($(date +%s) - start))
  printf 't=%02d:%02d pass=%d fail=%d pending=%d skipped=%d\n' \
    $((elapsed / 60)) $((elapsed % 60)) "$pass" "$fail" "$pending" "$skipped"
  if [ "$fail" -gt 0 ]; then
    table
    printf '%s' "$failed" | while IFS=$tab read -r name link; do
      case $link in
        */job/[0-9]*)
          job=${link##*/job/}; job=${job%%[!0-9]*}
          printf '%s\n' "--- $name (job $job) ---"
          gh run view --job "$job" --repo "$repo" --log-failed </dev/null | tail -n 120 ;;
        *) printf 'no job log for %s\n' "$name" ;;
      esac
    done
    exit 1
  fi
  if [ "$pending" -eq 0 ] && [ $((pass + skipped)) -gt 0 ]; then
    table
    exit 0
  fi
  if [ "$elapsed" -ge $((deadline * 60)) ]; then
    if [ -n "$waiting" ]; then printf '%s' "$waiting"; else printf 'pending: no checks reported\n'; fi
    exit 3
  fi
  sleep "$interval"
done
