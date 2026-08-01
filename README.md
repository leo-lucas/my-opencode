# AI Workstation

Docker image reutilizável para desenvolvimento com agentes de IA.

## Filosofia

A imagem é **stateless** e **reutilizável**. Nenhuma configuração pessoal, credencial ou estado é embutido na imagem.

Tudo é montado via volumes no momento do startup.

## Quick Start

```bash
# Mount all host configs automatically
docker compose up --build

# Terminal mode
MODE=tui docker compose up --build

# Web mode
MODE=web docker compose up --build

# Headless server
MODE=serve docker compose up --build
```

## Architecture

```
Host                          Container
────────                      ──────────
~/.ssh        ────→          /home/dev/.ssh
~/.docker     ────→          /home/dev/.docker
~/.config/gh  ────→          /home/dev/.config/gh
~/.config/opencode ──→       /home/dev/.config/opencode
~/.config/nvim ────→         /home/dev/.config/nvim
~/.gitconfig  ────→          /home/dev/.gitconfig
~/.zshrc      ────→          /home/dev/.zshrc
/workspace/*  ────→          /workspace/*
/var/run/docker.sock ──→     /var/run/docker.sock
```

## Workspace Structure

```
/workspace/
├── projects/      # Shared work projects
├── company/       # Company workspaces
├── personal/      # Personal projects
├── playground/    # Experiments
└── tmp/           # Temporary files
```

Mount additional directories as needed:

```yaml
volumes:
  - ~/projects/my-app:/workspace/company/my-app:rw
```

## Commands

```bash
# Run doctor check
docker compose exec opencode bash /home/dev/scripts/doctor.sh

# Run bootstrap checks only
docker compose exec opencode check

# Start in TUI mode
MODE=tui docker compose up

# Start in web mode
MODE=web docker compose up

# Start in headless server mode
MODE=serve docker compose up
```

## Tools

| Category  | Tools |
|-----------|-------|
| Shell     | zsh, tmux, starship |
| Nav       | eza, bat, fd, ripgrep, fzf, zoxide |
| Git       | lazygit, delta, git-lfs |
| Docker    | docker-cli, docker compose, buildx |
| K8s       | kubectl, helm |
| Languages | node, python, bun, uv, pnpm, npm, yarn |
| Utils     | jq, yq, tree, htop, make, gcc |
| Editor    | neovim |
| AI        | opencode, gh |

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `MODE` | `tui` | Run mode: `tui`, `web`, `serve`, `doctor`, `check` |
| `OPENCODE_PORT` | `8080` | Server port (web/serve) |
| `OPENCODE_HOSTNAME` | `0.0.0.0` | Server bind address |

## Optional Features

### Privileged Mode

Enable when you need elevated privileges:

```yaml
services:
  opencode:
    privileged: true
```

### Host Network

Use for better Docker-in-Docker networking:

```yaml
services:
  opencode:
    network_mode: host
```

### SSH Agent

Automatically mounted if available:

```yaml
volumes:
  - ${SSH_AUTH_SOCK:-/tmp/ssh-auth.sock}:/tmp/ssh-auth.sock:ro
```

### Custom Docker Contexts

Mount from host:

```yaml
volumes:
  - ~/.docker/contexts:/home/dev/.docker/contexts:ro
```

## Development

### Building

```bash
docker compose build
```

### Running checks

```bash
# Check all mounts and tools
docker compose run --rm opencode check

# Full doctor
docker compose exec opencode bash /home/dev/scripts/doctor.sh
```

## Statelessness

The image contains **only tools**. All state comes from host mounts:

- SSH keys from `~/.ssh`
- Docker configs from `~/.docker`
- GitHub auth from `~/.config/gh`
- OpenCode config from `~/.config/opencode`
- Git config from `~/.gitconfig`
- Caches from `~/.cache`, `~/.npm`, `~/.cargo`

This ensures the image is:
- Portable across machines
- Free of personal data
- Free of credentials
- Consistent across deployments
