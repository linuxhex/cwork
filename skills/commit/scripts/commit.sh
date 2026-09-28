#!/usr/bin/env bash
set -euo pipefail

# 自动提交，不确认
# 用法: commit.sh <主工程路径> [依赖工程路径] <需求key> <需求简称> <需求ID> <commit类型> <说明>

fail() { echo "ERROR: $*" >&2; exit 1; }

[[ $# -lt 6 ]] && fail "用法: commit.sh <主工程路径> [依赖工程路径] <需求key> <需求简称> <需求ID> <类型> <说明>"

MAIN_DIR="$1"
DEPS_RAW="${2:-}"
REQ_KEY="$3"
REQ_SHORT="$4"
REQ_ID="$5"
COMMIT_TYPE="$6"
COMMIT_DETAIL="${7:-}"

# 校验需求ID格式
[[ "$REQ_ID" =~ ^OMJF-[0-9]+$ ]] || fail "需求ID格式错误，必须为 OMJF-数字，如 OMJF-12345"

# 校验类型
case "$COMMIT_TYPE" in
  add|del|modify|fix|refactor|docs) ;;
  *) fail "类型必须是: add|del|modify|fix|refactor|docs" ;;
esac

# 收集所有仓库
REPOS="$MAIN_DIR"
if [[ -n "$DEPS_RAW" ]]; then
  REPOS="$REPOS,$DEPS_RAW"
fi

# 检查 workflow-state
check_phase() {
  local repo="$1"
  local state_file="$repo/docs/requirements/$REQ_KEY/workflow-state.json"
  [[ -f "$state_file" ]] || fail "workflow-state.json 不存在: $repo"
  local phase
  phase=$(grep -o '"phase"[[:space:]]*:[[:space:]]*"[^"]*"' "$state_file" | grep -o '"[^"]*"$' | tr -d '"')
  [[ "$phase" == "commit" ]] || fail "workflow-state 不是 commit: $repo (当前: $phase)"
}

# 检查分支一致
BASE_BRANCH=""
check_branch() {
  local repo="$1"
  local branch
  branch=$(git -C "$repo" branch --show-current)
  [[ -n "$branch" ]] || fail "detached HEAD: $repo"
  if [[ -z "$BASE_BRANCH" ]]; then
    BASE_BRANCH="$branch"
  else
    [[ "$branch" == "$BASE_BRANCH" ]] || fail "分支不一致: $repo ($branch != $BASE_BRANCH)"
  fi
}

# 推送防护：显式推到 origin/<当前分支>，禁止裸 git push（裸 push 走 upstream，upstream 错时会把特性代码推到 master 等错误分支）
# - upstream 指向别的分支 → 阻断推送，提示修正
# - 无 upstream（新分支首次推送）→ push -u origin <当前分支>，建立正确关联
push_current_branch() {
  local repo="$1"
  local branch
  branch=$(git -C "$repo" branch --show-current)
  [[ -n "$branch" ]] || fail "detached HEAD，无法推送: $repo"

  local upstream
  upstream=$(git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name @{upstream} 2>/dev/null || true)
  if [[ -n "$upstream" && "$upstream" != "origin/$branch" ]]; then
    fail "推送中止: $repo 当前分支 $branch 的 upstream 是 $upstream（非同名远端分支）。先执行 git branch --set-upstream-to=origin/$branch $branch 修正后再推送"
  fi

  if [[ -z "$upstream" ]]; then
    git -C "$repo" push -u origin "$branch" >/dev/null 2>&1 || fail "推送失败: $repo (origin/$branch)"
  else
    git -C "$repo" push origin "$branch" >/dev/null 2>&1 || fail "推送失败: $repo (origin/$branch)"
  fi
}

# 预检
while IFS= read -r repo; do
  [[ -z "$repo" ]] && continue
  check_phase "$repo"
  check_branch "$repo"
done < <(tr ',' '\n' <<<"$REPOS")

# 生成 commit message（带需求ID）
COMMIT_MSG="#${REQ_ID}
【${REQ_SHORT}】<${COMMIT_TYPE}> ${COMMIT_DETAIL}"

# 提交
OUTPUT=""
while IFS= read -r repo; do
  [[ -z "$repo" ]] && continue

  # 暂存需求文档
  git -C "$repo" add -A "docs/requirements/$REQ_KEY" 2>/dev/null || true

  # 检查是否有改动
  if git -C "$repo" diff --cached --quiet; then
    OUTPUT="$OUTPUT"$'\n'"$repo: SKIPPED_NO_CHANGES"
    continue
  fi

  # 提交
  git -C "$repo" commit -m "$COMMIT_MSG" >/dev/null 2>&1 || fail "提交失败: $repo"
  hash=$(git -C "$repo" rev-parse --short HEAD)
  OUTPUT="$OUTPUT"$'\n'"$repo: $hash"

  # 推送到远端同名分支（校验 upstream 一致性，不一致阻断）
  push_current_branch "$repo"

  # 更新 workflow-state
  state_file="$repo/docs/requirements/$REQ_KEY/workflow-state.json"
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "{\"phase\": \"done\", \"requirement_key\": \"$REQ_KEY\", \"updated_at\": \"$timestamp\"}" > "$state_file"
done < <(tr ',' '\n' <<<"$REPOS")

echo "COMMIT_DONE"
echo "$OUTPUT"
