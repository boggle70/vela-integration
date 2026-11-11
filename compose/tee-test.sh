#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2026 ETRI
# tee-test.sh — boot the same configuration as boot-test.sh, then load the Keystone
# driver and run a vela-apps enclave package in the guest over the serial console.
#
# Usage : compose/tee-test.sh <out>
#   <out>/q-vela/bin/qemu-system-riscv64
#   <out>/vela-fws/fw_dynamic.bin
#   <out>/vela-linux/Image, <out>/vela-linux/keystone-driver.ko
#   <out>/vela/ubuntu-noble-riscv64.qcow2
#   <out>/vela-apps/hello.vela
# Output: <out>/tee.log (serial), <out>/tee-qemu.log (-D)
#
# Files reach the guest through a virtio-9p share (mount tag "host0"); QEMU needs virtfs.
# Pass criterion: the package exits 0 and prints "[HOST] Terminating host...".
#
# Differences from boot-test.sh
#   - -smp is QEMU_SMP (default 1). With -smp 4 the hart that enters the enclave stalls (vela-fws SM issue).
#   - No hostfwd: files go through 9p and commands through the serial console.
#   - QEMU_MONITOR=<path> adds a QEMU monitor on a unix socket for debugging (socat - unix:<path>).
set -euo pipefail

[ $# -eq 1 ] || { echo "usage: $0 <out>" >&2; exit 2; }
out=$(cd "$1" && pwd)
QEMU_MEM=${QEMU_MEM:-4096}
QEMU_SMP=${QEMU_SMP:-1}
QEMU_MONITOR=${QEMU_MONITOR:-}
BOOT_TIMEOUT=${BOOT_TIMEOUT:-3600}
CMD_TIMEOUT=${CMD_TIMEOUT:-600}
PKG=${PKG:-hello.vela}
log=$out/tee.log
share=$out/tee-share
fifo=$out/tee.in

for f in q-vela/bin/qemu-system-riscv64 vela-fws/fw_dynamic.bin vela-linux/Image \
         vela-linux/keystone-driver.ko vela/ubuntu-noble-riscv64.qcow2 "vela-apps/$PKG"; do
  [ -f "$out/$f" ] || { echo "error: $out/$f missing" >&2; exit 1; }
done

rm -rf "$share" "$fifo"
mkdir -p "$share"
cp "$out/vela-linux/keystone-driver.ko" "$out/vela-apps/$PKG" "$share/"
mkfifo "$fifo"
: >"$log"
monitor=()
[ -z "$QEMU_MONITOR" ] || monitor=(-monitor "unix:$QEMU_MONITOR,server,nowait")

"$out/q-vela/bin/qemu-system-riscv64" \
  -machine virt,wg=on -nographic -m "$QEMU_MEM" -smp "$QEMU_SMP" \
  -bios "$out/vela-fws/fw_dynamic.bin" \
  -kernel "$out/vela-linux/Image" \
  -append "root=/dev/vda1 rw console=ttyS0 earlycon=sbi" \
  -cpu rv64,v=true,vlen=512,vext_spec=v1.0,zba=true,zbb=true,zbs=true,zbc=true,zbkb=true,zcb=true,zicond=true \
  -accel tcg,thread=multi \
  -semihosting-config enable=on,target=native,userspace=on \
  -netdev user,id=eth0 -device virtio-net-pci,netdev=eth0 \
  -device virtio-rng-pci \
  -drive file="$out/vela/ubuntu-noble-riscv64.qcow2",format=qcow2,if=virtio \
  -snapshot \
  -virtfs local,path="$share",mount_tag=host0,security_model=none,id=host0 \
  -device gemmini,id=gemmini0 \
  -D "$out/tee-qemu.log" \
  "${monitor[@]}" \
  <"$fifo" >"$log" 2>&1 &
pid=$!
exec 3>"$fifo"
trap 'exec 3>&-; kill "$pid" 2>/dev/null || true; rm -f "$fifo"' EXIT

mark=0
# Strip CRs and ANSI escapes (bash bracketed paste prints ESC[?2004l before command output).
since() { tail -c +$((mark + 1)) "$log" | tr -d '\r' | sed -E 's/\x1b\[[0-9;?]*[A-Za-z]//g'; }
send()  { mark=$(stat -c %s "$log"); printf '%s\r' "$1" >&3; }
fail()  { echo "error: $1" >&2; tail -50 "$log" >&2; exit 1; }

# wait_for <ERE> <timeout>: wait until output after the last send matches.
wait_for() {
  local start=$SECONDS
  until grep -qE "$1" <(since); do
    kill -0 "$pid" 2>/dev/null || fail "QEMU exited while waiting for /$1/"
    [ $((SECONDS - start)) -lt "$2" ] || fail "timeout (${2}s) waiting for /$1/"
    sleep 2
  done
}

# run <command>: run in the guest shell, return its exit code. The echoed command
# line contains "__RC__=$?", which the pattern does not match.
run() {
  send "$1; echo __RC__=\$?"
  wait_for '^__RC__=[0-9]+' "$CMD_TIMEOUT"
  return "$(since | grep -oE '^__RC__=[0-9]+' | tail -1 | cut -d= -f2)"
}

SUDO='echo | sudo -S -p ""'

start=$SECONDS
wait_for '^[[:alnum:]._-]+ login: ?$' "$BOOT_TIMEOUT"
echo "boot ok: login prompt after $((SECONDS - start))s"

send "vela"
send "echo __READY__"
wait_for '^__READY__$' 120

run "$SUDO mkdir -p /mnt/host && $SUDO mount -t 9p -o trans=virtio,version=9p2000.L host0 /mnt/host" \
  || fail "cannot mount the 9p share"
run "$SUDO insmod /mnt/host/keystone-driver.ko && test -c /dev/keystone_enclave" \
  || fail "cannot load keystone-driver.ko"
echo "driver ok: /dev/keystone_enclave present"

rc=0
run "cd /tmp && cp /mnt/host/$PKG . && $SUDO ./$PKG" || rc=$?
grep -qF '[HOST] Terminating host...' <(since) || fail "$PKG did not reach host termination (rc=$rc)"
[ "$rc" -eq 0 ] || fail "$PKG exited with $rc"
echo "tee ok: $PKG passed, tee.log $(wc -l <"$log") lines"

run "$SUDO dmesg | tail -20" || true
