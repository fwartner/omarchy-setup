#!/usr/bin/env bash
# Self-check for home/.chezmoi.toml.tmpl: re-running `chezmoi init` on a
# machine that is already configured must not change a single stored answer.
#
#   ./tests/chezmoi-init-test.sh      (skipped when chezmoi is not installed)
#
# This is the bug it exists for. The fleet-wide values were hardcoded in the
# template rather than prompted. bootstrap.sh then started running `chezmoi
# init` unconditionally -- correct in itself, because a machine configured
# before a template change keeps a stale config -- and the regeneration
# replaced a laptop's nine real URLs with the example.com defaults. It lost
# the vault, the mesh and everything rendered from them in one step, and the
# values existed nowhere else: the machine predated this repo's genericization
# for release, so they were only ever in its own ~/.config/chezmoi/chezmoi.toml.
#
# promptStringOnce is what makes re-init safe. A test that only rendered the
# template would not have caught this; it has to init over an existing config.
set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SELF_DIR/../home"

if ! command -v chezmoi >/dev/null 2>&1; then
  echo "chezmoi-init-test: skipped (no chezmoi)"
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
mkdir -p "$TMP/config"

# A machine someone has already answered every question on. Deliberately
# nothing like the template defaults, so a value bleeding through is obvious.
cat > "$CFG" <<'EOF'
[data]
    hostname        = "thinkpad-07"
    gdk_scale       = 2
    wifi_driver     = "broadcom"
    install_cursor  = true
    sudoless_docker = false
    role            = "spare"
    headscale_url   = "https://mesh.real.invalid"
    vault_url       = "https://vault.real.invalid"
    vault_email     = "someone@real.invalid"
    git_name        = "Real Person"
    git_email       = "someone@real.invalid"
    github_user     = "realperson"
    freellm_url     = "https://llm.real.invalid"
    affine_url      = "https://notes.real.invalid"
    ha_url          = "http://ha.real.invalid:8123"
    sentry_url      = "https://errors.real.invalid"
EOF

# </dev/null is the point as much as the assertions: if any value were not a
# promptXOnce, init would stop for an answer here rather than reuse it, and on
# an unattended run that is a machine parked until someone walks past it.
OUT="$(chezmoi --config "$CFG" --source "$SOURCE_DIR" init --source "$SOURCE_DIR" </dev/null 2>&1)"
rc=$?

echo "re-init over a configured machine"
eq "exit 0"                "$rc"                                      "0"
eq "asked nothing"         "$(printf '%s' "$OUT" | grep -ci 'prompt\|\?')" "0"
eq "wrote no example.com"  "$(grep -c 'example\.com' "$CFG")"          "0"

echo "every stored answer survived"
for kv in \
  'hostname:"thinkpad-07"' 'gdk_scale:2' 'wifi_driver:"broadcom"' \
  'install_cursor:true' 'sudoless_docker:false' 'role:"spare"' \
  'headscale_url:"https://mesh.real.invalid"' \
  'vault_url:"https://vault.real.invalid"' \
  'vault_email:"someone@real.invalid"' \
  'git_name:"Real Person"' 'git_email:"someone@real.invalid"' \
  'github_user:"realperson"' \
  'freellm_url:"https://llm.real.invalid"' \
  'affine_url:"https://notes.real.invalid"' \
  'ha_url:"http://ha.real.invalid:8123"' \
  'sentry_url:"https://errors.real.invalid"'; do
  key="${kv%%:*}"; want="${kv#*:}"
  got="$(chezmoi --config "$CFG" --source "$SOURCE_DIR" data 2>/dev/null \
    | jq -r --arg k "$key" '.[$k] | if type=="string" then "\"\(.)\"" else tostring end')"
  eq "$key" "$got" "$want"
done

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
