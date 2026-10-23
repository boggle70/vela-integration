#!/usr/bin/env bash
# vela — Ubuntu noble riscv64 이미지. 근거: vela/README.md "Preparing ubuntu image", vela/init.sh
# 산출물: <out>/ubuntu-noble-riscv64.qcow2
#
# init.sh 는 16G raw(sparse) 이미지를 만든다. GitHub runner SSD 가 14 GB 이므로
# 그대로 옮기면 sparse 가 풀릴 때 디스크를 넘는다. 압축 qcow2 로 바꿔 둔다.
# shellcheck source=components/lib.sh
source "$(dirname "$0")/lib.sh"

deps() {
  # init.sh: sudo, debootstrap, qemu-img, parted, losetup, mkfs.ext4, chroot(+ qemu-user binfmt)
  echo sudo debootstrap qemu-user-static binfmt-support qemu-utils parted fdisk e2fsprogs
}

build() {
  local src=$1 out=$2
  (cd "$src" && ./init.sh)
  qemu-img convert -c -O qcow2 "$src/ubuntu-noble-riscv64.img" "$out/ubuntu-noble-riscv64.qcow2"
  rm -f "$src/ubuntu-noble-riscv64.img"
}

main "$@"
