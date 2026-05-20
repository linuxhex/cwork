# 需求分析

## 背景
当前 init 的分支切换逻辑使用 `git reset --hard HEAD` + `git clean -fd` 强制丢弃本地改动，存在丢失用户未提交改动的风险。

## 目标
改为更安全的方式：先暂存当前改动，再从远端默认分支（master/main）checkout 出目标分支。

## 改动范围
- `skills/init/scripts/init.sh`
- `skills/init/scripts/init_requirement_workspace.sh`

## 改动内容

### 1. 移除强制丢弃逻辑
- 删除 `git reset --hard HEAD`
- 删除 `git clean -fd`
- 删除 `--force-discard` 参数

### 2. 新增暂存逻辑
```bash
git stash push -m "cwork-auto-stash before $FEATURE_BRANCH"
echo "$(date '+%Y-%m-%d %H:%M:%S') | stash before $FEATURE_BRANCH" >> .git/logs/cwork-stash
```

### 3. 限制基础分支
只允许从 `master` 或 `main` 分支 checkout，其他分支报错拒绝：
```bash
base_branch=""
if git show-ref --verify --quiet refs/remotes/origin/master; then
  base_branch="master"
elif git show-ref --verify --quiet refs/remotes/origin/main; then
  base_branch="main"
else
  fail "只支持从 master 或 main 分支 checkout，当前仓库无这两个分支"
fi
```

### 4. 切换分支
```bash
git fetch origin --prune
if git show-ref --verify --quiet "refs/remotes/origin/$FEATURE_BRANCH"; then
  git checkout -B "$FEATURE_BRANCH" "origin/$FEATURE_BRANCH"
else
  git checkout -B "$FEATURE_BRANCH" "origin/$base_branch"
fi
```

### 5. 恢复方式
用户需要恢复时，使用标准 git 命令：
- `git stash list` 查看暂存列表
- `git stash pop` 恢复最近一次暂存

## 风险点
- 暂存记录文件 `.git/logs/cwork-stash` 需要确保目录存在
- 如果用户在多个需求间切换，暂存可能叠加，需用户手动管理

## 验收标准
- 执行 init 时不会丢失未提交的改动
- 只从 master/main 分支 checkout
- 暂存信息记录到 .git/logs/cwork-stash
- 用户可通过 git stash 命令恢复
