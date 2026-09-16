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
- **Automatic updates**: config every 30 min, everything else daily, via systemd
  user timers

It orchestrates Omarchy's own commands rather than reimplementing them —
`omarchy-update -y` already snapshots Btrfs, updates pacman, AUR and mise, and
runs migrations.

## Quickstart

1. **Fork**, then edit the fleet constants in `home/.chezmoi.toml.tmpl` — they
   are all `example.com` and none of them resolve.
2. **Stand up Vaultwarden** (or any Bitwarden-compatible server) and create the
   items in [`docs/RUNBOOK.md`](docs/RUNBOOK.md) §Secrets.
3. **List your repos** in `packages/repos.txt`. Ships empty; sync is a no-op
   until you fill it.
4. **Adjust packages** in `packages/pacman.txt` and `packages/aur.txt`.
5. **Run it** on the laptop:

   ```sh
   curl -fsSL https://raw.githubusercontent.com/<you>/omarchy-setup/main/bootstrap.sh | bash
   ```

   Private fork? The raw URL 404s without a token — see `docs/RUNBOOK.md` §3.

`bootstrap.sh` is idempotent. Re-run it after any change; it is also what the
daily timer calls.

## Layout

```
bootstrap.sh              fresh Omarchy -> workstation, 9 steps
packages/                 pacman.txt, aur.txt, repos.txt
scripts/                  one concern each; bootstrap calls them in order
  mac/                    run on your existing machine, not the laptop
home/                     chezmoi source directory
tests/                    self-checks, run by `make test` and CI
docs/                     the plan, the per-laptop runbook, tool choices
```

## Things worth knowing before you use it

- **rbw cannot do WebAuthn.** If your vault's only second factor is a security
  key, no laptop will get past the unlock step. Enable TOTP alongside it.
- **Don't duplicate what Omarchy ships.** Listing a package it already installs
  is noise; listing one that *conflicts* with what it installs (`tealdeer` vs
  `tldr`, `mise` vs `mise-bin`) aborts the entire pacman transaction. Check
  names, `conflicts` in both directions, and `-bin`/`-git` variants.
- **Avoid AUR packages that build Electron.** They pull the Chromium source tree
  and take hours on a laptop.
- **Repo sync pushes local work** to `wip/<hostname>` so nothing lives only on a
  machine that can be lost. It refuses outright if the change set looks
  secret-shaped, and `pull-only` opts a repo out entirely.

## Requirements

Omarchy 4.x on the target. On your existing machine: `chezmoi`, `rbw`, the
Bitwarden CLI (`rbw` reads items but cannot create them), `kubectl` if you use
the kubeconfig item, and `jq`.

## Development

```sh
make lint    # shellcheck + bash -n over every script
make test    # self-checks: repo-sync, shell snippets, hypr bindings
```

CI runs both, plus renders every chezmoi template with fake data.

## License

MIT. See [LICENSE](LICENSE).
