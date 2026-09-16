#!/usr/bin/env bash
# Emit the package list for a manifest, filtered for this machine's role.
#
#   ./scripts/pkglist.sh pacman        names from packages/pacman.txt
#   ./scripts/pkglist.sh aur           names from packages/aur.txt
#   ROLE=spare ./scripts/pkglist.sh pacman
#
# Exists so bootstrap.sh and update-all.sh cannot disagree: they used to hold
# their own copies of the filter, which meant a spare machine had the GUI-heavy
# packages skipped at install and then reinstalled by the next nightly update.
set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR="${MANIFEST_DIR:-$SELF_DIR/../packages}"

# GUI-heavy extras, skipped on spare machines (4 GB Gemini Lake etc.).
SPARE_SKIP='^(dbeaver|telegram-desktop|bitwarden|obsidian|bruno|harlequin|posting)$'

role() {
  [ -n "${ROLE:-}" ] && { printf '%s\n' "$ROLE"; return; }
  chezmoi data 2>/dev/null | jq -r '.role // "daily"' 2>/dev/null || echo daily
}

main() {
  local which="${1:?usage: pkglist.sh pacman|aur}"
  local file="$MANIFEST_DIR/$which.txt"
  [ -f "$file" ] || { echo "no manifest at $file" >&2; return 1; }
  if [ "$(role)" = spare ]; then
    grep -vE '^\s*(#|$)' "$file" | awk '{print $1}' | grep -vE "$SPARE_SKIP"
  else
    grep -vE '^\s*(#|$)' "$file" | awk '{print $1}'
  fi
  return 0
}

[ "${BASH_SOURCE[0]}" = "$0" ] && main "$@"
