#!/usr/bin/env bash
# q-vela — QEMU (riscv64-softmmu). Source: q-vela/README.md "Build QEMU", "Verify the build"
# Outputs: <out>/bin/qemu-system-riscv64, <out>/bin/qemu-img, <out>/share/qemu (make install)
# shellcheck source=components/lib.sh
source "$(dirname "$0")/lib.sh"

deps() {
  echo git build-essential ninja-build pkg-config libglib2.0-dev libpixman-1-dev libslirp-dev \
    python3 python3-venv flex bison
}

build() {
  local src=$1 out=$2
  cd "$src/qemu" || exit
  # --enable-slirp is required for -netdev user in Launch (README)
  ./configure --target-list=riscv64-softmmu --enable-slirp --prefix="$out"
  make -j"$JOBS"
  make install

  "$out/bin/qemu-system-riscv64" --version
  "$out/bin/qemu-system-riscv64" -device help | grep -q gemmini || die "gemmini device missing"
  "$out/bin/qemu-system-riscv64" -netdev help | grep -qx user || die "slirp (user netdev) missing"
}

main "$@"
