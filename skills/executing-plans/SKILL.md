---
name: executing-plans
description: 在 writing-plans 之后执行。按计划落地实现，并强制进入 loop-refined 的多轮逻辑推演与修复闭环，收敛后进入 commit-code。
---

# Executing Plans

## 位置与串联
- 必须在 `writing-plans` 完成后执行。
- 执行过程中必须循环调用 `loop-refined`。
- 收敛后自动进入下一阶段：`commit-code`。

## 阶段目标
- 严格执行 `02-plan.md` 的任务。
- 每轮改动都经过“推演 -> 修复 -> 再推演”验证。
- 保证多工程改动最终一致且可追溯。

## HARD GATE
- 未进入 `executing-plans` 状态禁止编码。
- 任一任务未通过推演验证不得标记完成。
- 任一工程存在未关闭问题，不得进入 `commit-code`。

## 输入来源
1. 主工程 `02-plan.md`
2. 依赖工程 `02-repo-plan.md`
3. 上轮推演记录（若存在）：
   - 主工程 `03-changes.md`
   - 主工程 `process/round-<N>.md`
   - 依赖工程 `03-repo-changes.md`

## 执行节奏（单任务）
1. 领取任务：在 `agent_claims.json` 记录 owner 与 scope。
2. 最小改动实现：只改当前任务必要内容。
3. 立即进入 `loop-refined`：做一轮跨工程逻辑推演。
4. 记录问题并修复：更新主工程和依赖工程文档。
5. 再推演：确认修复有效且无新增回归。
6. 任务收口：满足 DoD 后进入下一任务。

## 默认质量策略
- 不强制新增单元测试。
- 问题发现与回归判断由 `loop-refined` 负责。
- 如业务高风险，可补充手工测试或联调脚本，但不是本流程硬门禁。

## 阶段推进命令
开始执行前：

```bash
bash skills/init/scripts/phase_checkpoint.sh \
  --main-dir <主工程绝对路径> \
  --deps <逗号分隔依赖工程绝对路径> \
  --requirement-key <需求key> \
  --phase executing-plans \
  --owner <agent-id>
```

每轮推演完成后：

```bash
bash skills/init/scripts/phase_checkpoint.sh \
  --main-dir <主工程绝对路径> \
  --deps <逗号分隔依赖工程绝对路径> \
  --requirement-key <需求key> \
  --phase loop-refined \
  --owner <agent-id>
```

## 并发协作约束（多 agent）
- 不同 agent 负责不同工程或不同模块。
- 任何阶段推进前必须加锁，避免状态竞争。
- 冲突处理优先级：状态文件事实 > 口头约定。
- 长任务需续租锁（TTL 到期前 renew）。

## 阶段通过标准
- `02-plan.md` 所有任务完成。
- `03-changes.md` 所有问题 `closed`。
- 最新一轮推演无新增问题。
- 所有工程 `workflow-state` 已到 `loop-refined` 或 `commit-code` 前态。

## 常见失败与处理
- 失败：推演发现跨工程契约破坏。
  - 处理：回到对应依赖工程修复契约，再次推演。
- 失败：某工程状态被其他 agent 提前推进。
  - 处理：读取 state 版本，按实际状态续跑，不回退已生效结果。
- 失败：任务完成但文档未同步。
  - 处理：补写 `03-*` 文档后重跑检查点。

## 质量红线
- 不允许“改完直接提交，不做 loop-refined”。
- 不允许“只在主工程记录问题，不同步依赖工程”。
- 不允许“问题 unresolved 仍推进到 commit-code”。

## 输出给下一阶段的最小交接
- 每工程最终改动摘要
- 问题清单（全部 closed）
- 最后一轮推演结论
- 可提交文件范围

下一阶段：`commit-code`
