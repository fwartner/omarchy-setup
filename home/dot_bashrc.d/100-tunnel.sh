# shellcheck shell=bash
# Burrow is the default for exposing a local port — https://useburrow.dev/docs
#
#   tunnel http 3000     usage as burrow documents it: PROTOCOL PORT
#   tunnel 3000          shorthand, assumes http
#
# Run through npx rather than installed: the client is Node-native and versioned
# per invocation, so there is no package to keep in step with the service.
tunnel() {
  case "${1:-}" in
    "")            echo "Usage: tunnel [protocol] <port>   e.g. tunnel http 3000" >&2; return 1 ;;
    *[!0-9]*)      npx -y useburrow "$@" ;;          # protocol given explicitly
    *)             npx -y useburrow http "$1" ;;     # bare port -> http
  esac
}
