# Omarchy Fleet — Master Plan

Personal workstation fleet on Omarchy Linux, separate from the Pixel & Process Mac, wired into the existing infrastructure (Headscale mesh, `*.intern.pixelandprocess.de` services, Vaultwarden, the shared Kubernetes cluster) and built for agentic coding.

Status: 2026-09-16 · Omarchy 4.0.4 (Quickshell shell, Lua Hyprland config, `linux-omarchy` kernel) · target: older Dell + Lenovo notebooks, all interchangeable.

---

## 1. Goals and non-goals

Goals

- Every laptop is a full, identical workstation. Pick any one up, log in, and Claude Code / Codex / VS Code / kubectl / gh work the same way.
- One command turns a fresh Omarchy install into that workstation (`bootstrap.sh`), idempotent, re-runnable after `omarchy update`.
- Nothing secret lives in git. All tokens, keys and kubeconfigs come from Vaultwarden at bootstrap or at runtime.
- The laptops are first-class citizens on the Headscale mesh: `llm.intern`, `notes.intern`, Home Assistant and the Serverschrank are reachable from anywhere; SSH between laptops works over Tailscale SSH.
- Config, notes and code sync through your own infrastructure (git + Obsidian vault + Syncthing), never through a laptop's local disk being "the" copy.

Non-goals

- The laptops do not become nodes of the shared Kubernetes cluster. They are clients only (kubectl/helm). Laptops close lids, lose Wi-Fi and get reinstalled; a control plane should never care about them.
- Hermes stays out of scope for the laptops (it lands on the Mac mini). The laptops only get the Hermes CLI/Telegram-side tooling if you want to poke at it.
- No Pixel & Process work on these machines. The Mac keeps Forge/Herd, Lexware, client data. The split is on purpose: fewer secrets on machines that travel.

## 2. Target architecture

```
                 Internet
                    │
     ┌──────────────┴───────────────┐
     │  Headscale (existing)        │  coordination only
     └──────────────┬───────────────┘
                    │ WireGuard mesh (tailscale client everywhere)
   ┌────────────────┼──────────────────────────────┐
   │                │                              │
 Laptop A        Laptop B  …  Laptop N        Serverschrank / Home
 (omarchy)       (omarchy)    (omarchy)        - Home Assistant
   │                │                          - Syncthing hub (new or existing box)
   │  identical     │                          - Obsidian vault git remote
   │  bootstrap     │
   └────────┬───────┘
            │ HTTPS over mesh
   ┌────────┴──────────────────────────────┐
   │ intern.pixelandprocess.de             │
   │  llm.intern  (FreeLLM gateway)        │
   │  notes.intern (AFFiNE + MCP)          │
   │  secrets.intern (Vaultwarden, new, on the cluster) ← secrets │
   │  headscale                            │
   └────────┬──────────────────────────────┘
            │ kubectl / helm (client only, kubeconfig from Vaultwarden)
   ┌────────┴──────────────────────────────┐
   │ Shared K8s cluster (cloud)            │
   │ pixelandprocess-gitops                │
   └───────────────────────────────────────┘
```

Layers, bottom to top:

