#!/usr/bin/env bash
# bootstrap.sh — turn a fresh Omarchy 4.x install into a fleet workstation.
#
# Usage (on the laptop, as your normal user, after first login). The repo is
# private, so both the download and the clone need a token:
#   read -rsp 'GitHub token: ' REPO_TOKEN; echo; export REPO_TOKEN
#   curl -fsSL -H "Authorization: Bearer $REPO_TOKEN" \
#     https://raw.githubusercontent.com/fwartner/omarchy-setup/main/bootstrap.sh | bash
# or, with the repo already cloned:
#   ./bootstrap.sh
#
# Idempotent: safe to re-run after `omarchy update`.
# Environment overrides:
#   REPO_URL        git URL of this repo (default: github.com/fwartner/omarchy-setup)
#   REPO_TOKEN      GitHub token for the first clone (the repo is private)
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
  # The repo is private and the vault cannot help yet: rbw is configured from
  # data that lives in this repo, so the token for the very first clone has to
  # be pasted here or passed in REPO_TOKEN. GIT_TERMINAL_PROMPT=0 makes the
  # anonymous attempt fail fast instead of blocking on a username prompt.
  if [ -z "${REPO_TOKEN:-}" ] \
     && ! GIT_TERMINAL_PROMPT=0 git clone "$REPO_URL" "$REPO_DIR" 2>/dev/null; then
    echo "Private repository: a GitHub token is needed for the first clone."
    echo "Vault item github-token-laptops, or any token with Contents: read."
    read -rsp "GitHub token: " REPO_TOKEN; echo
  fi
  if [ ! -d "$REPO_DIR/.git" ]; then
    # "x-access-token" is a valid username for any GitHub token, so the real
    # account name never has to be known here.
    GIT_TERMINAL_PROMPT=0 git clone \
      "${REPO_URL/https:\/\//https://x-access-token:${REPO_TOKEN}@}" "$REPO_DIR"
  fi
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
ROLE="$(chezmoi data | jq -r '.role // "daily"')"
# GUI-heavy extras are skipped on spare machines (4 GB Gemini Lake etc.)
SPARE_SKIP='^(dbeaver|telegram-desktop|bitwarden|obsidian|bruno|harlequin|posting)$'
# pacman / Omarchy repo
mapfile -t PKGS < <(grep -vE '^\s*(#|$)' packages/pacman.txt | { if [ "$ROLE" = spare ]; then grep -vE "$SPARE_SKIP"; else cat; fi; })
sudo omarchy-pkg-add "${PKGS[@]}"
# AUR
mapfile -t AUR < <(grep -vE '^\s*(#|$)' packages/aur.txt | { if [ "$ROLE" = spare ]; then grep -vE "$SPARE_SKIP"; else cat; fi; })
if [ "${#AUR[@]}" -gt 0 ]; then
  yay -S --needed --noconfirm "${AUR[@]}"
fi
# krew plugins
if command -v kubectl-krew >/dev/null 2>&1 || [ -x "$HOME/.krew/bin/kubectl-krew" ]; then
  export PATH="$HOME/.krew/bin:$PATH"
  kubectl krew install ctx ns neat view-secret >/dev/null 2>&1 || true
fi

step "7/9 apply dotfiles"
chezmoi apply --source "$REPO_DIR/home"

step "8/9 editors, dev envs, agents, kube, sync"
if [ "${SKIP_EDITORS:-0}" != "1" ]; then
  # Omarchy's own installers so theme sync keeps working
  # Verified against omacom/omarchy bin/: the installers are one binary per
  # editor (omarchy-install-editor-vscode), not a command taking an argument.
  omarchy-install-editor-vscode 2>/dev/null || omarchy install editor-vscode 2>/dev/null || true
  if [ "$(chezmoi data | jq -r '.install_cursor')" = "true" ]; then
    # Omarchy ships installers for emacs, helix, vscode and zed only — there is
    # no Cursor one — so this comes from the AUR like any other unpackaged app.
    yay -S --needed --noconfirm cursor-bin </dev/null || true
  fi
  if [ -f "$HOME/.config/Code/User/extensions.txt" ] && have code; then
    while read -r ext; do
      [ -z "$ext" ] && continue
      code --install-extension "$ext" --force >/dev/null || true
    done < "$HOME/.config/Code/User/extensions.txt"
  fi
fi
# Ghostty as the Omarchy default terminal (keeps Super+Return etc. working)
# omarchy-setup-defaults does not exist. The real command is omarchy-default-terminal,
# and --install fetches the terminal as well as making it the default.
omarchy-default-terminal --install ghostty 2>/dev/null || omarchy default terminal ghostty 2>/dev/null || true
for lang in node bun go python php laravel; do
  omarchy-install-dev-env "$lang" 2>/dev/null || omarchy install dev-env "$lang" || true
done
# global composer bin (laravel installer)
if have composer && ! have laravel; then composer global require laravel/installer >/dev/null 2>&1 || true; fi
./scripts/agents-setup.sh

# The first clone of this private repo carries a PAT in the remote URL, because
# gh is not authenticated yet at that point. git stores that URL verbatim in
# .git/config, so the token would sit in plaintext on a machine that travels.
# agents-setup.sh has just run `gh auth setup-git`, so pulls work without it.
CURRENT_ORIGIN="$(git -C "$REPO_DIR" remote get-url origin)"
SCRUBBED_ORIGIN="$(printf '%s' "$CURRENT_ORIGIN" | sed -E 's#(https://)[^@/]*@#\1#')"
[ "$CURRENT_ORIGIN" != "$SCRUBBED_ORIGIN" ] && git -C "$REPO_DIR" remote set-url origin "$SCRUBBED_ORIGIN"

./scripts/kube-setup.sh
./scripts/sync-setup.sh
./scripts/repo-sync.sh || true

step "8b/9 automatic updates"
# The unit files are chezmoi-managed and landed in step 7; enabling them is the
# one imperative bit. daemon-reload first so a changed unit is picked up.
systemctl --user daemon-reload 2>/dev/null || true
for t in omarchy-config-sync.timer omarchy-update-all.timer; do
  systemctl --user enable --now "$t" 2>/dev/null && echo "enabled $t" || echo "could not enable $t"
done

step "9/9 verify"
./scripts/verify.sh || true

cat <<EOF

Bootstrap finished. Remaining manual steps:
  1. claude          → log in with your Claude subscription
  2. codex login     → log in with your OpenAI account
  3. Syncthing hub   → accept this device in the hub UI
  4. reboot          → picks up hypr overrides and shell changes

Automatic updates are on: config every 30min, full update daily.
Run one now with: ~/.local/share/omarchy-setup/scripts/update-all.sh
Log: $LOG
EOF
