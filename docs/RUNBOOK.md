# Runbook — one laptop, start to finish

Print this or keep it open on the Mac. Every laptop follows the same list; only §0 and §7 differ per machine.

## 0. Before touching the laptop (Mac)

- [ ] Vaultwarden is live at `https://secrets.intern.pixelandprocess.de` and `rbw list` works from the Mac (see `apps/internal/vaultwarden/README.md` in pixelandprocess-gitops).
- [ ] All vault items from §Secrets below exist.
- [ ] Headscale: `headscale users list` shows `florian`; ACL has `tag:laptop`; create a key:
      `headscale preauthkeys create --user florian --reusable --expiration 24h --tags tag:laptop`
      → paste it into vault item `headscale-preauth` (or keep it on the clipboard).
- [ ] Repo pushed: `github.com/fwartner/omarchy-setup` (private). `bootstrap.sh` raw URL works.
- [ ] USB stick with `omarchy-4.0.4.iso` (verify SHA256 from the release page).
- [ ] Inventory row filled in `docs/INVENTORY.md` (hostname, DPI scale, Wi-Fi chipset).
- [ ] A USB-Ethernet adapter or phone tethering nearby in case Wi-Fi needs DKMS.

## 1. BIOS (2 min)

- [ ] Secure Boot: off. TPM can stay, but off if the installer complains.
- [ ] SATA/NVMe mode: AHCI (not RAID/RST on Dells).
- [ ] Virtualization (VT-x/AMD-V): on.
- [ ] Boot order: USB first, or use the one-time boot menu (F12 Dell / F12 Lenovo).
- [ ] Optional: update BIOS from the vendor site before install (or via `fwupdmgr` later).

## 2. Install Omarchy (5–10 min)

- [ ] Boot from USB. Keyboard: `de`.
- [ ] Username `florian`, strong password (this becomes the LUKS passphrase too).
- [ ] Hostname: from inventory.
- [ ] Full-disk install, encryption **on** (default). Confirm the disk wipe.
- [ ] Reboot, remove USB, enter LUKS passphrase on the built-in keyboard.
- [ ] First-boot screen: default agent → **Claude Code**.
- [ ] Connect Wi-Fi (`Super + Ctrl + W` / bar panel). If no Wi-Fi: plug in Ethernet, continue — the bootstrap handles Broadcom DKMS.

## 3. Bootstrap (15–30 min, mostly unattended)

Open a terminal (`Super + Return`):

```bash
curl -fsSL https://raw.githubusercontent.com/fwartner/omarchy-setup/main/bootstrap.sh | bash
```

You will be asked, in this order:

1. chezmoi questions: hostname, display scale (1 for 1080p/768p, 2 for HiDPI), Wi-Fi quirk (`none`/`broadcom`), Cursor yes/no, sudoless docker yes/no, role.
2. Headscale pre-auth key (paste; leave empty for browser login).
3. Vaultwarden master password (rbw login + unlock; 2FA code if enabled).
4. sudo password once at the start.

- [ ] Script ends with the "Bootstrap finished" banner.
- [ ] `tailscale status` shows this laptop plus the rest of the mesh.

## 4. Manual logins (5 min)

- [ ] `claude` → follow the OAuth link with your Claude subscription. `/mcp` shows affine, home-assistant, context7 connected.
- [ ] `codex login` → OpenAI account.
- [ ] `gh auth status` → already logged in via vault token; if not, `gh auth login`.
- [ ] Syncthing: open `http://localhost:8384`, copy the device ID (also printed by bootstrap). On the hub (Serverschrank / Mac mini): add device, share folders `claude-obsidian` and `sync`. Accept on the laptop.

## 5. Reboot and verify (5 min)

