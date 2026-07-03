#!/usr/bin/env bash
set -euo pipefail

# ── Configurações ──────────────────────────────────────────────────
REPO_URL="${OPENCODE_REPO_URL:-https://github.com/leo-lucas/my-opencode.git}"
BRANCH="${OPENCODE_BRANCH:-main}"
CONFIG_DIR="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"

# ── Cores ──────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ── Dependências ───────────────────────────────────────────────────
for cmd in git jq; do
    command -v "$cmd" &>/dev/null || error "'$cmd' não encontrado. Instale-o."
done

# ── Preparar diretório de trabalho ─────────────────────────────────
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

CLONE_DIR="$TMPDIR/repo"

# ── Clone do repositório ───────────────────────────────────────────
info "Clonando repositório: $REPO_URL (branch: $BRANCH)"
git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$CLONE_DIR" 2>/dev/null \
    || error "Falha ao clonar o repositório. Verifique a URL e o branch."

# Verifica se os arquivos de config existem no clone
if ! ls "$CLONE_DIR"/opencode.json "$CLONE_DIR"/.env &>/dev/null; then
    error "Repositório não contém 'opencode.json' e/ou '.env' esperados."
fi

# ── Detectar se CONFIG_DIR já é um repositório git ─────────────────
IS_GIT_REPO=false
if [[ -d "$CONFIG_DIR" && -d "$CONFIG_DIR/.git" ]]; then
    IS_GIT_REPO=true
fi

# ── Backup da config atual ─────────────────────────────────────────
BACKUP_DIR="$TMPDIR/backup_$(date +%Y%m%d_%H%M%S)"
if [[ -d "$CONFIG_DIR" ]]; then
    mkdir -p "$BACKUP_DIR"
    cp -a "$CONFIG_DIR" "$BACKUP_DIR/config"
    ok "Backup criado: $BACKUP_DIR/config"
fi

if [[ "$IS_GIT_REPO" == true ]]; then
    # ── CASO 1: CONFIG_DIR já é git — fazer merge mantendo histórico ──
    info "Config atual é um repositório git — fazendo merge mantendo histórico local"

    # Verificar se há mudanças não commitadas
    if [[ -n "$(git -C "$CONFIG_DIR" status --porcelain 2>/dev/null)" ]]; then
        warn "Há mudanças não commitadas no repositório local."
        warn "Fazendo stash antes do merge..."
        git -C "$CONFIG_DIR" stash push -m "stash antes do install $(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
    fi

    # Adicionar/remover remote para evitar conflitos de URL
    git -C "$CONFIG_DIR" remote remove upstream 2>/dev/null || true
    git -C "$CONFIG_DIR" remote add upstream "$REPO_URL" 2>/dev/null || true
    git -C "$CONFIG_DIR" fetch upstream "$BRANCH" 2>/dev/null || true

    # Fazer merge
    if git -C "$CONFIG_DIR" merge --allow-unrelated-histories upstream/"$BRANCH" -m "merge: upstream $REPO_URL ($BRANCH)" 2>/dev/null; then
        ok "Git merge concluído (histórico preservado)"
    else
        warn "Merge teve conflitos — tentando resolver com preferência local..."
        # Resolver conflitos: manter versão local para todos os conflitos
        git -C "$CONFIG_DIR" checkout --ours . 2>/dev/null || true
        git -C "$CONFIG_DIR" add -A 2>/dev/null || true
        git -C "$CONFIG_DIR" commit -m "merge: conflitos resolvidos (preferência: local)" 2>/dev/null || true
        ok "Conflitos resolvidos (versão local mantida)"
    fi

    # Limpar remote adicionado
    git -C "$CONFIG_DIR" remote remove upstream 2>/dev/null || true

    # Restaurar stash se existiu
    if git -C "$CONFIG_DIR" stash list 2>/dev/null | grep -q "stash antes do install"; then
        git -C "$CONFIG_DIR" stash pop 2>/dev/null || warn "Não foi possível restaurar o stash"
    fi

