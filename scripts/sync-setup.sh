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
# A backup can legitimately run for hours; without this systemd would kill it
# at DefaultTimeoutStartSec.
TimeoutStartSec=0
# Hetzner's nbg1 object storage intermittently answers 403 AccessDenied from one
# backend (see docs/RUNBOOK.md). restic treats 403 as fatal and does not retry it
# itself, so a single bad request would fail the whole night. Retry the run.
# No $VARIABLES in these lines: systemd expands $foo before bash ever sees it.
ExecStart=/bin/bash -c 'for attempt in 1 2 3 4 5; do restic -r "$(cat %h/.config/restic/repository)" backup %h/Projects %h/.config %h/Sync %h/Documents --exclude-file=%h/.config/restic/excludes --tag laptop --host %H && exit 0; echo "restic backup failed; retrying in 120s"; sleep 120; done; echo "restic backup failed 5 times, giving up"; exit 1'
ExecStartPost=/bin/bash -c 'for attempt in 1 2 3; do restic -r "$(cat %h/.config/restic/repository)" forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune --host %H && exit 0; sleep 120; done; exit 1'
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
    # Same 403 flakiness as the timer unit: retry rather than give up on one.
    for _ in 1 2 3 4 5; do
      restic -r "$REPO" snapshots >/dev/null 2>&1 && break
      restic -r "$REPO" init >/dev/null 2>&1 && break
      sleep 5
    done
  )
  echo "restic timer enabled"
else
  echo "vault item restic-laptops missing; skipping backups"
fi
