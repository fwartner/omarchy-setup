#!/usr/bin/env bash
# kubectl / helm as clients for the shared cluster. kubeconfig comes from the
# vault item "kubeconfig-shared" (notes field holds the full YAML, or attach it).
set -euo pipefail

sudo omarchy-pkg-add kubectl helm k9s kubectx

mkdir -p "$HOME/.kube"
chmod 700 "$HOME/.kube"
if [ ! -s "$HOME/.kube/config" ]; then
  if rbw get --field notes kubeconfig-shared >/dev/null 2>&1; then
    rbw get --field notes kubeconfig-shared > "$HOME/.kube/config"
    chmod 600 "$HOME/.kube/config"
    echo "kubeconfig written from vault"
  else
    echo "vault item kubeconfig-shared missing; copy kubeconfig manually to ~/.kube/config"
  fi
fi

# krew + a couple of useful plugins (optional)
if ! kubectl krew version >/dev/null 2>&1; then
  yay -S --needed --noconfirm krew-bin || true
fi

kubectl version --client
helm version
