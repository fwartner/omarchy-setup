#!/usr/bin/env bash
# Resolve the current Omarchy ISO — version, URL and SHA256 — from the release
# notes themselves. Nothing is pinned here, so a new Omarchy release needs no
# edit to this repo. Omarchy ships roughly weekly; hardcoded versions rot.
#
#   ./scripts/mac/latest-iso.sh              report only
#   ./scripts/mac/latest-iso.sh --download   fetch into ~/Downloads and verify
#
# Exits non-zero on a checksum mismatch, so it is safe to chain.
set -euo pipefail

REPO="${OMARCHY_REPO:-omacom/omarchy}"
DEST_DIR="${DEST_DIR:-$HOME/Downloads}"

case "${1:-}" in
  # Print the comment header and stop at the first line of code, so this stays
  # correct when the header grows.
  -h|--help) awk 'NR>1 && /^#/ {sub(/^# ?/,""); print; next} NR>1 {exit}' "$0"; exit 0 ;;
esac

REL="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest")"
TAG="$(printf '%s' "$REL" | jq -r '.tag_name // empty')"
NOTES="$(printf '%s' "$REL" | jq -r '.body // empty')"

# The release notes carry both values verbatim; parse them rather than guessing
# a URL from the tag, so a change in their naming shows up as a clean failure.
URL="$(printf '%s' "$NOTES" | grep -oE 'https://iso\.omarchy\.org/omarchy-[0-9.]+\.iso' | head -1)"
SHA="$(printf '%s' "$NOTES" | grep -oiE 'sha256:[[:space:]]*[0-9a-f]{64}' | grep -oE '[0-9a-f]{64}' | head -1)"

[ -n "$TAG" ] || { echo "could not read the latest release tag from $REPO" >&2; exit 1; }
[ -n "$URL" ] || { echo "release notes for $TAG carry no iso.omarchy.org URL" >&2; exit 1; }
[ -n "$SHA" ] || { echo "release notes for $TAG carry no SHA256" >&2; exit 1; }

ISO="$DEST_DIR/$(basename "$URL")"

sum() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
  else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

if [ "${1:-}" = "--download" ]; then
  mkdir -p "$DEST_DIR"
  REMOTE_BYTES="$(curl -fsSLI "$URL" | tr -d '\r' | awk 'tolower($1)=="content-length:"{n=$2} END{print n}')"
  LOCAL_BYTES=0
  [ -f "$ISO" ] && LOCAL_BYTES="$(wc -c < "$ISO" | tr -d ' ')"
  # Resuming onto a file that is already at or past full length appends garbage,
  # so only resume a genuinely short one and restart anything else.
  if [ -n "$REMOTE_BYTES" ] && [ "$LOCAL_BYTES" -gt "$REMOTE_BYTES" ]; then
    echo "local file is larger than the published ISO; starting over"
    rm -f "$ISO"
  fi
  if [ ! -s "$ISO" ] || [ "$(sum "$ISO")" != "$SHA" ]; then
    curl -fL --retry 3 -C - -o "$ISO" "$URL"
  fi
fi

printf 'latest:   %s\n' "$TAG"
printf 'url:      %s\n' "$URL"
printf 'sha256:   %s\n' "$SHA"

if [ -s "$ISO" ]; then
  GOT="$(sum "$ISO")"
  if [ "$GOT" = "$SHA" ]; then
    printf 'local:    %s  (verified)\n' "$ISO"
  else
    printf 'local:    %s  (CHECKSUM MISMATCH)\n' "$ISO" >&2
    printf '  expected %s\n  got      %s\n' "$SHA" "$GOT" >&2
    exit 1
  fi
else
  printf 'local:    not downloaded — run with --download\n'
fi
