# shellcheck shell=bash
# Ported from the Mac's ~/.zsh.d/aliases.zsh. Anything already defined in
# 10-env.sh (ls, ll, cat, k, lg, tf) is deliberately not repeated here.

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias la='ls -A'

alias nr='npm run'

# Git. The Mac gets most of these from oh-my-zsh's git plugin, which Omarchy has
# no equivalent for, so the handful actually used daily are spelled out.
alias gst='git status'
alias gco='git checkout'
alias gp='git push'
alias gpl='git pull'
alias gd='git diff'
alias gl='git log --oneline --graph --decorate -20'

# Jumps. On the laptops repos live at ~/Projects/<org>/<repo> (see 20-projects.sh),
# so the Mac's `dev` -> ~/Projects/Development has no counterpart; `proj` fuzzy-jumps.
alias p='cd "$HOME/Projects"'

# Edit shell config. The Mac's zshconfig/zshcustom, in bash terms.
alias bashconfig='${EDITOR:-nvim} "$HOME/.bashrc"'
alias bashcustom='${EDITOR:-nvim} "$HOME/.bashrc.d"'

# Conditional, so a machine missing one of these still gets a clean shell.
command -v btop      >/dev/null 2>&1 && alias bt='btop'
command -v htop      >/dev/null 2>&1 && alias ht='htop'
command -v prettyping >/dev/null 2>&1 && alias ping='prettyping'
command -v gh        >/dev/null 2>&1 && { alias ghpr='gh pr list'; alias ghprc='gh pr create'; }
command -v multipass >/dev/null 2>&1 && alias mp='multipass'

# A sourced file returns the status of its last command. The line above is a
# conditional, so on a machine without multipass this file would return non-zero
# and anything sourcing it with `set -e` would abort.
:
