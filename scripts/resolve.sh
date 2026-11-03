#!/usr/bin/env bash
# resolve.sh — resolve the manifest's branches/tags to commit SHAs and write a lock file.
#
# Usage : scripts/resolve.sh <manifest.xml> <lock.xml>
# Output: <lock.xml> — repo manifest -r format (revision=SHA, upstream=original revision)
#         stdout    — one "<project> <sha> <upstream>" line per project
# A project pinned to a SHA keeps its upstream attribute (the branch the SHA is taken from).
set -euo pipefail

[ $# -eq 2 ] || { echo "usage: $0 <manifest.xml> <lock.xml>" >&2; exit 2; }

python3 -I - "$1" "$2" <<'PY'
import re, subprocess, sys
import xml.etree.ElementTree as ET

src, dst = sys.argv[1], sys.argv[2]
tree = ET.parse(src)
root = tree.getroot()
remotes = {r.get('name'): r.get('fetch') for r in root.findall('remote')}
default = root.find('default')
default = default.attrib if default is not None else {}

for p in root.findall('project'):
    name = p.get('name')
    remote = p.get('remote') or default.get('remote')
    rev = p.get('revision') or default.get('revision')
    url = remotes[remote].rstrip('/') + '/' + name
    if re.fullmatch(r'[0-9a-f]{40}', rev):
        sha = rev
    else:
        # Priority: commit an annotated tag points to > tag > branch
        out = subprocess.run(
            ['git', 'ls-remote', url, f'refs/tags/{rev}^{{}}', f'refs/tags/{rev}', f'refs/heads/{rev}'],
            check=True, capture_output=True, text=True).stdout
        refs = dict(reversed(line.split('\t')) for line in out.splitlines())
        sha = next((refs[r] for r in (f'refs/tags/{rev}^{{}}', f'refs/tags/{rev}', f'refs/heads/{rev}')
                    if r in refs), None)
        if sha is None:
            sys.exit(f'error: {rev} not found in {url}')
    p.set('revision', sha)
    upstream = p.get('upstream') or rev
    p.set('upstream', upstream)
    print(name, sha, upstream)

ET.indent(tree)
tree.write(dst, encoding='UTF-8', xml_declaration=True)
PY
