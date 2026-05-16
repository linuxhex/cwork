#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SYNC_SCRIPT="$SCRIPT_DIR/sync_requirement_docs.sh"
STATE_SCRIPT="$SCRIPT_DIR/workflow_state.sh"
CLAIMS_SCRIPT="$SCRIPT_DIR/agent_claims.sh"

usage() {
  cat <<'USAGE'
Usage:
  bash skills/init/scripts/init_requirement_workspace.sh \
    --main-dir <absolute_path> \
    --deps <dep1,dep2,...> \
    --feature-branch <feature_...> \
    --requirement-key <lowercase_underscore_key> \
    --requirement-title "<title>" \
    --force-discard true
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
  git -C "$repo" reset --hard HEAD >/dev/null 2>&1 || return 1
  git -C "$repo" clean -fd >/dev/null 2>&1 || return 1
}

current_ref() {
  local repo="$1"
  git -C "$repo" symbolic-ref --quiet --short HEAD 2>/dev/null || git -C "$repo" rev-parse --short HEAD
}

preflight_repo() {
  local repo="$1"
  assert_git_repo "$repo"
  git -C "$repo" remote get-url origin >/dev/null 2>&1 || fail "origin remote is required: $repo"
  git -C "$repo" fetch origin --prune >/dev/null 2>&1 || fail "failed to fetch origin: $repo"
}

default_base_branch() {
  local repo="$1"
  local head_ref
  head_ref="$(git -C "$repo" symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null || true)"
  if [[ -n "$head_ref" ]]; then
    printf '%s' "${head_ref#refs/remotes/origin/}"
    return 0
  fi

  if git -C "$repo" show-ref --verify --quiet refs/remotes/origin/master; then
    printf 'master'
    return 0
  fi

  if git -C "$repo" show-ref --verify --quiet refs/remotes/origin/main; then
    printf 'main'
    return 0
  fi

  return 1
}

checkout_feature_from_latest_base() {
  local repo="$1"
  local feature_branch="$2"
  local base_branch="$3"

  force_discard_local_changes "$repo" || {
    echo "failed to discard local changes: $repo" >&2
    return 1
  }

  if git -C "$repo" show-ref --verify --quiet "refs/heads/$base_branch"; then
    git -C "$repo" checkout -f "$base_branch" >/dev/null 2>&1 || {
      echo "failed to checkout local $base_branch: $repo" >&2
      return 1
    }
  else
    git -C "$repo" checkout -B "$base_branch" "origin/$base_branch" >/dev/null 2>&1 || {
      echo "failed to create local $base_branch from origin/$base_branch: $repo" >&2
      return 1
    }
  fi

  git -C "$repo" reset --hard "origin/$base_branch" >/dev/null 2>&1 || {
    echo "failed to align $base_branch with origin/$base_branch: $repo" >&2
    return 1
  }

  if git -C "$repo" show-ref --verify --quiet "refs/heads/$feature_branch"; then
    git -C "$repo" checkout -f "$feature_branch" >/dev/null 2>&1 || {
      echo "failed to switch existing local branch: $repo -> $feature_branch" >&2
      return 1
    }
    printf '%s' "switched_existing_local"
    return 0
  fi

  if git -C "$repo" show-ref --verify --quiet "refs/remotes/origin/$feature_branch"; then
    git -C "$repo" checkout -B "$feature_branch" "origin/$feature_branch" >/dev/null 2>&1 || {
      echo "failed to switch existing remote branch: $repo -> $feature_branch" >&2
      return 1
    }
    printf '%s' "switched_existing_remote"
    return 0
  fi

  git -C "$repo" checkout -B "$feature_branch" "$base_branch" >/dev/null 2>&1 || {
    echo "failed to create branch from latest $base_branch: $repo -> $feature_branch" >&2
    return 1
  }
  printf '%s' "created_from_latest_base"
}

rollback_switched_repos() {
  local rollback_lines="$1"
  [[ -z "$rollback_lines" ]] && return 0

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    repo="${line%%|*}"
    ref="${line#*|}"
    git -C "$repo" checkout -f "$ref" >/dev/null 2>&1 || true
  done <<<"$rollback_lines"
}

