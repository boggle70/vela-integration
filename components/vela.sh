#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2026 FALINUX Co., Ltd.
# vela — Ubuntu noble riscv64 image. Source: vela/README.md "Preparing ubuntu image", vela/init.sh
# Output: <out>/ubuntu-noble-riscv64.qcow2
#
# init.sh creates a 16G raw (sparse) image. The GitHub runner SSD is 14 GB, so
# moving it as is would exceed the disk once the sparse file is expanded. Convert it to a compressed qcow2.
# shellcheck source=components/lib.sh
source "$(dirname "$0")/lib.sh"

deps() {
  # init.sh: sudo, debootstrap, qemu-img, parted, losetup, mkfs.ext4, chroot (+ qemu-user binfmt)
  echo sudo debootstrap qemu-user-static binfmt-support qemu-utils parted fdisk e2fsprogs
}

build() {
  local src=$1 out=$2
  (cd "$src" && ./init.sh)
  qemu-img convert -c -O qcow2 "$src/ubuntu-noble-riscv64.img" "$out/ubuntu-noble-riscv64.qcow2"
  rm -f "$src/ubuntu-noble-riscv64.img"
}

main "$@"
