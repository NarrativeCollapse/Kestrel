#!/usr/bin/env bash
# Boot a Kestrel disk image in QEMU/KVM and watch the serial console.
# Pass: graphical.target reached and a login prompt shown, with no Kestrel or display
#       manager unit failing. Fail: panic, emergency mode, a failed key unit, or timeout.
set -euo pipefail

DISK="$1"
LOG="${SERIAL_LOG:-serial.log}"
TIMEOUT="${BOOT_TIMEOUT:-900}"
: > "${LOG}"

qemu-system-x86_64 \
    -machine q35,accel=kvm -cpu host -smp 2 -m 4096 \
    -drive file="${DISK}",if=virtio,format=qcow2 \
    -nic user,model=virtio-net-pci \
    -display none -monitor none -serial file:"${LOG}" \
    -daemonize -pidfile qemu.pid

result=timeout
for ((t = 0; t < TIMEOUT; t += 5)); do
    if grep -aqE 'Kernel panic|emergency mode|Entering emergency' "${LOG}"; then
        result=crashed; break
    fi
    if grep -aq 'Graphical Interface' "${LOG}" && grep -aq 'login:' "${LOG}"; then
        result=booted; break
    fi
    sleep 5
done
# Give services a moment to settle, then stop the VM.
[[ "${result}" == booted ]] && sleep 30
kill "$(cat qemu.pid)" 2>/dev/null || true

echo "=== Boot result: ${result} after ~${t}s ==="
failed="$(grep -a 'FAILED' "${LOG}" | sed 's/\x1b\[[0-9;]*m//g' | sort -u || true)"
if [[ -n "${failed}" ]]; then
    echo "Units that failed during boot:"
    echo "${failed}"
    while IFS= read -r line; do echo "::warning::${line}"; done <<< "${failed}"
fi

if [[ "${result}" != booted ]]; then
    echo "::error::VM did not reach the login screen (${result}). Last console lines:"
    tail -n 60 "${LOG}"
    exit 1
fi
if grep -Ei 'kestrel|sddm|display-manager' <<< "${failed}" >/dev/null; then
    echo "::error::A Kestrel service or the login screen failed to start"
    exit 1
fi
echo "Boot test passed."
