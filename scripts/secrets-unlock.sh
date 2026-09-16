#!/usr/bin/env bash
# Configure rbw against Vaultwarden and unlock it, so chezmoi templates
# (rbw / rbwFields functions) and the other scripts can read secrets.
set -euo pipefail

VAULT_URL="$(chezmoi data 2>/dev/null | jq -r '.vault_url // empty')"
VAULT_EMAIL="$(chezmoi data 2>/dev/null | jq -r '.vault_email // empty')"

if ! command -v rbw >/dev/null 2>&1; then
  sudo omarchy-pkg-add rbw
fi

# rbw config: base_url points at Vaultwarden; pinentry via the terminal.
rbw config set base_url "$VAULT_URL"
rbw config set email "$VAULT_EMAIL"
rbw config set pinentry pinentry-tty 2>/dev/null || true
rbw config set lock_timeout 3600

if ! rbw unlocked >/dev/null 2>&1; then
  echo "Logging in to Vaultwarden as $VAULT_EMAIL ..."
  rbw login
  rbw unlock
fi
rbw sync
echo "vault unlocked, $(rbw list | wc -l) items visible"
