# shellcheck shell=bash
# Ported from ~/.zsh.d/infra.zsh.
#
# The Mac has `alias tofu='opentofu'`, which never worked: the OpenTofu binary is
# called `tofu`, and there is no `opentofu` command to alias to. 10-env.sh already
# has the correct `tf=tofu`, so nothing is redefined here.

command -v packer >/dev/null 2>&1 && alias pf='packer'

if command -v tofu >/dev/null 2>&1; then
  tfi() { tofu init "$@"; }
  tfp() { tofu plan "$@"; }
  tfa() { tofu apply "$@"; }
elif command -v terraform >/dev/null 2>&1; then
  tfi() { terraform init "$@"; }
  tfp() { terraform plan "$@"; }
  tfa() { terraform apply "$@"; }
fi
