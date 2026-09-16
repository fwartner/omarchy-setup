# Tooling — curated CLIs, TUIs and desktop apps

Decided 2026-09-16 over four rounds. Versions are what installs today (Arch `extra` / AUR / npm / GitHub release); `omarchy update` keeps pacman/AUR current, `mise upgrade` the rest. Everything here is installed by `bootstrap.sh` via `packages/pacman.txt`, `packages/aur.txt`, `packages/mise.toml` and `scripts/agents-setup.sh`.

## Shell and terminal core

| Tool | Role | Source · version | Notes |
|---|---|---|---|
| bash + **Starship** | shell, prompt | extra 1.26.0 | Omarchy stays on bash; Starship config in `home/dot_config/starship.toml` shows git, k8s context, node/php/go, jj. |
| **Ghostty** | terminal | extra 1.3.1 | Set as Omarchy default terminal by bootstrap (`omarchy-setup-defaults terminal ghostty` / Setup > Defaults). Config in `home/dot_config/ghostty/config`. |
| **herdr** | agent-aware multiplexer | AUR `herdr` 0.9.0 (GitHub herdrdev/herdr, Apache-2.0) | Replaces tmux/zellij. Workspaces → tabs → panes, sidebar shows Claude/Codex/OpenCode/Hermes state (blocked/working/done). `herdr --remote ssh://host` attaches to a herdr server on another laptop or the Mac mini over the mesh. Config `~/.config/herdr/config.toml`; prefix Ctrl+B. Integrations: `herdr integration install claude codex opencode hermes`. |
| **atuin** | shell history | extra 18.22.0 | Synced across laptops. Sync server: self-host `atuin server` on the cluster later (see Backlog); until then local only. |
| **yazi** | file manager | extra 26.9.1 | `y` wrapper in bashrc.d changes directory on exit. |
| **television** (`tv`) | fuzzy finder with channels | extra 0.15.9 | Files, git, env, kubernetes channels; `proj` uses fzf still (both installed). |
| **gitui**, lazygit | git TUIs | extra 0.28.1 / 0.65.1 | lazygit ships with Omarchy; gitui for speed on old CPUs. |
| **git-delta**, **difftastic** | diffs | extra 0.19.2 / 0.70.0 | delta as git pager; `git dft` alias for structural diffs. |
| fzf, ripgrep, fd, bat, eza, zoxide, btop, lazydocker, impala, bluetui, wiremix | Omarchy base | shipped | Not re-listed in packages. |
| just, hyperfine, tokei, dust, duf, procs, sd, typos, fastfetch | small utilities | extra | Cheap, useful, no config. |

## Kubernetes and infrastructure (clients only)

| Tool | Source · version | Notes |
|---|---|---|
| kubectl, helm | extra 1.36.4 / 4.3.0 | kubeconfig from vault (`kubeconfig-shared`, read-only SA). |
| **k9s** | extra 0.51.0 | Skins follow Omarchy theme via `~/.config/k9s/skins`. |
| kubectx/kubens | extra 0.11.0 | |
| **stern** | extra 1.34.0 | multi-pod logs. |
| **argocd** CLI | extra 3.4.2 | `argocd login argocd.intern… --sso` (pocket-id). |
| **kubectl-cnpg** | AUR 1.30.0 | matches the CloudNativePG operator on the cluster. |
| **velero** CLI | extra 1.18.2 | |
| krew | extra 0.5.0 | plugin manager; installs `ctx`, `ns`, `neat`, `view-secret`. |
| **hcloud** | extra 1.68.0 | Hetzner CLI; token from vault item `hcloud-readonly` (optional, not required by bootstrap). |
| **opentofu** + terraform | extra 1.12.6 / 1.15.9 | Both, because the Terraform state at P&P is still `terraform`; `tofu` for personal. |
| headlamp desktop | Omarchy Install > Package `headlamp-bin` (AUR) | optional, per machine. |

## Databases and HTTP

| Tool | Source · version | Notes |
|---|---|---|
| **lazysql** | AUR 0.5.5 | quick Postgres/MySQL/SQLite browsing. |
| **harlequin** | AUR 2.14.0 | SQL IDE in the terminal (Python; installed via `uv tool` if AUR build is slow). |
| **pgcli** | extra 4.6.0 | |
| redis-cli | extra `valkey` 9.1.2 | Arch replaced redis with valkey; `valkey-cli` is aliased to `redis-cli`. |
| **usql** | AUR 0.21.5 | one client for every DB. |
| **posting** | AUR 2.10.0 | Postman-style, YAML collections in `~/Projects/<repo>/.posting/`. |
| **atac** | extra 0.23.1 | lighter HTTP TUI. |
| **xh**, jq, **yq** (go-yq), **fx** | extra 0.26.2 / 1.8.2 / 4.53.3 / 39.2.0 | |
| DBeaver, Bruno | extra 26.2.0 / AUR `bruno` 4.1.0 | GUIs for when a screen is better. |

