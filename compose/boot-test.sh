#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2026 FALINUX Co., Ltd.
# boot-test.sh — boot the q-vela README "Launch" configuration and check that a login prompt appears on serial.
#
# Usage : compose/boot-test.sh <out>
#   <out>/q-vela/bin/qemu-system-riscv64
#   <out>/vela-fws/fw_dynamic.bin
#   <out>/vela-linux/Image
#   <out>/vela/ubuntu-noble-riscv64.qcow2
# Output: <out>/boot.log (serial), <out>/qemu.log (-D)
#
# Differences from the README
#   - -m is QEMU_MEM (default 4096). The README uses 16384, but a GitHub runner has 16 GB of memory.
#   - The image is qcow2, and -snapshot keeps the original unchanged.
#   - Only one gemmini is attached. The purpose is to check the boot.
set -euo pipefail

[ $# -eq 1 ] || { echo "usage: $0 <out>" >&2; exit 2; }
out=$(cd "$1" && pwd)
QEMU_MEM=${QEMU_MEM:-4096}
BOOT_TIMEOUT=${BOOT_TIMEOUT:-3600}
log=$out/boot.log

for f in q-vela/bin/qemu-system-riscv64 vela-fws/fw_dynamic.bin vela-linux/Image vela/ubuntu-noble-riscv64.qcow2; do
  [ -f "$out/$f" ] || { echo "error: $out/$f missing" >&2; exit 1; }
done

"$out/q-vela/bin/qemu-system-riscv64" \
  -machine virt,wg=on -nographic -m "$QEMU_MEM" -smp 4 \
  -bios "$out/vela-fws/fw_dynamic.bin" \
  -kernel "$out/vela-linux/Image" \
  -append "root=/dev/vda1 rw console=ttyS0 earlycon=sbi" \
  -cpu rv64,v=true,vlen=512,vext_spec=v1.0,zba=true,zbb=true,zbs=true,zbc=true,zbkb=true,zcb=true,zicond=true \
  -accel tcg,thread=multi \
  -semihosting-config enable=on,target=native,userspace=on \
  -netdev user,id=eth0,hostfwd=tcp::2222-:22 -device virtio-net-pci,netdev=eth0 \
  -device virtio-rng-pci \
  -drive file="$out/vela/ubuntu-noble-riscv64.qcow2",format=qcow2,if=virtio \
  -snapshot \
  -device gemmini,id=gemmini0 \
  -D "$out/qemu.log" \
  </dev/null >"$log" 2>&1 &
pid=$!
trap 'kill "$pid" 2>/dev/null || true' EXIT

# Accept only the getty prompt "<hostname> login:". The serial output contains CRs, so strip them first.
prompt() { tr -d '\r' <"$log" | grep -nE '^[[:alnum:]._-]+ login: ?$'; }

start=$SECONDS
while ! prompt >/dev/null; do
  if ! kill -0 "$pid" 2>/dev/null; then
    echo "error: QEMU exited before the login prompt" >&2
    tail -50 "$log" >&2
    exit 1
  fi
  if [ $((SECONDS - start)) -ge "$BOOT_TIMEOUT" ]; then
    echo "error: no login prompt within ${BOOT_TIMEOUT}s" >&2
    tail -50 "$log" >&2
    exit 1
  fi
  sleep 10
done
echo "boot ok: login prompt after $((SECONDS - start))s, boot.log $(wc -l <"$log") lines, prompt: $(prompt | head -1)"
