#!/usr/bin/env bash
# Runs after `omarchy update`. Omarchy may migrate/reset user configs;
# re-apply our dotfiles so overrides survive.
set -euo pipefail
if command -v chezmoi >/dev/null 2>&1; then
  chezmoi apply --force --source "$HOME/.local/share/omarchy-setup/home" </dev/null || true
fi
