# omarchy-setup

Turn a fresh [Omarchy](https://omarchy.org) install into a fully configured
workstation with one command, and keep it that way without thinking about it.

A template. Fork it, change a dozen values, run `bootstrap.sh` on a laptop.

## What it does

- **chezmoi** renders your dotfiles, including files built from secrets
  (`~/.ssh/id_ed25519`, `~/.kube/config`) that are never in git
- **Vaultwarden + rbw** hold every credential; the repo holds none
- **Headscale** joins each machine to your mesh with a pre-auth key
- **Packages** come from two plain-text manifests, filtered per machine role
- **restic** backs up nightly to S3-compatible storage, with retries
- **Repo sync** keeps the projects you actually work on cloned and current
- **Tunnels** via [Burrow](https://useburrow.dev) — `tunnel http 3000` exposes a
  local port over HTTPS
- **Automatic updates**: config every 30 min, everything else daily, via systemd
  user timers

It orchestrates Omarchy's own commands rather than reimplementing them —
`omarchy-update -y` already snapshots Btrfs, updates pacman, AUR and mise, and
runs migrations.

## What you need first

| Thing | Why | Required? |
|---|---|---|
| **Vaultwarden** (or Bitwarden) | every credential comes from here; bootstrap stops at step 5/9 without it | **yes** |
| **Headscale** (or Tailscale) | step 4/9 joins the mesh, and an internal vault is usually only reachable over it | yes, if your vault is internal |
| S3-compatible storage | restic backups | no |
| Kubernetes | the `kubeconfig-shared` item | no |
| AFFiNE / Home Assistant | MCP servers for coding agents | no |

Everything optional degrades cleanly — each script guards on its vault item and
skips when it is absent.

### Your vault's two-factor must include TOTP

This is the one that stops you cold. `rbw` implements **Authenticator (TOTP)**
and Email. A vault whose only second factor is WebAuthn fails at step 5/9 with
`unsupported two factor methods: WebAuthn`, and no CLI can ever satisfy WebAuthn
— it needs a browser and a physical key ceremony. Add TOTP alongside your
security key before you touch a laptop.

## Setup

**1. Fork and edit the fleet constants** in `home/.chezmoi.toml.tmpl`. They are
all `example.com` and none of them resolve. The prompts above that block are the
things that genuinely differ per machine; the constants are shared by the fleet.

**2. Create the vault items.** Minimum for a useful machine:

| Item | Holds |
|---|---|
| `ssh-laptops` | fleet SSH key — notes = private key, field `public_key` |
| `github-token-laptops` | PAT for `gh` and private clones |
| `headscale-preauth` | pre-auth key, refreshed per install |

Then as needed: `kubeconfig-shared`, `restic-laptops`, `affine-mcp`,
`homeassistant-mcp`. Full table in [`docs/RUNBOOK.md`](docs/RUNBOOK.md).

`rbw` reads items but **cannot create them or set custom fields** — use the
official Bitwarden CLI (`bw`) on your existing machine for that. The laptops
only ever read, so they only need `rbw`.

**3. List your repos** in `packages/repos.txt`, and your tools in
`packages/pacman.txt` / `aur.txt`. `repos.txt` ships empty; sync is a no-op
until you fill it.

**4. Per laptop:**

```sh
./scripts/mac/new-laptop-key.sh     # mint a 24h Headscale key into the vault
```

BIOS: Secure Boot off. On Dells set SATA Operation to **AHCI** — it defaults to
RAID and the installer will see no disk at all.

Install Omarchy, then on the laptop:

```sh
curl -fsSL https://raw.githubusercontent.com/<you>/omarchy-setup/main/bootstrap.sh | bash
./scripts/verify.sh
```

Private fork? The raw URL 404s without a token — see `docs/RUNBOOK.md` §3.

`bootstrap.sh` is idempotent. Re-run it after any change; the daily timer calls
the same path.

## Things that will bite you

Four lessons this repo paid for, all encoded in the scripts:

- **Do not duplicate or collide with Omarchy's own packages.** A duplicate is
  noise; a *conflict* aborts the entire pacman transaction mid-bootstrap. Check
  names, `conflicts` in **both** directions, and `-bin`/`-git` variants —
  `tealdeer` vs `tldr` and `mise` vs `mise-bin` each did this, for a different
  reason each time.
- **Avoid AUR packages that pull Electron.** They build the Chromium source tree
  and take hours on a laptop.
- **Pin providers for ambiguous dependencies.** `java-runtime>=21` has six
  providers; pacman stops and asks, and nobody is watching an unattended install.
- **`rbw` runs a background agent with no controlling terminal.** A terminal
  pinentry cannot work there — it reports "pinentry cancelled", which looks like
  you pressed escape. It needs a GUI pinentry. The agent also caches its config,
  so `rbw stop-agent` after changing it or the change is invisible.

## Status

Verified against a real cluster, GitHub, and the Arch/AUR package databases, and
partially against hardware — a pilot laptop reaches step 6/9. Steps 7–9
(dotfiles, editors and agents, verify) have **not** completed on-device yet.
Expect a surprise or two; `scripts/verify.sh` is what tells you which.

## Development

```sh
make lint    # shellcheck + bash -n over every script
make test    # self-checks: repo-sync, shell snippets, hypr bindings
```

CI runs both, plus renders every chezmoi template with fake data.

## License

MIT. See [LICENSE](LICENSE).
