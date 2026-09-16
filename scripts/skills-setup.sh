#!/usr/bin/env bash
# Install the coding-agent skills listed in packages/skills.txt.
#
#   ./scripts/skills-setup.sh
#
# Runs at bootstrap and again on every daily update, so it has to be safe to
# re-run: plugins install-then-update (both no-ops when current), clones are
# hard-reset to the fetched head, and a symlink is replaced only when it
# already points into our own clone directory.
#
# Skills from a git repo are symlinked rather than copied. A copy would need a
# reconcile step to notice deletions upstream; a symlink farm rebuilt from the
# clone is the same thing for free.
set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="${SKILLS_MANIFEST:-$SELF_DIR/../packages/skills.txt}"
CLONE_DIR="${SKILLS_CLONE_DIR:-$HOME/.local/share/agent-skills}"
SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"

have() { command -v "$1" >/dev/null 2>&1; }

# Link every top-level skill directory of $1 into $SKILLS_DIR.
link_skills() {
  local repo="$1" skill name target
  for skill in "$repo"/*/; do
    skill="${skill%/}"
    # A repo of skills also holds tests, docs and CI config. SKILL.md is what
    # makes a directory a skill; everything else is not ours to link.
    [ -f "$skill/SKILL.md" ] || continue
    name="$(basename "$skill")"
    target="$SKILLS_DIR/$name"
    if [ -L "$target" ]; then
      case "$(readlink "$target")" in
        "$CLONE_DIR"/*) ;;  # one of ours, safe to repoint
        *) printf '    kept   %s (symlink we did not create)\n' "$name"; continue ;;
      esac
    elif [ -e "$target" ]; then
      printf '    kept   %s (real directory)\n' "$name"
      continue
    fi
    # -n so an existing link to a directory is replaced, not followed into.
    ln -sfn "$skill" "$target" && printf '    linked %s\n' "$name"
  done
}

# Clone or refresh $1, then link what it contains.
sync_skills_repo() {
  local url="$1" name dest owner stem
  # <owner>-<repo>, not just <repo>: "skills" is a common enough repo name that
  # two manifest entries would otherwise land in the same directory.
  stem="${url%.git}"; owner="${stem%/*}"
  name="${owner##*/}-${stem##*/}"
  dest="$CLONE_DIR/$name"
  if [ -d "$dest/.git" ]; then
    # fetch + reset rather than pull: this is a read-only cache we never commit
    # into, so there is nothing to merge and a rewritten upstream still lands.
    git -C "$dest" fetch --quiet --depth 1 origin \
      && git -C "$dest" reset --hard --quiet FETCH_HEAD \
      || { printf '  FAILED  %s (fetch)\n' "$name"; return 1; }
    printf '  updated %s\n' "$name"
  else
    mkdir -p "$CLONE_DIR"
    git clone --depth 1 --quiet "$url" "$dest" \
      || { printf '  FAILED  %s (clone)\n' "$name"; return 1; }
    printf '  cloned  %s\n' "$name"
  fi
  link_skills "$dest"
}

# Install $1 (name@marketplace), adding marketplace source $2 first if given.
install_plugin() {
  local spec="$1" market="${2:-}"
  [ -n "$market" ] && claude plugin marketplace add "$market" >/dev/null 2>&1
  if ! claude plugin install "$spec" -s user -y </dev/null >/dev/null 2>&1; then
    printf '  FAILED  %s\n' "$spec"; return 1
  fi
  # install reports an already-installed plugin as success without touching it,
  # so the update is what keeps a laptop current after the first run.
  claude plugin update "$spec" >/dev/null 2>&1 || true
  printf '  ok      %s\n' "$spec"
}

main() {
  [ -f "$MANIFEST" ] || { echo "no skills manifest at $MANIFEST"; return 0; }
  mkdir -p "$SKILLS_DIR"

  local fail=0 kind ref market
  while read -r kind ref market; do
    [ -n "$kind" ] && [ -n "$ref" ] || continue
    case "$kind" in
      plugin)
        if have claude; then
          install_plugin "$ref" "$market" || fail=$((fail + 1))
        else
          printf '  skipped %s (claude not installed)\n' "$ref"
        fi
        ;;
      skills)
        sync_skills_repo "$ref" || fail=$((fail + 1))
        ;;
      *)
        printf '  ignored unknown entry kind: %s\n' "$kind"
        ;;
    esac
  done < <(sed -E 's/#.*//' "$MANIFEST" | awk 'NF')

  [ "$fail" -eq 0 ] || echo "$fail skill source(s) failed; the rest are installed"
  return 0
}

[ "${BASH_SOURCE[0]}" = "$0" ] && main "$@"
