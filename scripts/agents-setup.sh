#!/usr/bin/env bash
# Claude Code, Codex CLI, gh, and MCP wiring. Dotfiles (settings.json,
# config.toml) are already applied by chezmoi; this script only installs
# binaries and does the token-based logins that can come from the vault.
set -euo pipefail

have() { command -v "$1" >/dev/null 2>&1; }

# mise provides node; make sure it is on PATH for this shell
eval "$(mise activate bash 2>/dev/null || true)"

# --- Claude Code ------------------------------------------------------------
# Omarchy installs Claude Code when chosen as default agent on first boot.
if ! have claude; then
  # omarchy-install-agent does not exist. `omarchy-default-agent --install`
  # installs a coding agent and makes it the default; claude is in its arg list.
  # Note omarchy-install-ai-claude is the Claude *desktop app*, not Claude Code.
  omarchy-default-agent --install claude 2>/dev/null \
    || curl -fsSL https://claude.ai/install.sh | bash
fi

# --- Codex CLI --------------------------------------------------------------
if ! have codex; then
  omarchy-default-agent --install codex 2>/dev/null \
    || npm install -g @openai/codex
fi

# --- GitHub CLI --------------------------------------------------------------
if ! have gh; then
  sudo omarchy-pkg-add github-cli
fi
if ! gh auth status >/dev/null 2>&1; then
  # Vault item "github-token-laptops": a fine-grained PAT for the your-github-user account
  if rbw get github-token-laptops >/dev/null 2>&1; then
    rbw get github-token-laptops | gh auth login --with-token
    gh auth setup-git
  else
    echo "no github-token-laptops in vault; run 'gh auth login' manually"
  fi
fi

# --- MCP servers for Claude Code (user scope, shared across projects) --------
if have claude; then
  # AFFiNE notes (self-hosted). URL + token from vault item "affine-mcp".
  if rbw get affine-mcp >/dev/null 2>&1; then
    AFFINE_URL="$(rbw get --field url affine-mcp)"
    AFFINE_TOKEN="$(rbw get affine-mcp)"
    claude mcp remove affine -s user >/dev/null 2>&1 || true
    claude mcp add --transport http affine "$AFFINE_URL" -s user \
      --header "Authorization: Bearer $AFFINE_TOKEN" || true
  fi
  # Home Assistant (over the mesh). Token from vault item "homeassistant-mcp".
  if rbw get homeassistant-mcp >/dev/null 2>&1; then
    HA_URL="$(rbw get --field url homeassistant-mcp)"
    HA_TOKEN="$(rbw get homeassistant-mcp)"
    claude mcp remove home-assistant -s user >/dev/null 2>&1 || true
    claude mcp add --transport sse home-assistant "$HA_URL/mcp_server/sse" -s user \
      --header "Authorization: Bearer $HA_TOKEN" || true
  fi
  # Context7 docs
  claude mcp remove context7 -s user >/dev/null 2>&1 || true
  claude mcp add --transport http context7 https://mcp.context7.com/mcp -s user || true
  # Sentry (OAuth on first use), Linear (OAuth), GitHub (uses gh token), Playwright (local)
  claude mcp remove sentry -s user >/dev/null 2>&1 || true
  claude mcp add --transport http sentry https://mcp.sentry.dev/mcp -s user || true
  claude mcp remove linear -s user >/dev/null 2>&1 || true
  claude mcp add --transport http linear https://mcp.linear.app/mcp -s user || true
  claude mcp remove github -s user >/dev/null 2>&1 || true
  if gh auth token >/dev/null 2>&1; then
    claude mcp add --transport http github https://api.githubcopilot.com/mcp/ -s user \
      --header "Authorization: Bearer $(gh auth token)" || true
  fi
  claude mcp remove playwright -s user >/dev/null 2>&1 || true
  claude mcp add playwright -s user -- npx -y @playwright/mcp@latest || true
fi

# --- OpenCode (AUR opencode-bin) — config from chezmoi points at FreeLLM ----
have opencode || echo "opencode not found (AUR opencode-bin should have installed it)"

# --- Hermes Agent: CLI/client only, no daemon on laptops -------------------
if ! have hermes; then
  curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash || true
fi

# --- herdr integrations (agent state detection) ----------------------------
if have herdr; then
  for a in claude codex opencode hermes; do herdr integration install "$a" >/dev/null 2>&1 || true; done
fi

echo "agents installed. Interactive logins still needed: 'claude' and 'codex login'."
