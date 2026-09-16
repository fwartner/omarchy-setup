# Vaultwarden on the shared cluster

Prerequisite for the whole fleet: `bootstrap.sh` pulls every secret from here.
Hostname: `secrets.intern.pixelandprocess.de` (change in `kustomization.yaml` + `home/.chezmoi.toml.tmpl` if you pick another).

Drop this directory into `pixelandprocess-gitops` (e.g. `apps/vaultwarden/`) and let your existing GitOps flow apply it, or `kubectl apply -k .` once by hand.

Assumptions (adjust in `kustomization.yaml` patches if yours differ):

- ingress class `nginx` (or Traefik — swap the annotation)
- cert-manager with a `ClusterIssuer` named `letsencrypt` — `*.intern` must resolve publicly for HTTP-01, otherwise use DNS-01 or your internal CA
- a default `StorageClass` that supports `ReadWriteOnce`
- the `intern.` zone is only routed over Headscale; if the ingress is publicly reachable, keep `SIGNUPS_ALLOWED=false` and set `ADMIN_TOKEN`

Steps:

1. `kubectl create namespace vaultwarden`
2. Generate the admin token: `openssl rand -base64 48`, then
   `kubectl -n vaultwarden create secret generic vaultwarden-env --from-literal=ADMIN_TOKEN='<token>'`
   (or use SealedSecrets/SOPS in the gitops repo — do not commit the plain token).
3. `kubectl apply -k infra/vaultwarden/`
4. Open `https://secrets.intern.pixelandprocess.de/admin`, create your account, then set `SIGNUPS_ALLOWED=false` (it already is — the first account is created by temporarily setting it to true via the admin panel invite, or invite yourself from `/admin`).
5. Create the vault items listed in `docs/RUNBOOK.md` §Secrets.
6. Add a nightly backup of the PVC (`/data/db.sqlite3` + `attachments/`) to your restic/S3 — the cluster's existing PVC backup is fine; Vaultwarden is SQLite, one file.

Test from the Mac before touching a laptop: `rbw config set base_url https://secrets.intern.pixelandprocess.de && rbw login && rbw list`.
