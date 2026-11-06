#!/usr/bin/env bash
# report.sh — report the results of this run as issues in this repository, so the owners get a GitHub notification (email
# if they enabled it).
#
# For each job of this run attempt:
#   failure          → open an issue "integration: <job> failed" that mentions the owners, or comment on the open one
#   success          → comment on the open issue for that job and close it
#   skipped/cancelled → nothing
# Owners: build (<repo>)     → the "owners" annotation of <repo> in the lock file (space-separated GitHub logins)
#         resolve, boot-test → REPORT_OWNERS (also used for a repository without an owners annotation)
#         every failed job   → also REPORT_CC
#
# Usage : scripts/report.sh <lock.xml>     (the lock is missing when resolve failed before writing it)
# Env   : GH_TOKEN, GITHUB_REPOSITORY, GITHUB_RUN_ID, GITHUB_RUN_ATTEMPT, GITHUB_SERVER_URL (set by Actions)
#         REPORT_OWNERS    space-separated GitHub logins for resolve and boot-test
#         REPORT_CC        space-separated GitHub logins mentioned in every failure report, in addition to the owners
#         REPORT_OVERRIDE  if set, mention only this login (used outside riscv-vela, e.g. in a fork)
#         REPORT_SELF      job name of this job, excluded from the report (default: report)
# Local test (no writes):
#         REPORT_DRY_RUN=1 print the writes instead of making them
#         REPORT_JOBS      file of "<job name>\t<conclusion>\t<check run API URL>" lines, instead of the jobs API
#         REPORT_ISSUES    file of "<number>\t<title>" lines (open issues opened by this script), instead of the issues API
set -euo pipefail

[ $# -eq 1 ] || { echo "usage: $0 <lock.xml>" >&2; exit 2; }
lock=$1
repo=${GITHUB_REPOSITORY:?}
run_id=${GITHUB_RUN_ID:?}
attempt=${GITHUB_RUN_ATTEMPT:-1}
run_url="${GITHUB_SERVER_URL:-https://github.com}/$repo/actions/runs/$run_id"
self=${REPORT_SELF:-report}
summary=${GITHUB_STEP_SUMMARY:-/dev/null}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

note() { echo "$*"; echo "- $*" >>"$summary"; }

# Write calls: in dry-run mode, print them (and the body file) instead.
write() {
  if [ "${REPORT_DRY_RUN:-}" = 1 ]; then
    echo "dry-run: gh $*" >&2
    for a in "$@"; do
      case $a in body=@*) sed 's/^/  | /' "${a#body=@}" >&2 ;; esac
    done
    echo 0
  else
    gh "$@"
  fi
}

# "@a @b" for the given logins (each once, in order), or the override login.
mentions() {
  if [ -n "${REPORT_OVERRIDE:-}" ]; then
    echo "@$REPORT_OVERRIDE"
  else
    local out='' login
    # shellcheck disable=SC2048 # split the space-separated logins
    for login in $*; do
      case " $out" in *" @$login "*) ;; *) out+="@$login " ;; esac
    done
    echo "${out% }"
  fi
}

# owners annotation of a project in the lock file
owners_of() {
  [ -f "$lock" ] || return 0
  python3 -I - "$lock" "$1" <<'PY'
import sys
import xml.etree.ElementTree as ET
for p in ET.parse(sys.argv[1]).getroot().findall('project'):
    if p.get('name') == sys.argv[2]:
        print(' '.join(a.get('value', '') for a in p.findall('annotation') if a.get('name') == 'owners'))
PY
}

lock_table() {
  if [ ! -f "$lock" ]; then
    echo "lock.xml is not available (resolve did not finish)."
    return
  fi
  echo "| Repository | SHA | upstream |"
  echo "|---|---|---|"
  python3 -I - "$lock" <<'PY'
import sys
import xml.etree.ElementTree as ET
for p in ET.parse(sys.argv[1]).getroot().findall('project'):
    print(f"| {p.get('name')} | `{p.get('revision')}` | {p.get('upstream')} |")
PY
}

# error annotations of a check run (run-logged.sh posts the end of the log as one)
annotations() {
  [ -n "$1" ] || return 0
  gh api --paginate "${1#https://api.github.com/}/annotations" | jq -r '
    .[] | select(.annotation_level == "failure")
    | "**\(.title // "error")**\n\n````text\n\(.message)\n````\n"'
}

if [ -z "${REPORT_ISSUES:-}" ] && [ "$(gh api "repos/$repo" --jq .has_issues)" != true ]; then
  note "Issues are disabled in $repo. No report."
  exit 0
fi

if [ -n "${REPORT_JOBS:-}" ]; then
  cp "$REPORT_JOBS" "$tmp/jobs"
else
  gh api --paginate "repos/$repo/actions/runs/$run_id/attempts/$attempt/jobs?per_page=100" \
    | jq -r '.jobs[] | [.name, (.conclusion // ""), .check_run_url] | @tsv' >"$tmp/jobs"
fi

if [ -n "${REPORT_ISSUES:-}" ]; then
  cp "$REPORT_ISSUES" "$tmp/issues"
else
  gh api --paginate "repos/$repo/issues?state=open&per_page=100" \
    | jq -r '.[] | select(.pull_request == null and .user.login == "github-actions[bot]") | [.number, .title] | @tsv' \
    >"$tmp/issues"
fi

{ echo; echo "## Report"; echo; } >>"$summary"

while IFS=$'\t' read -r name conclusion check_url; do
  [ "$name" = "$self" ] && continue
  owners=
  case $name in
    "build ("*")") c=${name#build (}; owners=$(owners_of "${c%)}") ;;
  esac
  [ -n "$owners" ] || owners=${REPORT_OWNERS:-}
  owners="$owners ${REPORT_CC:-}"
  title="integration: $name failed"
  num=$(awk -F'\t' -v t="$title" '$2 == t { print $1; exit }' "$tmp/issues")

  case $conclusion in
    failure)
      {
        mentions "$owners"
        echo
        echo "\`$name\` failed in [run $run_id (attempt $attempt)]($run_url)."
        echo
        echo "#### Configuration"
        echo
        lock_table
        echo
        echo "#### Error annotations"
        echo
        annotations "$check_url" >"$tmp/ann"
        if [ -s "$tmp/ann" ]; then cat "$tmp/ann"; else echo "None. See the run log."; fi
      } >"$tmp/body"
      if [ -n "$num" ]; then
        write api -X POST "repos/$repo/issues/$num/comments" -F "body=@$tmp/body" --jq .id >/dev/null
        note "$name: failure, commented on #$num"
      else
        num=$(write api -X POST "repos/$repo/issues" -f "title=$title" -F "body=@$tmp/body" --jq .number)
        note "$name: failure, opened #$num"
      fi
      ;;
    success)
      [ -n "$num" ] || continue
      echo "\`$name\` passed in [run $run_id (attempt $attempt)]($run_url)." >"$tmp/body"
      write api -X POST "repos/$repo/issues/$num/comments" -F "body=@$tmp/body" --jq .id >/dev/null
      write api -X PATCH "repos/$repo/issues/$num" -f state=closed -f state_reason=completed --jq .number >/dev/null
      note "$name: success, closed #$num"
      ;;
  esac
done <"$tmp/jobs"
