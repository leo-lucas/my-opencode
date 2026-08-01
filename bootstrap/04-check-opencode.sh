#!/usr/bin/env bash

check_opencode() {
    header "Verificando OpenCode"

    if command -v opencode &>/dev/null; then
        ok "OpenCode: $(opencode --version 2>/dev/null || echo 'unknown')"
    else
        error "OpenCode não encontrado"
        return 1
    fi

    if [[ -d /home/dev/.config/opencode ]]; then
        ok "OpenCode config montado em ~/.config/opencode"

        if [[ -f /home/dev/.config/opencode/opencode.json || -f /home/dev/.config/opencode/opencode.jsonc ]]; then
            info "opencode.json/opencode.jsonc encontrado"
        else
            warn "opencode.json não encontrado em ~/.config/opencode"
            info "Monte o volume ~/.config/opencode:/home/dev/.config/opencode"
        fi
    else
        info "OpenCode config não montado (~/.config/opencode)"
        info "Monte o volume ~/.config/opencode:/home/dev/.config/opencode"
    fi
}
