#!/usr/bin/env bash
# Self-check for scripts/self-update.sh, against real git, fully offline.
#
#   ./tests/self-update-test.sh
#
# The case that matters is the one that bit a laptop: origin's history was
# rewritten, so the clone had no common ancestor and `git pull --ff-only` said
#   fatal: Not possible to fast-forward, aborting.
# Under `set -e` that ended bootstrap at step 2/9 and the machine could never
# update itself again. The repair must therefore survive it, and must still
# refuse when a dirty worktree means resetting would destroy something.
set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SELF_DIR/../scripts/self-update.sh"

pass=0; fail=0
eq() {
  if [ "$2" = "$3" ]; then pass=$((pass+1));
  else fail=$((fail+1)); printf '  ✘ %s\n     want: %s\n     got:  %s\n' "$1" "$3" "$2"; fi
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

git init -q --bare "$TMP/origin.git"
seed() {  # a fresh origin history and a clone of it
  rm -rf "$TMP/origin.git" "$TMP/clone" "$TMP/rewrite"
  git init -q --bare "$TMP/origin.git"
  git init -q "$TMP/rewrite"; git -C "$TMP/rewrite" checkout -q -b main
  echo one > "$TMP/rewrite/f"; git -C "$TMP/rewrite" add -A; git -C "$TMP/rewrite" commit -qm one
  git -C "$TMP/rewrite" remote add origin "$TMP/origin.git"
  git -C "$TMP/rewrite" push -q -u origin main
  git clone -q "$TMP/origin.git" "$TMP/clone"
}
seed
at() { git -C "$1" log --oneline -1 | cut -d' ' -f2-; }

echo "already current"
OUT="$(bash "$SCRIPT" "$TMP/clone" 2>&1)"; rc=$?
eq "exit 0"          "$rc"                  "0"
eq "said nothing"    "$OUT"                 ""
eq "still on one"    "$(at "$TMP/clone")"   "one"

echo "ordinary fast-forward"
echo two > "$TMP/rewrite/f"; git -C "$TMP/rewrite" commit -qam two
git -C "$TMP/rewrite" push -q origin main
OUT="$(bash "$SCRIPT" "$TMP/clone" 2>&1)"; rc=$?
eq "exit 0"          "$rc"                  "0"
eq "fast-forwarded"  "$(at "$TMP/clone")"   "two"
eq "quiet about it"  "$OUT"                 ""

echo "origin's history was rewritten"
# What squashing this repo for release did: a new root commit, force-pushed.
rm -rf "$TMP/rewrite"
git init -q "$TMP/rewrite"; git -C "$TMP/rewrite" checkout -q -b main
echo rewritten > "$TMP/rewrite/f"
git -C "$TMP/rewrite" add -A; git -C "$TMP/rewrite" commit -qm squashed
git -C "$TMP/rewrite" remote add origin "$TMP/origin.git"
git -C "$TMP/rewrite" push -q --force origin main
# Proof the old path really does die here, so this test is not guarding a myth.
# git exits 128 (fatal), not 1 -- asserted as "not zero" so a git release that
# renumbers it does not fail this for the wrong reason.
git -C "$TMP/clone" pull --ff-only >/dev/null 2>&1
eq "pull --ff-only fails"  "$([ "$?" -ne 0 ] && echo yes || echo no)" "yes"
OUT="$(bash "$SCRIPT" "$TMP/clone" 2>&1)"; rc=$?
eq "exit 0"                "$rc"                             "0"
eq "landed on the new root" "$(at "$TMP/clone")"             "squashed"
eq "content is right"      "$(cat "$TMP/clone/f")"           "rewritten"
eq "explained itself"      "$(printf '%s\n' "$OUT" | grep -c 'rewritten upstream')" "1"
eq "named the reflog"      "$(printf '%s\n' "$OUT" | grep -c 'reflog')" "1"

echo "refuses to discard uncommitted work"
seed
rm -rf "$TMP/rewrite"; git init -q "$TMP/rewrite"; git -C "$TMP/rewrite" checkout -q -b main
echo other > "$TMP/rewrite/f"; git -C "$TMP/rewrite" add -A
git -C "$TMP/rewrite" commit -qm unrelated
git -C "$TMP/rewrite" remote add origin "$TMP/origin.git"
git -C "$TMP/rewrite" push -q --force origin main
echo 'work in progress' > "$TMP/clone/f"
BEFORE="$(at "$TMP/clone")"
OUT="$(bash "$SCRIPT" "$TMP/clone" 2>&1)"; rc=$?
eq "exit 1"                "$rc"                             "1"
eq "kept the work"         "$(cat "$TMP/clone/f")"           "work in progress"
eq "did not move HEAD"     "$(at "$TMP/clone")"              "$BEFORE"
eq "said why"              "$(printf '%s\n' "$OUT" | grep -c 'uncommitted changes')" "1"

echo "unreachable origin leaves the checkout alone"
rm -rf "$TMP/origin.git"
BEFORE="$(at "$TMP/clone")"
OUT="$(bash "$SCRIPT" "$TMP/clone" 2>&1)"; rc=$?
eq "exit 1"                "$rc"                             "1"
eq "did not move HEAD"     "$(at "$TMP/clone")"              "$BEFORE"
eq "said so"               "$(printf '%s\n' "$OUT" | grep -c 'could not reach origin')" "1"

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
