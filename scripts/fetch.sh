#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2026 FALINUX Co., Ltd.
# fetch.sh — fetch one repository at the SHA pinned in the lock file (depth 1, without submodules).
#
# Usage: scripts/fetch.sh <lock.xml> <project> <dest>
#        scripts/fetch.sh <lock.xml> <project> --sha   # print the SHA only
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
    sys.exit(f'error: {sys.argv[2]} is not in the lock')
PY
)

if [ "$dest" = "--sha" ]; then
  echo "$sha"
  exit 0
fi

# GitHub allows fetching a reachable commit directly by SHA.
git init -q "$dest"
git -C "$dest" fetch -q --depth 1 "$url" "$sha"
git -C "$dest" -c advice.detachedHead=false checkout -q FETCH_HEAD
echo "$project $(git -C "$dest" rev-parse HEAD)"
