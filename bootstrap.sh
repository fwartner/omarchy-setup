#!/usr/bin/env bash
# bootstrap.sh — turn a fresh Omarchy 4.x install into a fleet workstation.
#
# Usage (on the laptop, as your normal user, after first login):
#   curl -fsSL https://raw.githubusercontent.com/fwartner/omarchy-setup/main/bootstrap.sh | bash
# or, with the repo already cloned:
#   ./bootstrap.sh
#
# Idempotent: safe to re-run after `omarchy update`.
# Environment overrides:
#   REPO_URL        git URL of this repo (default: github.com/fwartner/omarchy-setup)
#   SKIP_HEADSCALE  set to 1 to skip mesh join
#   SKIP_EDITORS    set to 1 to skip VS Code / Cursor install

set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/fwartner/omarchy-setup.git}"
REPO_DIR="${REPO_DIR:-$HOME/.local/share/omarchy-setup}"
LOG="$HOME/.local/state/omarchy-setup-bootstrap.log"
mkdir -p "$(dirname "$LOG")"
exec > >(tee -a "$LOG") 2>&1

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

if ! have omarchy && [ ! -d /usr/share/omarchy ]; then
  echo "This does not look like an Omarchy system. Aborting." >&2
  exit 1
fi
if [ "$(id -u)" -eq 0 ]; then
  echo "Run as your normal user, not root." >&2
  exit 1
fi

step "0/9 sudo keep-alive"
sudo -v
( while true; do sudo -n true; sleep 50; kill -0 "$$" || exit; done ) 2>/dev/null &

step "1/9 base tooling (chezmoi, rbw, git, jq)"
sudo omarchy-pkg-add chezmoi rbw git jq fzf ripgrep fd

step "2/9 clone/update repo"
if [ -d "$REPO_DIR/.git" ]; then
  git -C "$REPO_DIR" pull --ff-only
else
  git clone "$REPO_URL" "$REPO_DIR"
fi
cd "$REPO_DIR"

step "3/9 chezmoi init (asks per-machine questions on first run)"
if [ ! -f "$HOME/.config/chezmoi/chezmoi.toml" ]; then
  chezmoi init --source "$REPO_DIR/home"
fi

step "4/9 Headscale mesh"
if [ "${SKIP_HEADSCALE:-0}" != "1" ]; then
  ./scripts/headscale-join.sh
fi

step "5/9 unlock Vaultwarden (rbw)"
./scripts/secrets-unlock.sh

step "6/9 packages"
# pacman / Omarchy repo
mapfile -t PKGS < <(grep -vE '^\s*(#|$)' packages/pacman.txt)
sudo omarchy-pkg-add "${PKGS[@]}"
# AUR
mapfile -t AUR < <(grep -vE '^\s*(#|$)' packages/aur.txt)
if [ "${#AUR[@]}" -gt 0 ]; then
  yay -S --needed --noconfirm "${AUR[@]}"
fi

step "7/9 apply dotfiles"
chezmoi apply --source "$REPO_DIR/home"

step "8/9 editors, dev envs, agents, kube, sync"
if [ "${SKIP_EDITORS:-0}" != "1" ]; then
  # Omarchy's own installers so theme sync keeps working
  omarchy-install-editor vscode 2>/dev/null || omarchy install editor vscode || true
  if [ "$(chezmoi data | jq -r '.install_cursor')" = "true" ]; then
    omarchy-install-editor cursor 2>/dev/null || omarchy install editor cursor || true
  fi
  if [ -f "$HOME/.config/Code/User/extensions.txt" ] && have code; then
    while read -r ext; do
      [ -z "$ext" ] && continue
      code --install-extension "$ext" --force >/dev/null || true
    done < "$HOME/.config/Code/User/extensions.txt"
  fi
fi
for lang in node bun go python php; do
  omarchy-install-dev-env "$lang" 2>/dev/null || omarchy install dev-env "$lang" || true
done
./scripts/agents-setup.sh
./scripts/kube-setup.sh
./scripts/sync-setup.sh

step "9/9 verify"
./scripts/verify.sh || true

cat <<EOF

Bootstrap finished. Remaining manual steps:
  1. claude          → log in with your Claude subscription
  2. codex login     → log in with your OpenAI account
  3. Syncthing hub   → accept this device in the hub UI
  4. reboot          → picks up hypr overrides and shell changes
Log: $LOG
EOF
