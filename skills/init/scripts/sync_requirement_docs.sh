#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

trim() {
  local v="$1"
  v="${v#"${v%%[![:space:]]*}"}"
  v="${v%"${v##*[![:space:]]}"}"
  printf '%s' "$v"
}

write_if_changed_from_stdin() {
  local target="$1"
  local dir
  local tmp
  dir="$(dirname "$target")"
  mkdir -p "$dir"
  tmp="$(mktemp)"
  cat > "$tmp"
  if [[ -f "$target" ]] && cmp -s "$tmp" "$target"; then
    rm -f "$tmp"
    return 0
  fi
  mv "$tmp" "$target"
}

append_history_once() {
  local history_file="$1"
  local signature="$2"
  local line="$3"

  if [[ ! -f "$history_file" ]]; then
    cat > "$history_file" <<HISTORY
# 活跃需求历史

HISTORY
  fi

  if ! rg -Fq "$signature" "$history_file"; then
    printf '%s\n' "$line" >> "$history_file"
  fi
}

short_path_hash() {
  local v="$1"
  if command -v shasum >/dev/null 2>&1; then
    printf '%s' "$v" | shasum | awk '{print substr($1,1,8)}'
    return 0
  fi
  printf '%s' "$v" | cksum | awk '{print $1}'
}

MAIN_DIR=""
REQUIREMENT_KEY=""
DEPS_RAW=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --main-dir)
      MAIN_DIR="$2"; shift 2 ;;
    --requirement-key)
      REQUIREMENT_KEY="$2"; shift 2 ;;
    --deps)
      DEPS_RAW="$2"; shift 2 ;;
    *)
      fail "unknown argument: $1" ;;
  esac
done

