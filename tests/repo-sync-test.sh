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
  'your-github-user/burrow' \
  'your-org/gitops   pull-only' \
  '   ' \
  'your-org/lockwaved # trailing comment' \
  | manifest_entries)"
eq "entry count"        "$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')" "3"
eq "plain entry"        "$(printf '%s\n' "$OUT" | sed -n 1p)" "$(printf 'your-github-user/burrow\t-')"
eq "flagged entry"      "$(printf '%s\n' "$OUT" | sed -n 2p)" "$(printf 'your-org/gitops\tpull-only')"
eq "trailing comment"   "$(printf '%s\n' "$OUT" | sed -n 3p)" "$(printf 'your-org/lockwaved\t-')"

echo "secret_paths filter"
GOT="$(printf '%s\n' src/main.go .env README.md deploy.pem | secret_paths | tr '\n' ' ')"
eq "filters to secrets only" "$GOT" ".env deploy.pem "

# --- integration: the refusal path, against real git, fully offline ----------
# The unit tests above prove looks_secret() classifies correctly. This proves
# the classification is actually wired into sync_one() and stops the commit --
# the failure that would publish a secret is the two being disconnected.
echo "integration: secret refusal"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
git init -q --bare "$TMP/origin.git"
git -c init.defaultBranch=main clone -q "$TMP/origin.git" "$TMP/work" 2>/dev/null
(
  cd "$TMP/work" || exit 1
  git config user.email t@t; git config user.name t
  git checkout -q -b main 2>/dev/null || true
  echo hello > README.md && git add -A && git commit -qm init && git push -q -u origin main
) >/dev/null 2>&1

mkdir -p "$TMP/p/acme"
cp -R "$TMP/work" "$TMP/p/acme/widget"
git -C "$TMP/p/acme/widget" remote set-url origin "$TMP/origin.git"

# An un-ignored .env is the case that matters: gitignored secrets never reach
# git status at all, so they are not what this guard is for.
printf 'API_KEY=hunter2\n' > "$TMP/p/acme/widget/.env"
printf 'notes\n' > "$TMP/p/acme/widget/notes.md"

OUT="$(PROJECTS_ROOT="$TMP/p" sync_one acme/widget - 2>&1)"
eq "refuses the repo"         "$(printf '%s' "$OUT" | grep -c 'NOT committed')" "1"
eq "names the offending file" "$(printf '%s' "$OUT" | grep -c '[.]env')" "1"
eq "made no commit"           "$(git -C "$TMP/p/acme/widget" log --oneline | wc -l | tr -d ' ')" "1"
eq "pushed nothing"           "$(git -C "$TMP/origin.git" for-each-ref --format='%(refname:short)' | grep -c wip)" "0"
eq "left the work in place"   "$(cat "$TMP/p/acme/widget/.env")" "API_KEY=hunter2"

# Same repo without the secret must go through and reach the remote.
rm "$TMP/p/acme/widget/.env"
OUT="$(PROJECTS_ROOT="$TMP/p" sync_one acme/widget - 2>&1)"
eq "commits clean work"     "$(git -C "$TMP/p/acme/widget" log --oneline | wc -l | tr -d ' ')" "2"
eq "used a wip branch"      "$(git -C "$TMP/p/acme/widget" symbolic-ref --short HEAD | cut -d/ -f1)" "wip"
eq "reached the remote"     "$(git -C "$TMP/origin.git" for-each-ref --format='%(refname:short)' | grep -c wip)" "1"
eq "did not touch main"     "$(git -C "$TMP/origin.git" log --oneline main | wc -l | tr -d ' ')" "1"

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
