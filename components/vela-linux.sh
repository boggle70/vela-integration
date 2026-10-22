#!/usr/bin/env bash
# vela-linux — 커널 Image + Keystone driver. 근거: vela-linux/README.md "Building"
# 산출물: <out>/Image (q-vela Launch 의 -kernel), <out>/keystone-driver.ko
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

  # driver Makefile 은 CROSS_COMPILE=riscv64-linux-gnu- 를 고정해 쓴다 (README). 커널과 접두사를 맞춘다.
  [ "$CROSS_COMPILE" = riscv64-linux-gnu- ] || die "keystone driver 는 riscv64-linux-gnu- 만 지원"
  # driver Makefile 은 M=$(PWD) 를 쓴다. make -C 는 환경변수 PWD 를 바꾸지 않으므로 README 처럼 cd 후 make 한다.
  (cd "$src/linux-keystone-driver" && make)

  cp "$src/linux/arch/riscv/boot/Image" "$src/linux-keystone-driver/keystone-driver.ko" "$out/"
}

main "$@"
