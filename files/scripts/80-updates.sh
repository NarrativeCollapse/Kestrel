#!/usr/bin/env bash
# OS updates: download the new image in the background daily, apply on the next reboot.

set -xeuo pipefail

systemctl enable kestrel-os-update.timer

# bootc's own timer runs `bootc upgrade --apply`, which reboots the machine to apply
# an update — not something a desktop should do mid-game. Keep it off.
if systemctl list-unit-files bootc-fetch-apply-updates.timer >/dev/null 2>&1; then
    systemctl disable bootc-fetch-apply-updates.timer || true
fi
