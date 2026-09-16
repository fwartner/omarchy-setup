# shellcheck shell=bash
# Ported from ~/.zsh.d/laravel.zsh. Herd is macOS-only, so there is no Herd PATH
# or INI_SCAN_DIR here; php comes from mise and sites run with `php artisan serve`
# or the compose templates in templates/containers/.

alias art='php artisan'
alias a='php artisan'
alias art:migrate='php artisan migrate'
alias art:fresh='php artisan migrate:fresh --seed'
alias art:tinker='php artisan tinker'
alias art:cache='php artisan config:cache && php artisan route:cache && php artisan view:cache'
alias art:clear='php artisan config:clear && php artisan route:clear && php artisan view:clear && php artisan cache:clear'
alias cda='composer dump-autoload'
alias sail='./vendor/bin/sail'

newlaravel() {
  [ -n "${1:-}" ] || { echo "Usage: newlaravel <project-name>"; return 1; }
  composer create-project laravel/laravel "$1" && cd "$1" || return 1
}

laravel-serve() { php artisan serve --port "${1:-8000}"; }
artisan() { php artisan "$@"; }
