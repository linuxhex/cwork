#!/usr/bin/env bash
set -euo pipefail

fail(){ echo "ERROR: $*" >&2; exit 1; }

MAIN_DIR=""
REQUIREMENT_KEY=""
DEPS_RAW=""
OWNER=""
FROM_PHASE="brainstorming"
TO_PHASE="commit-code"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --main-dir) MAIN_DIR="$2"; shift 2 ;;
    --requirement-key) REQUIREMENT_KEY="$2"; shift 2 ;;
    --deps) DEPS_RAW="$2"; shift 2 ;;
    --owner) OWNER="$2"; shift 2 ;;
    --from-phase) FROM_PHASE="$2"; shift 2 ;;
    --to-phase) TO_PHASE="$2"; shift 2 ;;
    *) fail "unknown argument: $1" ;;
  esac
done

[[ -n "$MAIN_DIR" ]] || fail "--main-dir is required"
[[ -n "$REQUIREMENT_KEY" ]] || fail "--requirement-key is required"
[[ -n "$OWNER" ]] || OWNER="$(whoami)-pipeline-$$"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHECKPOINT="$SCRIPT_DIR/phase_checkpoint.sh"
PHASES=("brainstorming" "writing-plans" "executing-plans" "loop-refined" "commit-code")

started=false
for p in "${PHASES[@]}"; do
  if [[ "$p" == "$FROM_PHASE" ]]; then
    started=true
  fi
  [[ "$started" == "true" ]] || continue

  bash "$CHECKPOINT" --main-dir "$MAIN_DIR" --deps "$DEPS_RAW" --requirement-key "$REQUIREMENT_KEY" --phase "$p" --owner "$OWNER"
  echo "PIPELINE_PHASE_DONE=$p"

  if [[ "$p" == "$TO_PHASE" ]]; then
    break
  fi
done

echo "PIPELINE_DONE"
