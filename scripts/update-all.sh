#!/usr/bin/env bash
# One updater for the whole machine: configuration, system, packages, themes,
# dev runtimes and project repos.
#
#   ./scripts/update-all.sh            everything
#   ./scripts/update-all.sh --config   just the dotfiles (what the 30min timer runs)
#
# Orchestrates Omarchy's own commands rather than reimplementing them:
# `omarchy-update -y` already snapshots Btrfs, updates pacman and AUR, runs
# migrations, updates mise, prunes orphans, and fires the post-update hook that
# re-applies chezmoi. Duplicating any of that would fight it.
set -uo pipefail

REPO_DIR="${REPO_DIR:-$HOME/.local/share/omarchy-setup}"
SOURCE_DIR="$REPO_DIR/home"
LOG="$HOME/.local/state/omarchy-setup-update.log"
mkdir -p "$(dirname "$LOG")"

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }
note() { command -v notify-send >/dev/null 2>&1 && notify-send "$@" || true; }

exec > >(tee -a "$LOG") 2>&1
echo "=== update-all $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="

# --- configuration -----------------------------------------------------------
# `chezmoi apply` only replays the local source state. Pulling is what makes a
# change pushed from another machine actually land here, and it is the whole
# reason this runs on a timer.
step "configuration (chezmoi update)"
if have chezmoi; then
  if [ -d "$SOURCE_DIR/.git" ] || [ -d "$REPO_DIR/.git" ]; then
    git -C "$REPO_DIR" pull --ff-only --quiet || echo "could not fast-forward $REPO_DIR; leaving it alone"
  fi
  chezmoi apply --source "$SOURCE_DIR" || echo "chezmoi apply reported errors"
  # Unit files may have just changed underneath us.
  systemctl --user daemon-reload 2>/dev/null || true
else
  echo "chezmoi not installed; skipping"
fi

if [ "${1:-}" = "--config" ]; then
  echo "config-only run finished"
  exit 0
fi

# --- system, packages, dev runtimes -----------------------------------------
step "system (omarchy-update -y)"
if have omarchy-update; then
  # `-y` is Omarchy's documented unattended mode. Two belts anyway:
  # omarchy-update runs itself under `script -qefc`, which allocates a pty, and
  # omarchy-update-restart calls `gum confirm` with no unattended guard. Without
  # stdin closed and a ceiling, a kernel update could park the timer on a prompt
  # nobody is there to answer.
  timeout 120m omarchy-update -y </dev/null
  rc=$?
  [ "$rc" -eq 124 ] && echo "omarchy-update hit the 120m timeout and was stopped"
else
  echo "not an Omarchy system; skipping"
fi

# --- packages declared by this repo -----------------------------------------
step "package manifests"
if have omarchy-pkg-add; then
  # Same role filter as bootstrap, via the same script. Without this a spare
  # machine had its GUI-heavy packages skipped at install and then quietly
  # reinstalled by the first nightly update.
  mapfile -t PKGS < <("$REPO_DIR/scripts/pkglist.sh" pacman)
  [ "${#PKGS[@]}" -gt 0 ] && sudo -n omarchy-pkg-add "${PKGS[@]}" 2>/dev/null \
    || echo "pacman manifest needs sudo; run ./scripts/update-all.sh by hand to reconcile"
  mapfile -t AUR < <("$REPO_DIR/scripts/pkglist.sh" aur)
  [ "${#AUR[@]}" -gt 0 ] && yay -S --needed --noconfirm "${AUR[@]}" </dev/null || true
else
  echo "omarchy-pkg-add not present; skipping"
fi

# --- themes ------------------------------------------------------------------
step "themes"
if have omarchy-theme-update; then
  omarchy-theme-update </dev/null || echo "theme update reported errors"
else
  echo "omarchy-theme-update not present; skipping"
fi

# --- coding-agent skills ------------------------------------------------------
step "agent skills"
if [ -x "$REPO_DIR/scripts/skills-setup.sh" ]; then
  "$REPO_DIR/scripts/skills-setup.sh" || true
else
  echo "skills-setup.sh missing; skipping"
fi

# --- project repos -----------------------------------------------------------
step "project repos"
if [ -x "$REPO_DIR/scripts/repo-sync.sh" ]; then
  "$REPO_DIR/scripts/repo-sync.sh" || true
else
  echo "repo-sync.sh missing; skipping"
fi

# --- reboot -------------------------------------------------------------------
# Never reboot a laptop from a timer. Omarchy leaves a marker; surface it and
# let the person at the keyboard choose the moment.
if [ -f "$HOME/.local/state/omarchy/reboot-required" ]; then
  step "reboot required"
  echo "Omarchy flagged a reboot. Nothing was restarted."
  note -u normal "Omarchy update" "A reboot is required to finish updating."
fi

echo
echo "update-all finished $(date -u +%Y-%m-%dT%H:%M:%SZ) — log: $LOG"
