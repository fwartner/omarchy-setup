#!/usr/bin/env bash
# Syncthing (Obsidian vault + ~/Sync) and restic backups on a systemd user timer.
set -euo pipefail

sudo omarchy-pkg-add syncthing restic

# --- Syncthing as user service ---------------------------------------------
systemctl --user enable --now syncthing.service
mkdir -p "$HOME/Projects/claude-obsidian" "$HOME/Sync"
sleep 3
DEV_ID="$(syncthing --device-id 2>/dev/null || true)"
echo "Syncthing device ID: ${DEV_ID:-unknown} — add it on the hub (Serverschrank/Mac mini) and share:"
echo "  claude-obsidian  -> ~/Projects/claude-obsidian"
echo "  sync             -> ~/Sync"

# --- restic ------------------------------------------------------------------
# Vault item "restic-laptops": password = repo password, field "repository"
# = e.g. s3:https://s3.example.de/backups/laptops or rest:https://restic.intern.pixelandprocess.de/
if rbw get restic-laptops >/dev/null 2>&1; then
  mkdir -p "$HOME/.config/restic"
  rbw get --field repository restic-laptops > "$HOME/.config/restic/repository"
  rbw get restic-laptops > "$HOME/.config/restic/password"
  chmod 600 "$HOME/.config/restic/"*
  cat > "$HOME/.config/restic/excludes" <<'EOF'
**/node_modules
**/vendor
**/.cache
**/target
**/.venv
**/dist
~/.local/share/Trash
~/Downloads
~/.cache
EOF
  mkdir -p "$HOME/.config/systemd/user"
  cat > "$HOME/.config/systemd/user/restic-backup.service" <<'EOF'
[Unit]
Description=restic backup of home
After=network-online.target

[Service]
Type=oneshot
Environment=RESTIC_PASSWORD_FILE=%h/.config/restic/password
ExecStart=/bin/bash -c 'restic -r "$(cat %h/.config/restic/repository)" backup %h/Projects %h/.config %h/Sync %h/Documents --exclude-file=%h/.config/restic/excludes --tag laptop --host %H'
ExecStartPost=/bin/bash -c 'restic -r "$(cat %h/.config/restic/repository)" forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune --host %H'
EOF
  cat > "$HOME/.config/systemd/user/restic-backup.timer" <<'EOF'
[Unit]
Description=nightly restic backup

[Timer]
OnCalendar=daily
RandomizedDelaySec=1h
Persistent=true

[Install]
WantedBy=timers.target
EOF
  systemctl --user daemon-reload
  systemctl --user enable --now restic-backup.timer
  # initialise repo if new (safe to fail if it exists)
  RESTIC_PASSWORD_FILE="$HOME/.config/restic/password" restic -r "$(cat "$HOME/.config/restic/repository")" snapshots >/dev/null 2>&1 \
    || RESTIC_PASSWORD_FILE="$HOME/.config/restic/password" restic -r "$(cat "$HOME/.config/restic/repository")" init || true
  echo "restic timer enabled"
else
  echo "vault item restic-laptops missing; skipping backups"
fi
