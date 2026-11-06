#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2026 FALINUX Co., Ltd.
# run-logged.sh — run a command, save its output to a log file, and on failure post the end of the log as a GitHub annotation.
# Annotations are visible on the run page and through the check-run API without log access.
#
# Usage: scripts/run-logged.sh <title> <log> <command> [args...]
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
