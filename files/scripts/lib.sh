#!/usr/bin/env bash
# Shared helpers for Kestrel build scripts. Sourced, not executed
# (build.sh only runs files named NN-*.sh).

# install_optional PKG...
# EL10 + EPEL package availability shifts between minor releases. Required packages
# go through plain `dnf install` (build fails if missing); nice-to-haves go through
# here so a missing one is logged instead of breaking the weekly build.
install_optional() {
    local pkg available=() missing=()
    for pkg in "$@"; do
        if dnf -q repoquery --available --latest-limit=1 "$pkg" 2>/dev/null | grep . >/dev/null; then
            available+=("$pkg")
        else
            missing+=("$pkg")
        fi
    done
    if ((${#available[@]})); then
        dnf install -y "${available[@]}"
    fi
    if ((${#missing[@]})); then
        echo "::warning::Optional packages not available, skipped: ${missing[*]}"
    fi
}
