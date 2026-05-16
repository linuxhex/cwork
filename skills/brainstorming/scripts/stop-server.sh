#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PID_FILE="$SCRIPT_DIR/.visual-server.pid"

if [[ ! -f "$PID_FILE" ]]; then
  echo "VISUAL_SERVER_ALREADY_STOPPED"
  exit 0
fi

pid="$(cat "$PID_FILE" 2>/dev/null || true)"
if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
  kill "$pid" || true
fi
rm -f "$PID_FILE"

echo "VISUAL_SERVER_STOPPED"
