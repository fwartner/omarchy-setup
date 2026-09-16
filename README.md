# omarchy-setup

Fresh Omarchy install → identical personal workstation on every laptop, wired into the Headscale mesh, Vaultwarden, the shared cluster and the agentic toolchain.

```bash
curl -fsSL https://raw.githubusercontent.com/fwartner/omarchy-setup/main/bootstrap.sh | bash
```

- `docs/MASTER-PLAN.md` — architecture, decisions, phases
- `docs/RUNBOOK.md` — per-laptop checklist + list of vault items
- `docs/INVENTORY.md` — machines
- Phase 0 (Vaultwarden on the cluster) lives in `pixelandprocess-gitops/apps/internal/vaultwarden`
- `bootstrap.sh`, `scripts/` — the automation
- `home/` — chezmoi source dir (`chezmoi init --source ./home`)
- `packages/` — pacman + AUR lists

Not automated on purpose: LUKS/user (installer), Claude/Codex OAuth logins, Syncthing hub acceptance, BIOS.
