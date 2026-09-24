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
    fastfetch \
    btop \
    htop \
    p7zip \
    unzip

# Containers: podman and distrobox are required, not optional.
dnf install -y podman
if dnf -q repoquery --available --latest-limit=1 distrobox 2>/dev/null | grep . >/dev/null; then
    dnf install -y distrobox
else
    # Not packaged for EL10/EPEL 10: install the upstream release, pinned to its exact commit.
    DISTROBOX_VERSION="1.8.2.5"
    DISTROBOX_COMMIT="40c3cd724faa434aeb0a23e28776665b92de68bd"
    dnf install -y git-core
    DB_SRC="$(mktemp -d)"
    git clone --quiet --depth 1 --branch "${DISTROBOX_VERSION}" https://github.com/89luca89/distrobox "${DB_SRC}"
    test "$(git -C "${DB_SRC}" rev-parse HEAD)" = "${DISTROBOX_COMMIT}"
    (cd "${DB_SRC}" && ./install --prefix /usr)
    rm -rf "${DB_SRC}"
fi
distrobox version

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
