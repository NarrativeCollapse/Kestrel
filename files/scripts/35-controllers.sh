#!/usr/bin/env bash
# Xbox controllers (and other pads) with in-kernel drivers:
#   USB:       xpad          (Xbox 360 / One / Series, wired)
#   Bluetooth: hid-microsoft (Xbox One S / Series with Bluetooth firmware)
# Permissions for Flatpak apps come from 70-kestrel-game-controllers.rules (Microsoft 045e).
# Not covered: the Xbox Wireless Adapter USB dongle needs the out-of-tree xone driver plus
# Microsoft firmware, and unsigned modules don't load with Secure Boot on. See README.

set -xeuo pipefail
source "$(dirname "$0")/lib.sh"

KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-core | sort -V | tail -n1)"
KVR="${KVER%.*}"

has_module() { find "/usr/lib/modules/${KVER}" -name "$1.ko*" -print -quit | grep . >/dev/null; }

# RHEL-family kernels put less common drivers in kernel-modules-extra.
if ! has_module xpad || ! has_module hid-microsoft; then
    install_optional "kernel-modules-extra-${KVR}"
fi
for mod in xpad hid-microsoft; do
    if has_module "${mod}"; then
        echo "${mod}: present for ${KVER}"
    else
        echo "::warning::Kernel module ${mod} not available for ${KVER}; Xbox controller support is incomplete"
        mkdir -p /usr/share/kestrel
        echo "kernel module: ${mod}" >> /usr/share/kestrel/missing-optional-packages
    fi
done
depmod -a "${KVER}"

# Bluetooth for wireless pads
dnf install -y bluez
systemctl enable bluetooth.service

# Xbox controllers re-pair and reconnect more reliably with these BlueZ settings.
BT_CONF=/etc/bluetooth/main.conf
if [[ -f "${BT_CONF}" ]]; then
    sed -i \
        -e 's/^#\?\s*JustWorksRepairing\s*=.*/JustWorksRepairing = always/' \
        -e 's/^#\?\s*FastConnectable\s*=.*/FastConnectable = true/' \
        "${BT_CONF}"
    grep -E '^(JustWorksRepairing|FastConnectable)' "${BT_CONF}" || echo "::warning::BlueZ settings not found in ${BT_CONF}"
fi
