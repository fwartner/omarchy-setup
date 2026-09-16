#!/usr/bin/env bash
# Join this laptop to the Headscale mesh using the Tailscale client.
# Needs: HEADSCALE_URL (from chezmoi data) and a pre-auth key
# (env HEADSCALE_AUTHKEY, or prompted; create with
#  `headscale preauthkeys create --user your-user --reusable --expiration 24h --tags tag:laptop`).
set -euo pipefail

HEADSCALE_URL="${HEADSCALE_URL:-$(chezmoi data 2>/dev/null | jq -r '.headscale_url // empty')}"
if [ -z "$HEADSCALE_URL" ]; then
  read -rp "Headscale login server URL (https://headscale.example.de): " HEADSCALE_URL
fi

if ! command -v tailscale >/dev/null 2>&1; then
  # Omarchy's own installer adds the bar panel; fall back to plain package.
  # One binary per service in omacom/omarchy bin/, not a command taking an argument.
  omarchy-install-service-tailscale 2>/dev/null \
    || omarchy install service-tailscale 2>/dev/null \
    || sudo omarchy-pkg-add tailscale
fi
sudo systemctl enable --now tailscaled

if tailscale status >/dev/null 2>&1 && [ "$(tailscale status --json | jq -r '.BackendState')" = "Running" ]; then
  echo "tailscale already running as $(tailscale status --json | jq -r '.Self.HostName')"
  exit 0
fi

AUTHKEY="${HEADSCALE_AUTHKEY:-}"
if [ -z "$AUTHKEY" ]; then
  read -rsp "Headscale pre-auth key (leave empty for browser login): " AUTHKEY; echo
fi

HOSTNAME_ARG="--hostname=$(chezmoi data 2>/dev/null | jq -r '.hostname // empty')"
[ "$HOSTNAME_ARG" = "--hostname=" ] && HOSTNAME_ARG=""

if [ -n "$AUTHKEY" ]; then
  # shellcheck disable=SC2086
  sudo tailscale up --login-server "$HEADSCALE_URL" --authkey "$AUTHKEY" \
    --accept-routes --accept-dns --ssh $HOSTNAME_ARG
else
  # shellcheck disable=SC2086
  sudo tailscale up --login-server "$HEADSCALE_URL" \
    --accept-routes --accept-dns --ssh $HOSTNAME_ARG
fi

tailscale status
