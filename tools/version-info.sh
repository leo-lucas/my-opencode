#!/usr/bin/env bash
# ── Version info tool ──────────────────────────────────────────────

set -euo pipefail

echo "AI Workstation"
echo "==============="
echo ""
echo "Tools:"
for cmd in git gh opencode zsh tmux starship eza bat fd rg fzf zoxide lazygit docker kubectl helm node python3 bun uv pnpm npm yarn jq yq; do
    if command -v "$cmd" &>/dev/null; then
        version=$($cmd --version 2>/dev/null | head -1 || echo "installed")
        echo "  ✓ $cmd: $version"
    else
        echo "  ✗ $cmd: not found"
    fi
done
