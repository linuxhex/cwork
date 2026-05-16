#!/usr/bin/env bash
set -euo pipefail

fail() { echo "ERROR: $*" >&2; exit 1; }

REPO=""
REQUIREMENT_KEY=""
AGENT_ID=""
TASK_ID=""
NOTE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --requirement-key) REQUIREMENT_KEY="$2"; shift 2 ;;
    --agent-id) AGENT_ID="$2"; shift 2 ;;
    --task-id) TASK_ID="$2"; shift 2 ;;
    --note) NOTE="$2"; shift 2 ;;
    *) fail "unknown argument: $1" ;;
  esac
done

[[ -n "$REPO" ]] || fail "--repo is required"
[[ -n "$REQUIREMENT_KEY" ]] || fail "--requirement-key is required"
[[ -n "$AGENT_ID" ]] || fail "--agent-id is required"
[[ -n "$TASK_ID" ]] || fail "--task-id is required"
[[ "$REPO" = /* ]] || fail "--repo must be absolute"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAIMS_SCRIPT="$SCRIPT_DIR/../../init/scripts/agent_claims.sh"
STATE_SCRIPT="$SCRIPT_DIR/../../init/scripts/workflow_state.sh"

bash "$STATE_SCRIPT" --repo "$REPO" --requirement-key "$REQUIREMENT_KEY" --action assert --phase executing-plans >/dev/null
bash "$CLAIMS_SCRIPT" --repo "$REPO" --requirement-key "$REQUIREMENT_KEY" --action claim --agent-id "$AGENT_ID" --task-id "$TASK_ID" --note "$NOTE" >/dev/null
bash "$CLAIMS_SCRIPT" --repo "$REPO" --requirement-key "$REQUIREMENT_KEY" --action update --agent-id "$AGENT_ID" --task-id "$TASK_ID" --status in_progress --note "$NOTE" >/dev/null

TASK_FILE="$REPO/docs/requirements/$REQUIREMENT_KEY/process/task-${TASK_ID}.md"
mkdir -p "$(dirname "$TASK_FILE")"
if [[ ! -f "$TASK_FILE" ]]; then
  cat > "$TASK_FILE" <<TASK
# 任务执行记录：$TASK_ID

- agent_id: $AGENT_ID
- started_at: $(date '+%Y-%m-%d %H:%M:%S %z')
- note: $NOTE

## 实施步骤
- 

## 本轮问题
- 

## 下一步
- 
TASK
fi

echo "TASK_CLAIMED_AND_STARTED"
echo "TASK_FILE=$TASK_FILE"
