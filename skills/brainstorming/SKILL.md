---
name: brainstorming
description: 在 init 之后执行。把需求转成可执行分析，明确主工程和依赖工程的职责边界、契约影响、风险与验收标准，并自动推进到 writing-plans。
---

# Brainstorming

## 位置与串联
- 必须在 `init` 成功后执行。
- 完成后自动进入下一阶段：`writing-plans`。
- 若 `workflow-state` 不是 `init`，禁止执行。

## 阶段目标
- 把“口头需求”转成“跨工程可执行分析”。
- 输出统一口径，避免后续各工程理解偏差。
- 明确验收标准，作为后续计划和推演的收敛判据。

## HARD GATE
- 没有完成本阶段分析文档，不得进入 `writing-plans`。
- 没有明确验收标准，不得推进阶段。
- 没有覆盖依赖工程视角，不得推进阶段。

## 输入来源
1. 主工程 `docs/requirements/<requirement_key>/00-context.md`
2. 各依赖工程：
   - `00-repo-context.md`
   - `10-repo-perspective-custom.md`
   - `11-repo-contract-custom.md`
3. 当前代码上下文：关键模块、调用链、已有分支状态

## 必做清单
1. 复述需求目标：一句话说明“最终业务效果”。
2. 划定范围：`in-scope / out-of-scope`。
3. 拆分工程职责：主工程与每个依赖工程分别负责什么。
4. 梳理契约影响：输入输出字段、状态码、事件、幂等/防重口径。
5. 明确风险和回滚：每个风险至少给一个防护策略。
6. 定义验收标准：必须可判定通过/失败。

## 输出要求
主工程写入：`docs/requirements/<requirement_key>/01-analysis.md`

建议结构：
- 背景与目标
- 范围内/范围外
- 主工程改动点
- 依赖工程改动点
- 契约变更与兼容策略
- 风险清单与防护
- 验收标准（可执行）

依赖工程同步要求：
- `01-repo-analysis.md` 至少包含“该工程视角改动范围、依赖关系、风险口径”。
- `10/11` 中已有人工内容不得被覆盖。

## 强制同步与推进
完成文档后必须执行检查点：

```bash
bash skills/init/scripts/phase_checkpoint.sh \
  --main-dir <主工程绝对路径> \
  --deps <逗号分隔依赖工程绝对路径> \
  --requirement-key <需求key> \
  --phase brainstorming \
  --owner <agent-id>
```

此命令会自动完成：
- 多工程加锁（防并发冲突）
- 文档同步拆分（主工程 -> 依赖工程）
- 状态推进到 `brainstorming`

## 阶段通过标准
- `01-analysis.md` 存在且字段完整。
- 所有依赖工程均有对应分析视角落地。
- `phase_checkpoint` 返回 `CHECKPOINT_DONE`。

## 常见失败与处理
- 失败：某依赖工程文档缺失。
  - 处理：先修复该工程文档目录，再重跑 `phase_checkpoint`。
- 失败：状态冲突（被其他 agent 推进）。
  - 处理：先看 `workflow-state.json` 版本，再按当前状态继续。
- 失败：分析和依赖工程口径不一致。
  - 处理：先统一主工程分析，再触发一次同步。

## 质量红线
- 不允许“主工程分析很完整，依赖工程只有空模板”。
- 不允许“只写改哪里，不写为什么改”。
- 不允许“验收标准是主观描述”。

## 输出给下一阶段的最小交接
- 关键业务目标
- 工程职责边界
- 契约变更点
- 风险/回滚口径
- 明确验收标准

下一阶段：`writing-plans`
