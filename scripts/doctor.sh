#!/usr/bin/env bash

# ── Doctor script ──────────────────────────────────────────────────
# Health check command: doctor

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m'

passed=0
failed=0
warn=0

check() {
    local name="$1"
    shift
    if "$@" &>/dev/null; then
        local version
        version="$("$@" 2>&1 | head -1)" || version=""
        if [[ ${#version} -gt 60 ]]; then
            version="${version:0:60}..."
        fi
        echo -e "${GREEN}✓${NC} ${name}: ${version}"
        ((passed+=1))
    else
        echo -e "${RED}✗${NC} ${name}: não encontrado"
        ((failed+=1))
    fi
}

partial() {
    local name="$1"
    shift
    if "$@" &>/dev/null; then
        echo -e "${GREEN}✓${NC} ${name}"
        ((passed+=1))
    else
        echo -e "${YELLOW}!${NC} ${name}: problema parcial"
        ((warn+=1))
    fi
}

header() {
    echo -e "\n${BOLD}=== $* ===${NC}\n"
}

doctor() {
    header "AI Workstation Doctor"

    # Core tools
    check "Git" git --version
    check "GitHub CLI" gh version
    check "OpenCode" opencode --version
    check "Zsh" zsh --version
    check "Starship" starship --version
    check "Tmux" tmux -V
    check "Lazygit" lazygit --version
    check "Neovim" nvim --version
    check "SSH" ssh -V 2>&1 | head -1

    # Navigation
    check "Eza" eza --version
    check "Bat" bat --version
    check "Fd" fd --version
    check "Ripgrep" rg --version
    check "Fzf" fzf --version
    check "Zoxide" zoxide --version
    check "Delta" delta --version

    # Docker
    check "Docker CLI" docker --version
    partial "Docker Socket" bash -c "test -S /var/run/docker.sock && docker info" 2>/dev/null
    check "Docker Compose" docker compose version

    # Kubernetes
    check "Kubectl" kubectl version --client -o yaml
    check "Helm" helm version --short

    # Languages
    check "Node" node --version
    check "Python" python3 --version
    check "Bun" bun --version
    check "uv" uv --version
    check "pnpm" pnpm --version
    check "npm" npm --version
    check "yarn" yarn --version

    header "Resumo"
    echo -e "  ${GREEN}Passou: $passed${NC}"
    if [[ $warn -gt 0 ]]; then
        echo -e "  ${YELLOW}Aviso: $warn${NC}"
    fi
    if [[ $failed -gt 0 ]]; then
        echo -e "  ${RED}Falhou: $failed${NC}"
        return 1
    fi
    echo -e "  ${GREEN}Todos os checks passaram!${NC}\n"
}

doctor "$@"
