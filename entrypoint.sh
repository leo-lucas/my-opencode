#!/bin/sh

MODE="${1:-tui}"
PORT="${OPENCODE_PORT:-8080}"
HOSTNAME="${OPENCODE_HOSTNAME:-0.0.0.0}"

# Authenticate gh CLI
if [ -n "$GH_TOKEN" ]; then
  echo "Authenticating GitHub CLI with token..."
  echo "$GH_TOKEN" | gh auth login -p https --git-protocol https --with-token 2>&1
else
  echo "Starting GitHub CLI device auth flow..."
  echo "Visit https://github.com/login/device and enter the code shown below."
  gh auth login --hostname github.com --git-protocol https -p https 2>&1
fi

case "$MODE" in
  tui)
    shift
    exec opencode "$@"
    ;;
  web)
    echo "Starting opencode web mode on ${HOSTNAME}:${PORT}"
    exec opencode web --port ${PORT} --hostname ${HOSTNAME} --pure
    ;;
  serve)
    echo "Starting opencode headless server on ${HOSTNAME}:${PORT}"
    exec opencode serve --port ${PORT} --hostname ${HOSTNAME} --pure
    ;;
  run)
    shift
    exec opencode run "$@"
    ;;
  *)
    echo "Usage: $0 [tui|web|serve|run] [args...]"
    echo "  tui    - Terminal UI mode (default)"
    echo "  web    - Web interface mode"
    echo "  serve  - Headless server mode"
    echo "  run    - Run with a message"
    exit 1
    ;;
esac
