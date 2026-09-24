#!/usr/bin/env bash
# Terminal "bling", modelled on Bazzite: Homebrew, Nerd Font icons, starship prompt,
# eza/ugrep aliases, atuin history, zoxide, and a fastfetch banner.
# Homebrew itself lives in /var/home/linuxbrew (writable), unpacked on first boot by
# brew-setup.service; kestrel-brew-bling.service then installs the CLI tools from
# /usr/share/kestrel/Brewfile. Shell setup: /etc/profile.d/kestrel-bling.sh.

set -xeuo pipefail

NERD_FONTS_VERSION="v3.4.0"

# --- Homebrew (files from ghcr.io/ublue-os/brew, see Dockerfile) ---
# Homebrew needs git, curl and procps on the host; zstd unpacks its tarball on first boot.
dnf install -y git-core curl procps-ng file zstd
cp -a /ctx/brew_files/. /
test -f /usr/share/homebrew.tar.zst
systemctl enable brew-setup.service brew-update.timer brew-upgrade.timer
systemctl enable kestrel-brew-bling.service

# --- Nerd Font symbols: icons for starship/eza/fastfetch, used as a fallback by any font ---
WORK="$(mktemp -d)"
NF_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONTS_VERSION}"
curl -fsSL --retry 3 -o "${WORK}/NerdFontsSymbolsOnly.tar.xz" "${NF_URL}/NerdFontsSymbolsOnly.tar.xz"
curl -fsSL --retry 3 -o "${WORK}/SHA-256.txt" "${NF_URL}/SHA-256.txt"
NF_SHA="$(awk '$NF ~ /(^|[*\/])NerdFontsSymbolsOnly\.tar\.xz$/ {print $1}' "${WORK}/SHA-256.txt")"
test -n "${NF_SHA}"
echo "${NF_SHA}  ${WORK}/NerdFontsSymbolsOnly.tar.xz" | sha256sum -c -
mkdir -p /usr/share/fonts/nerd-fonts-symbols "${WORK}/nf"
tar -xJf "${WORK}/NerdFontsSymbolsOnly.tar.xz" -C "${WORK}/nf"
find "${WORK}/nf" -name '*.ttf' -exec install -m 0644 {} /usr/share/fonts/nerd-fonts-symbols/ \;
if [[ -f "${WORK}/nf/10-nerd-font-symbols.conf" ]]; then
    install -m 0644 "${WORK}/nf/10-nerd-font-symbols.conf" /usr/share/fontconfig/conf.avail/
    ln -sf /usr/share/fontconfig/conf.avail/10-nerd-font-symbols.conf /etc/fonts/conf.d/
fi
fc-cache -f /usr/share/fonts/nerd-fonts-symbols
test -n "$(fc-list 'Symbols Nerd Font')"
rm -rf "${WORK}"
