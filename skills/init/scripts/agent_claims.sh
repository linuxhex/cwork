#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

REPO=""
REQUIREMENT_KEY=""
ACTION=""
AGENT_ID=""
TASK_ID=""
STATUS=""
NOTE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --requirement-key) REQUIREMENT_KEY="$2"; shift 2 ;;
    --action) ACTION="$2"; shift 2 ;;
    --agent-id) AGENT_ID="$2"; shift 2 ;;
    --task-id) TASK_ID="$2"; shift 2 ;;
    --status) STATUS="$2"; shift 2 ;;
    --note) NOTE="$2"; shift 2 ;;
    *) fail "unknown argument: $1" ;;
  esac
done

[[ -n "$REPO" ]] || fail "--repo is required"
[[ -n "$REQUIREMENT_KEY" ]] || fail "--requirement-key is required"
[[ -n "$ACTION" ]] || fail "--action is required"
[[ "$REPO" = /* ]] || fail "--repo must be absolute"

CLAIMS_DIR="$REPO/docs/requirements/$REQUIREMENT_KEY"
CLAIMS_FILE="$CLAIMS_DIR/agent-claims.json"
CLAIMS_HISTORY_FILE="$CLAIMS_DIR/agent-claims.history.jsonl"
mkdir -p "$CLAIMS_DIR"

python3 - "$CLAIMS_FILE" "$CLAIMS_HISTORY_FILE" "$REQUIREMENT_KEY" "$ACTION" "$AGENT_ID" "$TASK_ID" "$STATUS" "$NOTE" <<'PY'
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

claims_file = Path(sys.argv[1])
claims_history_file = Path(sys.argv[2])
requirement_key = sys.argv[3]
action = sys.argv[4]
agent_id = sys.argv[5]
task_id = sys.argv[6]
status = sys.argv[7]
note = sys.argv[8]

def now():
    return datetime.now(timezone.utc).astimezone().isoformat()

def default_doc():
    return {
        "requirement_key": requirement_key,
        "updated_at": now(),
        "claims": []
    }

def load_doc():
    if claims_file.exists():
        return json.loads(claims_file.read_text(encoding="utf-8"))
    return default_doc()

def save_doc(doc):
    doc["updated_at"] = now()
    claims_file.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


doc = load_doc()
if doc.get("requirement_key") != requirement_key:
    raise SystemExit(f"ERROR: requirement key mismatch in claims file: {doc.get('requirement_key')} != {requirement_key}")

claims = doc.setdefault("claims", [])

if action == "init":
    save_doc(default_doc())
    print("CLAIMS_INIT_DONE")
    raise SystemExit(0)

if action == "list":
    print(json.dumps(doc, ensure_ascii=False, indent=2))
    raise SystemExit(0)

if action == "claim":
    if not agent_id or not task_id:
        raise SystemExit("ERROR: --agent-id and --task-id are required for claim")
    for c in claims:
        if c["task_id"] == task_id and c["status"] in {"claimed", "in_progress"} and c["agent_id"] != agent_id:
            raise SystemExit(f"ERROR: task already claimed by {c['agent_id']}")
    claims.append({
        "task_id": task_id,
        "agent_id": agent_id,
        "status": "claimed",
        "note": note,
        "updated_at": now()
    })
    save_doc(doc)
    print("CLAIM_DONE")
    raise SystemExit(0)

if action == "update":
    if not agent_id or not task_id or not status:
        raise SystemExit("ERROR: --agent-id --task-id --status are required for update")
    found = False
    for c in claims:
        if c["task_id"] == task_id and c["agent_id"] == agent_id:
            c["status"] = status
            if note:
                c["note"] = note
            c["updated_at"] = now()
            found = True
    if not found:
        raise SystemExit("ERROR: claim not found for agent/task")
    save_doc(doc)
    print("CLAIM_UPDATE_DONE")
    raise SystemExit(0)

if action == "release":
    if not agent_id or not task_id:
        raise SystemExit("ERROR: --agent-id and --task-id are required for release")
    before = len(claims)
    claims = [c for c in claims if not (c["task_id"] == task_id and c["agent_id"] == agent_id)]
    if len(claims) == before:
        raise SystemExit("ERROR: claim not found for release")
    doc["claims"] = claims
    save_doc(doc)
    print("CLAIM_RELEASE_DONE")
    raise SystemExit(0)

if action == "archive-completed":
    completed_status = {"done", "closed", "released", "skipped", "completed"}
    archived = [c for c in claims if c.get("status") in completed_status]
    remained = [c for c in claims if c.get("status") not in completed_status]

    if archived:
        claims_history_file.parent.mkdir(parents=True, exist_ok=True)
        with claims_history_file.open("a", encoding="utf-8") as f:
            for item in archived:
                f.write(json.dumps(
                    {"archived_at": now(), "requirement_key": requirement_key, "claim": item},
                    ensure_ascii=False
                ) + "\n")

    doc["claims"] = remained
    save_doc(doc)
    print("CLAIM_ARCHIVE_DONE")
    raise SystemExit(0)

raise SystemExit(f"ERROR: unknown action {action}")
PY
