#!/usr/bin/env bash
# cache-key.sh — 컴포넌트 산출물의 cache key 를 출력한다.
#   <component>-<레포 SHA>-<빌드 스크립트 hash 12자>
# 레포 SHA 나 components/ 스크립트가 바뀌면 key 가 바뀌어 다시 빌드한다.
#
# 사용법: scripts/cache-key.sh <lock.xml> <component>
set -euo pipefail

[ $# -eq 2 ] || { echo "usage: $0 <lock.xml> <component>" >&2; exit 2; }
root=$(cd "$(dirname "$0")/.." && pwd)
sha=$("$root/scripts/fetch.sh" "$1" "$2" --sha)
hash=$(cat "$root/components/lib.sh" "$root/components/$2.sh" | git hash-object --stdin | cut -c1-12)
echo "$2-$sha-$hash"
