#!/usr/bin/env bash
# Boot a Kestrel disk image in QEMU/KVM, log in over SSH and ask systemd how the boot went.
# Pass: default target is graphical, the display manager (login screen) is active, and no
#       Kestrel or display-manager unit failed. Other failed units are reported as warnings.
# Usage: boot-test.sh <disk.qcow2> <ssh private key>   (test user: kestreltest)
set -euo pipefail

DISK="$1"
KEY="$2"
LOG="${SERIAL_LOG:-serial.log}"
TIMEOUT="${BOOT_TIMEOUT:-900}"
SSH=(ssh -i "${KEY}" -p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
     -o ConnectTimeout=5 -o LogLevel=ERROR kestreltest@127.0.0.1)
: > "${LOG}"

qemu-system-x86_64 \
    -machine q35,accel=kvm -cpu host -smp 2 -m 4096 \
    -drive file="${DISK}",if=virtio,format=qcow2 \
    -nic user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:2222-:22 \
    -display none -monitor none -serial file:"${LOG}" \
    -daemonize -pidfile qemu.pid
trap 'kill "$(cat qemu.pid)" 2>/dev/null || true' EXIT

echo "Waiting for SSH..."
for ((t = 0; t < TIMEOUT; t += 5)); do
    if grep -aqE 'Kernel panic|Entering emergency' "${LOG}"; then
        echo "::error::Boot crashed"; tail -n 60 "${LOG}"; exit 1
    fi
    "${SSH[@]}" true 2>/dev/null && break
    sleep 5
done
if ! "${SSH[@]}" true 2>/dev/null; then
    echo "::error::No SSH after ${TIMEOUT}s. Last console lines:"; tail -n 60 "${LOG}"; exit 1
fi
echo "SSH up after ~${t}s"

# Let first-boot jobs finish (Flatpak/Homebrew setup can take minutes); cap the wait.
state="$("${SSH[@]}" 'timeout 600 systemctl is-system-running --wait' || true)"
default="$("${SSH[@]}" 'systemctl get-default')"
dm="$("${SSH[@]}" 'systemctl is-active display-manager.service' || true)"
failed="$("${SSH[@]}" 'systemctl --failed --no-legend --plain | cut -d" " -f1' || true)"

echo "=== system state: ${state}"
echo "=== default target: ${default}"
echo "=== display-manager: ${dm}"
echo "=== failed units: ${failed:-none}"
for unit in ${failed}; do
    echo "::group::journal: ${unit}"
    "${SSH[@]}" "journalctl -b -u ${unit} --no-pager -n 40" || true
    echo "::endgroup::"
    echo "::warning::Failed unit: ${unit}"
done

rc=0
[[ "${default}" == graphical.target ]] || { echo "::error::Default target is ${default}"; rc=1; }
[[ "${dm}" == active ]] || { echo "::error::Login screen (display-manager) is ${dm}"; rc=1; }
if grep -Eq 'kestrel|sddm|display-manager' <<< "${failed}"; then
    echo "::error::A Kestrel service or the login screen failed"; rc=1
fi
((rc == 0)) && echo "Boot test passed."
exit "${rc}"
