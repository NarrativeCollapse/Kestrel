#!/usr/bin/env bash
# Intel integrated graphics: Vulkan (ANV), OpenGL (Iris), VA-API video decode, firmware, tools.
# Note: Flatpak games (Steam etc.) use the Flatpak runtime's own, newer Mesa — these host
# packages matter for native apps, the desktop compositor and hardware video decode.

set -xeuo pipefail
source "$(dirname "$0")/lib.sh"

dnf install -y \
    mesa-dri-drivers \
    mesa-vulkan-drivers \
    vulkan-loader \
    linux-firmware

# Hardware video decode (VA-API, "iHD") for Broadwell and newer, incl. Alder Lake-N.
# RPM Fusion's intel-media-driver has every codec; the free libva-intel-media-driver is the
# fallback. They conflict, so only one is installed.
install_optional intel-media-driver
if ! rpm -q intel-media-driver >/dev/null 2>&1; then
    install_optional libva-intel-media-driver
fi

install_optional \
    libva-utils \
    vulkan-tools \
    mesa-demos \
    igt-gpu-tools \
    intel-gpu-tools \
    intel-gpu-firmware
