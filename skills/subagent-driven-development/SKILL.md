---
name: subagent-driven-development
description: 在执行多工程微服务计划时使用。用于把任务按工程分派给多个 agent 并通过 claim/lock 机制防止冲突。
---

# 子代理并发开发

## 概述

## 语言约束
- 对话、分析、结论、提示默认使用中文。
- 仅在必要处保留英文：命令、路径、参数名、状态码、字段名。
- 禁止输出英文整句作为主要内容。

该技能用于多 agent 并发落地 `executing-plans`。

核心原则：
- 每任务一个 agent
- 每任务有 claim
- 每任务完成后做规格审查 + 质量审查

## HARD GATE
- 仅在 `executing-plans` 阶段使用。
- 任务未 claim 不得开工。
- 同任务被他人 claim 时不得抢改。

## 本 skill 自带资产
- 脚本：`skills/subagent-driven-development/scripts/dispatch_task_claims.sh`
- Prompt：
  - `prompts/implementer-prompt.md`
  - `prompts/spec-reviewer-prompt.md`
  - `prompts/code-quality-reviewer-prompt.md`
- 示例：`examples/tasks.sample.txt`

## 批量任务认领

```bash
bash skills/subagent-driven-development/scripts/dispatch_task_claims.sh \
  --tasks-file skills/subagent-driven-development/examples/tasks.sample.txt \
  --requirement-key <需求key>
```

## 推荐流程
1. 控制代理读取 `02-plan.md` 拆任务。
2. 通过 `dispatch_task_claims.sh` 写入 claim。
3. 分派实现代理执行。
4. 使用 spec reviewer prompt 审查规格一致性。
5. 使用 code quality reviewer prompt 审查质量。
6. 问题修复后再进入 `loop-refined` 轮次验证。

## 反模式
- 多 agent 同时改同一模块无 claim。
- 实现代理完成后不做审查直接合并。
- claim 状态不更新，导致后续冲突。

## 完成定义
- 所有任务 claim 都有结束状态。
- 审查问题已处理。
- 变更已进入 `loop-refined` 收敛流程。
