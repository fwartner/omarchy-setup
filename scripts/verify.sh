#!/usr/bin/env bash
# Post-bootstrap checks. Exit code = number of failures.
set -uo pipefail
fail=0
ok()   { printf '  \033[32m✔\033[0m %s\n' "$*"; }
bad()  { printf '  \033[31m✘\033[0m %s\n' "$*"; fail=$((fail+1)); }
check(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }
# For checks whose command can fail while printing nothing to stdout. `check`
# alone cannot tell those apart from success: `test -z "$(chezmoi status)"`
# passed on a machine where chezmoi could not even find its source directory.
check_quiet(){
  local out
  if out="$(eval "$2" 2>/dev/null)" && [ -z "$out" ]; then ok "$1"; else bad "$1"; fi
}

# Every chezmoi call needs this. Without it chezmoi looks in its own default
# source directory, which this repo never uses, and errors -- silently, if the
# caller only looks at stdout.
SOURCE_DIR="${SOURCE_DIR:-$HOME/.local/share/omarchy-setup/home}"

echo "System"
check "omarchy CLI present"            "command -v omarchy || test -d /usr/share/omarchy"
check "LUKS root"                      "lsblk -o TYPE | grep -q crypt"
check "Btrfs root"                     "findmnt -no FSTYPE / | grep -q btrfs"
# Not `sudo -n ufw status`: without a cached sudo timestamp that fails, stderr
# is swallowed, and this reports an ACTIVE firewall as absent -- a false alarm
# on a security control, which is the worst direction to be wrong in. The unit
# state answers the same question and needs no privileges.
check "firewall active"                "systemctl is-active ufw || systemctl is-active nftables || systemctl is-active firewalld"

echo "Mesh"
check "tailscaled running"             "systemctl is-active tailscaled"
check "tailscale logged in"            "tailscale status --json | jq -e '.BackendState==\"Running\"'"
# Read URLs from chezmoi data so they match the actual fleet config, not the template example.com.
LLM_URL="$(chezmoi data 2>/dev/null | jq -r '.freellm_url // empty')"
AFFINE_URL="$(chezmoi data 2>/dev/null | jq -r '.affine_url // empty')"
if [ -n "$LLM_URL" ]; then
  check "LLM endpoint reachable"       "curl -fsS --max-time 5 \"$LLM_URL\" -o /dev/null"
else
  bad "freellm_url not set in chezmoi data"
fi
if [ -n "$AFFINE_URL" ]; then
  check "AFFiNE (notes) reachable"     "curl -fsS --max-time 5 \"$AFFINE_URL\" -o /dev/null"
else
  bad "affine_url not set in chezmoi data"
fi
check "Home Assistant reachable"       "curl -fsS --max-time 5 \"$(chezmoi data --source "$SOURCE_DIR" | jq -r .ha_url)\" -o /dev/null"

echo "Secrets & dotfiles"
check "rbw unlocked"                   "rbw unlocked"
check_quiet "chezmoi clean"            "chezmoi status --source \"$SOURCE_DIR\""
check "ssh config rendered"            "test -s ~/.ssh/config"

echo "Toolchain"
for b in git gh podman kubectl helm mise node bun go python php composer code claude codex opencode hermes herdr starship atuin yazi tv jj k9s stern argocd xh nvim wt; do
  check "$b" "command -v $b"
done
check "gh authenticated"               "gh auth status"
check "kubectl cluster reachable"      "kubectl get --raw /version"
check "podman works (rootless)"        "podman info"

echo "Tunnels"
# `tunnel` is a shell function from ~/.bashrc.d, not a binary, so `command -v`
# in this non-interactive shell cannot see it and reported it missing on a
# machine where it works. Ask an interactive shell, which is where it lives.
check "tunnel helper defined"          "test \"\$(bash -ic 'type -t tunnel' 2>/dev/null | tr -d '\r\n')\" = function"
# Burrow is invoked as `npx -y useburrow`, which fetches on demand and keeps no
# config file. The old check looked for ~/.config/burrow/config.toml, which
# nothing in this repo ever creates -- it could only ever fail.
check "npx available for burrow"       "command -v npx"

echo "Sync & backup"
check "syncthing user service"         "systemctl --user is-active syncthing"
check "restic timer"                   "systemctl --user is-enabled restic-backup.timer"

echo
if [ "$fail" -eq 0 ]; then echo "all checks passed"; else echo "$fail check(s) failed"; fi
exit "$fail"
