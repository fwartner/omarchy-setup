# Runbook — one laptop, start to finish

Print this or keep it open on the Mac. Every laptop follows the same list; only §0 and §7 differ per machine.

## 0. Before touching the laptop (Mac)

- [x] Vaultwarden is live at `https://secrets.intern.pixelandprocess.de` and `rbw list` works from the Mac (see `apps/internal/vaultwarden/README.md` in pixelandprocess-gitops).
- [x] All vault items from §Secrets below exist — verified against live infrastructure, not just created: the SSH key round-trips to the key on GitHub, the kubeconfig lists 7 nodes, the AFFiNE token returns its tool list, Home Assistant answers `API running.`, and the restic repo took a real backup and restore.
- [x] Headscale: `headscale users list` shows `florian`. Mint a key with
      `./scripts/mac/new-laptop-key.sh`, which writes it into vault item `headscale-preauth`.
      There is no ACL policy: headscale runs `policy.mode: database` with no rows, which means
      allow-all inside the tailnet. `tag:laptop` is forced server-side from the pre-auth key and
      needs no `tagOwners` entry, so the tag is a label, not an access boundary. Writing a first
      policy would flip the whole tailnet to deny-by-default — a separate, deliberate change.
- [x] Repo pushed: `github.com/fwartner/omarchy-setup` (private). The raw URL needs a token — it 404s without one — so the bootstrap command in §3 passes `Authorization: Bearer`.
- [ ] USB stick with the current Omarchy ISO (ISO downloaded and SHA256-verified; **writing the stick is still manual**). `./scripts/mac/latest-iso.sh --download` reads
      the version, URL and SHA256 out of the release notes, fetches into `~/Downloads` and
      verifies; it exits non-zero on a mismatch and skips the download if the file is already
      correct. No version is pinned anywhere in this repo — Omarchy ships roughly weekly.
- [ ] Inventory row filled in `docs/INVENTORY.md` (hostname, DPI scale, Wi-Fi chipset).
- [ ] A USB-Ethernet adapter or phone tethering nearby in case Wi-Fi needs DKMS.

## 1. BIOS (2 min)

- [ ] Secure Boot: off. TPM can stay, but off if the installer complains.
- [ ] SATA/NVMe mode: AHCI (**Latitude 7310 defaults to RAID/RST — change it or no disk is found**).
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

1. chezmoi questions: hostname, display scale (1 for 1080p/768p, 2 for HiDPI), Wi-Fi quirk (`none`/`broadcom`), Cursor yes/no, legacy docker-group prompt (answer no; podman is rootless), role.
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

- [ ] Reboot (Hyprland overrides, hostname).
- [ ] `~/.local/share/omarchy-setup/scripts/verify.sh` → all green. Typical first-run reds: kubectl (kubeconfig item missing). Home Assistant is reached at `http://homeassistant.ts.pixelandprocess.de:8123` — the MagicDNS name, because mDNS does not cross the mesh.
- [ ] Open VS Code from the Omarchy menu, theme matches Omarchy, Claude Code extension logged in.
- [ ] `herdr` starts, sidebar shows a `claude` pane state; `wt test-task` in any repo creates a worktree and opens Claude in it (then `wt rm test-task`).
- [ ] `atuin search`, `y` (yazi), `tv`, `gh dash`, `k9s` (read-only) all open.
- [ ] `proj` opens the fuzzy switcher; `clone fwartner/<repo>` works.
- [ ] `kubectl get nodes` returns the cluster, and `kubectl auth can-i '*' '*' -A` → `yes` (the fleet holds cluster-admin).
- [ ] Obsidian opens `~/Projects/claude-obsidian` and shows the `hermes/` folder synced from the Mac.
- [ ] `systemctl --user list-timers` shows `restic-backup.timer`. Run once by hand: `systemctl --user start restic-backup.service`, then `restic snapshots`.

## 6. Hardware pass (10 min, once per model)

