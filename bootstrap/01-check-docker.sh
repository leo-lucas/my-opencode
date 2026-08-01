#!/usr/bin/env bash

check_docker() {
    header "Verificando Docker"

    if command -v docker &>/dev/null; then
        ok "Docker CLI: $(docker --version 2>/dev/null || echo 'unknown')"
    else
        error "Docker CLI não encontrado"
        return 1
    fi

    # Check socket
    if [[ -S /var/run/docker.sock ]]; then
        ok "Docker socket acessível"

        if docker info &>/dev/null; then
            local version
            version=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo 'unknown')
            ok "Docker engine: $version"
        else
            error "Não foi possível conectar ao Docker engine"
            warn "Verifique se /var/run/docker.sock está montado e o usuário tem permissão"
        fi
    else
        error "Docker socket não encontrado em /var/run/docker.sock"
        warn "Monte o socket no docker-compose.yml:"
        echo -e "  volumes:"
        echo -e "    - /var/run/docker.sock:/var/run/docker.sock"
    fi

    # Check docker context
    if command -v docker &>/dev/null && docker info &>/dev/null; then
        local ctx
        ctx=$(docker context show 2>/dev/null || echo 'default')
        ok "Docker context: $ctx"
    fi

    # Check for mounted docker config
    if [[ -d /home/dev/.docker ]]; then
        ok "Docker config montado em ~/.docker"

        # Check for custom contexts
        if [[ -d /home/dev/.docker/contexts ]]; then
            local custom_ctxs
            custom_ctxs=$(ls /home/dev/.docker/contexts/meta/ 2>/dev/null | wc -l)
            if [[ $custom_ctxs -gt 0 ]]; then
                info "Contextos personalizados encontrados: $custom_ctxs"
            fi
        fi
    else
        info "Docker config não montado (sem contexts personalizados)"
    fi

    # Check compose
    if docker compose version &>/dev/null; then
        ok "Docker Compose: $(docker compose version --short 2>/dev/null || echo 'unknown')"
    fi

    # Check buildx
    if docker buildx version &>/dev/null; then
        ok "Docker Buildx disponível"
    fi
}
