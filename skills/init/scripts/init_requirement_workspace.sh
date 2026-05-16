#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  bash skills/init/scripts/init_requirement_workspace.sh \
    --main-dir <absolute_path> \
    --deps <dep1,dep2,...> \
    --feature-branch <feature_...> \
    --requirement-key <lowercase_underscore_key> \
    --requirement-title "<title>"
USAGE
}

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

validate_feature_branch() {
  local b="$1"

  [[ "$b" =~ ^feature_[A-Za-z_]+$ ]] || fail "branch must start with feature_ and contain only letters/underscores: $b"
  [[ ! "$b" =~ [0-9] ]] || fail "branch cannot contain digits: $b"

  IFS='_' read -r -a parts <<<"$b"
  [[ "${parts[0]}" == "feature" ]] || fail "branch must start with feature_: $b"
  (( ${#parts[@]} >= 2 )) || fail "branch must include at least one segment after feature_: $b"

  local seg
  local i
  for (( i=1; i<${#parts[@]}; i++ )); do
    seg="${parts[$i]}"
    [[ "$seg" =~ ^[a-z][A-Za-z]*$ ]] || fail "each segment must be lowerCamel letters only: $seg"
  done
}

assert_dir() {
  local d="$1"
  [[ -d "$d" ]] || fail "directory not found: $d"
}

assert_git_repo() {
  local repo="$1"
  git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "not a git repository: $repo"
}

force_discard_local_changes() {
  local repo="$1"
  git -C "$repo" reset --hard HEAD >/dev/null 2>&1 || fail "failed to reset tracked changes: $repo"
  git -C "$repo" clean -fd >/dev/null 2>&1 || fail "failed to clean untracked files: $repo"
}

checkout_feature_from_latest_master() {
  local repo="$1"
  local feature_branch="$2"

  assert_git_repo "$repo"

  git -C "$repo" remote get-url origin >/dev/null 2>&1 || fail "origin remote is required: $repo"
  force_discard_local_changes "$repo"

  git -C "$repo" fetch origin master >/dev/null 2>&1 || fail "failed to fetch origin/master: $repo"

  if git -C "$repo" show-ref --verify --quiet refs/heads/master; then
    git -C "$repo" checkout -f master >/dev/null 2>&1 || fail "failed to checkout local master: $repo"
  else
    git -C "$repo" checkout -B master origin/master >/dev/null 2>&1 || fail "failed to create local master from origin/master: $repo"
  fi

  git -C "$repo" reset --hard origin/master >/dev/null 2>&1 || fail "failed to align master with origin/master: $repo"

  if git -C "$repo" show-ref --verify --quiet "refs/heads/$feature_branch"; then
    git -C "$repo" checkout -f "$feature_branch" >/dev/null 2>&1 || fail "failed to switch existing local branch: $repo -> $feature_branch"
    printf '%s' "switched_existing_local"
    return 0
  fi

  if git -C "$repo" show-ref --verify --quiet "refs/remotes/origin/$feature_branch"; then
    git -C "$repo" checkout -B "$feature_branch" "origin/$feature_branch" >/dev/null 2>&1 || fail "failed to switch existing remote branch: $repo -> $feature_branch"
    printf '%s' "switched_existing_remote"
    return 0
  fi

  git -C "$repo" checkout -B "$feature_branch" master >/dev/null 2>&1 || fail "failed to create branch from latest master: $repo -> $feature_branch"
  printf '%s' "created_from_latest_master"
}

MAIN_DIR=""
DEPS_RAW=""
FEATURE_BRANCH=""
REQUIREMENT_KEY=""
REQUIREMENT_TITLE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --main-dir)
      MAIN_DIR="$2"
      shift 2
      ;;
    --deps)
      DEPS_RAW="$2"
      shift 2
      ;;
    --feature-branch)
      FEATURE_BRANCH="$2"
      shift 2
      ;;
    --requirement-key)
      REQUIREMENT_KEY="$2"
      shift 2
      ;;
    --requirement-title)
      REQUIREMENT_TITLE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

[[ -n "$MAIN_DIR" ]] || fail "--main-dir is required"
[[ -n "$FEATURE_BRANCH" ]] || fail "--feature-branch is required"
[[ -n "$REQUIREMENT_KEY" ]] || fail "--requirement-key is required"
[[ -n "$REQUIREMENT_TITLE" ]] || fail "--requirement-title is required"

[[ "$MAIN_DIR" = /* ]] || fail "--main-dir must be an absolute path"
assert_dir "$MAIN_DIR"
validate_feature_branch "$FEATURE_BRANCH"
[[ "$REQUIREMENT_KEY" =~ ^[a-z_]+$ ]] || fail "requirement-key must contain lowercase letters and underscores only"

TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S %z')"

DEP_LINES=""
if [[ -n "$DEPS_RAW" ]]; then
  while IFS= read -r line; do
    t="$(trim "$line")"
    if [[ -n "$t" ]]; then
      DEP_LINES="${DEP_LINES}${t}"$'\n'
    fi
  done < <(tr ',' '\n' <<<"$DEPS_RAW")
fi

if [[ -n "$DEP_LINES" ]]; then
  while IFS= read -r dep; do
    [[ -z "$dep" ]] && continue
    [[ "$dep" = /* ]] || fail "dependency path must be absolute: $dep"
    assert_dir "$dep"
    assert_git_repo "$dep"
  done <<<"$DEP_LINES"
fi

BRANCH_LOG_LINES=""
SPLIT_ACTION_LINES=""

main_branch_action="$(checkout_feature_from_latest_master "$MAIN_DIR" "$FEATURE_BRANCH")"
BRANCH_LOG_LINES="${BRANCH_LOG_LINES}"$'\n'"$MAIN_DIR|$main_branch_action|$FEATURE_BRANCH"
if [[ -n "$DEP_LINES" ]]; then
  while IFS= read -r dep; do
    [[ -z "$dep" ]] && continue
    dep_branch_action="$(checkout_feature_from_latest_master "$dep" "$FEATURE_BRANCH")"
    BRANCH_LOG_LINES="${BRANCH_LOG_LINES}"$'\n'"$dep|$dep_branch_action|$FEATURE_BRANCH"
  done <<<"$DEP_LINES"
fi

MAIN_DOC_DIR="$MAIN_DIR/docs/requirements/$REQUIREMENT_KEY"
mkdir -p "$MAIN_DOC_DIR/dependencies" "$MAIN_DOC_DIR/process"

cat > "$MAIN_DOC_DIR/00-context.md" <<CTX
# 需求上下文

- requirement_key: $REQUIREMENT_KEY
- requirement_title: $REQUIREMENT_TITLE
- feature_branch: $FEATURE_BRANCH
- 主工程: $MAIN_DIR
- 初始化时间: $TIMESTAMP

## 依赖工程
CTX

if [[ -z "$DEP_LINES" ]]; then
  printf '%s\n' '- 无' >> "$MAIN_DOC_DIR/00-context.md"
else
  while IFS= read -r dep; do
    [[ -z "$dep" ]] && continue
    printf '%s\n' "- $dep" >> "$MAIN_DOC_DIR/00-context.md"
  done <<<"$DEP_LINES"
fi

cat > "$MAIN_DOC_DIR/01-analysis.md" <<ANALYSIS
# 需求分析

## 背景
$REQUIREMENT_TITLE

## 目标
- 

## 范围内
- 

## 范围外
- 

## 主工程改动点
- 

## 依赖工程改动点
- 

## 风险与防护
- 

## 验收标准
- 
ANALYSIS

cat > "$MAIN_DOC_DIR/02-plan.md" <<PLAN
# 执行计划

## 任务清单
- [ ] 任务 1（工程：）
- [ ] 任务 2（工程：）

## 验证命令
- 

## 回滚策略
- 
PLAN

cat > "$MAIN_DOC_DIR/03-changes.md" <<CHANGES
# 改动与推演记录

## 逻辑推演轮次

### Round 1
- 发现：
- 修复：
- 复验：

CHANGES

cat > "$MAIN_DOC_DIR/04-process-record.md" <<PROCESS
# 执行过程记录

- 时间: $TIMESTAMP
- requirement_key: $REQUIREMENT_KEY
- feature_branch: $FEATURE_BRANCH
- 主工程: $MAIN_DIR

## 分支处理结果（repo|action|branch）
PROCESS

printf '%s\n' "$BRANCH_LOG_LINES" | sed '/^$/d' >> "$MAIN_DOC_DIR/04-process-record.md"

cat > "$MAIN_DOC_DIR/05-split-actions.md" <<SPLIT
# 子工程拆分动作记录

- 时间: $TIMESTAMP
- 源目录: $MAIN_DOC_DIR

## 拆分动作（target_repo|target_file|source_hint）
SPLIT

if [[ -n "$DEP_LINES" ]]; then
while IFS= read -r dep; do
  [[ -z "$dep" ]] && continue
  dep_name="$(basename "$dep")"
  dep_doc_dir="$dep/docs/requirements/$REQUIREMENT_KEY"
  mkdir -p "$dep_doc_dir"

  cat > "$dep_doc_dir/00-demand-from-main.md" <<DEMAND
# 来自主工程的需求拆分

- requirement_key: $REQUIREMENT_KEY
- requirement_title: $REQUIREMENT_TITLE
- feature_branch: $FEATURE_BRANCH
- 主工程: $MAIN_DIR
- 当前工程: $dep

## 当前工程需要承接的职责
- 
DEMAND

  cat > "$dep_doc_dir/01-change-points.md" <<POINTS
# 当前工程改动点

## 模块/文件
- 

## 契约变更
- 

## 风险
- 
POINTS

  cat > "$dep_doc_dir/02-plan-from-main.md" <<DPLAN
# 当前工程执行计划

## 任务
- [ ] 

## 验证
- 
DPLAN

  cat > "$MAIN_DOC_DIR/dependencies/$dep_name.md" <<MIRROR
# 依赖工程：$dep_name

- 路径: $dep
- 文档目录: $dep_doc_dir
- feature_branch: $FEATURE_BRANCH

## 该工程改动摘要
- 
MIRROR

  cat > "$dep_doc_dir/99-dispatch-receipt.md" <<RECEIPT
# 拆分接收记录

- 时间: $TIMESTAMP
- 来源主工程: $MAIN_DIR
- requirement_key: $REQUIREMENT_KEY
- feature_branch: $FEATURE_BRANCH

## 接收文件
- $dep_doc_dir/00-demand-from-main.md
- $dep_doc_dir/01-change-points.md
- $dep_doc_dir/02-plan-from-main.md
RECEIPT

  SPLIT_ACTION_LINES="${SPLIT_ACTION_LINES}"$'\n'"$dep|$dep_doc_dir/00-demand-from-main.md|$MAIN_DOC_DIR/01-analysis.md"
  SPLIT_ACTION_LINES="${SPLIT_ACTION_LINES}"$'\n'"$dep|$dep_doc_dir/01-change-points.md|$MAIN_DOC_DIR/03-changes.md"
  SPLIT_ACTION_LINES="${SPLIT_ACTION_LINES}"$'\n'"$dep|$dep_doc_dir/02-plan-from-main.md|$MAIN_DOC_DIR/02-plan.md"
  SPLIT_ACTION_LINES="${SPLIT_ACTION_LINES}"$'\n'"$dep|$dep_doc_dir/99-dispatch-receipt.md|dispatch-receipt"
done <<<"$DEP_LINES"
fi

if [[ -n "$SPLIT_ACTION_LINES" ]]; then
  printf '%s\n' "$SPLIT_ACTION_LINES" | sed '/^$/d' >> "$MAIN_DOC_DIR/05-split-actions.md"
else
  printf '%s\n' "- 无依赖工程拆分动作" >> "$MAIN_DOC_DIR/05-split-actions.md"
fi

echo "INIT_DONE"
echo "MAIN_DOC_DIR=$MAIN_DOC_DIR"
echo "FEATURE_BRANCH=$FEATURE_BRANCH"
echo "MAIN_REPO=$MAIN_DIR"
if [[ -n "$DEP_LINES" ]]; then
  while IFS= read -r dep; do
    [[ -z "$dep" ]] && continue
    echo "DEP_REPO=$dep"
  done <<<"$DEP_LINES"
fi