| Layer | Choice | Why |
|---|---|---|
| OS | Omarchy 4.x, stable channel, LUKS on | Opinionated, updates via `omarchy update` with Btrfs snapshot + rollback. Stable channel because you want to work, not test. |
| Hardware quirks | `linux-omarchy` kernel (default since 4.0.4), `fwupd` via Update > Firmware, `broadcom-wl-dkms` only where needed | 4.0.4 explicitly targets old-laptop issues (touchpad, resume, audio). Dell/Lenovo BIOS updates come via LVFS. |
| Mesh | Tailscale client → your Headscale (`Install > Service > Tailscale`, then `tailscale up --login-server …`) | Omarchy ships a Tailscale bar panel and Taildrop; it works unchanged against Headscale. Tailscale SSH replaces per-laptop SSH key juggling. |
| Secrets | Vaultwarden via `rbw` (Rust Bitwarden CLI) + chezmoi's `rbw` template functions | `rbw` keeps an unlocked agent so templates can pull secrets without pasting; chezmoi renders `~/.ssh/config`, `~/.kube/config`, `~/.config/gh/hosts.yml` etc. from vault items. |
| Dotfiles | chezmoi, repo `omarchy-setup`, source dir `home/` | Templates + per-machine data (`.chezmoi.toml.tmpl`) give "interchangeable but not identical" (hostname, DPI scale, Wi-Fi driver). |
| Packages | `packages/pacman.txt` + `packages/aur.txt`, installed with `omarchy-pkg-add` / `yay` | Declarative enough; Omarchy blocks raw `pacman -Syu`, so updates stay `omarchy update`. |
| Dev runtimes | `mise` (Omarchy's own mechanism: `omarchy install dev-env <lang>`) | Node/Bun/Go/Python/PHP via mise, same versions on every laptop from `~/.config/mise/config.toml`. |
| Editors | VS Code (Install > Editor), Cursor optional, Neovim stays as default `$EDITOR` for terminal work | VS Code settings + extension list come from the repo; Omarchy theme-matches VS Code and Cursor. |
| Agents | Claude Code, Codex CLI, `gh`; MCP servers for AFFiNE, Home Assistant, Context7 | Same setup as on the Mac. Omarchy's default coding-agent picker points to Claude Code. |
| Containers | Docker (rootful; opt into `Setup > Security > Sudoless Docker` only on machines you trust) | Local dev DBs via Install > Development > Docker DB. |
| Sync | Syncthing for `~/Projects/claude-obsidian` (Obsidian vault) and `~/Sync`; git for everything else | Vault also has a git remote as backup; Syncthing gives instant multi-laptop sync without a cloud. |
| Backups | restic → your own S3-compatible store (or restic-rest on the Serverschrank), nightly systemd timer, `~/Projects` + `~/.config` excluded caches | Laptops are disposable only if backups are boring. |

## 3. Decisions with reasoning

**All laptops identical, no "server laptop".** You chose interchangeable workstations. That means no service is pinned to a laptop. Anything that must run 24/7 (Syncthing hub, restic REST server, git remote) belongs in the Serverschrank or on the Mac mini, not on a notebook.

**Clients only for the shared cluster.** The cluster serves Pixel & Process production and personal stuff alike. A notebook joining as a worker mixes a non-deterministic, roaming device into a control plane you also bill clients from. If you ever want home compute, add a k3s on a Serverschrank box, not on a laptop.

**Headscale, not Tailscale SaaS.** It already runs. Omarchy's Tailscale integration is only the client + bar panel; the login server is a flag. Use pre-auth keys per laptop (tagged `tag:laptop`) so bootstrap can join non-interactively, and enable Tailscale SSH (`--ssh`) so laptops reach each other and the Serverschrank without distributing SSH keys.

**Vaultwarden + rbw instead of Bitwarden's official `bw` CLI.** `bw` needs a session token in an env var and is slow (Node). `rbw` has an agent, is packaged in Arch `extra`, works with Vaultwarden, and chezmoi has native `rbw`/`rbwFields` template functions. The one price: rbw must be unlocked before `chezmoi apply` (bootstrap handles this).

**chezmoi over bare-git or Ansible.** You have machines that differ in DPI, Wi-Fi chipset and hostname but should otherwise match. chezmoi templates cover that in a single repo without an inventory file, and `chezmoi update` re-applies after Omarchy updates. Ansible would be the answer if you had ten machines or servers in the mix; you don't.

**Omarchy stable channel, never `pacman -Syu`.** Omarchy takes a Btrfs snapshot before updates and blocks direct pacman upgrades. Keep that. Custom packages go through `omarchy-pkg-add` (pacman) and `yay -S` (AUR) so they get updated by `omarchy update` too.

**Don't fight Omarchy's config ownership.** `/usr/share/omarchy` is pacman-owned and overwritten. Everything you own lives under `~/.config` and is loaded by `~/.config/hypr/hyprland.lua` as overrides. chezmoi manages exactly those files and nothing below `/usr`. A `post-update` hook re-runs `chezmoi apply` so an Omarchy config migration never leaves you with defaults.

**VS Code as main editor, Neovim as `$EDITOR`.** Install via Omarchy's menu so theme sync works; settings and extension list come from chezmoi. Cursor is in the same menu if you want it on some machines (`.chezmoi.toml.tmpl` has a flag).

**Encryption on, with a caveat.** Omarchy defaults to LUKS. Keep it on laptops. Note the LUKS passphrase must be typed on a wired/internal keyboard, and "install for another owner" mode is irrelevant here.

## 4. Phases

### Phase 0 — Inventory and prep (½ day, on the Mac)

- **Deploy Vaultwarden to the shared cluster first** (`infra/vaultwarden/`, hostname `secrets.intern.pixelandprocess.de` — rename if you prefer another). Nothing else in the bootstrap works without it. Create your account, disable signups, test with `rbw` from the Mac, put the SQLite data dir into the cluster's PVC backup.
- Inventory each laptop: model, CPU, RAM, disk, Wi-Fi chipset (`lspci`/`lsusb` from any live USB), panel resolution. Record in `docs/INVENTORY.md`.
- BIOS: update via vendor tool or LVFS later; disable Secure Boot; set SATA/NVMe to AHCI; enable virtualization.
- Headscale: create a user `florian`, an ACL tag `tag:laptop`, and one reusable pre-auth key per laptop (short expiry). Store keys in Vaultwarden.
- Vaultwarden: create the items listed in `docs/RUNBOOK.md` §Secrets (SSH key, gh token, Anthropic/OpenAI API keys if used outside subscriptions, kubeconfig, restic repo + password, Syncthing device IDs).
- Push this repo to `github.com/fwartner/omarchy-setup` (private).
- Download `omarchy-4.0.4.iso`, verify SHA256, write one USB stick.

### Phase 1 — Pilot laptop (1 evening)

- Install Omarchy (full disk, LUKS, keyboard `de`, user `florian`, hostname per inventory).
- First boot: pick Claude Code as default agent, reboot into the desktop.
- `curl -fsSL https://raw.githubusercontent.com/fwartner/omarchy-setup/main/bootstrap.sh | bash` — this installs chezmoi + rbw, unlocks the vault, joins Headscale, installs packages, applies dotfiles, installs editors and dev envs.
- Run `scripts/verify.sh`, fix what fails, commit fixes. Expect two or three iterations on the pilot; that is what the pilot is for.

### Phase 2 — Fleet rollout (1 evening per laptop, mostly waiting)

- Same USB, same bootstrap. Only variables: hostname, DPI scale, Wi-Fi driver flag, whether to install Cursor.
- After each: `verify.sh` green, Syncthing shows all peers, `tailscale status` lists the fleet, `kubectl get nodes` works.

### Phase 3 — Agentic workflow (ongoing)

- Claude Code: `~/.claude/settings.json` from chezmoi (permissions, hooks, MCP servers for AFFiNE + Home Assistant + Context7). Login is per machine (subscription OAuth), that is the one manual step.
- Codex CLI: same, `~/.codex/config.toml`.
- Shared project conventions: `~/Projects/<org>/<repo>`, `gh repo clone` wrappers, a `proj` fzf switcher in `~/.bashrc.d/`.
- Obsidian vault synced (Syncthing) so Claude Code on any laptop reads the same `hermes/` memory the Mac writes.

### Phase 4 — Hardening and hygiene

- restic timer running and tested restore on one laptop.
- `omarchy update` monthly, then `chezmoi update`; the `post-update` hook already reapplies dotfiles.
- Quarterly: rotate Headscale pre-auth keys, gh token, check `fwupdmgr get-updates`.

## 5. Per-machine variables (chezmoi data)

| Variable | Example | Used for |
|---|---|---|
| `hostname` | `dell-7490` | Headscale node name, prompt |
| `gdk_scale` | `1` or `2` | `~/.config/hypr/monitors.lua` (older 1080p panels want 1) |
| `wifi_driver` | `""`, `broadcom` | installs `broadcom-wl-dkms` |
| `install_cursor` | `true/false` | Install > Editor Cursor |
| `sudoless_docker` | `false` | opt-in per machine |
| `role` | `daily`, `spare` | spare machines skip Syncthing folders that are large |

All are asked once by `.chezmoi.toml.tmpl` on first `chezmoi init` and stored in `~/.config/chezmoi/chezmoi.toml`.

## 6. Risks and mitigations

- Old Wi-Fi chipsets (Broadcom on some Dells): Arch dropped the prebuilt module; Omarchy 4.0.3 moved to DKMS. DKMS rebuilds on every kernel update — keep a USB Ethernet adapter in the drawer for the first boot.
- Custom `linux-omarchy` kernel: good for old hardware, but if a laptop misbehaves, the bootloader still offers the stock `linux` entry and Btrfs snapshots.
- Vault availability: Vaultwarden does not exist yet; it goes onto the shared cluster as step one (`infra/vaultwarden/`). Bootstrap joins Headscale first (pre-auth key is the only pasted secret) and only then talks to `secrets.intern`, so the vault can stay mesh-only.
- Claude/Codex subscription logins are device-bound OAuth; they cannot come from the vault. Plan one interactive login per laptop per tool.
- HiDPI assumption: Omarchy defaults to 2x scaling. On 1366×768 / 1080p 13–14" panels set `gdk_scale = 1` or everything is enormous.
- `omarchy reinstall` overwrites user config — never run it; use `omarchy reinstall configs` then `chezmoi apply`.

## 7. What is deliberately not automated

- LUKS passphrase and user creation (installer).
- First-boot agent choice (installer).
- Claude Code / Codex OAuth logins.
- Syncthing device introduction on the hub side (one click in the hub UI per laptop).
- BIOS settings.

Everything else is `bootstrap.sh`.

## 8. Repo layout

```
omarchy-setup/
├── bootstrap.sh                 one-shot: fresh Omarchy → workstation
├── infra/vaultwarden/           kustomize manifests for the cluster (Phase 0)
├── docs/
│   ├── MASTER-PLAN.md           this file
│   ├── RUNBOOK.md               per-laptop checklist + secrets list
│   └── INVENTORY.md             fill in per machine
├── packages/
│   ├── pacman.txt               Arch/Omarchy repo packages
│   └── aur.txt                  AUR packages (yay)
├── scripts/
│   ├── headscale-join.sh        tailscale up against your Headscale
│   ├── secrets-unlock.sh        rbw config + unlock
│   ├── agents-setup.sh          Claude Code, Codex, gh, MCP wiring
│   ├── kube-setup.sh            kubeconfig from vault, kubectl/helm plugins
│   ├── sync-setup.sh            Syncthing + restic timer
│   └── verify.sh                post-install checks
└── home/                        chezmoi source directory
    ├── .chezmoi.toml.tmpl       per-machine prompts
    ├── dot_bashrc.d/            shell snippets (sourced by ~/.bashrc)
    ├── dot_config/hypr/         monitors.lua, bindings.lua overrides
    ├── dot_config/omarchy/hooks/post-update.d/   re-apply chezmoi
    ├── dot_config/Code/User/    settings.json.tmpl, extensions.txt
    ├── dot_config/mise/config.toml
    ├── dot_config/git/config.tmpl
    ├── private_dot_ssh/config.tmpl
    └── dot_config/private_rbw/config.json.tmpl
```
