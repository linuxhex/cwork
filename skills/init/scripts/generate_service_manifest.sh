#!/usr/bin/env bash
set -euo pipefail

fail(){ echo "ERROR: $*" >&2; exit 1; }
trim(){ local v="$1"; v="${v#"${v%%[![:space:]]*}"}"; v="${v%"${v##*[![:space:]]}"}"; printf '%s' "$v"; }

MAIN_DIR=""
REQUIREMENT_KEY=""
DEPS_RAW=""
FEATURE_BRANCH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --main-dir) MAIN_DIR="$2"; shift 2 ;;
    --requirement-key) REQUIREMENT_KEY="$2"; shift 2 ;;
    --deps) DEPS_RAW="$2"; shift 2 ;;
    --feature-branch) FEATURE_BRANCH="$2"; shift 2 ;;
    *) fail "unknown argument: $1" ;;
  esac
done

[[ -n "$MAIN_DIR" ]] || fail "--main-dir is required"
[[ -n "$REQUIREMENT_KEY" ]] || fail "--requirement-key is required"

REQ_DIR="$MAIN_DIR/docs/requirements/$REQUIREMENT_KEY"
mkdir -p "$REQ_DIR"
OUT="$REQ_DIR/07-service-topology.md"

{
  echo "# 微服务拓扑与职责清单"
  echo
  echo "- requirement_key: $REQUIREMENT_KEY"
  echo "- feature_branch: ${FEATURE_BRANCH:-N/A}"
  echo "- generated_at: $(date '+%Y-%m-%d %H:%M:%S %z')"
  echo
  echo "## 主工程"
  echo "- name: $(basename "$MAIN_DIR")"
  echo "- path: $MAIN_DIR"
  echo "- role: orchestrator"
  echo
  echo "## 依赖工程"
} > "$OUT"

if [[ -z "$DEPS_RAW" ]]; then
  echo "- 无" >> "$OUT"
else
  while IFS= read -r dep; do
    dep="$(trim "$dep")"
    [[ -z "$dep" ]] && continue
    {
      echo "- name: $(basename "$dep")"
      echo "  path: $dep"
      echo "  role: to-be-defined"
      echo "  inbound_contract:"
      echo "    - "
      echo "  outbound_contract:"
      echo "    - "
      echo "  risk_focus:"
      echo "    - "
    } >> "$OUT"
  done < <(tr ',' '\n' <<<"$DEPS_RAW")
fi

echo "SERVICE_MANIFEST_GENERATED"
echo "FILE=$OUT"
