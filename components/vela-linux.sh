#!/usr/bin/env bash
# vela-linux — kernel Image + Keystone driver. Source: vela-linux/README.md "Building"
# Outputs: <out>/Image (-kernel in q-vela Launch), <out>/keystone-driver.ko
# shellcheck source=components/lib.sh
source "$(dirname "$0")/lib.sh"

deps() {
  echo build-essential flex bison bc libssl-dev libelf-dev gcc-riscv64-linux-gnu
}

build() {
  local src=$1 out=$2
  local kmake=(make -C "$src/linux" ARCH=riscv CROSS_COMPILE="$CROSS_COMPILE")

  "${kmake[@]}" defconfig
  "${kmake[@]}" -j"$JOBS" Image modules

  # The driver Makefile hardcodes CROSS_COMPILE=riscv64-linux-gnu- (README). Keep the kernel on the same prefix.
  [ "$CROSS_COMPILE" = riscv64-linux-gnu- ] || die "the keystone driver supports only riscv64-linux-gnu-"
  # The driver Makefile uses M=$(PWD). make -C does not change the PWD environment variable, so cd and run make as the README does.
  (cd "$src/linux-keystone-driver" && make)

  cp "$src/linux/arch/riscv/boot/Image" "$src/linux-keystone-driver/keystone-driver.ko" "$out/"
}

main "$@"
