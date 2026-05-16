#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PID_FILE="$SCRIPT_DIR/.visual-server.pid"
LOG_FILE="$SCRIPT_DIR/.visual-server.log"
PORT="${CWORK_VISUAL_PORT:-3901}"
HOST="${CWORK_VISUAL_HOST:-127.0.0.1}"

if [[ -f "$PID_FILE" ]]; then
  pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    echo "VISUAL_SERVER_ALREADY_RUNNING pid=$pid url=http://${HOST}:${PORT}"
    exit 0
  fi
fi

nohup node "$SCRIPT_DIR/server.cjs" >"$LOG_FILE" 2>&1 &
echo $! > "$PID_FILE"
sleep 0.2

echo "VISUAL_SERVER_STARTED pid=$(cat "$PID_FILE") url=http://${HOST}:${PORT}"
