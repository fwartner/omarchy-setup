# Prompt for Claude Code — Phase 0 on the Mac, end to end

Run in Terminal on the Mac: `cd ~/Projects/omarchy-setup && claude`, then paste everything below the line.
Prerequisite: Vaultwarden is live at https://secrets.intern.pixelandprocess.de and you have registered + enabled 2FA there.

---

You are preparing my Mac so that fresh Omarchy laptops can be bootstrapped with `bootstrap.sh` from this repo. Read `docs/MASTER-PLAN.md`, `docs/RUNBOOK.md` (especially §0 and §Secrets), `home/.chezmoi.toml.tmpl` and `scripts/*.sh` first so you know exactly which vault items, names, fields and URLs the scripts expect. Do everything below in order, non-interactively where possible, and stop to ask me only where marked ASK. Never print secrets to the terminal except where I ask you to show me a value once; never write secrets into this repo. Work in a branch for any repo changes and commit with conventional messages.

## 0. Sanity

- `git status` clean, on `main`, up to date with origin. If not, tell me and stop.
- `kubectl config current-context` must be the Pixel & Process cluster; `kubectl -n vaultwarden get pods` shows Running.

## 1. Fix rbw

- `brew upgrade rbw || brew install rbw`; require rbw ≥ 1.13.
- `rbw config show`. Set `base_url` to `https://secrets.intern.pixelandprocess.de`, `email` to `florian@pixelandprocess.de`, `lock_timeout` 3600. Config lives in `~/Library/Application Support/rbw/config.json` on macOS.
- Diagnose the earlier `rbw login` failure ("failed to parse JSON: expected ident"): curl `<base_url>/identity/accounts/prelogin` (POST, JSON body with my email) and `<base_url>/identity/connect/token` (POST, form body, wrong password) from this Mac and confirm both return JSON. If either returns HTML, print the `url_effective`, content-type and first 200 bytes, tell me what is intercepting it (DNS/split-DNS, Traefik router, proxy) and stop.
- ASK me to run `rbw login` and `rbw unlock` myself (master password + 2FA). Continue once `rbw list` works.

## 2. Bitwarden CLI for item creation

rbw cannot create items with custom fields, so install the official CLI for writing: `brew install bitwarden-cli`, `bw config server https://secrets.intern.pixelandprocess.de`, then ASK me to run `bw login` and `export BW_SESSION="$(bw unlock --raw)"` in this shell. Use `bw create item` with JSON templates (`bw get template item`) for everything below; use `bw get item <name>` first and update instead of duplicating if an item already exists.

## 3. Fleet SSH key → vault item `ssh-laptops`

- `ssh-keygen -t ed25519 -C omarchy-laptops -N '' -f /tmp/id_ed25519_laptops`
- Create a Secure Note item `ssh-laptops`: notes = full private key file, custom field `public_key` = the one-line `.pub`.
- `gh ssh-key add /tmp/id_ed25519_laptops.pub --title omarchy-laptops`
- Print the public key once for me, then `rm -P /tmp/id_ed25519_laptops*`.
- Verify: `rbw sync && rbw get --field public_key ssh-laptops` prints it.

## 4. GitHub token → `github-token-laptops`

- `gh` cannot create PATs. ASK me: open https://github.com/settings/personal-access-tokens/new, fine-grained, resource owner fwartner, all repositories, permissions Contents: read/write, Workflows: read/write, Metadata: read, Pull requests: read/write, expiry 1 year, and paste the token to you.
- Create Login item `github-token-laptops`, username `fwartner`, password = token. Verify with `curl -sS -H "Authorization: Bearer $(rbw get github-token-laptops)" https://api.github.com/user | jq .login`.

## 5. kubeconfig → `kubeconfig-shared`

- In the cluster create namespace-agnostic read-only access for the laptops: ServiceAccount `laptops` in namespace `kube-system`, ClusterRoleBinding to the built-in `view` ClusterRole, plus a Secret of type `kubernetes.io/service-account-token` for it. Put these manifests into `pixelandprocess-gitops` under `apps/system/rbac-laptops/` following the repo's Helm-chart-per-app convention (look at a small existing app under `apps/system/` and mirror it), commit on a branch `feat/laptops-rbac`, push, open a PR with `gh pr create --fill`, and apply it directly now with `kubectl apply` so I don't have to wait for ArgoCD (Argo will adopt it on merge).
- Build a standalone kubeconfig from the token, the cluster CA and server URL of the current context, context name `pp-shared-ro`. Test it with `KUBECONFIG=/tmp/kc kubectl get nodes` and `... kubectl auth can-i delete pods` (must be no).
- Create Secure Note item `kubeconfig-shared`, notes = the kubeconfig YAML. `rm -P /tmp/kc`.

