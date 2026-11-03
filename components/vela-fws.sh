#!/usr/bin/env bash
# vela-fws — Security Monitor (Rust) + OpenSBI. Source: vela-fws/README.md "TEE — Building OpenSBI + Security Monitor"
# Outputs: <out>/fw_dynamic.bin (-bios in q-vela Launch), <out>/fw_jump.bin (FW_BIN for vela-apps attestation)
# Out of stage 1 scope: edk2, buildroot (RAS boot path)
# shellcheck source=components/lib.sh
source "$(dirname "$0")/lib.sh"

deps() {
  echo build-essential curl ca-certificates gcc-riscv64-linux-gnu
}

build() {
  local src=$1 out=$2

  # sm/rust-toolchain.toml specifies nightly and the riscv64gc-unknown-linux-gnu target.
  # The distribution's cargo does not honor it, so rustup is required (README).
  if ! command -v rustup >/dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain none
  fi
  export PATH=$HOME/.cargo/bin:$PATH

  (cd "$src/sm" && rustup toolchain install && cargo build)

  # PLATFORM_RISCV_ABI=lp64d is required to link with libvela.a (lp64d) (README)
  make -C "$src/opensbi" PLATFORM=generic CROSS_COMPILE="$CROSS_COMPILE" PLATFORM_RISCV_ABI=lp64d -j"$JOBS"

  cp "$src/opensbi/build/platform/generic/firmware/fw_dynamic.bin" \
     "$src/opensbi/build/platform/generic/firmware/fw_jump.bin" "$out/"
  rustc --version >"$out/rustc-version.txt"
}

main "$@"
