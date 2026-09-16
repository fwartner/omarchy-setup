#!/usr/bin/env bash
# Self-check for scripts/skills-setup.sh against real git, fully offline.
#
#   ./tests/skills-test.sh
#
# The part worth testing is what the script refuses to touch. It writes into
# ~/.claude/skills, a directory the user and chezmoi also write into, so
# clobbering something there loses work that is in no repo.
set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SELF_DIR/../scripts/skills-setup.sh"

pass=0; fail=0
eq() {
  if [ "$2" = "$3" ]; then pass=$((pass+1));
  else fail=$((fail+1)); printf '  ✘ %s\n     want: %s\n     got:  %s\n' "$1" "$3" "$2"; fi
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --- an upstream repo of skills, shaped like michaelshimeles/skills ---------
mkdir -p "$TMP/upstream"/{alpha,beta,tests}
echo '# alpha' > "$TMP/upstream/alpha/SKILL.md"
echo '# beta'  > "$TMP/upstream/beta/SKILL.md"
echo 'print()' > "$TMP/upstream/tests/test_thing.py"   # no SKILL.md: not a skill
echo '# readme' > "$TMP/upstream/README.md"
git -C "$TMP/upstream" init -q
git -C "$TMP/upstream" add -A
git -C "$TMP/upstream" commit -qm init

cat > "$TMP/skills.txt" <<EOF
# a comment
skills  file://$TMP/upstream
plugin  demo@nowhere  some/marketplace
EOF

# A PATH holding only what the script uses, so "claude is not installed yet"
# is the state under test rather than a property of the machine running this.
mkdir -p "$TMP/bin"
for b in git basename dirname mkdir ln readlink sed awk; do
  ln -sf "$(command -v "$b")" "$TMP/bin/$b"
done

CLONE="$TMP/clones/$(basename "$TMP")-upstream"

run() {
  env -i HOME="$TMP/home" PATH="${1:-$TMP/bin}" \
    SKILLS_MANIFEST="$TMP/skills.txt" \
    SKILLS_CLONE_DIR="$TMP/clones" \
    CLAUDE_SKILLS_DIR="$TMP/skills" \
    /bin/bash "$SCRIPT" 2>&1
}

echo "first run"
OUT="$(run)"
eq "linked alpha"          "$(readlink "$TMP/skills/alpha")"        "$CLONE/alpha"
eq "linked beta"           "$(readlink "$TMP/skills/beta")"         "$CLONE/beta"
eq "skipped non-skill dir" "$(test -e "$TMP/skills/tests" && echo yes || echo no)" "no"
eq "skipped plain file"    "$(test -e "$TMP/skills/README.md" && echo yes || echo no)" "no"
eq "skipped the plugin"    "$(printf '%s\n' "$OUT" | grep -c 'skipped demo@nowhere')" "1"
eq "reported no failures"  "$(printf '%s\n' "$OUT" | grep -c FAILED)" "0"

echo "re-run is a no-op"
OUT="$(run)"
eq "still linked"          "$(readlink "$TMP/skills/alpha")"        "$CLONE/alpha"
eq "fetched, not recloned" "$(printf '%s\n' "$OUT" | grep -c 'updated .*-upstream')" "1"

echo "picks up an upstream addition"
mkdir -p "$TMP/upstream/gamma"; echo '# gamma' > "$TMP/upstream/gamma/SKILL.md"
git -C "$TMP/upstream" add -A && git -C "$TMP/upstream" commit -qm gamma
run >/dev/null
eq "linked the new skill"  "$(readlink "$TMP/skills/gamma")"        "$CLONE/gamma"

echo "leaves what it did not create"
# A skill the user wrote by hand, and one symlinked in from somewhere else.
rm "$TMP/skills/alpha" "$TMP/skills/beta"
mkdir -p "$TMP/skills/alpha"; echo 'mine' > "$TMP/skills/alpha/SKILL.md"
mkdir -p "$TMP/elsewhere/beta"; ln -s "$TMP/elsewhere/beta" "$TMP/skills/beta"
OUT="$(run)"
eq "kept the real directory" "$(cat "$TMP/skills/alpha/SKILL.md")"  "mine"
eq "kept the foreign link"   "$(readlink "$TMP/skills/beta")"       "$TMP/elsewhere/beta"
eq "said so, twice"          "$(printf '%s\n' "$OUT" | grep -c 'kept')" "2"

echo "plugin entries reach the claude CLI"
mkdir -p "$TMP/bin-claude"
ln -sf "$TMP/bin"/* "$TMP/bin-claude/"
cat > "$TMP/bin-claude/claude" <<EOF
#!/bin/sh
echo "\$@" >> "$TMP/claude.log"
EOF
chmod +x "$TMP/bin-claude/claude"
run "$TMP/bin-claude:$TMP/bin" >/dev/null
eq "added the marketplace" "$(grep -c '^plugin marketplace add some/marketplace$' "$TMP/claude.log")" "1"
eq "installed user-scoped" "$(grep -c '^plugin install demo@nowhere -s user -y$' "$TMP/claude.log")" "1"
eq "then updated it"       "$(grep -c '^plugin update demo@nowhere$' "$TMP/claude.log")" "1"

echo "survives an unreachable source"
printf 'skills  file://%s/does-not-exist\n' "$TMP" >> "$TMP/skills.txt"
OUT="$(run)"; rc=$?
eq "exit 0 anyway"         "$rc" "0"
eq "reported the failure"  "$(printf '%s\n' "$OUT" | grep -c 'FAILED')" "1"
eq "kept working repos"    "$(readlink "$TMP/skills/gamma")"        "$CLONE/gamma"

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
