# shellcheck shell=bash
# Ported from ~/.zsh.d/flutter.zsh. Flutter is not in the package manifests --
# it comes from mise or the AUR -- so everything here is guarded.
command -v flutter >/dev/null 2>&1 || return 0

alias f='flutter'
alias fg='flutter pub get'
alias fpg='flutter pub get'
alias fb='flutter build'
alias fr='flutter run'
alias fd='flutter devices'
alias fc='flutter clean'
alias fdoctor='flutter doctor -v'

frun() {
  if [ -n "${1:-}" ]; then flutter run --device-id="$1"; else flutter run; fi
}

fchannel() {
  [ -n "${1:-}" ] || { flutter channel; return; }
  flutter channel "$1" && flutter channel
}

fcreate() {
  [ -n "${1:-}" ] || { echo "Usage: fcreate <project-name>"; return 1; }
  flutter create "$1" && cd "$1" || return 1
}
