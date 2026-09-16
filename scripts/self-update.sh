#!/usr/bin/env bash
# Make a checkout of this repo match origin, even when origin's history was
# rewritten under it.
#
#   ./scripts/self-update.sh [repo-dir]
#
# `git pull --ff-only` is the right thing until the day main is force-pushed.
# Squashing this repo's history for release did exactly that, and every laptop
# that had already cloned it was left with no common ancestor:
#
#   + ba63a85...f3dab3a main -> origin/main (forced update)
#   fatal: Not possible to fast-forward, aborting.
#
# Under `set -e` in bootstrap that killed the run at step 2/9, on a machine
# that could then never update itself again -- the repair and the thing needing
# repair were the same checkout.
#
# This checkout is a mirror of origin. Nothing is meant to be committed here,
# so resetting onto the new history is the correct repair rather than a
# destructive one. The single case where it would destroy something is a dirty
# worktree, and that stops instead.
set -uo pipefail

REPO_DIR="${1:-${REPO_DIR:-$HOME/.local/share/omarchy-setup}}"
git() { command git -C "$REPO_DIR" "$@"; }

[ -d "$REPO_DIR/.git" ] || { echo "no git checkout at $REPO_DIR"; exit 1; }

git fetch --quiet --prune origin \
  || { echo "could not reach origin; leaving $REPO_DIR alone"; exit 1; }

BRANCH="$(git symbolic-ref --short HEAD 2>/dev/null || echo main)"
UPSTREAM="$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null)"
UPSTREAM="${UPSTREAM:-origin/$BRANCH}"
git rev-parse --verify --quiet "$UPSTREAM" >/dev/null \
  || { echo "$UPSTREAM does not exist on origin"; exit 1; }

# The ordinary case, and the only one that should ever happen.
if git merge --ff-only --quiet "$UPSTREAM" 2>/dev/null; then
  exit 0
fi

if [ -n "$(git status --porcelain)" ]; then
  echo "$REPO_DIR cannot fast-forward to $UPSTREAM and has uncommitted changes."
  echo "Nothing was touched. Commit, stash or discard them, then run this again."
  exit 1
fi

echo "$UPSTREAM has a history $REPO_DIR cannot fast-forward to (rewritten upstream)."
echo "This checkout mirrors origin, so it is being reset onto it."
LOCAL_ONLY="$(git log --oneline "$UPSTREAM..HEAD" 2>/dev/null | head -20)"
if [ -n "$LOCAL_ONLY" ]; then
  echo "Commits left behind, recoverable from 'git -C $REPO_DIR reflog':"
  echo "$LOCAL_ONLY" | sed 's/^/  /'
fi
git reset --hard --quiet "$UPSTREAM" || { echo "reset failed"; exit 1; }
echo "reset to $(git log --oneline -1)"
