# Global conventions (all laptops)

- Projects live in `~/Projects/<org>/<repo>`. Use `clone <org>/<repo>` (gh wrapper) to fetch; use `wt <task>` to start a worktree for a task instead of committing on main.
- Commit with conventional commits. Never commit secrets; `gitleaks` runs in pre-commit and will block you.
- Secrets come from Vaultwarden via `rbw get <item>` — never ask for them in chat, never write them to files.
- Laravel/Vue stack: PHP via system, Node via mise. Run `composer install && bun install` after cloning.
- Kubernetes access from these machines is read-only (`kubectl get/describe/logs`). Deploys happen via `infra-gitops` PRs, never `kubectl apply` from a laptop.
- Prefer `xh` over curl for API calls, `jj` or `git` as you like but keep the repo colocated.
- When a task is done, summarise in the PR body; the human reviews via `gh dash`.
- Shared team memory lives in the Obsidian vault at `~/Projects/claude-obsidian` (`hermes/` is Hermes' area, `notes/` is mine).
