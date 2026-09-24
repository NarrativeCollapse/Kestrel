#!/usr/bin/env bash
# Host-side gaming support.
# EL10 has no 32-bit (i686) packages, so Steam/Proton/Wine run as Flatpaks
# installed by the user from Bazaar. This script handles what must live on the host:
# power profiles, zram, GameMode, and enabling Kestrel's services.
# sysctl, udev and module files come from files/system.

set -xeuo pipefail
source "$(dirname "$0")/lib.sh"

# tuned-ppd: Plasma's power-profile slider (EL10 replaces power-profiles-daemon with it)
# zram-generator: compressed RAM swap
# gamemode: host daemon Steam/Lutris Flatpaks talk to via the GameMode portal
install_optional \
    tuned-ppd \
    zram-generator \
    gamemode

if rpm -q tuned >/dev/null 2>&1; then
    systemctl enable tuned.service
fi
if rpm -q tuned-ppd >/dev/null 2>&1; then
    systemctl enable tuned-ppd.service
fi

# zram swap tuning only makes sense when swap is actually in RAM.
if rpm -q zram-generator >/dev/null 2>&1; then
    cat > /usr/lib/sysctl.d/61-kestrel-zram.conf <<'EOF'
# zram swap is cheap; swap anonymous memory before dropping file cache.
vm.swappiness = 180
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
vm.page-cluster = 0
EOF
else
    rm -f /usr/lib/systemd/zram-generator.conf
fi

chmod 0755 /usr/bin/kestrel-flatpak-extras
systemctl enable kestrel-flatpak-extras.timer
