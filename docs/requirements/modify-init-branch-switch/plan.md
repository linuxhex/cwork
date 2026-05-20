# 修改 init 分支切换逻辑实现计划

**目标：** 将 init 的分支切换从强制丢弃改为暂存方式，只从 master/main checkout

**架构：** 修改两个脚本，移除强制丢弃逻辑，新增暂存逻辑，限制基础分支

**技术栈：** Bash

---

### 任务 1：修改 init.sh

**文件：**
- 修改：`skills/init/scripts/init.sh`

- [ ] **步骤 1：修改 switch_branch 函数**

将第 51-74 行的 `switch_branch` 函数替换为：

```bash
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
  if git -C "$repo" show-ref --verify --quiet "refs/remotes/origin/$FEATURE_BRANCH"; then
    git -C "$repo" checkout -B "$FEATURE_BRANCH" "origin/$FEATURE_BRANCH" >/dev/null 2>&1
  else
    git -C "$repo" checkout -B "$FEATURE_BRANCH" "origin/$base_branch" >/dev/null 2>&1
  fi
}
```

---

### 任务 2：修改 init_requirement_workspace.sh

**文件：**
- 修改：`skills/init/scripts/init_requirement_workspace.sh`

- [ ] **步骤 1：删除 force_discard_local_changes 函数**

删除第 62-66 行：
```bash
force_discard_local_changes() {
  local repo="$1"
  git -C "$repo" reset --hard HEAD >/dev/null 2>&1 || return 1
  git -C "$repo" clean -fd >/dev/null 2>&1 || return 1
}
```

- [ ] **步骤 2：修改 checkout_feature_from_latest_base 函数**

将第 102-152 行替换为：

```bash
checkout_feature_from_latest_base() {
  local repo="$1"
  local feature_branch="$2"

  # 暂存当前改动
  if git -C "$repo" diff --quiet HEAD && git -C "$repo" diff --cached --quiet; then
    : # 无改动，不暂存
  else
    git -C "$repo" stash push -m "cwork-auto-stash before $feature_branch" >/dev/null 2>&1 || true
    mkdir -p "$repo/.git/logs"
    echo "$(date '+%Y-%m-%d %H:%M:%S') | stash before $feature_branch" >> "$repo/.git/logs/cwork-stash"
  fi

  # 获取远端默认分支（只允许 master 或 main）
  local base_branch=""
  if git -C "$repo" show-ref --verify --quiet refs/remotes/origin/master; then
    base_branch="master"
  elif git -C "$repo" show-ref --verify --quiet refs/remotes/origin/main; then
    base_branch="main"
  else
    echo "只支持从 master 或 main 分支 checkout，当前仓库无这两个分支: $repo" >&2
    return 1
  fi

  # 切换 feature 分支
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

  git -C "$repo" checkout -B "$feature_branch" "origin/$base_branch" >/dev/null 2>&1 || {
    echo "failed to create branch from origin/$base_branch: $repo -> $feature_branch" >&2
    return 1
  }
  printf '%s' "created_from_origin_base"
}
```

- [ ] **步骤 3：删除 default_base_branch 函数**

删除第 80-100 行（不再需要）。

- [ ] **步骤 4：删除 --force-discard 参数处理**

删除第 227-230 行：
```bash
    --force-discard)
      FORCE_DISCARD="$2"
      shift 2
      ;;
```

删除第 246 行：
```bash
[[ "$FORCE_DISCARD" == "true" ]] || fail "--force-discard true is required before destructive cleanup"
```

- [ ] **步骤 5：更新 usage 说明**

将第 9-19 行的 usage 函数更新为：

```bash
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
```

- [ ] **步骤 6：删除 FORCE_DISCARD 变量声明**

删除第 204 行：
```bash
FORCE_DISCARD="false"
```

- [ ] **步骤 7：修改 preflight_repo 函数**

删除第 78 行的 fetch（移到 checkout 函数内）：
```bash
git -C "$repo" fetch origin --prune >/dev/null 2>&1 || fail "failed to fetch origin: $repo"
```

- [ ] **步骤 8：修改主循环中的调用**

将第 286-298 行的循环修改为：

```bash
while IFS= read -r repo_base_line; do
  [[ -z "$repo_base_line" ]] && continue
  repo="${repo_base_line%%|*}"
  repo_before_ref="$(current_ref "$repo")"
  if repo_branch_action="$(checkout_feature_from_latest_base "$repo" "$FEATURE_BRANCH")"; then
    BRANCH_LOG_LINES="${BRANCH_LOG_LINES}"$'\n'"$repo|$repo_branch_action|$FEATURE_BRANCH"
    ROLLBACK_LINES="${ROLLBACK_LINES}"$'\n'"$repo|$repo_before_ref"
  else
    rollback_switched_repos "$ROLLBACK_LINES"
    fail "atomic switch failed, rolled back switched repos: $repo"
  fi
done <<<"$REPO_BASE_LINES"
```

注意：`REPO_BASE_LINES` 现在只包含仓库路径，不再包含 base_branch。

- [ ] **步骤 9：修改 REPO_BASE_LINES 生成**

将第 279-284 行修改为：

```bash
while IFS= read -r repo; do
  [[ -z "$repo" ]] && continue
  preflight_repo "$repo"
  REPO_BASE_LINES="${REPO_BASE_LINES}"$'\n'"$repo"
done <<<"$ALL_REPO_LINES"
```
