# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2026 FALINUX Co., Ltd.
# lib.sh — shared part of components/*.sh. Each script sources this file, defines deps() and build(), and calls main "$@".
#
# Usage: components/<name>.sh deps              # print the required apt packages
#        components/<name>.sh build <src> <out>  # build the <src> repository and put the outputs in <out>
#
# If the repository provides ci/integration-build.sh, build runs that script (the intended form once per-repository CI is in place).
# Otherwise the script in this directory carries out the build procedure from the repository's README.

# shellcheck shell=bash
set -euo pipefail

CROSS_COMPILE=${CROSS_COMPILE:-riscv64-linux-gnu-}
JOBS=${JOBS:-$(nproc)}

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" >&2; }
die() { log "error: $*"; exit 1; }

main() {
  case "${1:-}" in
    deps)
      deps
      ;;
    build)
      [ $# -eq 3 ] || die "usage: $0 build <src> <out>"
      local src out
      src=$(cd "$2" && pwd)
      mkdir -p "$3"
      out=$(cd "$3" && pwd)
      if [ -f "$src/ci/integration-build.sh" ]; then
        log "using the repository's script: ci/integration-build.sh"
        (cd "$src" && bash ci/integration-build.sh "$out")
      else
        build "$src" "$out"
      fi
      log "outputs:"
      ls -l "$out" >&2
      ;;
    *)
      die "usage: $0 deps | build <src> <out>"
      ;;
  esac
}
