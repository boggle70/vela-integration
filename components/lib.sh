# lib.sh — components/*.sh 공통부. 각 스크립트가 source 한 뒤 deps(), build() 를 정의하고 main "$@" 를 호출한다.
#
# 사용법: components/<name>.sh deps              # 필요한 apt 패키지 목록 출력
#         components/<name>.sh build <src> <out>  # <src> 레포를 빌드해 산출물을 <out> 에 둔다
#
# 레포가 ci/integration-build.sh 를 제공하면 build 는 그 스크립트를 실행한다 (레포별 CI 가 갖춰진 뒤의 형태).
# 제공하지 않으면 이 디렉터리의 스크립트가 레포 README 의 빌드 절차를 대신 수행한다.

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
        log "레포 제공 스크립트 사용: ci/integration-build.sh"
        (cd "$src" && bash ci/integration-build.sh "$out")
      else
        build "$src" "$out"
      fi
      log "산출물:"
      ls -l "$out" >&2
      ;;
    *)
      die "usage: $0 deps | build <src> <out>"
      ;;
  esac
}
