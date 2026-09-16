# shellcheck shell=bash
export EDITOR=nvim
export VISUAL=code
export PATH="$HOME/.local/bin:$PATH"

# mise (Omarchy's runtime manager)
command -v mise >/dev/null && eval "$(mise activate bash)"
# zoxide
command -v zoxide >/dev/null && eval "$(zoxide init bash)"

alias ls='eza --group-directories-first'
alias ll='eza -l --git --group-directories-first'
alias cat='bat --paging=never'
alias k=kubectl
alias lg=lazygit
alias om='omarchy'
