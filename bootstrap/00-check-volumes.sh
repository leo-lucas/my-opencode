#!/usr/bin/env bash
set -euo pipefail

# ── Directory of this script ───────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Color helpers ──────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()      { echo -e "${GREEN}[✓]${NC}   $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[✗]${NC}   $*" >&2; }
header()  { echo -e "\n${BOLD}${CYAN}=== $* ===${NC}\n"; }

# ── Volume definitions ─────────────────────────────────────────────
declare -A VOLUMES=(
    [".ssh"]="/home/dev/.ssh"
    [".docker"]="/home/dev/.docker"
    ["gh config"]="/home/dev/.config/gh"
    ["opencode config"]="/home/dev/.config/opencode"
    ["nvim config"]="/home/dev/.config/nvim"
    [".gitconfig"]="/home/dev/.gitconfig"
    [".zshrc"]="/home/dev/.zshrc"
    [".cache"]="/home/dev/.cache"
    [".npm"]="/home/dev/.npm"
    [".cargo"]="/home/dev/.cargo"
    ["local/share"]="/home/dev/.local/share"
)

WORKSPACES=(
    "/workspace/projects"
    "/workspace/company"
    "/workspace/personal"
    "/workspace/playground"
    "/workspace/tmp"
)

# ── Check if all volumes exist ─────────────────────────────────────
check_volumes() {
    header "Verificando volumes"

    local missing=()

    for name in "${!VOLUMES[@]}"; do
        local path="${VOLUMES[$name]}"
        if [[ ! -e "$path" ]]; then
            warn "Volume ausente: $name ($path)"
            missing+=("$name")
        else
            ok "Volume montado: $name"
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        warn "\nVolume(s) ausente(s):"
        for name in "${missing[@]}"; do
            echo -e "  ${YELLOW}- ${name}${NC}"
        done
        echo ""
        echo "Monte os volumes ausentes no docker-compose.yml:"
        for name in "${missing[@]}"; do
            local path="${VOLUMES[$name]}"
            echo -e "  volumes:"
            echo -e "    - \${HOME}/${path#/home/dev/}:${path}:ro"
        done
        echo ""
        warn "Alguns recursos podem não funcionar sem estes volumes."
        warn "O container continuará iniciando."
    fi

    # Check workspace directories
    ok "Diretórios de workspace verificados"
    for ws in "${WORKSPACES[@]}"; do
        if [[ -d "$ws" ]]; then
            ok "Workspace: $ws"
        fi
    done
}

# ── Check permissions ──────────────────────────────────────────────
check_permissions() {
    header "Verificando permissões"

    local issues=0

    for name in "${!VOLUMES[@]}"; do
        local path="${VOLUMES[$name]}"
        if [[ -e "$path" ]]; then
            if [[ -r "$path" ]]; then
                ok "Permissão de leitura: $name"
            else
                error "Sem permissão de leitura: $name"
                ((issues+=1))
            fi
        fi
    done

    if [[ $issues -gt 0 ]]; then
        warn "$issues problema(s) de permissão encontrado(s)"
    else
        ok "Todas as permissões OK"
    fi
}

# ── Source all checks ──────────────────────────────────────────────
run_all() {
    local skip_docker="${SKIP_DOCKER_CHECK:-false}"
    local skip_gh="${SKIP_GH_CHECK:-false}"
    local skip_ssh="${SKIP_SSH_CHECK:-false}"
    local skip_opencode="${SKIP_OPENCODE_CHECK:-false}"

    check_volumes
    check_permissions

    if [[ "$skip_docker" == "false" ]]; then
        source "${SCRIPT_DIR}/01-check-docker.sh"
        check_docker
    fi

    if [[ "$skip_gh" == "false" ]]; then
        source "${SCRIPT_DIR}/02-check-gh.sh"
        check_gh
    fi

    if [[ "$skip_ssh" == "false" ]]; then
        source "${SCRIPT_DIR}/03-check-ssh.sh"
        check_ssh
    fi

    if [[ "$skip_opencode" == "false" ]]; then
        source "${SCRIPT_DIR}/04-check-opencode.sh"
        check_opencode
    fi

    header "Bootstrap completo"
    echo -e "${GREEN}Workstation pronta.${NC}\n"
}

# ── Run if executed directly ───────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_all
else
    # Export functions for sourcing
    export -f check_volumes check_permissions header info ok warn error
fi
