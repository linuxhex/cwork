#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

REPO=""
REQUIREMENT_KEY=""
ACTION=""
PHASE=""
EXPECT_VERSION=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --requirement-key) REQUIREMENT_KEY="$2"; shift 2 ;;
    --action) ACTION="$2"; shift 2 ;;
    --phase) PHASE="$2"; shift 2 ;;
    --expect-version) EXPECT_VERSION="$2"; shift 2 ;;
    *) fail "unknown argument: $1" ;;
  esac
done

[[ -n "$REPO" ]] || fail "--repo is required"
[[ -n "$REQUIREMENT_KEY" ]] || fail "--requirement-key is required"
[[ -n "$ACTION" ]] || fail "--action is required"
[[ "$REPO" = /* ]] || fail "--repo must be absolute"

if [[ -n "$EXPECT_VERSION" ]]; then
  [[ "$EXPECT_VERSION" =~ ^[0-9]+$ ]] || fail "--expect-version must be non-negative integer"
fi

STATE_DIR="$REPO/docs/requirements/$REQUIREMENT_KEY"
STATE_FILE="$STATE_DIR/workflow-state.json"
mkdir -p "$STATE_DIR"

python3 - "$STATE_FILE" "$REQUIREMENT_KEY" "$ACTION" "$PHASE" "$EXPECT_VERSION" <<'PY'
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

state_file = Path(sys.argv[1])
requirement_key = sys.argv[2]
action = sys.argv[3]
phase = sys.argv[4]
expect_version_raw = sys.argv[5]
expect_version = int(expect_version_raw) if expect_version_raw else None

phases = ["init", "brainstorming", "writing-plans", "executing-plans", "loop-refined", "commit-code", "done"]

def now():
    return datetime.now(timezone.utc).astimezone().isoformat()

def default_state():
    return {
        "requirement_key": requirement_key,
        "current_phase": "init",
        "version": 1,
        "updated_at": now(),
        "history": [{"phase": "init", "at": now(), "action": "init_state", "version": 1}],
    }

def load_state():
    if state_file.exists():
        s = json.loads(state_file.read_text(encoding="utf-8"))
        s.setdefault("version", 1)
        s.setdefault("history", [])
        return s
    return default_state()

def write_state(s):
    s["updated_at"] = now()
    state_file.write_text(json.dumps(s, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

def assert_expect_version(s):
    if expect_version is not None and int(s.get("version", 1)) != expect_version:
        raise SystemExit(f"ERROR: state version mismatch, current={s.get('version')}, expected={expect_version}")

def next_phase(current):
    if current not in phases:
        raise SystemExit(f"ERROR: unknown current phase {current}")
    idx = phases.index(current)
    if idx + 1 >= len(phases):
        raise SystemExit(f"ERROR: no next phase from {current}")
    return phases[idx + 1]

state = load_state()
if state.get("requirement_key") != requirement_key:
    raise SystemExit(f"ERROR: requirement key mismatch in state file: {state.get('requirement_key')} != {requirement_key}")

current = state.get("current_phase", "init")

if action == "init":
    if expect_version is not None:
        assert_expect_version(state)
    state = default_state()
    write_state(state)
    print("STATE_INIT_DONE")
    raise SystemExit(0)

if action == "get":
    print(current)
    raise SystemExit(0)

if action == "get-version":
    print(str(state.get("version", 1)))
    raise SystemExit(0)

if action == "assert":
    if not phase:
        raise SystemExit("ERROR: --phase is required for assert")
    if current != phase:
        raise SystemExit(f"ERROR: phase assert failed, current={current}, expected={phase}")
    print("STATE_ASSERT_OK")
    raise SystemExit(0)

if action == "can-advance":
    if not phase:
        raise SystemExit("ERROR: --phase is required for can-advance")
    if phase not in phases:
        raise SystemExit(f"ERROR: unknown phase {phase}")
    if current == phase:
        print("STATE_CAN_ADVANCE_TOUCH")
        raise SystemExit(0)
    expected = next_phase(current)
    if phase != expected:
        raise SystemExit(f"ERROR: invalid phase transition {current} -> {phase}, expected {expected}")
    print("STATE_CAN_ADVANCE_OK")
    raise SystemExit(0)

if action == "advance":
    if not phase:
        raise SystemExit("ERROR: --phase is required for advance")
    if phase not in phases:
        raise SystemExit(f"ERROR: unknown phase {phase}")

    assert_expect_version(state)
    if current == phase:
        state["version"] = int(state.get("version", 1)) + 1
        state.setdefault("history", []).append({"phase": phase, "at": now(), "action": "touch_phase", "version": state["version"]})
        write_state(state)
        print(f"STATE_TOUCH_DONE:{state['version']}")
        raise SystemExit(0)

    expected = next_phase(current)
    if phase != expected:
        raise SystemExit(f"ERROR: invalid phase transition {current} -> {phase}, expected {expected}")

    state["current_phase"] = phase
    state["version"] = int(state.get("version", 1)) + 1
    state.setdefault("history", []).append({"phase": phase, "at": now(), "action": "advance_phase", "version": state["version"]})
    write_state(state)
    print(f"STATE_ADVANCE_DONE:{state['version']}")
    raise SystemExit(0)

if action == "force-set":
    if not phase:
        raise SystemExit("ERROR: --phase is required for force-set")
    if phase not in phases:
        raise SystemExit(f"ERROR: unknown phase {phase}")
    assert_expect_version(state)
    state["current_phase"] = phase
    state["version"] = int(state.get("version", 1)) + 1
    state.setdefault("history", []).append({"phase": phase, "at": now(), "action": "force_set_phase", "version": state["version"]})
    write_state(state)
    print(f"STATE_FORCE_SET_DONE:{state['version']}")
    raise SystemExit(0)

raise SystemExit(f"ERROR: unknown action {action}")
PY
