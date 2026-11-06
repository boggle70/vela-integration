#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2026 FALINUX Co., Ltd.
# cache-key.sh — print the cache key for a component's outputs.
#   <component>-<repository SHA>-<first 12 chars of the build script hash>
# If the repository SHA or the components/ scripts change, the key changes and the component is rebuilt.
#
# Usage: scripts/cache-key.sh <lock.xml> <component>
set -euo pipefail

[ $# -eq 2 ] || { echo "usage: $0 <lock.xml> <component>" >&2; exit 2; }
root=$(cd "$(dirname "$0")/.." && pwd)
sha=$("$root/scripts/fetch.sh" "$1" "$2" --sha)
hash=$(cat "$root/components/lib.sh" "$root/components/$2.sh" | git hash-object --stdin | cut -c1-12)
echo "$2-$sha-$hash"
