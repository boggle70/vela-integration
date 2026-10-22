#!/usr/bin/env bash
# fetch.sh — lock 파일에 고정된 SHA 로 레포 하나를 받는다 (depth 1, submodule 제외).
#
# 사용법: scripts/fetch.sh <lock.xml> <project> <dest>
#         scripts/fetch.sh <lock.xml> <project> --sha   # SHA 만 출력
set -euo pipefail

[ $# -eq 3 ] || { echo "usage: $0 <lock.xml> <project> <dest|--sha>" >&2; exit 2; }
lock=$1 project=$2 dest=$3

read -r url sha < <(python3 -I - "$lock" "$project" <<'PY'
import sys
import xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
remotes = {r.get('name'): r.get('fetch') for r in root.findall('remote')}
default = root.find('default')
default = default.attrib if default is not None else {}
for p in root.findall('project'):
    if p.get('name') == sys.argv[2]:
        remote = p.get('remote') or default.get('remote')
        print(remotes[remote].rstrip('/') + '/' + p.get('name'), p.get('revision'))
        break
else:
    sys.exit(f'error: lock 에 {sys.argv[2]} 가 없다')
PY
)

if [ "$dest" = "--sha" ]; then
  echo "$sha"
  exit 0
fi

# GitHub 는 reachable commit 을 SHA 로 직접 fetch 할 수 있다.
git init -q "$dest"
git -C "$dest" fetch -q --depth 1 "$url" "$sha"
git -C "$dest" -c advice.detachedHead=false checkout -q FETCH_HEAD
echo "$project $(git -C "$dest" rev-parse HEAD)"
