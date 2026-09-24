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

install_optional \
    intel-media-driver \
    libva-intel-media-driver \
    libva-utils \
    vulkan-tools \
    mesa-demos \
    intel-gpu-tools \
    intel-gpu-firmware
