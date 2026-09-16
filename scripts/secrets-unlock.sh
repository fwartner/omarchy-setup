#!/usr/bin/env bash
# Configure rbw against Vaultwarden and unlock it, so chezmoi templates
# (rbw / rbwFields functions) and the other scripts can read secrets.
set -euo pipefail

VAULT_URL="$(chezmoi data 2>/dev/null | jq -r '.vault_url // empty')"
VAULT_EMAIL="$(chezmoi data 2>/dev/null | jq -r '.vault_email // empty')"

if ! command -v rbw >/dev/null 2>&1; then
  sudo omarchy-pkg-add rbw
fi

# rbw config: base_url points at Vaultwarden.
rbw config set base_url "$VAULT_URL"
rbw config set email "$VAULT_EMAIL"
rbw config set lock_timeout 3600

# Picking a pinentry is the fiddly part, for two reasons.
#
# 1. rbw does not prompt in your terminal. It runs a background agent, and the
#    agent spawns pinentry with no controlling terminal -- so pinentry-tty has
#    nothing to attach to and reports "pinentry cancelled", which reads like the
#    user pressed escape. Under a graphical session the GUI variants work,
#    because they talk to Wayland/X rather than a TTY.
# 2. All variants ship in one `pinentry` package, but each GUI one needs its own
#    libraries (Qt for qt, gcr for gnome3). A binary being present does not mean
#    it runs, so each candidate is executed before being chosen.
if ! command -v pinentry >/dev/null 2>&1; then
  sudo omarchy-pkg-add pinentry || true
fi

if [ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]; then
  # qt first: it draws its own window and needs only Qt plus a display. gnome3 is
  # last of the GUI three because it defers to gcr's prompter over D-Bus, which
  # Hyprland does not run, so it can pass --version and still fail to prompt.
  CANDIDATES="pinentry-qt pinentry-gtk pinentry-gnome3 pinentry-curses pinentry-tty"
else
  CANDIDATES="pinentry-curses pinentry-tty"
fi

PINENTRY=""
for p in $CANDIDATES; do
  if command -v "$p" >/dev/null 2>&1 && "$p" --version >/dev/null 2>&1; then
    PINENTRY="$p"; break
  fi
done

if [ -n "$PINENTRY" ]; then
  rbw config set pinentry "$PINENTRY"
  echo "pinentry: $PINENTRY"
else
  echo "WARNING: no working pinentry found; rbw unlock will fail. Tried: $CANDIDATES" >&2
fi

# The agent reads its config once at startup and keeps it. Without this, every
# fix above is invisible to the agent already running from the previous attempt,
# and the same failure repeats no matter what the config now says.
rbw stop-agent >/dev/null 2>&1 || true

if ! rbw unlocked >/dev/null 2>&1; then
  echo "Logging in to Vaultwarden as $VAULT_EMAIL ..."
  rbw login
  rbw unlock
fi
rbw sync
echo "vault unlocked, $(rbw list | wc -l) items visible"
