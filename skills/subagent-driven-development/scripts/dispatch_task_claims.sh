#!/usr/bin/env bash
set -euo pipefail

fail(){ echo "ERROR: $*" >&2; exit 1; }

TASKS_FILE=""
REQUIREMENT_KEY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tasks-file) TASKS_FILE="$2"; shift 2 ;;
    --requirement-key) REQUIREMENT_KEY="$2"; shift 2 ;;
    *) fail "unknown argument: $1" ;;
  esac
done

[[ -n "$TASKS_FILE" ]] || fail "--tasks-file is required"
[[ -f "$TASKS_FILE" ]] || fail "tasks file not found: $TASKS_FILE"
[[ -n "$REQUIREMENT_KEY" ]] || fail "--requirement-key is required"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
START_TASK="$SCRIPT_DIR/../../executing-plans/scripts/claim_and_start_task.sh"

while IFS='|' read -r repo task_id agent_id note; do
  [[ -z "$repo" || "$repo" =~ ^[[:space:]]*# ]] && continue
  note="${note:-}"
  bash "$START_TASK" \
    --repo "$repo" \
    --requirement-key "$REQUIREMENT_KEY" \
    --agent-id "$agent_id" \
    --task-id "$task_id" \
    --note "$note"
done < "$TASKS_FILE"

echo "SUBAGENT_DISPATCH_DONE"
