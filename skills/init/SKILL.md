---
name: init
description: 需求流程起点。初始化主工程与依赖工程，统一分支、建立需求文档体系、生成多工程视角拆分文档，并自动串联到 brainstorming。
---

# Init

## 位置与串联
- 必须作为流程起点执行。
- 完成后自动进入下一阶段：`brainstorming`。

## 阶段目标
- 把当前工程设为主工程，建立跨工程统一上下文。
- 所有相关工程同步切换/创建同名 feature 分支。
- 自动生成主工程和依赖工程需求文档、过程文档、拆分记录。

## 必填输入
1. `main_dir`：主工程绝对路径（默认当前目录）。
2. `deps`：依赖工程绝对路径列表（逗号分隔）。
3. `feature_branch`：目标分支名。
4. `requirement_key`：需求标识（小写+下划线）。
5. `requirement_title`：需求标题。
6. `force_discard=true`：确认允许强制回退未提交改动。

## 分支命名规则（强制）
- 必须 `feature_` 开头。
- 仅允许英文字母与下划线。
- 不允许数字、中文、短横线。
- 下划线分段后，每段满足 `^[a-z][A-Za-z]*$`。

示例：
- `feature_userCenterExport`
- `feature_chargeFlowAlign_orderSync`

## HARD GATE
- 未传 `--force-discard true`，禁止执行。
- 任一依赖工程路径无效，禁止执行。
- 任一仓库非 git 或无 `origin`，禁止执行。

## 核心动作（自动）
1. 预检查所有工程：git 仓库、远程、路径、分支规则。
2. 获取远程默认分支：`origin/HEAD`，失败则回退 `master/main`。
3. 强制回退本地改动：`reset --hard` + `clean -fd`。
4. 对齐默认分支到远程最新。
5. 分支切换策略：
   - 本地有分支：强制切换
   - 远程有分支：跟踪切换
   - 都没有：从最新默认分支新建
6. 多仓原子保障：任一仓失败，已切换仓库回滚到原引用。
7. 生成文档体系并初始化 workflow/claims。

## 执行命令

```bash
bash skills/init/scripts/init_requirement_workspace.sh \
  --main-dir <主工程绝对路径> \
  --deps <逗号分隔依赖工程绝对路径> \
  --feature-branch <feature_...> \
  --requirement-key <需求key> \
  --requirement-title "<需求标题>" \
  --force-discard true
```

## 自动生成产物
主工程目录：`docs/requirements/<requirement_key>/`
- `00-context.md`
- `01-analysis.md`
- `02-plan.md`
- `03-changes.md`
- `04-process-record.md`
- `05-split-actions.md`
- `dependencies/*`
- `process/*`

依赖工程目录：`docs/requirements/<requirement_key>/`
- `00-repo-context.md`
- `01-repo-analysis.md`
- `02-repo-plan.md`
- `03-repo-changes.md`
- `10-repo-perspective-custom.md`
- `11-repo-contract-custom.md`
- `98-main-doc-links.md`
- `99-dispatch-receipt.md`
- `commit-allowlist.txt`

每工程根需求标记：
- `docs/requirements/ACTIVE_REQUIREMENT.md`
- `docs/requirements/ACTIVE_REQUIREMENT_HISTORY.md`

并发治理：
- `workflow-state.json`
- `agent-claims.json`

## 阶段完成判定
- 所有工程均在同名 feature 分支。
- 文档目录生成完整。
- `ACTIVE_REQUIREMENT.md` 在每个工程存在。
- 后续可直接在任一工程目录继续 AI 对话并识别需求上下文。

## 常见失败与处理
- 失败：远程默认分支无法识别。
  - 处理：先修复 `origin/HEAD` 或补齐 `master/main`。
- 失败：某仓切换失败。
  - 处理：脚本自动回滚，修复后重跑全流程。
- 失败：误触发强制回退。
  - 处理：从 git reflog 或备份恢复，init 不能自动恢复未提交改动。

## 质量红线
- 不允许只切主工程分支，不切依赖工程。
- 不允许手工跳过文档生成。
- 不允许不记录 requirement_key 就进入后续阶段。

下一阶段：`brainstorming`
