#!/usr/bin/env bash
# ── AI Workstation Entry Point ──────────────────────────────────────

set -euo pipefail

MODE="${1:-${MODE:-tui}}"

# ── Colors ──────────────────────────────────────────────────────────
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── Run bootstrap checks ───────────────────────────────────────────
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║     AI Workstation - OpenCode            ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════╝${NC}"

SKIP_DOCKER_CHECK=false SKIP_GH_CHECK=false SKIP_SSH_CHECK=false SKIP_OPENCODE_CHECK=false \
    bash /home/dev/bootstrap/00-check-volumes.sh

# ── Run startup.d scripts ──────────────────────────────────────────
if [[ -d /home/dev/startup.d ]]; then
    for script in /home/dev/startup.d/*.sh; do
        if [[ -x "$script" ]]; then
            source "$script"
        fi
    done
fi

# ── Switch to workspace ────────────────────────────────────────────
if [[ -d /workspace/projects ]]; then
    cd /workspace/projects
else
    cd /workspace
fi

# ── Launch mode ────────────────────────────────────────────────────
case "$MODE" in
    tui)
        echo -e "\n${GREEN}Iniciando ZSH no workspace...${NC}\n"
        exec zsh
        ;;
    doctor)
        exec bash /home/dev/scripts/doctor.sh
        ;;
    check)
        echo -e "\n${GREEN}Rodando verificações...${NC}\n"
        bash /home/dev/bootstrap/00-check-volumes.sh
        ;;
    web)
        shift
        exec opencode web --port "${OPENCODE_PORT:-8080}" --hostname "${OPENCODE_HOSTNAME:-0.0.0.0}"
        ;;
    serve)
        shift
        exec opencode serve --port "${OPENCODE_PORT:-8080}" --hostname "${OPENCODE_HOSTNAME:-0.0.0.0}"
        ;;
    run)
        shift
        exec opencode run "$@"
        ;;
    *)
        shift
        exec opencode "$@"
        ;;
esac