- [ ] `sudo fwupdmgr refresh && sudo fwupdmgr get-updates` → apply BIOS/firmware updates, reboot.
- [ ] Touchpad gestures, brightness keys, volume keys, lid close → suspend, resume from suspend, webcam, audio.
- [ ] If something is off: `Update > Hardware` in the Omarchy menu restarts the subsystem; `omarchy debug` for logs. Fallback kernel: pick stock `linux` in the boot menu if `linux-omarchy` misbehaves, then file it in INVENTORY.md.
- [ ] Battery: `Setup > Power` profile balanced; check `powerprofilesctl`.
- [ ] Panel: if everything is huge or tiny, change `gdk_scale` in `~/.config/chezmoi/chezmoi.toml` and `chezmoi apply`, then `hyprctl reload`.

## 7. Per-model notes

See `docs/INVENTORY.md` — Latitude 7310 (daily) and V130-15IGM (spare) each have a section with BIOS keys, Wi-Fi variants, RAM upgrade and known quirks. Any 1366×768 panel: `gdk_scale = 1`, VS Code `window.zoomLevel = -1`.

## 8. Maintenance (recurring)

Monthly

- [ ] `omarchy update` (takes a Btrfs snapshot first). The post-update hook re-applies chezmoi.
- [ ] `chezmoi update` if the repo changed elsewhere; `mise upgrade`.
- [ ] `verify.sh` still green.

Quarterly

- [ ] Rotate `github-token-laptops`, Headscale pre-auth keys (they expire anyway), Home Assistant and AFFiNE tokens → update vault items → `chezmoi apply` + `agents-setup.sh` on each laptop.
      `github-token-laptops` currently holds a **classic** PAT whose scopes include `admin:org`, `admin:enterprise` and `delete_repo`, and classic PATs inherit org access, so it reaches Pixel-Process-UG repos too. Replacing it with a fine-grained token (owner `fwartner`, Contents RW / Workflows RW / Metadata R / Pull requests RW) is the single biggest reduction in blast radius for a lost laptop. Until then, revoking it is step one of the lost-laptop drill below.
- [ ] `restic check` and a test restore of one file.
- [ ] Prune Headscale nodes that no longer exist.

## Secrets — Vaultwarden items the bootstrap expects

| Item name | Type | Where the value goes | Fields |
|---|---|---|---|
| `headscale-preauth` | Login | scripts/headscale-join.sh (manual paste) | password = key |
| `ssh-laptops` | Secure note | ~/.ssh/id_ed25519_laptops(.pub) | notes = private key, custom field `public_key` |
| `github-token-laptops` | Login | gh auth | password = fine-grained PAT (repo, read:org, workflow) |
| `affine-mcp` | Login | Claude MCP | password = `aff_mcp_v1.` token, custom field `url` = `https://notes.intern.pixelandprocess.de/api/workspaces/<workspace-id>/mcp` |
| `homeassistant-mcp` | Login | Claude MCP | password = long-lived token, custom field `url` = `http://<ha-tailscale-name>:8123` |
| `kubeconfig-shared` | Secure note | ~/.kube/config | notes = kubeconfig YAML, context `pp-shared-admin` (ServiceAccount `laptops`, **cluster-admin**) |
| `restic-laptops` | Login | restic timer | password = repo password, custom fields `repository`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` |
| `hetzner-api` | Login | nothing — Mac convenience only | password = Hetzner Cloud API token (read/write) |
| `hcloud-readonly` | Login | `hcloud`, read-only infra queries | password = Hetzner Cloud API token, **Read** permission. Console only — the Cloud API has no token endpoint (`/v1/tokens` 404s) |
| `sentry-token` | Login | `sentry-cli` | password = GlitchTip auth token. `SENTRY_URL` is exported by `10-env.sh`; without it sentry-cli talks to sentry.io |

Generate the fleet SSH key once on the Mac: `ssh-keygen -t ed25519 -C laptops -f ~/Desktop/id_ed25519_laptops`, paste into the vault item, add the `.pub` to GitHub and to the Serverschrank's `authorized_keys`, then delete the local copies.

`sentry-token` and `hcloud-readonly` ship empty. Every script that reads a vault item guards on it, so an empty value means the feature is skipped rather than half-configured — fill them with `rbw edit <item>` whenever you get to it.

`hetzner-api` is the odd one out: no bootstrap step and no script reads it, and it is not
needed on a laptop at all. It is full read/write on `api.hetzner.cloud` — servers, volumes,
networks, firewalls, load balancers, including deletion — so any laptop with `rbw` unlocked
can destroy the cluster with it. It does **not** cover Object Storage (`/v1/object_storage`
and `/v1/storage_boxes` both 404); buckets and S3 credentials live in the console and the
S3 API. If the fleet ever grows past machines you personally carry, this item and
`github-token-laptops` are the two to move into a vault account the laptops do not log into.

Create the AFFiNE credential **inside the self-hosted instance** (`https://notes.intern.pixelandprocess.de` → Settings → Integrations → MCP Server), not through the button on affine.pro, which sends you to AFFiNE Cloud. A cloud-issued token fails against the self-hosted endpoint with a 401 that is byte-identical to the one you get for sending no credential at all, so there is nothing in the error to tell you which mistake you made. Transport is streamable HTTP; the endpoint is stateless and returns no `mcp-session-id`.

