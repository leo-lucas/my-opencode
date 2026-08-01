#!/usr/bin/env bash

check_ssh() {
    header "Verificando SSH"

    if [[ -d /home/dev/.ssh ]]; then
        local keys
        keys=$(find /home/dev/.ssh -maxdepth 1 -name "id_*" ! -name "*.pub" 2>/dev/null | wc -l)
        local hosts
        hosts=0
        if [[ -f /home/dev/.ssh/known_hosts ]]; then
            hosts=$(wc -l < /home/dev/.ssh/known_hosts 2>/dev/null || echo 0)
        fi

        if [[ $keys -gt 0 ]]; then
            ok "Chaves SSH: $keys"
        else
            warn "Nenhuma chave SSH encontrada em ~/.ssh"
            info "Monte ~/.ssh como volume para autenticação SSH"
        fi

        if [[ $hosts -gt 0 ]]; then
            ok "Hosts conhecidos: $hosts"
        fi
    else
        info "SSH config não montado (~/.ssh)"
        info "Monte o volume ~/.ssh:/home/dev/.ssh para autenticação SSH"
    fi

    # Check SSH agent
    if [[ -S "${SSH_AUTH_SOCK:-}" ]]; then
        ok "SSH Agent conectado: ${SSH_AUTH_SOCK}"
    else
        info "SSH Agent não conectado"
        info "Monte o socket do SSH agent:"
        echo -e "  volumes:"
        echo -e "    - \${SSH_AUTH_SOCK:-/run/user/\$(id -u)/ssh.sock}:/tmp/ssh-auth.sock"
        echo -e "  environment:"
        echo -e "    - SSH_AUTH_SOCK=/tmp/ssh-auth.sock"
    fi
}