## Laravel / PHP / JS stack (full)

- `omarchy install dev-env php laravel node bun go python` — PHP + composer + xdebug from pacman, everything else via **mise** (`packages/mise.toml`: node lts, bun, go, python 3.13, plus `herdr` fallback if AUR lags).
- Laravel installer via `composer global require laravel/installer`; Herd is macOS-only, so local sites run with `php artisan serve` or `podman-compose` — templates in `templates/containers/` (postgres 17, mysql 8.4, valkey, mailpit, minio).
- Omarchy's `Install > Development > Docker DB` (`omarchy-install-docker-dbs`) is **not** used here: it installs Docker, which would put a rootful daemon back on the machine. Use the compose templates instead.

## Git workflow

| Tool | Source · version | Notes |
|---|---|---|
| gh | extra 2.101.0 | token from vault. |
| **gh-dash** | AUR 4.25.2 | PR/issue dashboard across `fwartner`, `Pixel-Process-UG`, `formspring-io`; config `home/dot_config/gh-dash/config.yml`. |
| **jj** (Jujutsu) | extra 0.45.1 | colocated with git (`jj git init --colocate`); config `home/dot_config/jj/config.toml`. |
| **pre-commit** + **gitleaks** + commitlint | extra 4.6.2 / 8.30.1 / AUR 20.3.1 | global git template (`init.templateDir`) installs the gitleaks hook in every new clone. |
| git-absorb, git-branchless | extra 0.9.0 / 0.11.1 | |

## Agents

| Tool | Source · version | Notes |
|---|---|---|
| **Claude Code** | npm/native 2.1.273 | Omarchy installs it when chosen as default agent; `agents-setup.sh` adds MCP servers: AFFiNE, Home Assistant, Context7, **Sentry**, **Linear**, **GitHub**, **Playwright**. Global `~/.claude/CLAUDE.md` + `~/.claude/skills/` from `home/dot_claude/`. |
| **Codex CLI** | npm 0.154.0 | |
| **OpenCode** | AUR `opencode-bin` 1.18.31 | provider = your FreeLLM gateway for cheap runs (`home/dot_config/opencode/opencode.json`). |
| **Hermes Agent** (client only) | GitHub v2026.9.14, `curl … install.sh` | Installed but not run as a daemon; used as `hermes` CLI against the Mac mini instance and for herdr integration. |
| `wt` | repo script | `wt <task>` = git worktree in `../<repo>.wt/<task>` + herdr workspace + `claude` in it. Parallel agents never collide. |
| No local models | — | Everything via `llm.intern` (FreeLLM) or Claude/OpenAI subscriptions. |

## Knowledge / notes

Obsidian (Syncthing vault, shared with Hermes), **glow** 3.0.0, **mdcat** AUR 2.16.0, **slides** AUR 0.9.0, **tealdeer** 1.9.0 (`tldr`), `cheat.sh` via `cht` function, **zk** 0.15.6 pointed at the vault's `inbox/` folder.

## Desktop

Bitwarden desktop (extra 2026.3.1, pointed at `secrets.intern`) + browser extension (manual, Chromium web store), Telegram Desktop (extra 7.2.8), DBeaver, Bruno. Everything else from Omarchy's own menu.

## Ops from the laptop

sentry-cli (AUR `sentry-cli-bin` 2.31.0, token from vault item `sentry-token` — optional; targets the self-hosted GlitchTip via `SENTRY_URL`, not sentry.io), **logcli** (extra 3.6.6, Loki on the cluster), gping 1.21.0, trippy 0.13.0, bandwhich 0.23.1, dog 0.1.0, hass-cli (AUR `python-homeassistant-cli` 1.0.0; uses the same HA token as the MCP item).

## Base platform versions (2026-09-16)

Omarchy 4.0.4 · Hyprland (Lua config) · Neovim 0.12.5 · chezmoi 2.72.2 · rbw 1.15.0 · mise 2026.9.9 · Tailscale 1.102.4 · Podman 6.1.2 (rootless) · Syncthing 2.1.5 · restic 0.19.1.

## Backlog (not in bootstrap yet)

- atuin sync server on the cluster (`apps/internal/atuin` in gitops) — then `atuin login` in bootstrap.
- ntfy on the cluster + Claude Code `Stop`/`Notification` hooks → phone.
- k9s / Ghostty / gh-dash theme follow Omarchy `theme-set` hook.
