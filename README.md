# OpenCode Docker

Run OpenCode (AI coding agent) inside Docker, in **tui**, **web**, or **serve** mode.

## Quick Start

```bash
# Web mode (default)
docker compose up --build

# Terminal mode
MODE=tui docker compose up --build

# Headless server
MODE=serve docker compose up --build
```

Then open `http://localhost:8080` for web mode.

## Modes

| Mode | Command | Use case |
|------|---------|----------|
| `tui` | `opencode` | Interactive terminal UI |
| `web` | `opencode web` | Browser-based web interface |
| `serve` | `opencode serve` | Headless API server |
| `run` | `opencode run <message>` | One-shot message execution |

Set mode via `MODE` env var or first argument to entrypoint:

```bash
MODE=tui docker compose up
docker compose run --entrypoint "opencode run hello" opencode
```

## Configuration

Copy and edit `.env.example`:

```bash
cp .env.example .env
```

| Variable | Default | Description |
|----------|---------|-------------|
| `MODE` | `tui` | Run mode: `tui`, `web`, `serve`, `run` |
| `OPENCODE_PORT` | `8080` | Server port (web/serve modes) |
| `OPENCODE_HOSTNAME` | `0.0.0.0` | Server bind address |
| `PROJECT_PATH` | `.` | Local project dir to mount as `/workspace` |

## Volumes

| Volume | Purpose |
|--------|---------|
| `PROJECT_PATH:/workspace` | Your project files (read-write) |
| `opencode-config` | Persistent opencode config & auth |
| `~/.local/share/opencode/auth.json` | LLM provider credentials (optional) |

## Build

```bash
docker build -t opencode .
docker run -it --rm -v $(pwd):/workspace -p 8080:8080 opencode web
```

## Attach to running server

```bash
docker compose exec opencode opencode attach http://localhost:8080
```

## Auth / Providers

LLM provider credentials are stored in the `opencode-config` volume. To reuse host credentials:

```yaml
volumes:
  - ~/.local/share/opencode/auth.json:/opencode/.opencode/auth.json:ro
```

## Example: web mode with custom port

```yaml
# docker-compose.yml override
services:
  opencode:
    environment:
      - MODE=web
      - OPENCODE_PORT=3000
    ports:
      - "3000:3000"
```