else
    # ── CASO 2: CONFIG_DIR não é git — clonar direto e fazer merge manual ──
    info "Config atual não é um repositório git — clonando direto no $CONFIG_DIR"

    # Salvar arquivos locais antes de sobrescrever
    LOCAL_SAVE="$TMPDIR/local_files"
    mkdir -p "$LOCAL_SAVE"
    if [[ -d "$CONFIG_DIR" ]]; then
        (
            cd "$CONFIG_DIR"
            shopt -s dotglob nullglob
            cp -a ./* "$LOCAL_SAVE/" 2>/dev/null || true
        )
    fi

    # Salvar memory/ separadamente (machine-specific, não mergeado)
    MEMORY_SAVE="$TMPDIR/memory_save"
    if [[ -d "$CONFIG_DIR/memory" ]]; then
        mkdir -p "$MEMORY_SAVE"
        cp -a "$CONFIG_DIR/memory"/* "$MEMORY_SAVE/" 2>/dev/null || true
    fi

    # Clonar direto no config dir
    rm -rf "$CONFIG_DIR"
    git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$CONFIG_DIR" 2>/dev/null \
        || error "Falha ao clonar no diretório de config."

    ok "Repositório clonado em $CONFIG_DIR"

    # Restaurar memory/ (machine-specific, nunca mergeado)
    if [[ -d "$MEMORY_SAVE" ]]; then
        mkdir -p "$CONFIG_DIR/memory"
        cp -a "$MEMORY_SAVE/"* "$CONFIG_DIR/memory/" 2>/dev/null || true
        info "  ~ memory/ restaurado (machine-specific)"
    fi

    # Restaurar arquivos locais que não existem no repositório
    for f in "$LOCAL_SAVE/"*; do
        [[ -f "$f" ]] || continue
        fname=$(basename "$f")
        if [[ ! -f "$CONFIG_DIR/$fname" ]]; then
            cp "$f" "$CONFIG_DIR/$fname"
            info "  + $fname (restaurado do local)"
        else
            info "  ~ $fname (existente no repositório — mantido)"
        fi
    done

    # ── Merge manual (scripts jq) para opencode.json ────────────────
    # Usar LOCAL_SAVE para ler o "local" (original) e CLONE_DIR para "remote"
    LOCAL_JSON="$LOCAL_SAVE/opencode.json"
    REMOTE_JSON="$CLONE_DIR/opencode.json"
    if [[ -f "$LOCAL_JSON" ]] && [[ -f "$REMOTE_JSON" ]]; then
        REMOTE=$(jq '.' "$REMOTE_JSON")
        LOCAL=$(jq '.' "$LOCAL_JSON")

        MERGED_PLUGINS=$(jq -n \
            --argjson local  "$(echo "$LOCAL"  | jq '.plugin  // []')" \
            --argjson remote "$(echo "$REMOTE" | jq '.plugin  // []')" \
            '($local + $remote | unique)')

        MERGED_MCP=$(jq -n \
            --argjson local  "$(echo "$LOCAL"  | jq '.mcp  // {}')" \
            --argjson remote "$(echo "$REMOTE" | jq '.mcp  // {}')" \
            '$local * $remote')

        MERGED_PROVIDER=$(jq -n \
            --argjson local  "$(echo "$LOCAL"  | jq '.provider  // {}')" \
            --argjson remote "$(echo "$REMOTE" | jq '.provider  // {}')" \
            '$local * $remote')

        MERGED_PERM=$(jq -n \
            --argjson local  "$(echo "$LOCAL"  | jq '.permission  // {}')" \
            --argjson remote "$(echo "$REMOTE" | jq '.permission  // {}')" \
            '$local * $remote')

        jq -n \
            --arg schema "$(echo "$LOCAL" | jq -r '.["$schema"] // empty')" \
            --argjson plugins "$MERGED_PLUGINS" \
            --argjson mcp "$MERGED_MCP" \
            --argjson provider "$MERGED_PROVIDER" \
            --argjson permission "$MERGED_PERM" \
            'if $schema != "" then {} | .["$schema"] = $schema else {} end | .plugin = $plugins | .mcp = $mcp | .provider = $provider | .permission = $permission' > "$CONFIG_DIR/opencode.json"

        ok "opencode.json mergeado (plugins, MCP, providers, permissions)"
    elif [[ -f "$REMOTE_JSON" ]]; then
        cp "$REMOTE_JSON" "$CONFIG_DIR/opencode.json"
        ok "opencode.json criado (novo)"
    fi

    # ── Merge manual .env ───────────────────────────────────────────
    LOCAL_ENV_FILE="$LOCAL_SAVE/.env"
    REMOTE_ENV_FILE="$CLONE_DIR/.env"
    if [[ -f "$LOCAL_ENV_FILE" ]]; then
        # Começa com o local e adiciona chaves novas do remoto
        cp "$LOCAL_ENV_FILE" "$CONFIG_DIR/.env"
        declare -A LOCAL_ENV
        while IFS='=' read -r key value; do
            [[ -z "$key" || "$key" =~ ^# ]] && continue
            LOCAL_ENV["$key"]="$value"
        done < "$LOCAL_ENV_FILE"

        if [[ -f "$REMOTE_ENV_FILE" ]]; then
            while IFS='=' read -r key value; do
                [[ -z "$key" || "$key" =~ ^# ]] && continue
                if [[ -z "${LOCAL_ENV[$key]+x}" ]]; then
                    echo "$key=$value" >> "$CONFIG_DIR/.env"
                    info "  + $key (adicionado do repositório)"
                else
                    info "  ~ $key (mantido local)"
                fi
            done < "$REMOTE_ENV_FILE"
        fi
        ok ".env mergeado"
    elif [[ -f "$REMOTE_ENV_FILE" ]]; then
        cp "$REMOTE_ENV_FILE" "$CONFIG_DIR/.env"
        ok ".env criado (novo)"
    fi

    # ── Merge manual tui.json ───────────────────────────────────────
    LOCAL_TUI_FILE="$LOCAL_SAVE/tui.json"
    REMOTE_TUI_FILE="$CLONE_DIR/tui.json"
    if [[ -f "$REMOTE_TUI_FILE" ]]; then
        if [[ -f "$LOCAL_TUI_FILE" ]]; then
            REMOTE_TUI=$(jq '.' "$REMOTE_TUI_FILE")
            LOCAL_TUI=$(jq '.' "$LOCAL_TUI_FILE")
            SCHEMA_KEY=$(jq -r 'keys[] | select(startswith("$"))' "$LOCAL_TUI_FILE" 2>/dev/null || echo "")
            if [[ -n "$SCHEMA_KEY" ]]; then
                MERGED_TUI=$(jq -n \
                    --argjson local  "$(echo "$LOCAL_TUI" | jq '.plugin  // []')" \
                    --argjson remote "$(echo "$REMOTE_TUI" | jq '.plugin  // []')" \
                    --arg schema_key "$SCHEMA_KEY" \
                    --argjson schema_val "$LOCAL_TUI" \
                    '({
                        plugin: ($local + $remote | unique)
                    } + (if $schema_val[$schema_key] != null then { ($schema_key): $schema_val[$schema_key] } else {} end))')
            else
                MERGED_TUI=$(jq -n \
                    --argjson local  "$(echo "$LOCAL_TUI" | jq '.plugin  // []')" \
                    --argjson remote "$(echo "$REMOTE_TUI" | jq '.plugin  // []')" \
                    '{ plugin: ($local + $remote | unique) }')
            fi
            echo "$MERGED_TUI" | jq '.' > "$CONFIG_DIR/tui.json"
            ok "tui.json mergeado"
        else
            cp "$REMOTE_TUI_FILE" "$CONFIG_DIR/tui.json"
            ok "tui.json criado (novo)"
        fi
    fi

    # ── Merge manual dcp.jsonc ──────────────────────────────────────
    LOCAL_DCP_FILE="$LOCAL_SAVE/dcp.jsonc"
    REMOTE_DCP_FILE="$CLONE_DIR/dcp.jsonc"
    if [[ -f "$REMOTE_DCP_FILE" ]]; then
        if [[ -f "$LOCAL_DCP_FILE" ]]; then
            cp "$LOCAL_DCP_FILE" "$CONFIG_DIR/dcp.jsonc"
            info "dcp.jsonc local mantido"
        else
            cp "$REMOTE_DCP_FILE" "$CONFIG_DIR/dcp.jsonc"
            ok "dcp.jsonc criado (novo)"
        fi
    fi

    # memory/ é exclusivo de cada máquina — mantido intacto, sem merge
fi

# ── Install de plugins ─────────────────────────────────────────────
info "Verificando plugins..."
if [[ -f "$CONFIG_DIR/package.json" ]]; then
    REMOTE_PKGS=$(jq -r '.dependencies // {} | keys[]' "$CLONE_DIR/package.json" 2>/dev/null || true)
    if [[ -n "$REMOTE_PKGS" ]]; then
        while IFS= read -r pkg; do
            info "  + $pkg"
        done <<< "$REMOTE_PKGS"
        npm install $(echo "$REMOTE_PKGS" | sed 's/@/ /g' | xargs) --prefix "$CONFIG_DIR" 2>/dev/null || warn "Algum plugin falhou ao instalar"
        ok "Dependências verificadas"
    fi
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Install concluído com sucesso!${NC}"
echo -e "${GREEN}  Config: $CONFIG_DIR${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
info "Plugins/MCPs adicionais podem ser necessários. Execute 'opencode' para verificar."
