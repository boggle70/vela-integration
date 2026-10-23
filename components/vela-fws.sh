#!/usr/bin/env bash
# vela-fws — Security Monitor(Rust) + OpenSBI. 근거: vela-fws/README.md "TEE — Building OpenSBI + Security Monitor"
# 산출물: <out>/fw_dynamic.bin (q-vela Launch 의 -bios), <out>/fw_jump.bin (vela-apps attestation 의 FW_BIN)
# 1단계 범위 밖: edk2, buildroot (RAS 부팅 경로)
# shellcheck source=components/lib.sh
source "$(dirname "$0")/lib.sh"

RUST_NIGHTLY=${RUST_NIGHTLY:-nightly-2026-10-21}

deps() {
  echo build-essential curl ca-certificates gcc-riscv64-linux-gnu
}

build() {
  local src=$1 out=$2

  # sm/rust-toolchain.toml 이 nightly 와 riscv64gc-unknown-linux-gnu target 을 지정한다.
  # 배포판 cargo 는 이를 따르지 않으므로 rustup 이 필요하다 (README).
  if ! command -v rustup >/dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain none
  fi
  export PATH=$HOME/.cargo/bin:$PATH

  # channel = "nightly" 는 날짜가 고정되지 않아 실행일에 따라 결과가 바뀐다.
  # nightly 2026-10-22(7189d39d9)부터 libvela.a 링크에서 `bcmp` 미정의로 실패한다 (run 39907381493).
  # 마지막 성공 버전(2026-10-21, run 39816688832)으로 고정한다. 레포 쪽 고정이 반영되면 제거한다.
  sed -i "s/^channel = \"nightly\"$/channel = \"$RUST_NIGHTLY\"/" "$src/sm/rust-toolchain.toml"
  grep -q "^channel = \"$RUST_NIGHTLY\"$" "$src/sm/rust-toolchain.toml" || die "sm/rust-toolchain.toml channel 고정 실패"

  (cd "$src/sm" && rustup toolchain install && cargo build)

  # PLATFORM_RISCV_ABI=lp64d 는 libvela.a(lp64d) 와 링크하려면 필수다 (README)
  make -C "$src/opensbi" PLATFORM=generic CROSS_COMPILE="$CROSS_COMPILE" PLATFORM_RISCV_ABI=lp64d -j"$JOBS"

  cp "$src/opensbi/build/platform/generic/firmware/fw_dynamic.bin" \
     "$src/opensbi/build/platform/generic/firmware/fw_jump.bin" "$out/"
  rustc --version >"$out/rustc-version.txt"
}

main "$@"
