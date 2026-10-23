#!/usr/bin/env bash
# resolve.sh — manifest 의 branch/tag 를 commit SHA 로 확정해 lock 파일을 만든다.
#
# 사용법: scripts/resolve.sh <manifest.xml> <lock.xml>
# 출력  : <lock.xml> — repo manifest -r 형식 (revision=SHA, upstream=원래 revision)
#         표준출력  — "<project> <sha> <upstream>" 한 줄씩
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
        # 우선순위: annotated tag 가 가리키는 commit > tag > branch
        out = subprocess.run(
            ['git', 'ls-remote', url, f'refs/tags/{rev}^{{}}', f'refs/tags/{rev}', f'refs/heads/{rev}'],
            check=True, capture_output=True, text=True).stdout
        refs = dict(reversed(line.split('\t')) for line in out.splitlines())
        sha = next((refs[r] for r in (f'refs/tags/{rev}^{{}}', f'refs/tags/{rev}', f'refs/heads/{rev}')
                    if r in refs), None)
        if sha is None:
            sys.exit(f'error: {url} 에 {rev} 가 없다')
    p.set('revision', sha)
    p.set('upstream', rev)
    print(name, sha, rev)

ET.indent(tree)
tree.write(dst, encoding='UTF-8', xml_declaration=True)
PY
