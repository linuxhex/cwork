---
name: executing-plans
description: 按计划实施并执行“逻辑推演-修复-再推演”循环，直到问题收敛；最后完成多工程提交。
---

# Executing Plans

## 目标
严格按计划执行，并通过多轮逻辑推演与修复，消除遗漏和回归风险。

## 强制循环（必须执行）
1. 实施当前任务最小改动。
2. 调用 `logic-review-loop`，对主工程和所有依赖工程做一次更大范围逻辑推演。
3. 记录发现的问题到 `03-changes.md`（主工程）、`process/round-<N>.md`（主工程过程文件）和依赖工程 `01-change-points.md`。
4. 修复问题。
5. 再调用 `logic-review-loop` 做下一轮推演。
6. 重复 3-5，直到没有未解决问题。

## 完成门禁
- 所有计划任务状态为已完成。
- 所有推演发现项状态为已关闭。
- 主工程和所有依赖工程都完成提交。

## 多工程提交规则
- 每个工程独立 commit。
- commit message 包含同一个 `requirement_key`。
- 提交顺序：依赖工程 -> 主工程。
- 最终输出提交清单：工程路径、分支名、commit hash。
