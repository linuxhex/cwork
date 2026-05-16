#!/usr/bin/env bash
set -euo pipefail

fail() { echo "ERROR: $*" >&2; exit 1; }
trim() {
  local v="$1"
  v="${v#"${v%%[![:space:]]*}"}"
  v="${v%"${v##*[![:space:]]}"}"
  printf '%s' "$v"
}
ensure_section() {
  local file="$1"
  local title="$2"
  local body="$3"
  if ! rg -n "^## ${title}$" "$file" >/dev/null 2>&1; then
    {
      printf '\n## %s\n' "$title"
      printf '%s\n' "$body"
    } >> "$file"
  fi
}

MAIN_DIR=""
REQUIREMENT_KEY=""
DEPS_RAW=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --main-dir) MAIN_DIR="$2"; shift 2 ;;
    --requirement-key) REQUIREMENT_KEY="$2"; shift 2 ;;
    --deps) DEPS_RAW="$2"; shift 2 ;;
    *) fail "unknown argument: $1" ;;
  esac
done

[[ -n "$MAIN_DIR" ]] || fail "--main-dir is required"
[[ -n "$REQUIREMENT_KEY" ]] || fail "--requirement-key is required"
[[ "$MAIN_DIR" = /* ]] || fail "--main-dir must be absolute"

MAIN_PLAN="$MAIN_DIR/docs/requirements/$REQUIREMENT_KEY/02-plan.md"
[[ -f "$MAIN_PLAN" ]] || fail "missing file: $MAIN_PLAN"

ensure_section "$MAIN_PLAN" "计划摘要" "- 目标：\n- 范围：\n- 完成定义："
ensure_section "$MAIN_PLAN" "任务分解" "- [ ] 任务1："
ensure_section "$MAIN_PLAN" "跨工程顺序" "1. "
ensure_section "$MAIN_PLAN" "验证策略（loop-refined）" "- 第1轮：\n- 第2轮："
ensure_section "$MAIN_PLAN" "回滚策略" "- "
ensure_section "$MAIN_PLAN" "提交策略" "- commit type: add|del|modify|fix|refactor|docs"

if [[ -n "$DEPS_RAW" ]]; then
  while IFS= read -r dep; do
    dep="$(trim "$dep")"
    [[ -z "$dep" ]] && continue
    dep_plan="$dep/docs/requirements/$REQUIREMENT_KEY/02-repo-plan.md"
    [[ -f "$dep_plan" ]] || continue
    ensure_section "$dep_plan" "本工程任务" "- [ ] "
    ensure_section "$dep_plan" "前置依赖" "- "
    ensure_section "$dep_plan" "DoD" "- "
    ensure_section "$dep_plan" "本工程回滚" "- "
  done < <(tr ',' '\n' <<<"$DEPS_RAW")
fi

echo "PLAN_DOCS_PREPARED"
