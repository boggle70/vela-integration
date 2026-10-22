#!/usr/bin/env bash
# boot-test.sh — q-vela README "Launch" 구성으로 부팅해 serial 에 login prompt 가 나오는지 확인한다.
#
# 사용법: compose/boot-test.sh <out>
#   <out>/q-vela/bin/qemu-system-riscv64
#   <out>/vela-fws/fw_dynamic.bin
#   <out>/vela-linux/Image
#   <out>/vela/ubuntu-noble-riscv64.qcow2
# 결과  : <out>/boot.log (serial), <out>/qemu.log (-D)
#
# README 와 다른 점
#   - -m 은 QEMU_MEM(기본 4096). README 는 16384 인데 GitHub runner 메모리가 16 GB 다.
#   - 이미지는 qcow2, -snapshot 으로 원본을 바꾸지 않는다.
#   - gemmini 는 1개만 붙인다. 부팅 확인이 목적이다.
set -euo pipefail

[ $# -eq 1 ] || { echo "usage: $0 <out>" >&2; exit 2; }
out=$(cd "$1" && pwd)
QEMU_MEM=${QEMU_MEM:-4096}
BOOT_TIMEOUT=${BOOT_TIMEOUT:-3600}
log=$out/boot.log

for f in q-vela/bin/qemu-system-riscv64 vela-fws/fw_dynamic.bin vela-linux/Image vela/ubuntu-noble-riscv64.qcow2; do
  [ -f "$out/$f" ] || { echo "error: $out/$f 없음" >&2; exit 1; }
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

start=$SECONDS
while ! grep -q 'login:' "$log"; do
  if ! kill -0 "$pid" 2>/dev/null; then
    echo "error: QEMU 가 login prompt 전에 종료됐다" >&2
    tail -50 "$log" >&2
    exit 1
  fi
  if [ $((SECONDS - start)) -ge "$BOOT_TIMEOUT" ]; then
    echo "error: ${BOOT_TIMEOUT}s 안에 login prompt 가 나오지 않았다" >&2
    tail -50 "$log" >&2
    exit 1
  fi
  sleep 10
done
echo "boot ok: login prompt 까지 $((SECONDS - start))s"