## 6. MCP tokens → `affine-mcp` and `homeassistant-mcp`

- ASK me for: (a) the AFFiNE MCP endpoint URL and token for notes.intern.pixelandprocess.de (I created one before; if I don't have it handy, tell me where in AFFiNE to generate it), (b) a Home Assistant long-lived access token (Profile → Security → Long-lived access tokens, name "omarchy-laptops").
- Determine Home Assistant's name on the Headscale mesh: `kubectl -n headscale exec deploy/headscale -- headscale nodes list` and find the HA node. The MagicDNS base domain is `ts.pixelandprocess.de` (see `apps/internal/headscale/values.yaml` in the gitops repo). If the node is not called `homeassistant`, update `ha_url` in `home/.chezmoi.toml.tmpl` to `http://<node-name>.ts.pixelandprocess.de:8123` and commit. If HA is not on the mesh at all, tell me — that is a separate task.
- Create Login items: `affine-mcp` (password = token, custom field `url` = MCP endpoint) and `homeassistant-mcp` (password = token, custom field `url` = `http://<ha-magicdns>:8123`). Verify HA: `curl -sS -H "Authorization: Bearer $(rbw get homeassistant-mcp)" "$(rbw get --field url homeassistant-mcp)/api/" | jq .message`.

## 7. restic backup target → `restic-laptops`

- Find out what object storage the cluster already uses for backups (`apps/system/velero`, the CNPG barman config, or the new `feat/db-pvc-backups` work in the gitops repo) — endpoint, bucket naming, how credentials are provided. ASK me to confirm you may create a new bucket/prefix `laptops` there with a dedicated, minimal-permission credential (Hetzner Object Storage or whatever it is; if creating credentials needs the provider console, tell me exactly what to click and I'll paste the key pair).
- Create Login item `restic-laptops`: password = a new 32-char random repo password, custom field `repository` = `s3:https://<endpoint>/<bucket>/laptops`, custom fields `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`. Then update `scripts/sync-setup.sh` so it exports those two fields as env vars for restic (currently it only reads `repository` and the password) and commit.
- `brew install restic` and `restic -r <repository> init` from this Mac with those credentials to prove the target works.

## 8. Headscale: tag + pre-auth key

- Find the Headscale ACL policy (in `apps/internal/headscale` in the gitops repo, or in the running config via `kubectl -n headscale exec deploy/headscale -- headscale policy get`). Add `tag:laptop` with owner `florian` and an ACL allowing `tag:laptop` to reach everything the user `florian`'s existing devices can reach — mirror the existing rule for my Mac; don't touch any other rule. Show me the diff, ASK for approval, then commit on branch `feat/headscale-laptop-tag`, push, PR, and apply the policy now if it's file-based (`headscale policy set`).
- Do NOT create the pre-auth key yet (they expire in 24h). Instead add a script `scripts/mac/new-laptop-key.sh` to this repo that runs `kubectl -n headscale exec deploy/headscale -- headscale preauthkeys create --user florian --reusable --expiration 24h --tags tag:laptop` and writes the key into vault item `headscale-preauth` via `bw` (creating or updating it), so I can run it right before each install. Create the item now with an empty password.

## 9. Omarchy ISO

- Download `https://iso.omarchy.org/omarchy-4.0.4.iso` to `~/Downloads`, verify sha256 `ddeded2758c48318d201dfdac905ecb28f570441883f0c052ea3cd5d05acf92d` (if the release page https://github.com/omacom/omarchy/releases lists a newer 4.0.x, take that one and its checksum instead and update the version in `docs/RUNBOOK.md` + `docs/MASTER-PLAN.md`).
- `brew install --cask balenaetcher`. Do not write the USB yourself; tell me it's ready.

## 10. Repo wrap-up

- Run `make lint`. Render every chezmoi template with the real vault unlocked: `chezmoi execute-template --source ./home < <file>` for each `*.tmpl` (including the ssh ones now that the items exist) and fix anything that fails.
- Push all branches, merge the omarchy-setup PR(s) yourself with `gh pr merge --squash --delete-branch` (the gitops PRs I merge myself).
- Final report: a checklist of what's done, the two things I still do by hand (write the USB, run `scripts/mac/new-laptop-key.sh` right before installing), and the exact bootstrap command for the first laptop, which for a private repo is:
  `git clone https://fwartner:$(rbw get github-token-laptops)@github.com/fwartner/omarchy-setup ~/.local/share/omarchy-setup && ~/.local/share/omarchy-setup/bootstrap.sh`
  — adjust if you changed anything that affects it.
