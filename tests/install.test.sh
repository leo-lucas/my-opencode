#!/usr/bin/env bash
set -euo pipefail

# ── Configurações dos testes ───────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/../install.sh"
TEST_BASE=$(mktemp -d)
PASS=0
FAIL=0
TOTAL=0

# ── Cores ──────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

fail()  { echo -e "${RED}[FAIL]${NC} $1"; FAIL=$((FAIL+1)); }
pass()  { echo -e "${GREEN}[PASS]${NC}  $1"; PASS=$((PASS+1)); }

setup_test() {
    TOTAL=$((TOTAL+1))
    echo -e "\n${CYAN}── Test $TOTAL: $1 ──${NC}"
    rm -rf "$TEST_BASE"/*
}

# ── Helper para verificar JSON via python3 ─────────────────────────
json_check() {
    local file="$1"
    local python_expr="$2"
    local expected="$3"
    python3 -c "
import json, sys
with open('$file') as f:
    data = json.load(f)
result = $python_expr
sys.exit(0 if result == $expected else 1)
" 2>/dev/null
}

json_has_key() {
    local file="$1"
    local key_path="$2"
    python3 -c "
import json
with open('$file') as f:
    data = json.load(f)
try:
    parts = '$key_path'.split('.')
    obj = data
    for p in parts:
        if p.startswith('[') and p.endswith(']'):
            obj = obj[p[1:-1]]
        else:
            obj = obj[p]
except (KeyError, IndexError, TypeError) as e:
    print(f'MISSING: {e}', file=sys.stderr)
    exit(1)
print(obj)
" 2>/dev/null
}

# ── Cria um repo remoto simulado com opções extras ────────────────
create_remote_repo() {
    local dir="$1"
    local mode="${2:-basic}"
    local subdir="$dir/remote_work"
    local bare="$dir/remote_bare"
    local saved_dir
    saved_dir=$(pwd)

    rm -rf "$subdir" "$bare"
    mkdir -p "$subdir"
    cd "$subdir"
        git init -q && git config user.email "t@t.com" && git config user.name "T"

        cat > opencode.json << 'EOFJ'
{
    "$schema": "https://opencode.ai/opencode.schema.json",
    "plugin": [{"name":"remote-plugin","config":{"enabled":true}}],
    "mcp": {"remote-server":{"command":"remote-cmd","args":[]}},
    "provider": {"remote-provider":{"model":"remote-model"}},
    "permission": {"remote-perm":{"action":"remote-action"}}
}
EOFJ

        cat > .env << 'EOFE'
REMOTE_KEY=remote_value
NEW_KEY=new_value
EOFE

        case "$mode" in
            with-tui)
                cat > tui.json << 'EOFJ'
{ "$schema":"tui.schema.json","plugin":[{"name":"remote-tui-plugin"}] }
EOFJ
                ;;
            with-dcp)
                echo '{"key":"remote-dcp-value"}' > dcp.jsonc
                ;;
            with-memory)
                mkdir -p memory
                echo "mem content" > memory/graph.json
                ;;
            with-package)
                cat > package.json << 'EOFJ'
{ "dependencies": {"@test/plugin-a":"^1.0.0"} }
EOFJ
                ;;
        esac

        git add -A && git commit -q -m "initial"
    cd "$saved_dir"

    git clone --bare "$subdir" "$bare" 2>/dev/null
    rm -rf "$subdir"
    echo "$bare"
}

# ── Executa o install com overrides de env vars ────────────────────
run_install() {
    local config_dir="$1"
    local remote_url="$2"
    export OPENCODE_CONFIG_DIR="$config_dir"
    export OPENCODE_BRANCH="main"
    export OPENCODE_REPO_URL="$remote_url"
    bash "$INSTALL_SCRIPT" >> "$TEST_BASE/install.log" 2>&1 || true
    unset OPENCODE_CONFIG_DIR OPENCODE_BRANCH OPENCODE_REPO_URL
}

assert_exists() {
    if [[ -e "$1" ]]; then pass "$1 existe"; else fail "$1 não existe"; fi
}
assert_file_exists() {
    if [[ -f "$1" ]]; then pass "$1 existe"; else fail "$1 não existe"; fi
}
assert_dir_exists() {
    if [[ -d "$1" ]]; then pass "$1 é diretório"; else fail "$1 não é diretório"; fi
}
assert_file_not_exists() {
    if [[ ! -f "$1" ]]; then pass "$1 não existe"; else fail "$1 existe"; fi
}
assert_contains() {
    if grep -q "$2" "$1" 2>/dev/null; then pass "'$2' encontrado em $(basename $1)"; else fail "'$2' NÃO encontrado em $(basename $1)"; fi
}
assert_not_contains() {
    if ! grep -q "$2" "$1" 2>/dev/null; then pass "'$2' ausente em $(basename $1)"; else fail "'$2' encontrado em $(basename $1)"; fi
}
assert_json_has() {
    local file="$1"
    local field="$2"
    python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
sys.exit(0 if sys.argv[2] in data else 1)
" "$file" "$field" 2>/dev/null && pass "JSON $field presente em $(basename $file)" || fail "JSON $field ausente em $(basename $file)"
}
assert_json_eq() {
    local file="$1"
    local field="$2"
    local expected="$3"
    local actual
    actual=$(json_has_key "$file" "$field" 2>/dev/null || echo "__MISSING__")
    if [[ "$actual" == "$expected" ]]; then
        pass "JSON $(basename $file).$field = '$expected'"
    else
        fail "JSON $(basename $file).$field = '$actual' (esperado: '$expected')"
    fi
}
assert_json_array_contains() {
    local file="$1"
    local field="$2"
    local value="$3"
    python3 -c "
import json
with open('$file') as f:
    data = json.load(f)
items = data.get('$field', [])
names = [i.get('name','') for i in items if isinstance(i, dict)]
assert '$value' in names
" 2>/dev/null && pass "$(basename $file) $field contém '$value'" || fail "$(basename $file) $field NÃO contém '$value'"
}

cleanup() { rm -rf "$TEST_BASE"; }
trap cleanup EXIT

# ═══════════════════════════════════════════════════════════════════
# TESTES
# ═══════════════════════════════════════════════════════════════════

# ── T1: Novo install (config_dir não existe) ──────────────────────
setup_test "Novo install — config_dir não existe"
run_install "$TEST_BASE/new_config" "$(create_remote_repo "$TEST_BASE" basic)"

assert_file_exists "$TEST_BASE/new_config/opencode.json"
assert_file_exists "$TEST_BASE/new_config/.env"
assert_contains "$TEST_BASE/new_config/.env" 'REMOTE_KEY=remote_value'
assert_contains "$TEST_BASE/new_config/.env" 'NEW_KEY=new_value'
assert_json_has "$TEST_BASE/new_config/opencode.json" '$schema'
assert_json_has "$TEST_BASE/new_config/opencode.json" "plugin"

# ── T2: Merge opencode.json (não-git) — preserva local, adiciona remoto ──
setup_test "Merge opencode.json (não-git) — union plugins, merge por chave"
CONFIG_NG="$TEST_BASE/ng_config"
mkdir -p "$CONFIG_NG"

cat > "$CONFIG_NG/opencode.json" << 'EOFJ'
{
    "$schema":"local.schema.json",
    "plugin": [{"name":"local-plugin"},{"name":"shared-plugin","config":{"v":"1"}}],
    "mcp": {"local-server":{"cmd":"local"},"shared-server":{"cmd":"shared-old"}},
    "provider": {"local-prov":{"m":"local"},"shared-prov":{"m":"shared-old"}},
    "permission": {}
}
EOFJ

run_install "$CONFIG_NG" "$(create_remote_repo "$TEST_BASE" basic)"

assert_json_eq "$CONFIG_NG/opencode.json" '$schema' 'local.schema.json'
assert_json_array_contains "$CONFIG_NG/opencode.json" "plugin" "local-plugin"
assert_json_array_contains "$CONFIG_NG/opencode.json" "plugin" "remote-plugin"
assert_json_array_contains "$CONFIG_NG/opencode.json" "plugin" "shared-plugin"
assert_json_has "$CONFIG_NG/opencode.json" "mcp"
assert_json_array_contains "$CONFIG_NG/opencode.json" "plugin" "remote-plugin"
assert_json_has "$CONFIG_NG/opencode.json" "provider"

# ── T3: Merge .env (não-git) — mantém locais, adiciona novos ──────
setup_test "Merge .env (não-git) — preserva valores locais"
CONFIG_NG2="$TEST_BASE/ng_config2"
mkdir -p "$CONFIG_NG2"

cat > "$CONFIG_NG2/opencode.json" << 'EOFJ'
{ "plugin":[],"mcp":{},"provider":{},"permission":{} }
EOFJ
cat > "$CONFIG_NG2/.env" << 'EOFE'
REMOTE_KEY=local_override
LOCAL_KEY=local_only
EOFE

run_install "$CONFIG_NG2" "$(create_remote_repo "$TEST_BASE" basic)"

assert_contains "$CONFIG_NG2/.env" 'REMOTE_KEY=local_override'
assert_contains "$CONFIG_NG2/.env" 'LOCAL_KEY=local_only'
assert_contains "$CONFIG_NG2/.env" 'NEW_KEY=new_value'

# ── T4: Merge tui.json (não-git) ──────────────────────────────────
setup_test "Merge tui.json (não-git) — union plugins"
CONFIG_NG3="$TEST_BASE/ng_config3"
mkdir -p "$CONFIG_NG3"

cat > "$CONFIG_NG3/opencode.json" << 'EOFJ'
{ "plugin":[],"mcp":{},"provider":{},"permission":{} }
EOFJ
cat > "$CONFIG_NG3/tui.json" << 'EOFJ'
{ "$schema":"tui-local.json","plugin":[{"name":"tui-local"}] }
EOFJ

run_install "$CONFIG_NG3" "$(create_remote_repo "$TEST_BASE" with-tui)"

assert_file_exists "$CONFIG_NG3/tui.json"
assert_json_array_contains "$CONFIG_NG3/tui.json" "plugin" "tui-local"
assert_json_array_contains "$CONFIG_NG3/tui.json" "plugin" "remote-tui-plugin"

# ── T5: dcp.jsonc — novo ──────────────────────────────────────────
setup_test "dcp.jsonc novo (não-git)"
CONFIG_NG4="$TEST_BASE/ng_config4"
mkdir -p "$CONFIG_NG4"

cat > "$CONFIG_NG4/opencode.json" << 'EOFJ'
{ "plugin":[],"mcp":{},"provider":{},"permission":{} }
EOFJ

run_install "$CONFIG_NG4" "$(create_remote_repo "$TEST_BASE" with-dcp)"

assert_file_exists "$CONFIG_NG4/dcp.jsonc"
assert_contains "$CONFIG_NG4/dcp.jsonc" '"key"'

# ── T6: dcp.jsonc — existente mantido ─────────────────────────────
setup_test "dcp.jsonc existente — mantido"
CONFIG_NG5="$TEST_BASE/ng_config5"
mkdir -p "$CONFIG_NG5"

cat > "$CONFIG_NG5/opencode.json" << 'EOFJ'
{ "plugin":[],"mcp":{},"provider":{},"permission":{} }
EOFJ
echo '{"key":"local-dcp-value"}' > "$CONFIG_NG5/dcp.jsonc"

run_install "$CONFIG_NG5" "$(create_remote_repo "$TEST_BASE" with-dcp)"

assert_contains "$CONFIG_NG5/dcp.jsonc" '"local-dcp-value"'

# ── T7: memory/ — mantido intacto (não é mergeado) ────────────────
setup_test "memory/ — mantido intacto, sem merge"
CONFIG_NG6="$TEST_BASE/ng_config6"
mkdir -p "$CONFIG_NG6"

cat > "$CONFIG_NG6/opencode.json" << 'EOFJ'
{ "plugin":[],"mcp":{},"provider":{},"permission":{} }
EOFJ
mkdir -p "$CONFIG_NG6/memory"
echo "local-memory" > "$CONFIG_NG6/memory/graph.json"

run_install "$CONFIG_NG6" "$(create_remote_repo "$TEST_BASE" basic)"

# memory local deve permanecer sem alterações
assert_file_exists "$CONFIG_NG6/memory/graph.json"
assert_contains "$CONFIG_NG6/memory/graph.json" 'local-memory'

# ── T8: Arquivos locais não-no-repo são preservados (não-git) ─────
setup_test "Arquivos locais não-no-repo preservados (não-git)"
CONFIG_NG7="$TEST_BASE/ng_config7"
mkdir -p "$CONFIG_NG7"

cat > "$CONFIG_NG7/opencode.json" << 'EOFJ'
{ "plugin":[],"mcp":{},"provider":{},"permission":{} }
EOFJ
cat > "$CONFIG_NG7/.env" << 'EOFE'
LOCAL_KEY=local_only
EOFE
echo "custom content" > "$CONFIG_NG7/custom-file.txt"

run_install "$CONFIG_NG7" "$(create_remote_repo "$TEST_BASE" basic)"

assert_file_exists "$CONFIG_NG7/custom-file.txt"
assert_contains "$CONFIG_NG7/custom-file.txt" 'custom content'
assert_contains "$CONFIG_NG7/.env" 'LOCAL_KEY=local_only'
assert_contains "$CONFIG_NG7/.env" 'REMOTE_KEY=remote_value'

# ── T9: Merge com config git — sem conflitos ─────────────────────
setup_test "Merge com config git — sem conflitos"
CONFIG_G="$TEST_BASE/git_config"
mkdir -p "$CONFIG_G"
(
    cd "$CONFIG_G"
    git init -q && git config user.email "t@t.com" && git config user.name "T"
    cat > opencode.json << 'EOFJ'
{ "$schema":"git-local.schema","plugin":[{"name":"git-local-plugin"}],"mcp":{"git-server":{"cmd":"g"}},"provider":{},"permission":{} }
EOFJ
    git add -A && git commit -q -m "local"
)

run_install "$CONFIG_G" "$(create_remote_repo "$TEST_BASE" basic)"

assert_dir_exists "$CONFIG_G/.git"

# ── T10: Config git com mudanças não-commitadas (stash) ───────────
setup_test "Config git com mudanças não-commitadas — stash preservado"
CONFIG_G2="$TEST_BASE/git_config_stash"
mkdir -p "$CONFIG_G2"
(
    cd "$CONFIG_G2"
    git init -q && git config user.email "t@t.com" && git config user.name "T"
    cat > opencode.json << 'EOFJ'
{ "$schema":"stash-test","plugin":[{"name":"stash-local"}],"mcp":{},"provider":{},"permission":{} }
EOFJ
    git add -A && git commit -q -m "local"
    # Alteração não commitada
    echo "stashed" >> opencode.json
)

run_install "$CONFIG_G2" "$(create_remote_repo "$TEST_BASE" basic)"

assert_contains "$CONFIG_G2/opencode.json" '"stash-local"'
assert_contains "$CONFIG_G2/opencode.json" 'stashed'

# ── T11: Backup é criado ──────────────────────────────────────────
setup_test "Backup é criado com config existente"
CONFIG_B="$TEST_BASE/backup_config"
mkdir -p "$CONFIG_B"

cat > "$CONFIG_B/opencode.json" << 'EOFJ'
{ "$schema":"backup-test","plugin":[{"name":"backup-plugin"}],"mcp":{},"provider":{},"permission":{} }
EOFJ

run_install "$CONFIG_B" "$(create_remote_repo "$TEST_BASE" basic)"

assert_contains "$TEST_BASE/install.log" 'Backup criado'

# ── T12: Config existente no repo não é sobrescrito (não-git) ─────
setup_test "Config existente no repo não é sobrescrito (não-git)"
CONFIG_NG8="$TEST_BASE/ng_config8"
mkdir -p "$CONFIG_NG8"

cat > "$CONFIG_NG8/opencode.json" << 'EOFJ'
{ "$schema":"my-schema","plugin":[{"name":"my-local"}],"mcp":{"my-mcp":{"cmd":"x"}},"provider":{},"permission":{} }
EOFJ

run_install "$CONFIG_NG8" "$(create_remote_repo "$TEST_BASE" basic)"

assert_json_eq "$CONFIG_NG8/opencode.json" '$schema' 'my-schema'
assert_json_array_contains "$CONFIG_NG8/opencode.json" "plugin" "my-local"

# ── T13: Merge providers (não-git) — merge por chave ──────────────
setup_test "Merge provider (não-git) — merge por chave"
CONFIG_NG9="$TEST_BASE/ng_config9"
mkdir -p "$CONFIG_NG9"

cat > "$CONFIG_NG9/opencode.json" << 'EOFJ'
{ "schema":"test","plugin":[],"mcp":{},"provider":{"local-prov":{"model":"local"}},"permission":{} }
EOFJ

run_install "$CONFIG_NG9" "$(create_remote_repo "$TEST_BASE" basic)"

assert_json_has "$CONFIG_NG9/opencode.json" "provider"

# ── T14: Merge permission (não-git) ───────────────────────────────
setup_test "Merge permission (não-git) — merge por chave"
CONFIG_NG10="$TEST_BASE/ng_config10"
mkdir -p "$CONFIG_NG10"

cat > "$CONFIG_NG10/opencode.json" << 'EOFJ'
{ "schema":"test","plugin":[],"mcp":{},"provider":{},"permission":{"local-perm":{"action":"local"}} }
EOFJ

run_install "$CONFIG_NG10" "$(create_remote_repo "$TEST_BASE" basic)"

assert_json_has "$CONFIG_NG10/opencode.json" "permission"

# ═══════════════════════════════════════════════════════════════════
# RESULTADO
# ═══════════════════════════════════════════════════════════════════
echo ""
echo -e "═══════════════════════════════════════════"
echo -e "  Total: $TOTAL | ${GREEN}Pass: $PASS${NC} | ${RED}Fail: $FAIL${NC}"
echo -e "═══════════════════════════════════════════"

if [[ "$FAIL" -gt 0 ]]; then
    echo -e "${RED}ALGUNS TESTES FALHARAM${NC}"
    echo ""
    echo "Log completo: $TEST_BASE/install.log"
    exit 1
fi
echo -e "${GREEN}TODOS OS TESTES PASSARAM${NC}"
