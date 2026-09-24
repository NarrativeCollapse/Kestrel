#!/usr/bin/env bash
# Branding. Change DISTRO_NAME to rename the distro everywhere it's shown.
# ID stays "almalinux" on purpose — tools (dnf, EPEL, installers) key off it.

set -xeuo pipefail

DISTRO_NAME="Kestrel"
DISTRO_TAGLINE="AlmaLinux Atomic KDE for gaming"

VERSION_ID="$(. /usr/lib/os-release && echo "${VERSION_ID}")"

sed -i \
    -e "s|^PRETTY_NAME=.*|PRETTY_NAME=\"${DISTRO_NAME} ${VERSION_ID} (${DISTRO_TAGLINE})\"|" \
    -e "s|^NAME=.*|NAME=\"${DISTRO_NAME}\"|" \
    /usr/lib/os-release

sed -i '/^VARIANT=/d' /usr/lib/os-release
echo "VARIANT=\"Gaming\"" >> /usr/lib/os-release

# Shown in KDE's "About This System" (kinfocenter)
mkdir -p /etc/xdg
cat > /etc/xdg/kcm-about-distrorc <<EOF
[General]
Name=${DISTRO_NAME}
Variant=${DISTRO_TAGLINE}
Website=https://almalinux.org
EOF

cat /usr/lib/os-release
