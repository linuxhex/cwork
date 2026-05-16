---
name: commit-code
description: 在 loop-refined 收敛后执行。对主工程与依赖工程进行统一格式提交，并把 workflow 状态推进到 done。
---

# Commit Code

## 位置与串联
- 必须在 `loop-refined` 收敛后执行。
- 这是流程最后阶段，完成后状态应为 `done`。

## 阶段目标
- 统一提交主工程和依赖工程改动。
- 提交信息满足你定义的规范。
- 保证每个工程都可追溯到同一 `requirement_key`。

## 必填输入
1. `repos`：主工程 + 依赖工程绝对路径（逗号分隔）。
2. `requirement_short`：需求简称。
3. `requirement_key`：需求标识。
4. `commit_type`：`add|del|modify|fix|refactor|docs`。
5. `commit_detail`：详细说明。

## commit message 规范（强制）
格式：`【需求简称】<type> 详细说明`

示例：
- `【占位单互联】<add> 增加多工程初始化和文档拆分自动化`
- `【占位单互联】<modify> 调整 loop-refined 收敛门禁与状态推进`

## HARD GATE
- 任一工程不在 `commit-code` 状态，禁止提交。
- 任一工程分支与其他工程不一致，禁止提交。
- `commit_type` 不在白名单，禁止提交。
- 无允许提交路径时，禁止提交。

## 暂存策略
默认顺序：
1. 先加入 `docs/requirements/<requirement_key>`。
2. 优先使用仓库内 `commit-allowlist.txt`。
3. 或显式传入 `--allowlist-file`。
4. 仅在明确允许时使用 `--allow-all-changes`。

## 执行命令

```bash
bash skills/commit-code/scripts/commit_all_related_repos.sh \
  --repos <逗号分隔绝对路径> \
  --requirement-short "<需求简称>" \
  --requirement-key <需求key> \
  --commit-type <add|del|modify|fix|refactor|docs> \
  --commit-detail "<详细说明>" \
  [--allowlist-file <路径>] \
  [--allow-all-changes]
```

## 提交行为（脚本内置）
1. 先预检查所有工程（分支一致、状态正确）。
2. 先做全工程暂存准备。
3. 逐仓提交：若中途失败，回滚已提交仓库到提交前 HEAD。
4. 提交完成后，把所有工程状态推进到 `done`。
5. 归档完成 claims。

## 阶段推进建议
在正式提交前先执行一次检查点：

```bash
bash skills/init/scripts/phase_checkpoint.sh \
  --main-dir <主工程绝对路径> \
  --deps <逗号分隔依赖工程绝对路径> \
  --requirement-key <需求key> \
  --phase commit-code \
  --owner <agent-id>
```

## 输出结果要求
必须输出每个工程：
- 工程路径
- 分支名
- commit hash（无改动则 `SKIPPED_NO_CHANGES`）
- commit message

## 常见失败与处理
- 失败：未提供 allowlist 且未允许全量提交。
  - 处理：补 `commit-allowlist.txt` 或明确加 `--allow-all-changes`。
- 失败：某仓提交冲突或 hook 拒绝。
  - 处理：脚本会回滚已提交仓，修复后重跑。
- 失败：状态不是 `commit-code`。
  - 处理：补跑前序阶段检查点后再提交。

## 质量红线
- 不允许跨工程使用不同 commit message。
- 不允许跳过状态校验直接手工提交。
- 不允许只提交主工程不提交依赖工程。

## 完成定义
- 所有工程提交成功或显式 `SKIPPED_NO_CHANGES`。
- 所有工程 `workflow-state` 为 `done`。
- 提交清单可用于后续 push / PR / 发布。
