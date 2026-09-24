#!/usr/bin/env bash
# Refresh repos and pull the newest KDE Plasma that EPEL offers.
# The base image is rebuilt on AlmaLinux's schedule; upgrading here means every
# weekly Kestrel build picks up EPEL's latest Plasma without waiting for upstream.

set -xeuo pipefail

# EPEL + CRB are already enabled by the atomic-desktop base; make sure of it anyway.
dnf install -y 'dnf-command(config-manager)' epel-release
dnf config-manager --set-enabled crb

# Bring everything (Plasma, Frameworks, Mesa, firmware) up to the newest available.
dnf upgrade -y --refresh

# Log the Plasma version that ended up in the image (shows in CI logs).
rpm -q plasma-workspace kwin || true
