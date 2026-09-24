#!/usr/bin/env bash
# Laptop audio. Intel laptops from ~10th gen on (incl. Alder Lake-N like the i3-N305) route
# speakers and digital mics through the SOF audio DSP. The kernel driver is there, but without
# the SOF firmware/topology files PipeWire only sees "Dummy Output", and without the ALSA UCM
# profiles it can't map speakers/headphones/mics. Fedora-based spins (e.g. Bazzite) ship both.

set -xeuo pipefail
source "$(dirname "$0")/lib.sh"

dnf install -y alsa-sof-firmware
install_optional \
    alsa-ucm \
    alsa-utils \
    pipewire-alsa \
    pipewire-pulseaudio \
    wireplumber

# Show what the image carries for Alder Lake-N (logged for CI).
find /usr/lib/firmware/intel -path '*sof*' -iname '*adl*' | sort | head -n 20 || true
