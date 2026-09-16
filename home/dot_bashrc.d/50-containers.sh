# shellcheck shell=bash
# Ported from ~/.zsh.d/docker.zsh. This fleet runs rootless podman; podman-docker
# provides a `docker` command, but these point at podman directly so the aliases
# do not depend on that shim being installed.

alias d='podman'
alias dps='podman ps'
alias dpsa='podman ps -a'
alias di='podman images'
alias dprune='podman system prune -f'
alias dc='podman-compose'
alias dco='podman-compose'
alias dcup='podman-compose up -d'
alias dcdown='podman-compose down'
alias dclogs='podman-compose logs -f'
alias dcexec='podman-compose exec'

dexec() {
  [ -n "${1:-}" ] || { echo "Usage: dexec <container> [cmd]"; return 1; }
  podman exec -it "$1" "${2:-sh}"
}

dstopall() {
  local ids; ids="$(podman ps -q)"
  [ -n "$ids" ] || { echo "No running containers"; return 0; }
  # shellcheck disable=SC2086
  podman stop $ids
}

dclean() { podman system prune -f; }
