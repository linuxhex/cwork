#!/usr/bin/env bash
set -euo pipefail

# 一行命令初始化，不逐条确认
# 用法: init.sh <需求名> <分支名> <主工程路径> [依赖工程路径]

fail() { echo "ERROR: $*" >&2; exit 1; }

[[ $# -lt 3 ]] && fail "用法: init.sh <需求名> <分支名> <主工程路径> [依赖工程路径]"

REQ_TITLE="$1"
FEATURE_BRANCH="$2"
MAIN_DIR="$3"
DEPS_RAW="${4:-}"

# 生成为 requirement_key（转小写，空格转下划线）
REQ_KEY=$(echo "$REQ_TITLE" | tr '[:upper:] ' '[:lower:]_')

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

# 获取默认分支
get_base_branch() {
  local repo="$1"
  local head_ref
  head_ref=$(git -C "$repo" symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null || true)
  if [[ -n "$head_ref" ]]; then
    echo "${head_ref#refs/remotes/origin/}"
    return
  fi
  git -C "$repo" show-ref --verify --quiet refs/remotes/origin/master && echo "master" && return
  git -C "$repo" show-ref --verify --quiet refs/remotes/origin/main && echo "main" && return
  fail "无法识别默认分支: $repo"
}

# 切换分支
switch_branch() {
  local repo="$1"
  local base
  base=$(get_base_branch "$repo")

  git -C "$repo" fetch origin --prune >/dev/null 2>&1 || true
  git -C "$repo" reset --hard HEAD >/dev/null 2>&1 || true
  git -C "$repo" clean -fd >/dev/null 2>&1 || true

  if git -C "$repo" show-ref --verify --quiet "refs/heads/$base"; then
    git -C "$repo" checkout -f "$base" >/dev/null 2>&1
  else
    git -C "$repo" checkout -B "$base" "origin/$base" >/dev/null 2>&1
  fi
  git -C "$repo" reset --hard "origin/$base" >/dev/null 2>&1

  if git -C "$repo" show-ref --verify --quiet "refs/heads/$FEATURE_BRANCH"; then
    git -C "$repo" checkout -f "$FEATURE_BRANCH" >/dev/null 2>&1
  elif git -C "$repo" show-ref --verify --quiet "refs/remotes/origin/$FEATURE_BRANCH"; then
    git -C "$repo" checkout -B "$FEATURE_BRANCH" "origin/$FEATURE_BRANCH" >/dev/null 2>&1
  else
    git -C "$repo" checkout -B "$FEATURE_BRANCH" "$base" >/dev/null 2>&1
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
{"phase": "init", "requirement_key": "$REQ_KEY", "requirement_title": "$REQ_TITLE", "feature_branch": "$FEATURE_BRANCH", "main_repo": "$MAIN_DIR", "deps": "${DEPS_RAW:-}", "updated_at": "$TIMESTAMP"}
EOF

# 依赖工程：只写一个状态文件
if [[ -n "$DEP_DIRS" ]]; then
  while IFS= read -r dep; do
    [[ -z "$dep" ]] && continue
    dep_doc_dir="$dep/docs/requirements/$REQ_KEY"
    mkdir -p "$dep_doc_dir"

    # 只写一个文件：workflow-state.json（包含所有信息）
    cat > "$dep_doc_dir/workflow-state.json" <<EOF
{"phase": "init", "requirement_key": "$REQ_KEY", "requirement_title": "$REQ_TITLE", "feature_branch": "$FEATURE_BRANCH", "main_repo": "$MAIN_DIR", "updated_at": "$TIMESTAMP"}
EOF
  done <<<"$DEP_DIRS"
fi

echo "INIT_DONE"
echo "requirement_key=$REQ_KEY"
echo "feature_branch=$FEATURE_BRANCH"
echo "main_doc_dir=$MAIN_DOC_DIR"
echo "NEXT_SKILL=implement"
