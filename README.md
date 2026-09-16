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
- **Omarchy plugins** from `packages/plugins.txt`, installed and enabled at bootstrap
- **Agent skills** from `packages/skills.txt` — Claude Code plugins and plain
  skill repos, installed at bootstrap and refreshed daily
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

**1. Fork it.** Nothing needs editing first. `chezmoi init` asks for everything
on the first run of `bootstrap.sh` — the per-machine values (hostname, display
scale, Wi-Fi quirk, role) and the fleet-wide ones (vault, mesh, git identity,
and the optional LLM/notes/Home Assistant URLs). Every one is a
`promptStringOnce`, so the answers are stored in
`~/.config/chezmoi/chezmoi.toml` and a later re-init reuses them rather than
asking again. `vault_url` is the only one bootstrap cannot continue without.

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
until you fill it. Coding-agent skills live in `packages/skills.txt` — see
below.

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

`bootstrap.sh` is idempotent, and a second run on the same machine **updates it
instead of reinstalling it**. Once a run finishes it drops a marker in
`~/.local/state/`; every later run pulls this repo, then hands off to
`scripts/update-all.sh` — config, `omarchy-update -y`, themes, packages, agent
skills and repos — and finishes with `verify.sh`. That is strictly more than
replaying the install steps, which never update the system at all.

So there is one command to remember. `./bootstrap.sh --full` (or
`FULL_BOOTSTRAP=1`) forces the install path back, for when a step needs
replaying. The marker is written last, so a run that died half way through is
not mistaken for a finished one.

## Agent skills

`packages/skills.txt` is how every laptop ends up with the same skills loaded
into Claude Code. Two kinds of entry, because skills ship two ways:

```
plugin  superpowers@claude-plugins-official  anthropics/claude-plugins-official
skills  https://github.com/michaelshimeles/skills.git
```

A `plugin` line goes through `claude plugin install`; the third field is the
marketplace source, added first so a machine that has never seen it can still
resolve the name. A `skills` line is a plain repo whose top-level directories
each hold a `SKILL.md` — it is cloned once to `~/.local/share/agent-skills` and
every skill inside symlinked into `~/.claude/skills`, so one fetch updates all
of them.

The symlink farm is only ever added to. A real directory, or a symlink pointing
somewhere the script did not put it, is left in place, so hand-written skills
and anything chezmoi manages survive a re-run. Skills you want templated per
machine go in `home/dot_claude/skills/` instead and are applied by chezmoi.

## Things that will bite you

Eight lessons this repo paid for, all encoded in the scripts:

- **Do not duplicate or collide with Omarchy's own packages.** A duplicate is
  noise; a *conflict* aborts the entire pacman transaction mid-bootstrap. Check
  names, `conflicts` in **both** directions, and `-bin`/`-git` variants —
  `tealdeer` vs `tldr` and `mise` vs `mise-bin` each did this, for a different
  reason each time.
- **Avoid AUR packages that pull Electron.** They build the Chromium source tree
  and take hours on a laptop.
- **Pin providers for ambiguous dependencies.** `java-runtime>=21` has six
  providers; pacman stops and asks, and nobody is watching an unattended install.
- **Pin the Hyprland Lua API to the version your fleet runs, not the default
  branch.** `o.rebind` exists in Omarchy's development branch and not in 4.x, so
  `bindings.lua` loaded fine in review and died on the laptop with `attempt to
  call a nil value (field 'rebind')`. `hl.unbind` then `o.bind` is the form 4.x
  documents. `tests/bindings-test.lua` now stubs the API *strictly* — any helper
  absent from v4.0.4 raises — because the previous stub defined `o.rebind`
  itself and so confirmed a function that was never there.
- **`git pull --ff-only` is a trap for a checkout you force-push under.**
  Squashing this repo's history for release left every existing laptop with no
  common ancestor, so step 2/9 died with `Not possible to fast-forward` on the
  machine that needed repairing. `scripts/self-update.sh` fetches and resets
  onto the new history, and refuses when the worktree is dirty.
- **`chezmoi apply` prompts, and an unattended run waits forever.** When a
  target changed since chezmoi last wrote it, apply stops on
  `diff/overwrite/all-overwrite/skip/quit`. VS Code rewrites its own
  `settings.json`, so this is routine, not rare -- it parked a laptop at step
  7/9. Every unattended apply passes `--force`, the repo being the source of
  truth for fleet config, and `make lint` fails if one stops doing so.
- **A value hardcoded in `.chezmoi.toml.tmpl` is a value a re-init destroys.**
  The fleet URLs used to be constants in that file. Genericizing this repo for
  release replaced them with `example.com`, and the first `chezmoi init` on an
  already-configured laptop wrote those defaults over its nine real URLs — the
  vault, the mesh and everything rendered from them, gone in one step, because
  the machine predated the genericization and held them nowhere else. They are
  all `promptStringOnce` now, which never overwrites a stored answer.
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
make test    # self-checks: repo-sync, agent skills, shell snippets, hypr bindings
```

CI runs both, plus renders every chezmoi template with fake data.

## License

MIT. See [LICENSE](LICENSE).
