# shellcheck shell=bash
# Ported from ~/.zsh.d/k8s.zsh. `k` is already aliased in 10-env.sh.
command -v kubectl >/dev/null 2>&1 || return 0

command -v kubectx  >/dev/null 2>&1 && alias kx='kubectx'
command -v kubens   >/dev/null 2>&1 && alias kn='kubens'
command -v minikube >/dev/null 2>&1 && alias mkc='minikube'

kns() {
  [ -n "${1:-}" ] || { echo "Usage: kns <namespace>"; return 1; }
  kubectl config set-context --current --namespace="$1"
}

# First pod name matching a pattern. Usage: kpod <pattern> [namespace]
kpod() {
  [ -n "${1:-}" ] || { echo "Usage: kpod <pattern> [namespace]"; return 1; }
  if [ -n "${2:-}" ]; then
    kubectl get pods -n "$2" -o name | grep -E "$1" | head -1
  else
    kubectl get pods -o name | grep -E "$1" | head -1
  fi
}
