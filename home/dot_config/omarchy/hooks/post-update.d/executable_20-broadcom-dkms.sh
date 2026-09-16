#!/usr/bin/env bash
# Only deployed on machines with wifi_driver = broadcom (see .chezmoiignore).
# Rebuild the DKMS module after a kernel update so Wi-Fi comes back on reboot.
set -euo pipefail
if pacman -Q broadcom-wl-dkms >/dev/null 2>&1; then
  sudo dkms autoinstall || true
fi
