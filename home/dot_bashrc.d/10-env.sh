# shellcheck shell=bash
export EDITOR=nvim
export VISUAL=code
export PATH="$HOME/.local/bin:$HOME/.krew/bin:$HOME/.config/composer/vendor/bin:$PATH"

# mise (Omarchy's runtime manager)
command -v mise >/dev/null && eval "$(mise activate bash)"
# zoxide
command -v zoxide >/dev/null && eval "$(zoxide init bash)"
# starship prompt (replaces Omarchy's PS1)
command -v starship >/dev/null && eval "$(starship init bash)"
# atuin history (keeps ctrl-r; up-arrow stays native)
command -v atuin >/dev/null && eval "$(atuin init bash --disable-up-arrow)"
# television fuzzy finder keybindings (ctrl-t files, ctrl-g git, alt-a env)
command -v tv >/dev/null && eval "$(tv init bash)"

alias ls='eza --group-directories-first'
alias ll='eza -l --git --group-directories-first'
alias cat='bat --paging=never'
alias k=kubectl
alias lg=lazygit
alias om='omarchy'
alias redis-cli='valkey-cli'
alias tf=tofu

# yazi: cd to the directory you quit in
y() {
  local tmp cwd; tmp="$(mktemp -t yazi-cwd.XXXXXX)"
  yazi "$@" --cwd-file="$tmp"
  if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then cd -- "$cwd" || return; fi
  rm -f -- "$tmp"
}

# cheat.sh
cht() { curl -s "https://cht.sh/$*"; }

# Ported from the Mac's ~/.zsh.d/exports.zsh. Herd, NVM-under-Herd, Fastlane and
# the Antigravity PATH are macOS-only and deliberately absent.
[ -f "$HOME/.env.local" ] && . "$HOME/.env.local"
export BAT_THEME="${BAT_THEME:-base16}"
export DIRENV_LOG_FORMAT=""

# Errors go to the self-hosted GlitchTip (Sentry-API compatible), not sentry.io.
# sentry-cli defaults to sentry.io when this is unset, so a release upload would
# silently go to the wrong place. Token is in the vault item `sentry-token`.
#
# Deliberately the PUBLIC host, unlike every other *.intern service here: the
# errors.intern ingress sits behind the Pocket ID forward-auth middleware
# (glitchtip-pocketid-glitchtip@kubernetescrd), which is interactive SSO. A CLI
# holding a bearer token gets 401 from the proxy before GlitchTip ever sees the
# request. errors.example.com answers /api/0/ directly.
export SENTRY_URL="${SENTRY_URL:-https://errors.example.com}"
