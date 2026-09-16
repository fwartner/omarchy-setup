#!/usr/bin/env bash
# Mint a Headscale pre-auth key and park it in Vaultwarden as `headscale-preauth`.
#
# Run this on the Mac right before installing a laptop — the key expires in 24h,
# which is why it is not created during Phase 0.
#
#   ./scripts/mac/new-laptop-key.sh
#
# Needs: kubectl pointed at the Pixel & Process cluster, jq, and the Bitwarden CLI
# unlocked (`bw login && export BW_SESSION="$(bw unlock --raw)"`). rbw cannot
# write items, so the official CLI does the writing; the laptops still read with rbw.
set -euo pipefail

ITEM="headscale-preauth"
USER_NAME="${HEADSCALE_USER:-your-user}"
TAG="${HEADSCALE_TAG:-tag:laptop}"
EXPIRY="${HEADSCALE_EXPIRY:-24h}"
# Homebrew's bw is shadowed on this Mac by ~/.brv-cli/bin/bw, so resolve it explicitly.
BW="${BW:-$(command -v /opt/homebrew/bin/bw || command -v bw)}"

[ -n "${BW_SESSION:-}" ] || { echo "BW_SESSION is empty. Run: export BW_SESSION=\"\$($BW unlock --raw)\"" >&2; exit 1; }

hs() { kubectl -n headscale exec deploy/headscale -- headscale "$@"; }

# headscale 0.29 takes a numeric user ID here, not a name (`--user your-user` is
# rejected). Resolve it so the script survives the user being recreated.
USER_ID="$(hs users list -o json | jq -r --arg n "$USER_NAME" '.[] | select(.name == $n) | .id')"
[ -n "$USER_ID" ] || { echo "no headscale user named $USER_NAME" >&2; exit 1; }

# Tags are forced server-side from the key, so this works with no ACL policy
# loaded (the tailnet is allow-all today). Verified against headscale v0.29.3.
KEY="$(hs preauthkeys create -u "$USER_ID" --reusable --expiration "$EXPIRY" --tags "$TAG" -o json | jq -r .key)"
[ -n "$KEY" ] && [ "$KEY" != "null" ] || { echo "headscale returned no key" >&2; exit 1; }

"$BW" sync >/dev/null
if ID="$("$BW" get item "$ITEM" 2>/dev/null | jq -r .id)" && [ -n "$ID" ] && [ "$ID" != "null" ]; then
  "$BW" get item "$ID" \
    | jq --arg k "$KEY" '.login.password = $k' \
    | "$BW" encode | "$BW" edit item "$ID" >/dev/null
  echo "updated vault item $ITEM"
else
  "$BW" get template item \
    | jq --arg n "$ITEM" --arg k "$KEY" \
        '.type = 1 | .name = $n | .notes = "Headscale pre-auth key, reusable, 24h. Minted by scripts/mac/new-laptop-key.sh." | .login = {username: "", password: $k, totp: null, uris: []}' \
    | "$BW" encode | "$BW" create item >/dev/null
  echo "created vault item $ITEM"
fi

echo "key expires in $EXPIRY. On the laptop the bootstrap reads it, or paste it by hand."
