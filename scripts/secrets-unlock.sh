#!/usr/bin/env bash
# Configure rbw against Vaultwarden and unlock it, so chezmoi templates
# (rbw / rbwFields functions) and the other scripts can read secrets.
set -euo pipefail

VAULT_URL="$(chezmoi data 2>/dev/null | jq -r '.vault_url // empty')"
VAULT_EMAIL="$(chezmoi data 2>/dev/null | jq -r '.vault_email // empty')"

if ! command -v rbw >/dev/null 2>&1; then
  sudo omarchy-pkg-add rbw
fi

# rbw config: base_url points at Vaultwarden; pinentry asks for the master password.
rbw config set base_url "$VAULT_URL"
rbw config set email "$VAULT_EMAIL"

# rbw shells out to whatever `pinentry` is configured here. Pointing it at a
# binary that does not exist fails as "pinentry cancelled", which looks like the
# user pressed escape. Install it if missing, then pick one that is really there.
if ! command -v pinentry-tty >/dev/null 2>&1 && ! command -v pinentry-curses >/dev/null 2>&1; then
  sudo omarchy-pkg-add pinentry || true
fi
for p in pinentry-tty pinentry-curses pinentry; do
  if command -v "$p" >/dev/null 2>&1; then rbw config set pinentry "$p"; break; fi
done
command -v "$(rbw config show | jq -r .pinentry)" >/dev/null 2>&1 \
  || echo "WARNING: no usable pinentry found; rbw unlock will fail" >&2
rbw config set lock_timeout 3600

if ! rbw unlocked >/dev/null 2>&1; then
  echo "Logging in to Vaultwarden as $VAULT_EMAIL ..."
  rbw login
  rbw unlock
fi
rbw sync
echo "vault unlocked, $(rbw list | wc -l) items visible"
