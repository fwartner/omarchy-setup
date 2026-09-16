#!/usr/bin/env bash
# Self-check for the two pure helpers in scripts/repo-sync.sh: manifest parsing
# and the secret denylist. These are the parts where a bug is silent and costly
# — a missed secret gets pushed to GitHub and cannot be unpublished.
#
#   ./tests/repo-sync-test.sh
set -uo pipefail

# shellcheck source=../scripts/repo-sync.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../scripts/repo-sync.sh"

pass=0; fail=0
eq() {
  if [ "$2" = "$3" ]; then pass=$((pass+1));
  else fail=$((fail+1)); printf '  ✘ %s\n     want: %s\n     got:  %s\n' "$1" "$3" "$2"; fi
}
is_secret()  { looks_secret "$1" && echo yes || echo no; }

echo "secret denylist"
for p in .env .env.local .env.production config/.env deploy.pem server.key \
         id_ed25519 id_rsa credentials.json service-account-prod.json \
         cluster.kubeconfig app.p12 release.jks; do
  eq "$p is a secret" "$(is_secret "$p")" "yes"
done
for p in README.md src/main.go .envrc environment.ts keyboard.tsx \
         docs/credentials-guide.md pemberton.txt monkey.json src/key.go; do
  eq "$p is not a secret" "$(is_secret "$p")" "no"
done

echo "manifest parsing"
OUT="$(printf '%s\n' \
  '# a comment' \
  '' \
  'fwartner/burrow' \
  'Pixel-Process-UG/gitops   pull-only' \
  '   ' \
  'Lockwave-io/lockwaved # trailing comment' \
  | manifest_entries)"
eq "entry count"        "$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')" "3"
eq "plain entry"        "$(printf '%s\n' "$OUT" | sed -n 1p)" "$(printf 'fwartner/burrow\t-')"
eq "flagged entry"      "$(printf '%s\n' "$OUT" | sed -n 2p)" "$(printf 'Pixel-Process-UG/gitops\tpull-only')"
eq "trailing comment"   "$(printf '%s\n' "$OUT" | sed -n 3p)" "$(printf 'Lockwave-io/lockwaved\t-')"

echo "secret_paths filter"
GOT="$(printf '%s\n' src/main.go .env README.md deploy.pem | secret_paths | tr '\n' ' ')"
eq "filters to secrets only" "$GOT" ".env deploy.pem "

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
