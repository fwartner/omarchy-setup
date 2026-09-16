#!/usr/bin/env bash
# Only deployed on machines with wifi_driver = rtl8821ce (see .chezmoiignore).
# Rebuild the out-of-tree Realtek module after a kernel update.
set -euo pipefail
if pacman -Q rtl8821ce-dkms-git >/dev/null 2>&1; then
  sudo dkms autoinstall || true
fi
