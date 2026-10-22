#!/usr/bin/env bash
# run-logged.sh — 명령을 실행하며 출력을 로그 파일에 남기고, 실패하면 로그 끝부분을 GitHub annotation 으로 올린다.
# annotation 은 run 페이지와 check-run API 에서 로그 권한 없이 볼 수 있다.
#
# 사용법: scripts/run-logged.sh <title> <log> <명령> [인자...]
set -uo pipefail

[ $# -ge 3 ] || { echo "usage: $0 <title> <log> <command> [args...]" >&2; exit 2; }
title=$1 log=$2
shift 2

"$@" 2>&1 | tee "$log"
rc=${PIPESTATUS[0]}
if [ "$rc" -ne 0 ]; then
  msg=$(tail -n 40 "$log" | sed -e 's/%/%25/g' -e 's/\r/%0D/g' | sed ':a;N;$!ba;s/\n/%0A/g')
  echo "::error title=$title (exit $rc)::$msg"
fi
exit "$rc"
