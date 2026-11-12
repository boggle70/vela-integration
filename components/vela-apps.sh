#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2026 ETRI
# vela-apps — Keystone SDK, Eyrie runtime and the hello example. Source: vela-apps/README.md "TEE — Building the Keystone Applications"
# Output: <out>/hello.vela (self-extracting enclave package, run in the guest by compose/tee-test.sh)
#
# FW_BIN is not set, so the attestation example is skipped (vela-apps examples/CMakeLists.txt).
# shellcheck source=components/lib.sh
source "$(dirname "$0")/lib.sh"

deps() {
  echo build-essential cmake makeself git gcc-riscv64-linux-gnu g++-riscv64-linux-gnu
}

build() {
  local src=$1 out=$2
  # macros.cmake reads the toolchain prefix from the environment.
  export CROSS_COMPILE
  export KEYSTONE_SDK_DIR=$src/sdk/build
  export KEYSTONE_RUNTIME=$src/runtime

  cmake -S "$src/sdk" -B "$KEYSTONE_SDK_DIR"
  make -C "$KEYSTONE_SDK_DIR" -j"$JOBS"
  make -C "$KEYSTONE_SDK_DIR" install

  cmake -S "$src/examples" -B "$src/examples/build"
  make -C "$src/examples/build" -j"$JOBS" hello-package

  cp "$src/examples/build/hello/hello.vela" "$out/"
}

main "$@"
