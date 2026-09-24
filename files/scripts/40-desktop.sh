#!/usr/bin/env bash
# Daily-driver desktop extras on top of the base KDE install.
# Native RPMs for KDE apps (integrate best with Plasma); everything else is a Flatpak.

set -xeuo pipefail
source "$(dirname "$0")/lib.sh"

install_optional \
    kate \
    ark \
    kcalc \
    spectacle \
    filelight \
    kdeconnectd \
    kde-partitionmanager \
    plasma-systemmonitor \
    kde-gtk-config \
    ffmpegthumbs \
    kio-extras \
    distrobox \
    fastfetch \
    btop \
    htop \
    p7zip \
    unzip

# Browser: LibreWolf (Flatpak) replaces Firefox. Drop the Firefox RPM if the base shipped one.
if rpm -q firefox >/dev/null 2>&1; then
    dnf remove -y firefox
fi

# App store: Bazaar (Flatpak) replaces KDE Discover.
# Remove Discover and its backends/notifier; list what dnf takes with it in the build log.
DISCOVER_PKGS=$(rpm -qa --qf '%{NAME}\n' 'plasma-discover*' | sort -u)
if [[ -n "${DISCOVER_PKGS}" ]]; then
    # shellcheck disable=SC2086
    dnf remove -y ${DISCOVER_PKGS}
fi

# Discover's notifier used to keep Flatpaks updated; a daily timer does it now.
systemctl enable kestrel-flatpak-update.timer
