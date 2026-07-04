#!/bin/sh

MODE="${1:-tui}"
PORT="${OPENCODE_PORT:-8080}"
HOSTNAME="${OPENCODE_HOSTNAME:-0.0.0.0}"

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
