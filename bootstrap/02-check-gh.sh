#!/usr/bin/env bash

check_gh() {
    header "Verificando GitHub CLI"

    if command -v gh &>/dev/null; then
        ok "GitHub CLI: $(gh version 2>/dev/null | head -1 || echo 'unknown')"
    else
        error "GitHub CLI não encontrado"
        return 1
    fi

    # Check for mounted config
    if [[ -f /home/dev/.config/gh/hosts.yml ]]; then
        local user
        user=$(gh api user --jq .login 2>/dev/null || echo 'unknown')
        if [[ "$user" != "unknown" ]]; then
            ok "Autenticado como: $user"
        else
            warn "hosts.yml encontrado mas autenticação falhou"
        fi
    else
        info "GitHub auth não montado (~/.config/gh)"
        info "Use 'gh auth login' ou monte o volume ~/.config/gh"
    fi
}
