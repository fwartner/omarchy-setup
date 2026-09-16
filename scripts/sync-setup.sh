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
# = s3:https://nbg1.your-objectstorage.com/<bucket>/laptops, plus the S3 key pair
# in the fields AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY.
if rbw get restic-laptops >/dev/null 2>&1; then
  mkdir -p "$HOME/.config/restic"
  rbw get --field repository restic-laptops > "$HOME/.config/restic/repository"
  rbw get restic-laptops > "$HOME/.config/restic/password"
  # S3 credentials for the restic repo. systemd reads this as an EnvironmentFile,
  # so it is plain KEY=value with no quoting and no export.
  : > "$HOME/.config/restic/env"
  chmod 600 "$HOME/.config/restic/env"
  for k in AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY; do
    v="$(rbw get --field "$k" restic-laptops 2>/dev/null || true)"
    [ -n "$v" ] && printf '%s=%s\n' "$k" "$v" >> "$HOME/.config/restic/env"
  done
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
# S3 credentials; written by sync-setup.sh from the vault item. Optional so the
# unit still starts against a non-S3 repo (rest:, sftp:, local path).
EnvironmentFile=-%h/.config/restic/env
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
  # initialise repo if new (safe to fail if it exists). Runs in a subshell so the
  # S3 credentials never leak into the rest of this script's environment.
  (
    set -a
    # shellcheck disable=SC1091
    . "$HOME/.config/restic/env" 2>/dev/null || true
    set +a
    export RESTIC_PASSWORD_FILE="$HOME/.config/restic/password"
    REPO="$(cat "$HOME/.config/restic/repository")"
    restic -r "$REPO" snapshots >/dev/null 2>&1 || restic -r "$REPO" init || true
  )
  echo "restic timer enabled"
else
  echo "vault item restic-laptops missing; skipping backups"
fi
