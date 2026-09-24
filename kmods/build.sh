#!/usr/bin/env bash
# Build Kestrel's out-of-tree kernel modules for the kernel the Kestrel image will ship,
# and sign them if the module signing key was provided as a build secret.
# Output: /out/<kernel version>/*.ko (+ SIGNED marker when signed).
set -xeuo pipefail

SRC=/src
KEY=/run/secrets/kmod_key
CERT_PEM=/files/system/usr/share/kestrel/secureboot/kestrel-kmod.pem

# Same repos and upgrade as 10-base.sh, so this lands on the same kernel as the image.
dnf install -y 'dnf-command(config-manager)' epel-release
dnf config-manager --set-enabled crb
dnf upgrade -y --refresh --nobest 'kernel*'

KVER="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-core | sort -V | tail -n1)"
KVR="${KVER%.*}"
dnf install -y "kernel-devel-${KVR}" gcc make elfutils-libelf-devel openssl

OUT="/out/${KVER}"
mkdir -p "${OUT}"
BUILD="$(mktemp -d)"
cp -r "${SRC}/xpad" "${BUILD}/"
make -C "/usr/src/kernels/${KVER}" M="${BUILD}/xpad" modules
cp "${BUILD}/xpad/xpad.ko" "${OUT}/"

if [[ -s "${KEY}" ]]; then
    test -f "${CERT_PEM}" || { echo "::error::KMOD_SIGNING_KEY is set but ${CERT_PEM} is missing"; exit 1; }
    for ko in "${OUT}"/*.ko; do
        "/usr/src/kernels/${KVER}/scripts/sign-file" sha256 "${KEY}" "${CERT_PEM}" "${ko}"
        modinfo -F signer "${ko}" | grep . >/dev/null
    done
    touch "${OUT}/SIGNED"
else
    echo "::warning::No KMOD_SIGNING_KEY secret: modules are unsigned and only load with Secure Boot off"
fi
modinfo "${OUT}"/*.ko | grep -E '^(filename|vermagic|signer):' || true
