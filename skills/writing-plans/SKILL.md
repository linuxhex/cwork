---
name: writing-plans
description: 在 brainstorming 之后执行。把分析拆成跨工程可执行计划，定义任务顺序、完成标准、推演验证策略，并自动推进到 executing-plans。
---

# Writing Plans

## 位置与串联
- 必须在 `brainstorming` 完成后执行。
- 完成后自动进入下一阶段：`executing-plans`。
- 若 `workflow-state` 不是 `brainstorming`，禁止执行。

## 阶段目标
- 把分析文档变成可执行任务清单。
- 每个任务都可验证、可回滚、可追溯到具体工程。
- 预先定义 `loop-refined` 的验证轮次和收敛标准。

## HARD GATE
- 没有 `01-analysis.md`，不得开始写计划。
- 计划中任何任务缺少 DoD（完成定义），不得推进阶段。
- 跨工程任务没有顺序依赖说明，不得推进阶段。

## 输入来源
1. 主工程：`01-analysis.md`
2. 依赖工程：`01-repo-analysis.md`、`10/11` 视角补充
3. 当前代码结构与现有接口契约

## 计划设计原则
- 先依赖后主工程：先改契约提供方，再改调用方。
- 每个任务只解决一个可验证目标。
- 避免“大任务一把梭”，优先可回滚的小步提交。
- 默认不强制新增单元测试，验证由 `loop-refined` 承担。

## 任务模板（推荐）
- 任务名
- 归属工程（绝对路径）
- 变更模块/文件
- 依赖前置任务
- 执行步骤
- 验证方式（loop-refined 的哪一轮验证什么）
- DoD
- 风险与回滚

## 输出要求
主工程写入：`docs/requirements/<requirement_key>/02-plan.md`

依赖工程写入：
- `02-repo-plan.md`
- 可选补充：`10-repo-perspective-custom.md`

## 推荐任务拆分方式
1. 契约定义任务：字段、状态、事件口径统一。
2. 依赖工程改造任务：按工程拆开。
3. 主工程集成任务：调用链改造与兼容。
4. 联调任务：跨工程主路径与异常路径。
5. 推演收敛任务：明确进入 `commit-code` 的门禁。

## 阶段推进命令

```bash
bash skills/init/scripts/phase_checkpoint.sh \
  --main-dir <主工程绝对路径> \
  --deps <逗号分隔依赖工程绝对路径> \
  --requirement-key <需求key> \
  --phase writing-plans \
  --owner <agent-id>
```

自动完成：
- 锁定多工程
- 同步文档拆分
- 状态推进到 `writing-plans`

## 阶段通过标准
- `02-plan.md` 存在且任务完整。
- 每个依赖工程均有 `02-repo-plan.md`。
- 全部任务具备：工程归属 + 验证方式 + DoD + 回滚策略。
- `phase_checkpoint` 返回 `CHECKPOINT_DONE`。

## 常见失败与处理
- 失败：任务未绑定工程目录。
  - 处理：补充“归属工程绝对路径”。
- 失败：验证方式空泛（如“确认没问题”）。
  - 处理：改为可执行的 `loop-refined` 验证项。
- 失败：跨工程顺序不明确。
  - 处理：增加前置依赖关系和执行顺序。

## 质量红线
- 不允许把 `loop-refined` 写成“可选步骤”。
- 不允许省略回滚策略。
- 不允许只写主工程计划，不写依赖工程视角计划。

## 输出给下一阶段的最小交接
- 明确任务列表
- 执行顺序
- 每任务 DoD
- 推演验证方案
- 提交门禁

下一阶段：`executing-plans`
