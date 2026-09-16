# Handover prompt for Claude Code

Run: `cd ~/Projects/omarchy-setup && claude`, paste everything below the line. This is the single prompt that carries the project from "repo written" to "first laptop bootable", including the Mac-side prep that used to be in `CLAUDE-CODE-PROMPT-mac-prep.md`.

---

You are taking over the `omarchy-setup` project: a chezmoi/bootstrap repo that turns fresh Omarchy 4.x installs on my two personal laptops (Dell Latitude 7310 = `daily`, Lenovo V130-15IGM 81HL = `spare`) into identical agentic-coding workstations wired into my infrastructure (Headscale mesh at `headscale.pixelandprocess.de`, Vaultwarden at `secrets.intern.pixelandprocess.de` — already deployed and I'm registered there —, the shared k8s cluster managed by `~/Projects/Development/pixelandprocess-gitops`, AFFiNE, Home Assistant, FreeLLM gateway). The plan and all decisions are in the repo; do not redesign, execute and fix.

Read first, in this order: `README.md`, `docs/MASTER-PLAN.md`, `docs/TOOLING.md`, `docs/INVENTORY.md`, `docs/RUNBOOK.md`, `bootstrap.sh`, `scripts/*.sh`, `home/.chezmoi.toml.tmpl`, `home/.chezmoiignore`, `packages/*`. Then `git log --oneline` to see what was done: PRs #3–#7 already executed most of the Mac-side prep (restic S3 target on Hetzner, Headscale key script `scripts/mac/new-laptop-key.sh`, ISO resolver `scripts/mac/latest-iso.sh`, private-repo bootstrap with token scrub, AFFiNE MCP endpoint notes). Do not redo those.

Rules: work on a branch `feat/handover-<date>`, conventional commits, never commit secrets, never print a secret except where I ask for one value once. Stop and ask me only where marked ASK. Everything else: decide, do, note it in the final report.

## Phase A — repo review and repair (no external side effects)

1. `make lint`. Render every chezmoi template with fake data the way `.github/workflows/ci.yml` does; fix failures.
2. Cross-check `packages/pacman.txt` and `packages/aur.txt` against the Arch/AUR package databases (`https://archlinux.org/packages/search/json/?name=X`, `https://aur.archlinux.org/rpc/v5/info?arg[]=X`): every name must exist. Fix renamed packages (e.g. `valkey` vs `redis`, `go-yq` vs `yq`). Record the versions you find in the tables of `docs/TOOLING.md` where they differ from what's written.
3. Verify the Omarchy CLI names used in `bootstrap.sh` and `scripts/` against the current Omarchy source (`https://github.com/omacom/omarchy`, `bin/` directory on the default branch): `omarchy-pkg-add`, `omarchy-install-editor`, `omarchy-install-dev-env`, `omarchy-install-service`, `omarchy-install-agent`, `omarchy-setup-defaults`, `omarchy-setup-security-sudoless-docker`, `omarchy-kernel-cmdline-add`. Where a name doesn't exist, replace it with the real command or the `omarchy <group> <cmd>` form, keeping the `|| fallback` pattern. Also confirm the Hyprland Lua API calls in `home/dot_config/hypr/monitors.lua` (`o.env`, `o.monitor`) against Omarchy's default config in the same repo. `bindings.lua` was removed in PR #4 because its API guesses were unverified — recreate it only from verified API (bindings wanted: Super+E → VS Code, Super+Shift+P → project switcher, Super+Shift+C → Claude Code in a project, Super+Shift+O → Obsidian).
4. Confirm the herdr CLI surface used in `home/dot_local/bin/executable_wt` (`herdr workspace new … --cwd … -- <cmd>`) and `scripts/agents-setup.sh` (`herdr integration install <agent>`) against `https://github.com/herdrdev/herdr` README/docs; adjust flags. Same for the OpenCode config schema in `home/dot_config/opencode/opencode.json.tmpl` (`https://opencode.ai/docs/config`) and the `claude mcp add` invocations (`claude mcp add --help`).
5. Check the Bitwarden Vaultwarden template functions in `home/private_dot_ssh/*.tmpl` against chezmoi's docs (`rbw`, `rbwFields`): `(rbw "item").notes` and `(index (rbwFields "item") "public_key").value` must be the right shapes. Fix if not.
6. Commit as you go.

## Phase B — Mac-side prep: only what's still missing

Run `rbw sync && rbw list` and compare against the secrets table in `docs/RUNBOOK.md`. For every item that exists, skip its section. For the rest follow `docs/CLAUDE-CODE-PROMPT-mac-prep.md`. Full checklist for reference: rbw fix + login (ASK), `bw` CLI login (ASK), fleet SSH key → `ssh-laptops`, GitHub PAT → `github-token-laptops` (ASK for the token), read-only ServiceAccount + kubeconfig → `kubeconfig-shared` (via a gitops PR under `apps/system/rbac-laptops/`), AFFiNE + Home Assistant tokens → `affine-mcp` / `homeassistant-mcp` (ASK; also confirm HA's Headscale node name and fix `ha_url`), restic target → `restic-laptops` (ASK before creating buckets/credentials), Headscale `tag:laptop` ACL (show diff, ASK) + `scripts/mac/new-laptop-key.sh`, Omarchy ISO download + checksum. Additionally create two optional items only if I say yes when you ASK: `sentry-token` (for sentry-cli) and `hcloud-readonly`.

## Phase C — dry run of the bootstrap on this Mac

You cannot run Omarchy here, but you can catch 80 % of the failures:
1. With the vault unlocked, `chezmoi execute-template --source ./home < f` for every `*.tmpl` — real data this time — and `chezmoi --source ./home --destination /tmp/fakehome apply --dry-run --verbose` with a chezmoi config that sets `hostname=latitude-7310`, `gdk_scale=1`, `wifi_driver=none`, `role=daily`, then again with `hostname=v130-15igm`, `role=spare`. Every file must render; check `.chezmoiignore` excludes what it should for `spare`.
2. `bash -n` and shellcheck on everything (already in `make lint`), plus a manual read of `bootstrap.sh` for ordering problems: Headscale join happens before the vault is used, `rbw unlocked` is checked before `chezmoi apply`, `mise activate` is sourced before anything calls `node`/`npm`.
3. Pull the `omarchy-4.0.4.iso` package list if available (or the `omarchy` repo's install scripts) and verify none of our pacman packages conflict with what Omarchy pins (e.g. a different terminal or bar). Report any overlap.
4. Fix everything you find; commit.

## Phase D — finish

1. Update `docs/RUNBOOK.md` §0 checkboxes to reflect what is now actually done, and `docs/INVENTORY.md` "verify" cells if I gave you data.
2. Push the branch, open a PR with a summary, `gh pr merge --squash --delete-branch` after CI is green. Merge the gitops PRs only after I approve them (ASK).
3. Final report: what's done, what's still manual (write USB with Etcher, run `scripts/mac/new-laptop-key.sh` right before install, BIOS SATA→AHCI on the Dell, Secure Boot off on both), the exact bootstrap command for a fresh laptop (private repo, so clone with the token: `git clone https://fwartner:$(rbw get github-token-laptops)@github.com/fwartner/omarchy-setup ~/.local/share/omarchy-setup && ~/.local/share/omarchy-setup/bootstrap.sh`), and a list of anything you were unsure about so I can decide.
