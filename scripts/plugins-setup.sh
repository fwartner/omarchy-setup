#!/usr/bin/env bash
# Install the Omarchy plugins listed in packages/plugins.txt.
#
#   ./scripts/plugins-setup.sh
#
# `omarchy plugin add` is idempotent enough to re-run: an already-installed
# plugin reports itself and is skipped rather than reinstalled.
set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="${PLUGIN_MANIFEST:-$SELF_DIR/../packages/plugins.txt}"

if ! command -v omarchy-plugin-add >/dev/null 2>&1; then
  echo "omarchy-plugin-add not present; skipping plugins"
  exit 0
fi
[ -f "$MANIFEST" ] || { echo "no plugin manifest at $MANIFEST"; exit 0; }

fail=0
while read -r url _; do
  [ -n "$url" ] || continue
  # --yes so an unattended bootstrap is not left on a confirmation prompt.
  if omarchy-plugin-add "$url" --enable --yes </dev/null; then
    printf '  installed %s\n' "$url"
  else
    printf '  FAILED    %s\n' "$url"; fail=$((fail + 1))
  fi
done < <(sed -E 's/#.*//' "$MANIFEST" | awk 'NF')

[ "$fail" -eq 0 ] || echo "$fail plugin(s) failed; the rest are installed"
exit 0