write_active_requirement_marker() {
  local repo="$1"
  local role="$2"
  local repo_doc_dir="$3"
  local history_file

  mkdir -p "$repo/docs/requirements"
  history_file="$repo/docs/requirements/ACTIVE_REQUIREMENT_HISTORY.md"
  if [[ ! -f "$history_file" ]]; then
    cat > "$history_file" <<HISTORY
# 活跃需求历史

HISTORY
  fi
  printf '%s\n' "- $TIMESTAMP | key=$REQUIREMENT_KEY | branch=$FEATURE_BRANCH | role=$role | doc=$repo_doc_dir" >> "$history_file"

  cat > "$repo/docs/requirements/ACTIVE_REQUIREMENT.md" <<ACTIVE
# 当前活跃需求

- requirement_key: $REQUIREMENT_KEY
- requirement_title: $REQUIREMENT_TITLE
- feature_branch: $FEATURE_BRANCH
- repo_role: $role
- main_repo: $MAIN_DIR
- repo_doc_dir: $repo_doc_dir
- initialized_at: $TIMESTAMP

## 使用方式
- 在当前工程目录内直接基于本文件和 \`repo_doc_dir\` 下文档继续对话。
- 不要求先回到主工程对话。
ACTIVE
}

MAIN_DIR=""
DEPS_RAW=""
FEATURE_BRANCH=""
REQUIREMENT_KEY=""
REQUIREMENT_TITLE=""
FORCE_DISCARD="false"

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
    --force-discard)
      FORCE_DISCARD="$2"
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
[[ "$FORCE_DISCARD" == "true" ]] || fail "--force-discard true is required before destructive cleanup"

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
ROLLBACK_LINES=""
ALL_REPO_LINES="$MAIN_DIR"$'\n'"$DEP_LINES"
REPO_BASE_LINES=""

while IFS= read -r repo; do
  [[ -z "$repo" ]] && continue
  preflight_repo "$repo"
  repo_base="$(default_base_branch "$repo")" || fail "cannot resolve default branch from origin for repo: $repo"
  REPO_BASE_LINES="${REPO_BASE_LINES}"$'\n'"$repo|$repo_base"
done <<<"$ALL_REPO_LINES"

while IFS= read -r repo_base_line; do
  [[ -z "$repo_base_line" ]] && continue
  repo="${repo_base_line%%|*}"
  repo_base="${repo_base_line#*|}"
  repo_before_ref="$(current_ref "$repo")"
  if repo_branch_action="$(checkout_feature_from_latest_base "$repo" "$FEATURE_BRANCH" "$repo_base")"; then
    BRANCH_LOG_LINES="${BRANCH_LOG_LINES}"$'\n'"$repo|$repo_branch_action|$FEATURE_BRANCH|$repo_base"
    ROLLBACK_LINES="${ROLLBACK_LINES}"$'\n'"$repo|$repo_before_ref"
  else
    rollback_switched_repos "$ROLLBACK_LINES"
    fail "atomic switch failed, rolled back switched repos: $repo"
  fi
done <<<"$REPO_BASE_LINES"

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

## 验证方式（默认 loop-refined）
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

cat > "$MAIN_DOC_DIR/06-main-repo-perspective.md" <<MAINVIEW
# 主工程视角说明

- requirement_key: $REQUIREMENT_KEY
- requirement_title: $REQUIREMENT_TITLE
- 当前工程: $MAIN_DIR
- 角色: main

## 主工程必须承接
- 需求总线管理
- 跨工程拆分与联动记录
- 最终收敛与提交流程驱动

## 本工程改动摘要
- 

## 对依赖工程的约束
- 
MAINVIEW

if [[ ! -f "$MAIN_DOC_DIR/commit-allowlist.txt" ]]; then
  cat > "$MAIN_DOC_DIR/commit-allowlist.txt" <<ALLOW
# 可选：提交白名单（相对当前仓库根目录）
# 取消注释并维护需要纳入提交的路径。
# docs/requirements/$REQUIREMENT_KEY
# src/your/module/path
ALLOW
fi

write_active_requirement_marker "$MAIN_DIR" "main" "$MAIN_DOC_DIR"
bash "$STATE_SCRIPT" --repo "$MAIN_DIR" --requirement-key "$REQUIREMENT_KEY" --action init >/dev/null
bash "$CLAIMS_SCRIPT" --repo "$MAIN_DIR" --requirement-key "$REQUIREMENT_KEY" --action init >/dev/null

cat > "$MAIN_DOC_DIR/04-process-record.md" <<PROCESS
# 执行过程记录

- 时间: $TIMESTAMP
- requirement_key: $REQUIREMENT_KEY
- feature_branch: $FEATURE_BRANCH
- 主工程: $MAIN_DIR

## 分支处理结果（repo|action|branch|base_branch）
PROCESS

printf '%s\n' "$BRANCH_LOG_LINES" | sed '/^$/d' >> "$MAIN_DOC_DIR/04-process-record.md"

cat > "$MAIN_DOC_DIR/05-split-actions.md" <<SPLIT
# 子工程拆分动作记录

- 时间: $TIMESTAMP
- 源目录: $MAIN_DOC_DIR

## 拆分动作（target_repo|target_file|source_hint）
SPLIT

if [[ -n "$DEP_LINES" ]]; then
  bash "$SYNC_SCRIPT" \
    --main-dir "$MAIN_DIR" \
    --requirement-key "$REQUIREMENT_KEY" \
    --deps "$DEPS_RAW"

  while IFS= read -r dep; do
    [[ -z "$dep" ]] && continue
    bash "$STATE_SCRIPT" --repo "$dep" --requirement-key "$REQUIREMENT_KEY" --action init >/dev/null
    bash "$CLAIMS_SCRIPT" --repo "$dep" --requirement-key "$REQUIREMENT_KEY" --action init >/dev/null
  done <<<"$DEP_LINES"
else
  printf '%s\n' "- 无依赖工程拆分动作" >> "$MAIN_DOC_DIR/05-split-actions.md"
fi

echo "INIT_DONE"
echo "MAIN_DOC_DIR=$MAIN_DOC_DIR"
echo "FEATURE_BRANCH=$FEATURE_BRANCH"
echo "MAIN_REPO=$MAIN_DIR"
echo "NEXT_SKILL=brainstorming"
if [[ -n "$DEP_LINES" ]]; then
  while IFS= read -r dep; do
    [[ -z "$dep" ]] && continue
    echo "DEP_REPO=$dep"
  done <<<"$DEP_LINES"
fi
