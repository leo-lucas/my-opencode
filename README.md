# Opencode Config

Configuração personalizada do [opencode](https://github.com/anthropic/opencode) com merge automático de repositório remoto.

## Install

O script `install.sh` clona o repositório `leo-lucas/my-opencode` e **mergeia** as configurações com as configurações locais, preservando tudo que é específico da sua máquina.

### Backup automático

Antes de qualquer mudança, o script faz backup completo em `/tmp/backup_YYYYMMDD_HHMMSS/config/`.

### Uso direto do GitHub (one-liner)

```bash
curl -sL https://raw.githubusercontent.com/leo-lucas/my-opencode/main/install.sh | bash
```

### Uso local

```bash
# Opcional: branch (padrão: main)
export OPENCODE_BRANCH="main"

# Opcional: diretório de config (padrão: ~/.config/opencode)
export OPENCODE_CONFIG_DIR="$HOME/.config/opencode"

# Opcional: URL do repositório (padrão: https://github.com/leo-lucas/my-opencode.git)
export OPENCODE_REPO_URL="https://github.com/seu-org/seu-repo.git"

# Executar
chmod +x install.sh
./install.sh
```

### Variáveis de ambiente

| Variável | Obrigatório | Padrão | Descrição |
|---|---|---|---|
| `OPENCODE_BRANCH` | não | `main` | Branch para clonar |
| `OPENCODE_CONFIG_DIR` | não | `~/.config/opencode` | Diretório de instalação |
| `OPENCODE_REPO_URL` | não | `https://github.com/leo-lucas/my-opencode.git` | URL do repositório |

### Dependências

- `git`
- `jq`
- `npm` (para instalar plugins)

## Estratégia de merge

O script detecta se `~/.config/opencode` **já é um repositório git** e segue um caminho diferente:

### Se config **não é git** (clone direto)

1. Salva arquivos locais em temp dir
2. `rm -rf` + `git clone` direto no config dir
3. Restaura `memory/` intacto (machine-specific)
4. Restaura arquivos locais que não existem no repo
5. Merge manual via `jq`:
   - `opencode.json` — plugins unidos (union), MCP/providers por chave, schema local mantido
   - `.env` — valores locais mantidos, novas chaves adicionadas
   - `tui.json` — plugins unidos, schema local mantido
   - `dcp.jsonc` — criado apenas se não existir
   - `memory/` — **nunca mergeado**, restaurado intacto

### Se config **já é git** (merge preservando histórico)

1. Stash de mudanças não commitadas
2. Adiciona remote `upstream` temporário
3. `git merge --allow-unrelated-histories` (histórico preservado)
4. Conflitos resolvidos com `checkout --ours` (versão local ganha)
5. Restaura stash e remove remote temporário

### Tabela de merge

| Arquivo | Estratégia |
|---|---|
| `opencode.json` | Plugins unidos, MCP/providers/permission por chave, schema local mantido |
| `.env` | Chaves locais mantidas, novas chaves do remoto adicionadas |
| `tui.json` | Plugins unidos (sem duplicatas), schema local mantido |
| `dcp.jsonc` | Criado apenas se não existir localmente |
| `memory/` | **Machine-specific** — nunca mergeado, restaurado intacto |

## Exemplo de fluxo

```bash
# 1. Instala/atualiza configs
curl -sL https://raw.githubusercontent.com/leo-lucas/my-opencode/main/install.sh | bash

# 2. Verifica o último backup
ls /tmp/backup_*/config/

# 3. Se quiser clonar para outra máquina
git clone git@github.com:leo-lucas/my-opencode.git ~/.config/opencode
```

## Estrutura

```
.
├── install.sh          # Script de install com merge e backup
├── opencode.json       # Config principal (plugins, MCP, providers)
├── dcp.jsonc           # Dynamic Context Pruning
├── tui.json            # TUI plugins
├── .env                # Variáveis de ambiente (API keys)
├── memory/             # Knowledge graph (machine-specific, não versionado)
└── .opencode/          # Config adicional do opencode
```

## Plugins & MCPs

O `opencode.json` configura:

- **Plugins**: canvas, type-inject, dcp, websearch-cited, notificator, workspace, octto, opentmux, llama.cpp
- **MCPs**: context7, memory, chrome-devtools, playwright, duckduckgo
- **Providers**: llama.cpp local + Google (Gemini 2.5 Flash)

## Testes

```bash
bash tests/install.test.sh
```

14 testes cobrindo: novo install, merge opencode.json, merge .env, merge tui.json, dcp.jsonc, memory/, arquivos não-no-repo, git merge, git stash, backup, schemas/provedores/permissões.

36 asserts passando. Os testes rodam em `/tmp` isolado, nunca tocam em `~/.config/opencode` real.