- [ ] Reboot (Hyprland overrides, docker group, hostname).
- [ ] `~/.local/share/omarchy-setup/scripts/verify.sh` → all green. Typical first-run reds: Home Assistant (mDNS `homeassistant.local` doesn't resolve over the mesh — use its Tailscale name in `ha_url` instead), kubectl (kubeconfig item missing).
- [ ] Open VS Code (`Super + E`), theme matches Omarchy, Claude Code extension logged in.
- [ ] `proj` opens the fuzzy switcher; `clone fwartner/<repo>` works.
- [ ] `kubectl get nodes` returns the cluster.
- [ ] Obsidian opens `~/Projects/claude-obsidian` and shows the `hermes/` folder synced from the Mac.
- [ ] `systemctl --user list-timers` shows `restic-backup.timer`. Run once by hand: `systemctl --user start restic-backup.service`, then `restic snapshots`.

## 6. Hardware pass (10 min, once per model)

- [ ] `sudo fwupdmgr refresh && sudo fwupdmgr get-updates` → apply BIOS/firmware updates, reboot.
- [ ] Touchpad gestures, brightness keys, volume keys, lid close → suspend, resume from suspend, webcam, audio.
- [ ] If something is off: `Update > Hardware` in the Omarchy menu restarts the subsystem; `omarchy debug` for logs. Fallback kernel: pick stock `linux` in the boot menu if `linux-omarchy` misbehaves, then file it in INVENTORY.md.
- [ ] Battery: `Setup > Power` profile balanced; check `powerprofilesctl`.
- [ ] Panel: if everything is huge or tiny, change `gdk_scale` in `~/.config/chezmoi/chezmoi.toml` and `chezmoi apply`, then `hyprctl reload`.

## 7. Per-model notes

Keep these in `INVENTORY.md`; the runbook stays generic. Known classes:

- Dell Latitude/XPS with Intel Wi-Fi: nothing special.
- Dell with Broadcom BCM43xx: `wifi_driver = broadcom`; expect a DKMS build on every kernel update (post-update hook handles it).
- Lenovo ThinkPad: enable "Thunderbolt BIOS Assist" off, "Linux" as OS in BIOS if offered; TrackPoint works out of the box.
- Any 1366×768 panel: `gdk_scale = 1`, VS Code `window.zoomLevel = -1`.

## 8. Maintenance (recurring)

Monthly

- [ ] `omarchy update` (takes a Btrfs snapshot first). The post-update hook re-applies chezmoi.
- [ ] `chezmoi update` if the repo changed elsewhere; `mise upgrade`.
- [ ] `verify.sh` still green.

Quarterly

- [ ] Rotate `github-token-laptops`, Headscale pre-auth keys (they expire anyway), Home Assistant and AFFiNE tokens → update vault items → `chezmoi apply` + `agents-setup.sh` on each laptop.
- [ ] `restic check` and a test restore of one file.
- [ ] Prune Headscale nodes that no longer exist.

## Secrets — Vaultwarden items the bootstrap expects

| Item name | Type | Where the value goes | Fields |
|---|---|---|---|
| `headscale-preauth` | Login | scripts/headscale-join.sh (manual paste) | password = key |
| `ssh-laptops` | Secure note | ~/.ssh/id_ed25519_laptops(.pub) | notes = private key, custom field `public_key` |
| `github-token-laptops` | Login | gh auth | password = fine-grained PAT (repo, read:org, workflow) |
| `affine-mcp` | Login | Claude MCP | password = token, custom field `url` = MCP endpoint |
| `homeassistant-mcp` | Login | Claude MCP | password = long-lived token, custom field `url` = `http://<ha-tailscale-name>:8123` |
| `kubeconfig-shared` | Secure note | ~/.kube/config | notes = kubeconfig YAML (a read-mostly service-account context, not cluster-admin) |
| `restic-laptops` | Login | restic timer | password = repo password, custom field `repository` |

Generate the fleet SSH key once on the Mac: `ssh-keygen -t ed25519 -C laptops -f ~/Desktop/id_ed25519_laptops`, paste into the vault item, add the `.pub` to GitHub and to the Serverschrank's `authorized_keys`, then delete the local copies.

## Rollback

- Omarchy update broke something: reboot, choose the previous Btrfs snapshot in the boot menu.
- Dotfiles broke something: `chezmoi apply --dry-run --verbose` shows the diff; `omarchy reinstall configs` restores Omarchy defaults, then fix the repo and `chezmoi apply`.
- Laptop lost: `headscale nodes delete`, rotate `github-token-laptops` and `ssh-laptops`, revoke the HA/AFFiNE tokens, `restic snapshots --host <hostname>` still has the data. LUKS protects the disk itself.