[[ -n "$MAIN_DIR" ]] || fail "--main-dir is required"
[[ -n "$REQUIREMENT_KEY" ]] || fail "--requirement-key is required"
[[ "$MAIN_DIR" = /* ]] || fail "--main-dir must be absolute"
[[ -d "$MAIN_DIR" ]] || fail "main dir not found: $MAIN_DIR"

MAIN_DOC_DIR="$MAIN_DIR/docs/requirements/$REQUIREMENT_KEY"
[[ -d "$MAIN_DOC_DIR" ]] || fail "main requirement doc dir not found: $MAIN_DOC_DIR"

CONTEXT_FILE="$MAIN_DOC_DIR/00-context.md"
ANALYSIS_FILE="$MAIN_DOC_DIR/01-analysis.md"
PLAN_FILE="$MAIN_DOC_DIR/02-plan.md"
CHANGES_FILE="$MAIN_DOC_DIR/03-changes.md"
SPLIT_FILE="$MAIN_DOC_DIR/05-split-actions.md"

[[ -f "$CONTEXT_FILE" ]] || fail "missing file: $CONTEXT_FILE"
[[ -f "$ANALYSIS_FILE" ]] || fail "missing file: $ANALYSIS_FILE"
[[ -f "$PLAN_FILE" ]] || fail "missing file: $PLAN_FILE"
[[ -f "$CHANGES_FILE" ]] || fail "missing file: $CHANGES_FILE"

requirement_title="$(sed -n 's/^- requirement_title: //p' "$CONTEXT_FILE" | head -n1)"
feature_branch="$(sed -n 's/^- feature_branch: //p' "$CONTEXT_FILE" | head -n1)"
main_repo="$(sed -n 's/^- 主工程: //p' "$CONTEXT_FILE" | head -n1)"

[[ -n "$requirement_title" ]] || requirement_title="(未填写)"
[[ -n "$feature_branch" ]] || feature_branch="(未填写)"
[[ -n "$main_repo" ]] || main_repo="$MAIN_DIR"

DEP_LINES=""
if [[ -n "$DEPS_RAW" ]]; then
  while IFS= read -r line; do
    t="$(trim "$line")"
    [[ -n "$t" ]] && DEP_LINES="${DEP_LINES}${t}"$'\n'
  done < <(tr ',' '\n' <<<"$DEPS_RAW")
fi

if [[ -z "$DEP_LINES" ]]; then
  exit 0
fi

mkdir -p "$MAIN_DOC_DIR/dependencies"
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S %z')"
SPLIT_ACTION_LINES=""

write_active_requirement_marker() {
  local repo="$1"
  local role="$2"
  local repo_doc_dir="$3"
  local history_file
  local signature
  local history_line

  mkdir -p "$repo/docs/requirements"
  history_file="$repo/docs/requirements/ACTIVE_REQUIREMENT_HISTORY.md"
  signature="key=$REQUIREMENT_KEY | branch=$feature_branch | role=$role | doc=$repo_doc_dir"
  history_line="- $TIMESTAMP | $signature"
  append_history_once "$history_file" "$signature" "$history_line"

  write_if_changed_from_stdin "$repo/docs/requirements/ACTIVE_REQUIREMENT.md" <<ACTIVE
# 当前活跃需求

- requirement_key: $REQUIREMENT_KEY
- requirement_title: $requirement_title
- feature_branch: $feature_branch
- repo_role: $role
- main_repo: $main_repo
- repo_doc_dir: $repo_doc_dir

## 使用方式
- 在当前工程目录内直接基于本文件和 \`repo_doc_dir\` 下文档继续对话。
- 不要求先回到主工程对话。
ACTIVE
}

while IFS= read -r dep; do
  [[ -z "$dep" ]] && continue
  [[ "$dep" = /* ]] || fail "dependency path must be absolute: $dep"
  [[ -d "$dep" ]] || fail "dependency dir not found: $dep"

  dep_name="$(basename "$dep")"
  dep_hash="$(short_path_hash "$dep")"
  dep_doc_dir="$dep/docs/requirements/$REQUIREMENT_KEY"
  dep_main_mirror="$MAIN_DOC_DIR/dependencies/${dep_name}__${dep_hash}.md"
  dep_custom_perspective="$dep_doc_dir/10-repo-perspective-custom.md"
  dep_custom_contract="$dep_doc_dir/11-repo-contract-custom.md"
  dep_allowlist="$dep_doc_dir/commit-allowlist.txt"
  mkdir -p "$dep_doc_dir"

  if [[ ! -f "$dep_doc_dir/00-repo-context.md" ]]; then
  cat > "$dep_doc_dir/00-repo-context.md" <<DEMAND
# 当前工程需求上下文（工程视角）

- requirement_key: $REQUIREMENT_KEY
- requirement_title: $requirement_title
- feature_branch: $feature_branch
- 主工程: $main_repo
- 当前工程: $dep

## 当前工程需要承接的职责
- 结合主工程总说明，明确本工程改动边界。
- 保持与主工程、其他依赖工程的契约一致。
DEMAND
  fi

  if [[ ! -f "$dep_doc_dir/01-repo-analysis.md" ]]; then
  cat > "$dep_doc_dir/01-repo-analysis.md" <<POINTS
# 当前工程需求分析（工程视角）

## 主工程总分析映射
- 来源: $ANALYSIS_FILE

## 当前工程改动范围
- 

## 与主工程/其他工程的契约关系
- 

## 本工程独立认知（自动同步不会覆盖）
- 见：$dep_custom_perspective
- 见：$dep_custom_contract

## 风险
- 
POINTS
  fi

  if [[ ! -f "$dep_doc_dir/02-repo-plan.md" ]]; then
  cat > "$dep_doc_dir/02-repo-plan.md" <<DPLAN
# 当前工程执行计划（工程视角）

## 主工程总计划映射
- 来源: $PLAN_FILE

## 当前工程任务
- [ ] 

## 验证方式（默认 loop-refined）
- 

## 任务边界补充（自动同步不会覆盖）
- 见：$dep_custom_perspective
DPLAN
  fi

  if [[ ! -f "$dep_doc_dir/03-repo-changes.md" ]]; then
  cat > "$dep_doc_dir/03-repo-changes.md" <<DCHANGES
# 当前工程改动与推演记录（工程视角）

## 主工程总改动映射
- 来源: $CHANGES_FILE

## Round 1
- 发现：
- 修复：
- 复验：

## 工程特有判断依据（自动同步不会覆盖）
- 见：$dep_custom_contract
DCHANGES
  fi

  write_if_changed_from_stdin "$dep_doc_dir/98-main-doc-links.md" <<DLINKS
# 主工程文档映射

- 主工程目录: $main_repo
- 主工程需求目录: $MAIN_DOC_DIR
- 主工程 01-analysis: $ANALYSIS_FILE
- 主工程 02-plan: $PLAN_FILE
- 主工程 03-changes: $CHANGES_FILE
DLINKS

  write_if_changed_from_stdin "$dep_doc_dir/99-dispatch-receipt.md" <<RECEIPT
# 拆分接收记录

- 来源主工程: $main_repo
- requirement_key: $REQUIREMENT_KEY
- feature_branch: $feature_branch

## 接收文件
- $dep_doc_dir/00-repo-context.md
- $dep_doc_dir/01-repo-analysis.md
- $dep_doc_dir/02-repo-plan.md
- $dep_doc_dir/03-repo-changes.md
RECEIPT

  if [[ ! -f "$dep_custom_perspective" ]]; then
    cat > "$dep_custom_perspective" <<CPER
# 本工程独立需求认知（手工维护，不会被自动同步覆盖）

- 工程名称: $dep_name
- 工程路径: $dep
- requirement_key: $REQUIREMENT_KEY

## 这个工程眼里的需求目标
- 

## 这个工程必须保证的行为
- 

## 这个工程不负责的范围
- 

## 与其他工程协作时的注意事项
- 
CPER
  fi

  if [[ ! -f "$dep_custom_contract" ]]; then
    cat > "$dep_custom_contract" <<CCON
# 本工程契约与边界认知（手工维护，不会被自动同步覆盖）

## 输入契约（从谁来，字段/协议是什么）
- 

## 输出契约（给谁用，字段/协议是什么）
- 

## 兼容性要求
- 

## 风险判定口径（本工程）
- 
CCON
  fi

  if [[ ! -f "$dep_allowlist" ]]; then
    cat > "$dep_allowlist" <<DALLOW
# 可选：提交白名单（相对当前仓库根目录）
# 取消注释并维护需要纳入提交的路径。
# docs/requirements/$REQUIREMENT_KEY
# src/your/module/path
DALLOW
  fi

  write_if_changed_from_stdin "$dep_main_mirror" <<MIRROR
# 依赖工程：$dep_name

- 路径: $dep
- 文档目录: $dep_doc_dir
- feature_branch: $feature_branch

## 该工程改动摘要
- 
MIRROR

  write_active_requirement_marker "$dep" "dependency" "$dep_doc_dir"

  SPLIT_ACTION_LINES="${SPLIT_ACTION_LINES}"$'\n'"$dep|$dep_doc_dir/00-repo-context.md|$ANALYSIS_FILE"
  SPLIT_ACTION_LINES="${SPLIT_ACTION_LINES}"$'\n'"$dep|$dep_doc_dir/01-repo-analysis.md|$ANALYSIS_FILE"
  SPLIT_ACTION_LINES="${SPLIT_ACTION_LINES}"$'\n'"$dep|$dep_doc_dir/02-repo-plan.md|$PLAN_FILE"
  SPLIT_ACTION_LINES="${SPLIT_ACTION_LINES}"$'\n'"$dep|$dep_doc_dir/03-repo-changes.md|$CHANGES_FILE"
  SPLIT_ACTION_LINES="${SPLIT_ACTION_LINES}"$'\n'"$dep|$dep_doc_dir/98-main-doc-links.md|$MAIN_DOC_DIR"
  SPLIT_ACTION_LINES="${SPLIT_ACTION_LINES}"$'\n'"$dep|$dep_doc_dir/99-dispatch-receipt.md|dispatch-receipt"
  SPLIT_ACTION_LINES="${SPLIT_ACTION_LINES}"$'\n'"$dep|$dep_custom_perspective|repo-perspective-custom"
  SPLIT_ACTION_LINES="${SPLIT_ACTION_LINES}"$'\n'"$dep|$dep_custom_contract|repo-contract-custom"
  SPLIT_ACTION_LINES="${SPLIT_ACTION_LINES}"$'\n'"$dep|$dep_allowlist|commit-allowlist-template"
  SPLIT_ACTION_LINES="${SPLIT_ACTION_LINES}"$'\n'"$dep|$dep/docs/requirements/ACTIVE_REQUIREMENT.md|active-requirement-marker"
done <<<"$DEP_LINES"

{
  cat <<SPLIT
# 子工程拆分动作记录

- 源目录: $MAIN_DOC_DIR

## 拆分动作（target_repo|target_file|source_hint）
SPLIT
  printf '%s\n' "$SPLIT_ACTION_LINES" | sed '/^$/d'
} | write_if_changed_from_stdin "$SPLIT_FILE"
