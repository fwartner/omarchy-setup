#!/usr/bin/env bash
# Post-bootstrap checks. Exit code = number of failures.
set -uo pipefail
fail=0
ok()   { printf '  \033[32m✔\033[0m %s\n' "$*"; }
bad()  { printf '  \033[31m✘\033[0m %s\n' "$*"; fail=$((fail+1)); }
check(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }

echo "System"
check "omarchy CLI present"            "command -v omarchy || test -d /usr/share/omarchy"
check "LUKS root"                      "lsblk -o TYPE | grep -q crypt"
check "Btrfs root"                     "findmnt -no FSTYPE / | grep -q btrfs"
check "firewall active"                "sudo -n ufw status 2>/dev/null | grep -q active || sudo -n iptables -S 2>/dev/null | grep -q DROP"

echo "Mesh"
check "tailscaled running"             "systemctl is-active tailscaled"
check "tailscale logged in"            "tailscale status --json | jq -e '.BackendState==\"Running\"'"
check "llm.intern reachable"           "curl -fsS --max-time 5 https://llm.intern.pixelandprocess.de -o /dev/null || curl -fsS --max-time 5 http://llm.intern.pixelandprocess.de -o /dev/null"
check "notes.intern reachable"         "curl -fsS --max-time 5 https://notes.intern.pixelandprocess.de -o /dev/null"
check "Home Assistant reachable"       "curl -fsS --max-time 5 http://homeassistant.local:8123 -o /dev/null"

echo "Secrets & dotfiles"
check "rbw unlocked"                   "rbw unlocked"
check "chezmoi clean"                  "test -z \"\$(chezmoi status)\""
check "ssh config rendered"            "test -s ~/.ssh/config"

echo "Toolchain"
for b in git gh podman kubectl helm mise node bun go python php composer code claude codex opencode herdr starship atuin yazi tv jj k9s stern argocd xh nvim wt; do
  check "$b" "command -v $b"
done
check "gh authenticated"               "gh auth status"
check "kubectl cluster reachable"      "kubectl get --raw /version"
check "podman works (rootless)"        "podman info"

echo "Sync & backup"
check "syncthing user service"         "systemctl --user is-active syncthing"
check "restic timer"                   "systemctl --user is-enabled restic-backup.timer"

echo
if [ "$fail" -eq 0 ]; then echo "all checks passed"; else echo "$fail check(s) failed"; fi
exit "$fail"
