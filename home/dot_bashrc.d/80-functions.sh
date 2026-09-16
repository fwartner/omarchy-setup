# shellcheck shell=bash
# Ported from ~/.zsh.d/functions.zsh. The zsh-only and macOS-only parts are
# rewritten rather than copied; each is noted where it differs.

# The Mac's `reload` / `zshreload-custom` / `zshconfig-check`, in bash terms.
# shellcheck source=/dev/null
reload() { . "$HOME/.bashrc" && echo "Bash config reloaded."; }

reload-custom() {
  local f
  for f in "$HOME"/.bashrc.d/*.sh; do
    # shellcheck source=/dev/null
    [ -f "$f" ] && . "$f"
  done
  echo "Custom bash config reloaded (~/.bashrc.d)."
}

bashconfig-check() {
  local err=0 f
  bash -n "$HOME/.bashrc" || err=1
  for f in "$HOME"/.bashrc.d/*.sh; do
    [ -f "$f" ] || continue
    bash -n "$f" || err=1
  done
  [ "$err" -eq 0 ] && echo "All checks passed." || return 1
}

mkd() { mkdir -p "$1" && cd "$1" || return 1; }

extract() {
  [ -f "${1:-}" ] || { echo "Usage: extract <file>"; return 1; }
  case "$1" in
    *.tar.gz|*.tgz)   tar xzf "$1" ;;
    *.tar.bz2|*.tbz2) tar xjf "$1" ;;
    *.tar.xz)         tar xJf "$1" ;;
    *.tar.zst)        tar --zstd -xf "$1" ;;   # common on Arch, absent on the Mac
    *.tar)            tar xf "$1" ;;
    *.zip|*.ZIP)      unzip "$1" ;;
    *.gz)             gunzip -k "$1" ;;
    *.bz2)            bunzip2 -k "$1" ;;
    *.zst)            unzstd "$1" ;;
    *) echo "Unknown archive type: $1"; return 1 ;;
  esac
}

tre() { tree -L "${1:-2}" -a; }

json() {
  command -v jq >/dev/null 2>&1 || { echo "jq not found" >&2; return 1; }
  jq .
}

weather() { curl -s "https://wttr.in/${1:-}"; }

# `ss` is iproute2 and always present on Arch; the Mac version shells out to
# lsof, which is not installed by default here.
ports() {
  if command -v ss >/dev/null 2>&1; then ss -tulpn
  elif command -v lsof >/dev/null 2>&1; then lsof -i -P -n | grep LISTEN
  else echo "neither ss nor lsof found" >&2; return 1
  fi
}

killport() {
  [ -n "${1:-}" ] || { echo "Usage: killport <port>"; return 1; }
  local pids=""
  if command -v lsof >/dev/null 2>&1; then
    pids="$(lsof -ti ":$1" 2>/dev/null)"
  elif command -v fuser >/dev/null 2>&1; then
    pids="$(fuser -n tcp "$1" 2>/dev/null | tr -s ' ' '\n' | grep -E '^[0-9]+$')"
  fi
  [ -n "$pids" ] || { echo "No process listening on port $1"; return 1; }
  echo "Killing process(es) on port $1: $pids"
  # shellcheck disable=SC2086
  kill -9 $pids
}

# The Mac uses terminal-notifier, which does not exist on Linux. Omarchy ships
# libnotify, so this is a desktop notification rather than a no-op.
notify() {
  if command -v notify-send >/dev/null 2>&1; then notify-send "${*:-Done}"
  else echo "${*:-Done}"
  fi
}
