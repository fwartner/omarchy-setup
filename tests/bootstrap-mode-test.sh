#!/usr/bin/env bash
# Self-check for bootstrap.sh's install-vs-update decision.
#
#   ./tests/bootstrap-mode-test.sh
#
# Getting this wrong is expensive in both directions: delegate too eagerly and a
# half-finished machine never finishes installing; delegate never and the one
# command people actually remember stops updating anything. Neither shows up
# until someone is sitting in front of a laptop, so it is checked here instead.
#
# Everything steps 0-2 shell out to is a shim on PATH, so this runs anywhere.
# Steps 3-9 are unreachable from the update path and are not faked -- the
# install case asserts only that it got past the branch.
set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SELF_DIR/../bootstrap.sh"

pass=0; fail=0
eq() {
  if [ "$2" = "$3" ]; then pass=$((pass+1));
  else fail=$((fail+1)); printf '  ✘ %s\n     want: %s\n     got:  %s\n' "$1" "$3" "$2"; fi
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
MARKER="$TMP/home/.local/state/omarchy-setup-bootstrapped"

# --- a checkout shaped like a bootstrapped machine's ------------------------
git init -q --bare "$TMP/origin.git"
git clone -q "$TMP/origin.git" "$TMP/repo" 2>/dev/null
git -C "$TMP/repo" checkout -q -b main 2>/dev/null || true
mkdir -p "$TMP/repo/scripts"
for s in update-all verify; do
  printf '#!/bin/sh\necho "%s ran" >> "%s/calls"\n' "$s" "$TMP" > "$TMP/repo/scripts/$s.sh"
  chmod +x "$TMP/repo/scripts/$s.sh"
done
git -C "$TMP/repo" add -A
git -C "$TMP/repo" -c user.email=t@t -c user.name=t commit -qm init
git -C "$TMP/repo" push -q -u origin main

# --- shims for everything steps 0-2 reach for -------------------------------
mkdir -p "$TMP/bin"
cat > "$TMP/bin/sudo" <<EOF
#!/bin/sh
echo "sudo \$*" >> "$TMP/calls"
# -v primes the keep-alive and -n refreshes it; both succeed silently. Anything
# else is a package install, recorded above rather than run.
case "\$1" in -v|-n) exit 0 ;; esac
EOF
printf '#!/bin/sh\nexit 0\n' > "$TMP/bin/omarchy"
printf '#!/bin/sh\necho "pkg-add $*" >> "%s/calls"\n' "$TMP" > "$TMP/bin/omarchy-pkg-add"
printf '#!/bin/sh\necho "chezmoi $*" >> "%s/calls"\n' "$TMP" > "$TMP/bin/chezmoi"
chmod +x "$TMP/bin"/*
# Shims first, then the real system paths for git, coreutils and the like. Only
# the mutating commands need faking; everything else may as well be genuine.
FAKE_PATH="$TMP/bin:/usr/bin:/bin"

ARGS=()
RUN_N=0
run() {
  : > "$TMP/calls"
  RUN_N=$((RUN_N + 1))
  # Redirected to a file, not captured in $( ): the sudo keep-alive subshell
  # inherits stdout and outlives the script, so a command substitution would
  # block on it for the length of its sleep.
  env -i HOME="$TMP/home" PATH="$FAKE_PATH" REPO_DIR="$TMP/repo" "$@" \
    "${BASH:-/bin/bash}" "$SCRIPT" ${ARGS[@]+"${ARGS[@]}"} > "$TMP/out" 2>&1
  local rc=$?
  # Kept so a failure here is diagnosable from a CI log, which is the only
  # place some of these differences show up.
  { printf '\n--- run %d (rc=%d, args: %s) ---\n' "$RUN_N" "$rc" "${ARGS[*]:-none}"
    cat "$TMP/out"; } >> "$TMP/transcript"
  echo "$rc"
}

echo "no marker: installs"
mkdir -p "$TMP/home"
run >/dev/null
# Step 3/9 is the first step past the branch. Reaching it means it installed.
eq "did not delegate"     "$(grep -c 'update-all ran' "$TMP/calls")"   "0"
eq "got past the branch"  "$(grep -c 'chezmoi init' "$TMP/calls")"     "1"

echo "marker present: updates"
mkdir -p "$(dirname "$MARKER")"; echo '2026-01-01T00:00:00Z abc1234' > "$MARKER"
RC="$(run)"
eq "exit 0"               "$RC"                                        "0"
eq "ran the updater"      "$(grep -c 'update-all ran' "$TMP/calls")"   "1"
eq "then verified"        "$(grep -c 'verify ran' "$TMP/calls")"       "1"
eq "skipped install"      "$(grep -c 'chezmoi init' "$TMP/calls")"     "0"
eq "said why"             "$(grep -c 'updating instead' "$TMP/out")"   "1"
eq "quoted the marker"    "$(grep -c 'abc1234' "$TMP/out")"            "1"
eq "named the escape"     "$(grep -c 'bootstrap.sh --full' "$TMP/out")" "1"

echo "steps 0-2 still run before delegating"
# Placed after them on purpose: sudo has to be cached or the updater's `sudo -n`
# package reconcile silently skips, and the checkout has to be current or it
# hands off to a stale updater.
eq "primed sudo"          "$(grep -c '^sudo -v' "$TMP/calls")"         "1"
eq "installed base tools" "$(grep -c 'pkg-add chezmoi rbw git' "$TMP/calls")" "1"
eq "pulled the repo"      "$(grep -c 'Already up to date' "$TMP/out")" "1"

echo "--full overrides the marker"
ARGS=(--full)
run >/dev/null
eq "installed anyway"     "$(grep -c 'chezmoi init' "$TMP/calls")"     "1"
eq "did not delegate"     "$(grep -c 'update-all ran' "$TMP/calls")"   "0"

echo "FULL_BOOTSTRAP=1 is the same switch"
# Documented alongside the other overrides, and the only form that survives
# `curl ... | bash`, which has nowhere to put an argument.
ARGS=()
run FULL_BOOTSTRAP=1 >/dev/null
eq "installed anyway"     "$(grep -c 'chezmoi init' "$TMP/calls")"     "1"

if [ "$fail" -gt 0 ]; then
  echo
  echo "=== git $(git --version | awk '{print $3}'), bash ${BASH_VERSION%%(*} ==="
  echo "=== what bootstrap.sh actually printed ==="
  cat "$TMP/transcript"
fi

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
