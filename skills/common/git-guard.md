# Git 分支防护规范（建分支/推送/pull 强制约束）

## 概述

**适用范围（强制）**：所有 cwork 技能中执行 git 分支操作的场景——cwork-init 建分支、cwork-implement 建/切换分支（单服务不走 init 脚本时 AI 手工执行）、cwork-commit 推送、cwork-code pull、cwork-do 编排。

**问题背景（已实际发生）**：`git checkout -b/-B <feature> origin/master` 时，git 默认 autoSetupMerge 会把 **origin/master 设为新分支的 upstream**。后果：当前分支关联的远端分支是 master，后续裸 `git push` 把特性代码直接推到远端 master。

## 三条硬约束（不可违反）

1. **特性分支的 upstream 只能是 `origin/<同名分支>`**，绝不能是 master/main 等其他分支；新建分支在远端出现同名分支前可以无 upstream（无关联）
2. **禁止裸 `git push`**——一律显式 `git push origin <当前分支>`（首次推送用 `git push -u origin <当前分支>` 建立正确关联）
3. **禁止裸 `git pull`**——一律显式 `git pull origin <当前分支>`

## 建分支命令序列（AI 手工执行时必须完整走完）

```bash
# 1. 从远端最新 master 建特性分支（分支名格式：{type}/{YYYYMMDD}_{description}，type=feature/hotfix/bugfix/refactor）
git fetch origin --prune
git checkout -B feature/20260928_xxx origin/master

# 2. 立即纠正 upstream（核心防护，禁止省略）
git branch --set-upstream-to=origin/feature/20260928_xxx feature/20260928_xxx 2>/dev/null \
  || git branch --unset-upstream feature/20260928_xxx   # 远端无同名分支 → 清除从 master 继承的错误跟踪

# 3. 验证：输出必须是 origin/feature/20260928_xxx 或空（无 upstream）；输出 origin/master 即为事故状态，必须回步骤 2
git rev-parse --abbrev-ref @{upstream} 2>/dev/null
```

## 推送命令（每个工程推送前）

```bash
branch=$(git branch --show-current)
upstream=$(git rev-parse --abbrev-ref @{upstream} 2>/dev/null || echo "")
# upstream 指向别的分支（如 origin/master）→ 停止推送，先执行：
#   git branch --set-upstream-to=origin/$branch $branch
# 无 upstream（首次）→ git push -u origin "$branch"
# upstream 正确   → git push origin "$branch"
```

## 输出报告约束

向用户报告分支状态时，**"跟踪 origin/master"是事故状态不是正常状态**——若发现特性分支 upstream 指向 master/main 等其他分支，必须立即纠正后再继续，不得当作切换成功汇报。

## 已内置防护的脚本（无需手工干预）

| 脚本 | 防护 |
|---|---|
| `skills/init/scripts/init_requirement_workspace.sh` | `ensure_correct_upstream`：三条 checkout 路径后自动纠正/清除 upstream |
| `skills/init/scripts/init.sh` | 同上（旧版一行命令脚本） |
| `skills/commit/scripts/commit.sh` | `push_current_branch`：upstream 不一致 fail 阻断 / 无 upstream 用 `push -u` / 显式推 `origin <当前分支>` |
| `skills/code/scripts/code_query.sh` | pull 显式指定当前分支 |

## 反模式

- ❌ 建分支后不校验 upstream 就继续（git 默认行为恰恰是问题根源）
- ❌ 裸 `git push` / 裸 `git pull`
- ❌ 把"跟踪 origin/master"当正常状态汇报
- ❌ 分支名随手起（如 `aaa`）——必须 `{type}/{YYYYMMDD}_{description}` 格式
