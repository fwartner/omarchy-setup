# Prompt for Claude Code — deploy Vaultwarden to the shared cluster

Run Claude Code inside your `pixelandprocess-gitops` checkout on the Mac (kubectl context pointing at the shared cluster), then paste everything below the line.

---

Deploy Vaultwarden (the self-hosted Bitwarden-compatible server, image `vaultwarden/server`) to this cluster via this GitOps repo. It will be the secrets backend for my personal Omarchy laptop fleet, so it has to be done cleanly and end-to-end. Work in a branch, commit as you go, and stop for my approval before anything is applied to the cluster.

## Target

- Hostname: `secrets.intern.pixelandprocess.de` (this is the only hostname; do not use `vault.intern`).
- Namespace: `vaultwarden`.
- Single replica, `strategy: Recreate` (SQLite on a ReadWriteOnce PVC — never two pods).
- PVC 5Gi on the cluster's default StorageClass; mount at `/data`.
- Image tag pinned to the current stable Vaultwarden release (look it up on GitHub releases, do not use `latest`).

## Discover before writing

1. Inspect this repo and figure out how apps are structured here (Helm charts + values, kustomize, ArgoCD/Flux Application objects, folder conventions, how namespaces and ingresses are declared). Follow the existing conventions exactly; do not introduce a second style.
2. Detect from the cluster: ingress class (`kubectl get ingressclass`), cert-manager and its `ClusterIssuer` names, the default StorageClass, whether SealedSecrets / SOPS / External Secrets is used for secrets in this repo, and whether other apps under `*.intern.pixelandprocess.de` use any auth middleware or IP allowlists (they may be Headscale-only). Reuse whatever the other `*.intern` apps use for TLS and exposure.
3. Report the findings to me in a short summary before you write manifests.

## Configuration (environment for the container)

- `DOMAIN=https://secrets.intern.pixelandprocess.de`
- `SIGNUPS_ALLOWED=false`
- `INVITATIONS_ALLOWED=true`
- `SHOW_PASSWORD_HINT=false`
- `WEBSOCKET_ENABLED=true`
- `LOG_LEVEL=warn`
- `ROCKET_PORT=80`
- `ADMIN_TOKEN` — must be a secret, never plaintext in git. Generate it with `openssl rand -base64 48`, store it the way this repo stores secrets (SealedSecret/SOPS/ExternalSecret). If none of those exists, create the Kubernetes Secret out-of-band with `kubectl create secret generic vaultwarden-env --from-literal=ADMIN_TOKEN=…` and document that in the app's README, but do not commit the token. Print the token to me once so I can save it.
- Optional SMTP: check whether other apps in the repo have SMTP settings (an existing mail secret); if yes, wire `SMTP_HOST/PORT/FROM/USERNAME/PASSWORD/SECURITY` from the same secret so invitations and 2FA emails work. If not, skip and note it.

## Ingress

- Host `secrets.intern.pixelandprocess.de`, TLS via cert-manager using the same ClusterIssuer the other intern apps use; TLS secret `vaultwarden-tls`.
- Annotations for the detected ingress controller: body size ≥ 128m (attachments), read timeout ≥ 3600s (websocket notifications).
- Route `/` to the service on port 80; websocket goes over the same port in current Vaultwarden versions (no separate 3012 route needed — verify against the pinned version's docs and adjust if that version still needs `/notifications/hub` on 3012).
- If the intern apps are exposed only via Headscale/an internal LB, do the same; if they are public with an allowlist, replicate the allowlist.

## Probes, resources, security

- Liveness and readiness: `GET /alive` on the http port.
- Requests cpu 50m / memory 128Mi, limits cpu 500m / memory 512Mi.
- `securityContext.fsGroup: 1000`, run as non-root if the image allows it without breaking `/data` permissions (test it).
- NetworkPolicy if the repo uses them for other apps.

## Backup

- The SQLite DB and attachments live in `/data`. Hook the PVC into whatever backup the cluster already has (Velero, restic CronJob, CSI snapshots — find it). If nothing exists, add a nightly CronJob in the same namespace that runs `sqlite3 /data/db.sqlite3 ".backup /data/backup/db-$(date +%F).sqlite3"` via a sidecar-style job mounting the PVC, keeps 14 days, and tell me it's a stopgap.

## Deliverables

1. Findings summary (conventions, ingress class, issuer, storage, secrets mechanism, backup mechanism).
2. Manifests/chart values in the repo's style, plus a short `README.md` next to them: hostname, how the admin token is stored, how to invite the first user, backup location, how to upgrade the image tag.
3. `kubectl diff` / `kustomize build` / `helm template` output for review, and DNS check: does `secrets.intern.pixelandprocess.de` already resolve (where do the other intern hostnames point — external-dns, manual DNS, Headscale DNS)? If a DNS record is needed, tell me exactly what to create.
4. STOP and ask me before applying or merging.
5. After I approve: apply (or merge for the GitOps controller), wait for the pod to be Ready and the certificate to be issued, `curl -I https://secrets.intern.pixelandprocess.de/alive`, and confirm `/admin` loads with the token.
6. Then walk me through the first-user setup: open `/admin`, invite `florian@pixelandprocess.de`, complete registration, enable 2FA, confirm `SIGNUPS_ALLOWED` stays false.
7. Final check from my Mac: `rbw config set base_url https://secrets.intern.pixelandprocess.de && rbw config set email florian@pixelandprocess.de && rbw login && rbw list` must succeed (install `rbw` via Homebrew if missing).

Constraints: no destructive commands against the cluster, no changes to other apps, no plaintext secrets in git, conventional commits, one PR.
