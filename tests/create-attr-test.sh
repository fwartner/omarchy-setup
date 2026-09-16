#!/usr/bin/env bash
# Self-check for the files the apps own as much as this repo does.
#
#   ./tests/create-attr-test.sh      (skipped when chezmoi is not installed)
#
# Four targets are written by their own program as well as by chezmoi: Claude
# Code adds hooks to .claude/settings.json, codex rewrites .codex/config.toml
# on login, VS Code rewrites its settings.json on any UI change, and mise
# rewrites its config on `mise use`. Every unattended apply passes --force
# since bootstrap otherwise stopped on a conflict prompt, so without the
# create_ attribute the nightly timer reverts all four and the apps write them
# again -- a revert war nobody watches, which on the pilot had already eaten a
# plugin's SessionStart hook.
#
# create_ means: write it on a machine that does not have it, never touch it
# again. This asserts the second half, which is the half that costs data.
set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SELF_DIR/../home"

if ! command -v chezmoi >/dev/null 2>&1; then
  echo "create-attr-test: skipped (no chezmoi)"
  exit 0
fi

pass=0; fail=0
eq() {
  if [ "$2" = "$3" ]; then pass=$((pass+1));
  else fail=$((fail+1)); printf '  ✘ %s\n     want: %s\n     got:  %s\n' "$1" "$3" "$2"; fi
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
CFG="$TMP/config/chezmoi.toml"
mkdir -p "$TMP/config" "$TMP/home"
cat > "$CFG" <<EOF
destDir = "$TMP/home"
[data]
    hostname        = "t"
    gdk_scale       = 1
    wifi_driver     = "none"
    install_cursor  = false
    sudoless_docker = false
    role            = "daily"
    headscale_url   = "https://h.invalid"
    vault_url       = "https://v.invalid"
    vault_email     = "a@b.invalid"
    git_name        = "T"
    git_email       = "a@b.invalid"
    github_user     = "t"
    freellm_url     = "https://l.invalid"
    affine_url      = "https://n.invalid"
    ha_url          = "http://ha.invalid:8123"
    sentry_url      = "https://e.invalid"
EOF

cm() { chezmoi --config "$CFG" --source "$SOURCE_DIR" "$@"; }

APP_OWNED=".claude/settings.json .codex/config.toml .config/Code/User/settings.json .config/mise/config.toml"

# Applying a single target does not create its parent, and a full apply would
# need the vault. The directories are not what is under test.
for t in $APP_OWNED; do mkdir -p "$TMP/home/$(dirname "$t")"; done

echo "seeded on a machine that does not have them"
for t in $APP_OWNED; do
  cm apply --force "$TMP/home/$t" >/dev/null 2>&1
  eq "created $t" "$(test -s "$TMP/home/$t" && echo yes || echo no)" "yes"
done

echo "never overwritten once the app has written them"
# What the apps actually do: add their own keys and keep the rest.
for t in $APP_OWNED; do
  printf '\n# written by the app itself, must survive\n' >> "$TMP/home/$t"
done
for t in $APP_OWNED; do
  cm apply --force "$TMP/home/$t" >/dev/null 2>&1
  eq "kept the app's write to $t" \
     "$(grep -c 'written by the app itself' "$TMP/home/$t" 2>/dev/null)" "1"
done

echo "and they stop showing as dirty"
# The pilot reported all four as MM forever, because apply reverted them and
# the app rewrote them between every run.
OUT="$(cm status 2>/dev/null | awk '{print $2}')"
for t in $APP_OWNED; do
  eq "$t is not reported modified" "$(printf '%s\n' "$OUT" | grep -cx "$t")" "0"
done

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
