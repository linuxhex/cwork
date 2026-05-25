#!/usr/bin/env bash
set -euo pipefail

# 一行命令初始化，不逐条确认
# 用法: init.sh <需求名> <需求ID> <分支名> <主工程路径> [依赖工程路径]

fail() { echo "ERROR: $*" >&2; exit 1; }

[[ $# -lt 4 ]] && fail "用法: init.sh <需求名> <需求ID> <分支名> <主工程路径> [依赖工程路径]"

REQ_TITLE="$1"
REQ_ID="$2"
FEATURE_BRANCH="$3"
MAIN_DIR="$4"
DEPS_RAW="${5:-}"

# 生成为 requirement_key（转小写，空格转下划线）
REQ_KEY=$(echo "$REQ_TITLE" | tr '[:upper:] ' '[:lower:]_')

# 校验需求ID格式
[[ "$REQ_ID" =~ ^OMJF-[0-9]+$ ]] || fail "需求ID格式错误，必须为 OMJF-数字，如 OMJF-12345"

# 校验
[[ -d "$MAIN_DIR" ]] || fail "主工程路径不存在: $MAIN_DIR"
git -C "$MAIN_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "不是 git 仓库: $MAIN_DIR"

[[ "$FEATURE_BRANCH" =~ ^feature_[A-Za-z_]+$ ]] || fail "分支名必须以 feature_ 开头，仅含字母和下划线"

# 依赖工程校验
DEP_DIRS=""
if [[ -n "$DEPS_RAW" ]]; then
  while IFS= read -r dep; do
    [[ -z "$dep" ]] && continue
    [[ -d "$dep" ]] || fail "依赖工程路径不存在: $dep"
    git -C "$dep" rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "不是 git 仓库: $dep"
    DEP_DIRS="$DEP_DIRS$dep"$'\n'
  done < <(tr ',' '\n' <<<"$DEPS_RAW")
fi

# 切换分支
switch_branch() {
  local repo="$1"
  local base_branch=""

  # 暂存当前改动
  if git -C "$repo" diff --quiet HEAD && git -C "$repo" diff --cached --quiet; then
    : # 无改动，不暂存
  else
    git -C "$repo" stash push -m "cwork-auto-stash before $FEATURE_BRANCH" >/dev/null 2>&1 || true
    mkdir -p "$repo/.git/logs"
    echo "$(date '+%Y-%m-%d %H:%M:%S') | stash before $FEATURE_BRANCH" >> "$repo/.git/logs/cwork-stash"
  fi

  # 获取远端默认分支（只允许 master 或 main）
  git -C "$repo" fetch origin --prune >/dev/null 2>&1 || true

  if git -C "$repo" show-ref --verify --quiet refs/remotes/origin/master; then
    base_branch="master"
  elif git -C "$repo" show-ref --verify --quiet refs/remotes/origin/main; then
    base_branch="main"
  else
    fail "只支持从 master 或 main 分支 checkout，当前仓库无这两个分支: $repo"
  fi

  # 切换 feature 分支
  if git -C "$repo" show-ref --verify --quiet "refs/heads/$FEATURE_BRANCH"; then
    git -C "$repo" checkout -f "$FEATURE_BRANCH" >/dev/null 2>&1
  elif git -C "$repo" show-ref --verify --quiet "refs/remotes/origin/$FEATURE_BRANCH"; then
    git -C "$repo" checkout -B "$FEATURE_BRANCH" "origin/$FEATURE_BRANCH" >/dev/null 2>&1
  else
    git -C "$repo" checkout -B "$FEATURE_BRANCH" "origin/$base_branch" >/dev/null 2>&1
  fi
}

# 切换主工程
switch_branch "$MAIN_DIR"

# 切换依赖工程
if [[ -n "$DEP_DIRS" ]]; then
  while IFS= read -r dep; do
    [[ -z "$dep" ]] && continue
    switch_branch "$dep"
  done <<<"$DEP_DIRS"
fi

# 建文档目录
MAIN_DOC_DIR="$MAIN_DIR/docs/requirements/$REQ_KEY"
mkdir -p "$MAIN_DOC_DIR"

# 写 workflow-state（包含所有信息，唯一文件）
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
cat > "$MAIN_DOC_DIR/workflow-state.json" <<EOF
{"phase": "init", "requirement_key": "$REQ_KEY", "requirement_title": "$REQ_TITLE", "requirement_id": "$REQ_ID", "feature_branch": "$FEATURE_BRANCH", "main_repo": "$MAIN_DIR", "deps": "${DEPS_RAW:-}", "updated_at": "$TIMESTAMP"}
EOF

# 依赖工程：只写一个状态文件
if [[ -n "$DEP_DIRS" ]]; then
  while IFS= read -r dep; do
    [[ -z "$dep" ]] && continue
    dep_doc_dir="$dep/docs/requirements/$REQ_KEY"
    mkdir -p "$dep_doc_dir"

    # 只写一个文件：workflow-state.json（包含所有信息）
    cat > "$dep_doc_dir/workflow-state.json" <<EOF
{"phase": "init", "requirement_key": "$REQ_KEY", "requirement_title": "$REQ_TITLE", "requirement_id": "$REQ_ID", "feature_branch": "$FEATURE_BRANCH", "main_repo": "$MAIN_DIR", "updated_at": "$TIMESTAMP"}
EOF
  done <<<"$DEP_DIRS"
fi

echo "INIT_DONE"
echo "requirement_key=$REQ_KEY"
echo "feature_branch=$FEATURE_BRANCH"
echo "main_doc_dir=$MAIN_DOC_DIR"
echo "NEXT_SKILL=implement"
