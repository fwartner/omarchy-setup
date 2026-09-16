#!/usr/bin/env bash
# Sources every ~/.bashrc.d snippet in a clean shell and checks the aliases and
# functions ported from the Mac actually arrive. Catches the failure that would
# otherwise only show up on a laptop: a snippet that errors out halfway and
# silently drops everything below it.
#
#   ./tests/bashrc-test.sh
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.." || exit 1

pass=0; fail=0
have() {
  if alias "$1" >/dev/null 2>&1 || declare -F "$1" >/dev/null 2>&1; then
    pass=$((pass+1))
  else
    fail=$((fail+1)); printf '  ✘ %s is neither an alias nor a function\n' "$1"
  fi
}

# Templates were silently outside this test: the glob was *.sh, so renaming
# 10-env.sh to .tmpl for one value dropped it from coverage without a word, and
# 20-projects.sh.tmpl had never been in it at all. Render them into a temp dir
# with the template actions stubbed -- what is under test here is the shell, not
# the substitution, which the chezmoi CI job renders for real.
SNIPPETS="$(mktemp -d)"
trap 'rm -rf "$SNIPPETS"' EXIT
for f in home/dot_bashrc.d/*.sh; do cp "$f" "$SNIPPETS/$(basename "$f")"; done
for f in home/dot_bashrc.d/*.sh.tmpl; do
  [ -e "$f" ] || continue
  sed -E 's#\{\{[^}]*\}\}#https://rendered.invalid#g' "$f" \
    > "$SNIPPETS/$(basename "$f" .tmpl)"
done

# Each snippet must parse on its own before anything is sourced.
for f in "$SNIPPETS"/*.sh; do
  if bash -n "$f" 2>/dev/null; then pass=$((pass+1))
  else fail=$((fail+1)); printf '  ✘ %s does not parse\n' "$f"; fi
done

set +u
for f in "$SNIPPETS"/*.sh; do
  # shellcheck source=/dev/null
  . "$f" 2>/dev/null || { fail=$((fail+1)); printf '  ✘ %s failed to source\n' "$f"; }
done

# Unconditional ones: these must exist on any machine.
for n in .. ... .... la nr gst gco gp gpl gd gl p bashconfig bashcustom \
         art a art:migrate art:fresh art:tinker art:cache art:clear cda sail \
         newlaravel laravel-serve artisan \
         d dps dpsa di dprune dc dco dcup dcdown dclogs dcexec dexec dstopall dclean \
         reload reload-custom bashconfig-check mkd extract tre json weather ports killport notify \
         tunnel; do
  have "$n"
done

# Containers must point at podman, not docker.
for a in d dc dcup; do
  v="$(alias "$a" 2>/dev/null | sed "s/^alias $a=//;s/'//g")"
  case "$v" in
    podman*) pass=$((pass+1)) ;;
    *) fail=$((fail+1)); printf '  ✘ alias %s is %q, expected podman\n' "$a" "$v" ;;
  esac
done

# 10-env.sh owns these; the ported files must not redefine and fight over them.
dupes="$(grep -hoE "^alias (ll|cat|k|lg|tf)=" "$SNIPPETS"/*.sh | sort | uniq -d)"
if [ -z "$dupes" ]; then pass=$((pass+1)); else fail=$((fail+1)); printf '  ✘ redefined: %s\n' "$dupes"; fi

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
