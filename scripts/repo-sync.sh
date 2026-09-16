#!/usr/bin/env bash
# Keep the repos in packages/repos.txt cloned and current under ~/Projects/<org>/<repo>.
#
#   ./scripts/repo-sync.sh            sync everything in the manifest
#   ./scripts/repo-sync.sh --dry-run  say what would happen, touch nothing
#
# Clean repos fast-forward. Repos with local work are committed to a
# wip/<hostname> branch and pushed, so nothing lives only on a laptop that can
# be lost. Nothing is ever force-pushed, rebased or deleted, and a repo marked
# `pull-only` in the manifest is never written to.
set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="${MANIFEST:-$SELF_DIR/../packages/repos.txt}"
PROJECTS_ROOT="${PROJECTS_ROOT:-$HOME/Projects}"
DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

ok()   { printf '  \033[32m✔\033[0m %s\n' "$*"; }
skip() { printf '  \033[33m•\033[0m %s\n' "$*"; }
bad()  { printf '  \033[31m✘\033[0m %s\n' "$*"; }
run()  { if [ "$DRY_RUN" = 1 ]; then printf '      would: %s\n' "$*"; else "$@"; fi; }

# --- pure helpers, unit-tested by tests/repo-sync-test.sh --------------------

# Strip comments and blanks. Emits "owner/repo<TAB>flags".
manifest_entries() {
  sed -E 's/#.*//' | awk 'NF { printf "%s\t%s\n", $1, ($2 == "" ? "-" : $2) }'
}

# Paths that must never be swept up by `git add -A` and pushed to a remote.
# Publication is irreversible, so this fails the repo rather than the file:
# committing "everything except the secret" would push a half-state and still
# leave the operator believing the sync worked.
looks_secret() {
  case "${1##*/}" in
    .env|.env.*|*.pem|*.key|*.p12|*.pfx|*.keystore|*.jks) return 0 ;;
    id_rsa|id_dsa|id_ecdsa|id_ed25519) return 0 ;;
    credentials|credentials.json|service-account*.json|*.kubeconfig) return 0 ;;
  esac
  case "$1" in
    */.env|*/.env.*|.ssh/*|*/.aws/credentials|*/.kube/config) return 0 ;;
  esac
  return 1
}

# Reads NUL-free paths on stdin, echoes the ones that look like secrets.
secret_paths() {
  local p
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    looks_secret "$p" && printf '%s\n' "$p"
  done
  return 0
}

# --- git helpers -------------------------------------------------------------

default_branch() {
  local d="$1" b
  b="$(git -C "$d" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)" || b=""
  [ -n "$b" ] && { printf '%s\n' "${b#origin/}"; return; }
  # No origin/HEAD (a fresh clone of an empty default, or a pruned ref).
  for b in main master; do
    git -C "$d" show-ref --verify --quiet "refs/remotes/origin/$b" && { printf '%s\n' "$b"; return; }
  done
  git -C "$d" symbolic-ref --quiet --short HEAD 2>/dev/null || printf 'main\n'
}

sync_one() {
  local slug="$1" flags="$2"
  local org="${slug%%/*}" repo="${slug##*/}"
  local dir="$PROJECTS_ROOT/$org/$repo"

  if [ ! -d "$dir/.git" ]; then
    run mkdir -p "$PROJECTS_ROOT/$org"
    if run git clone --quiet "https://github.com/$slug.git" "$dir"; then
      ok "$slug cloned"
    else
      bad "$slug clone failed"
      return 1
    fi
    return 0
  fi

  git -C "$dir" remote update --prune >/dev/null 2>&1 || true

  local dirty unpushed branch
  dirty="$(git -C "$dir" status --porcelain 2>/dev/null)"
  branch="$(git -C "$dir" symbolic-ref --quiet --short HEAD 2>/dev/null || echo DETACHED)"
  unpushed="$(git -C "$dir" log --oneline '@{upstream}..HEAD' 2>/dev/null || true)"

  if [ -z "$dirty" ] && [ -z "$unpushed" ]; then
    if run git -C "$dir" pull --ff-only --quiet; then ok "$slug up to date"
    else skip "$slug could not fast-forward (diverged); left alone"; fi
    return 0
  fi

  if [ "$flags" = "pull-only" ]; then
    skip "$slug has local work but is pull-only; left alone"
    return 0
  fi
  if [ "$branch" = "DETACHED" ]; then
    skip "$slug is on a detached HEAD; left alone"
    return 0
  fi

  local secrets
  secrets="$(git -C "$dir" status --porcelain | awk '{ $1=""; sub(/^ /,""); print }' | secret_paths)"
  if [ -n "$secrets" ]; then
    bad "$slug NOT committed: files that must not be pushed"
    printf '%s\n' "$secrets" | sed 's/^/        /'
    return 1
  fi

  # Never write work-in-progress onto the branch everyone else builds from.
  local def target
  def="$(default_branch "$dir")"
  target="$branch"
  if [ "$branch" = "$def" ]; then
    target="wip/$(hostname -s)"
    run git -C "$dir" checkout -q -B "$target"
  fi

  if [ -n "$dirty" ]; then
    run git -C "$dir" add -A
    run git -C "$dir" commit -q -m "wip: automatic sync from $(hostname -s) $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  fi
  if run git -C "$dir" push -q --set-upstream origin "$target"; then
    ok "$slug local work pushed to $target"
  else
    bad "$slug push to $target failed; work is committed locally"
    return 1
  fi
}

main() {
  [ -f "$MANIFEST" ] || { echo "no manifest at $MANIFEST" >&2; exit 1; }
  [ "$DRY_RUN" = 1 ] && echo "(dry run — nothing will be written)"
  echo "syncing repos from $(basename "$MANIFEST") into $PROJECTS_ROOT"
  local fail=0 slug flags
  while IFS=$'\t' read -r slug flags; do
    sync_one "$slug" "$flags" || fail=$((fail + 1))
  done < <(manifest_entries < "$MANIFEST")
  echo
  if [ "$fail" -eq 0 ]; then echo "repo sync clean"; else echo "$fail repo(s) need attention"; fi
  return "$fail"
}

[ "${BASH_SOURCE[0]}" = "$0" ] && main "$@"
