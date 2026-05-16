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

MAIN_ANALYSIS="$MAIN_DIR/docs/requirements/$REQUIREMENT_KEY/01-analysis.md"
[[ -f "$MAIN_ANALYSIS" ]] || fail "missing file: $MAIN_ANALYSIS"

ensure_section "$MAIN_ANALYSIS" "背景与目标" "- "
ensure_section "$MAIN_ANALYSIS" "范围内" "- "
ensure_section "$MAIN_ANALYSIS" "范围外" "- "
ensure_section "$MAIN_ANALYSIS" "主工程改动点" "- "
ensure_section "$MAIN_ANALYSIS" "依赖工程改动点" "- "
ensure_section "$MAIN_ANALYSIS" "契约影响（字段/状态/事件）" "- "
ensure_section "$MAIN_ANALYSIS" "风险与防护" "- "
ensure_section "$MAIN_ANALYSIS" "验收标准" "- "

if [[ -n "$DEPS_RAW" ]]; then
  while IFS= read -r dep; do
    dep="$(trim "$dep")"
    [[ -z "$dep" ]] && continue
    dep_analysis="$dep/docs/requirements/$REQUIREMENT_KEY/01-repo-analysis.md"
    [[ -f "$dep_analysis" ]] || continue
    ensure_section "$dep_analysis" "本工程目标理解" "- "
    ensure_section "$dep_analysis" "本工程改动范围" "- "
    ensure_section "$dep_analysis" "契约与边界" "- "
    ensure_section "$dep_analysis" "风险口径" "- "
    ensure_section "$dep_analysis" "与主工程一致性检查" "- "
  done < <(tr ',' '\n' <<<"$DEPS_RAW")
fi

echo "BRAINSTORMING_DOCS_PREPARED"
