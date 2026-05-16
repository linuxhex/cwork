#!/usr/bin/env bash
set -euo pipefail

fail() { echo "ERROR: $*" >&2; exit 1; }
trim() {
  local v="$1"
  v="${v#"${v%%[![:space:]]*}"}"
  v="${v%"${v##*[![:space:]]}"}"
  printf '%s' "$v"
}

MAIN_DIR=""
REQUIREMENT_KEY=""
ROUND=""
SUMMARY=""
OPEN_ISSUES=""
CLOSED_ISSUES=""
DEPS_RAW=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --main-dir) MAIN_DIR="$2"; shift 2 ;;
    --requirement-key) REQUIREMENT_KEY="$2"; shift 2 ;;
    --round) ROUND="$2"; shift 2 ;;
    --summary) SUMMARY="$2"; shift 2 ;;
    --open-issues) OPEN_ISSUES="$2"; shift 2 ;;
    --closed-issues) CLOSED_ISSUES="$2"; shift 2 ;;
    --deps) DEPS_RAW="$2"; shift 2 ;;
    *) fail "unknown argument: $1" ;;
  esac
done

[[ -n "$MAIN_DIR" ]] || fail "--main-dir is required"
[[ -n "$REQUIREMENT_KEY" ]] || fail "--requirement-key is required"
[[ -n "$ROUND" ]] || fail "--round is required"
[[ "$MAIN_DIR" = /* ]] || fail "--main-dir must be absolute"
[[ "$ROUND" =~ ^[0-9]+$ ]] || fail "--round must be number"

MAIN_REQ_DIR="$MAIN_DIR/docs/requirements/$REQUIREMENT_KEY"
[[ -d "$MAIN_REQ_DIR" ]] || fail "missing requirement dir: $MAIN_REQ_DIR"

ROUND_FILE="$MAIN_REQ_DIR/process/round-${ROUND}.md"
mkdir -p "$(dirname "$ROUND_FILE")"

cat > "$ROUND_FILE" <<ROUNDMD
# Loop Refined Round $ROUND

- at: $(date '+%Y-%m-%d %H:%M:%S %z')
- summary: ${SUMMARY:-N/A}
- open_issues: ${OPEN_ISSUES:-0}
- closed_issues: ${CLOSED_ISSUES:-0}

## 推演范围
- 主工程：$MAIN_DIR

## 发现的问题
- 

## 修复动作
- 

## 回归验证
- 

## 下一轮计划
- 
ROUNDMD

MAIN_CHANGES="$MAIN_REQ_DIR/03-changes.md"
if [[ -f "$MAIN_CHANGES" ]] && ! rg -n "^## Round ${ROUND}$" "$MAIN_CHANGES" >/dev/null 2>&1; then
  {
    printf '\n## Round %s\n' "$ROUND"
    printf '%s\n' "- summary: ${SUMMARY:-N/A}"
    printf '%s\n' "- open_issues: ${OPEN_ISSUES:-0}"
    printf '%s\n' "- closed_issues: ${CLOSED_ISSUES:-0}"
    printf '%s\n' "- findings:"
    printf '%s\n' "- fixes:"
    printf '%s\n' "- regressions:"
  } >> "$MAIN_CHANGES"
fi

if [[ -n "$DEPS_RAW" ]]; then
  while IFS= read -r dep; do
    dep="$(trim "$dep")"
    [[ -z "$dep" ]] && continue
    dep_changes="$dep/docs/requirements/$REQUIREMENT_KEY/03-repo-changes.md"
    [[ -f "$dep_changes" ]] || continue
    if ! rg -n "^## Round ${ROUND}$" "$dep_changes" >/dev/null 2>&1; then
      {
        printf '\n## Round %s\n' "$ROUND"
        printf '%s\n' "- findings:"
        printf '%s\n' "- fixes:"
        printf '%s\n' "- verify:"
      } >> "$dep_changes"
    fi
  done < <(tr ',' '\n' <<<"$DEPS_RAW")
fi

echo "LOOP_ROUND_RECORDED"
echo "ROUND_FILE=$ROUND_FILE"