`rbw` reads items but cannot create them or set custom fields. Creating and updating these items is done on the Mac with the official Bitwarden CLI (`brew install bitwarden-cli`, `bw config server https://secrets.intern.pixelandprocess.de`). The laptops only ever read, so they only need `rbw`.

## Known issue — Hetzner Object Storage, nbg1 ceph5

As of 2026-09-16 a share of S3 requests to `nbg1.your-objectstorage.com` fail with
`403 AccessDenied`, and every failure observed came back from the backend
`nbg1-prod1-ceph5`. Identical back-to-back requests alternate 200 and 403 at roughly
15-20% failure. The cluster's older `cnpg-backup-s3` credential does not show it, so it
looks like a per-credential replication gap on that one node rather than a permission
problem.

What this means in practice:

- `restic init`, `backup`, `restore` and `forget` may fail on one run and succeed on the
  next. Retrying is the correct response; restic treats 403 as fatal and will not retry
  it itself.
- **`restic check` can report `The repository index is damaged and must be repaired`
  on a perfectly healthy repository.** This was observed and then contradicted by two
  consecutive clean `check` runs on the same repo. Do not run `restic repair index`
  on the strength of a single failed check — run `check` again first.
- Regenerating the S3 credential does not fix it and makes things worse short-term: a
  brand-new key returns `InvalidAccessKeyId` on 100% of requests until it propagates.

The distinguishing error codes are worth knowing: `InvalidAccessKeyId` means the key does
not exist on the backend that served the request; `AccessDenied` means it exists but that
backend will not authorise it. Neither indicates a wrong secret.

If nightly backups show intermittent failures, this is why. Open a ticket with Hetzner
referencing the `HostId` from the error body rather than rotating credentials.

## Rollback

- Omarchy update broke something: reboot, choose the previous Btrfs snapshot in the boot menu.
- Dotfiles broke something: `chezmoi apply --dry-run --verbose` shows the diff; `omarchy reinstall configs` restores Omarchy defaults, then fix the repo and `chezmoi apply`.
- Laptop lost: this is now a **cluster-admin credential loss**, so it comes first. Delete the token Secret and let it reissue, which invalidates every distributed kubeconfig at once:
  `kubectl -n kube-system delete secret laptops-token` then re-run `scripts/mac/` kubeconfig generation and update `kubeconfig-shared`.
  Then revoke `github-token-laptops` (an org-wide classic PAT), `headscale nodes delete`, rotate `ssh-laptops`, revoke the HA/AFFiNE tokens, and rotate the Hetzner S3 key pair in `restic-laptops`. `restic snapshots --host <hostname>` still has the data. LUKS protects the disk itself.
