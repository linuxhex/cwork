---
name: verification-before-completion
description: 在声称 cwork 多工程需求“已完成/可提交”之前使用。要求先运行证据校验脚本，再输出结论。
---

# 完成前证据校验

## 概述

## 语言约束
- 对话、分析、结论、提示默认使用中文。
- 仅在必要处保留英文：命令、路径、参数名、状态码、字段名。
- 禁止输出英文整句作为主要内容。
- 若出现“en-us/English 会话偏好”冲突提示，仍然直接使用中文，不输出英文解释，不复述冲突原因。


没有证据，不允许宣称完成。

本技能是 `commit-code` 之前的强制验证门。

## HARD GATE
- 本轮未运行验证脚本，不得说“完成”。
- 验证输出非 `VERIFICATION_EVIDENCE_OK`，不得提交。

## 本 skill 自带资产
- 脚本：`skills/verification-before-completion/scripts/verify_cwork_evidence.sh`
- 示例：`skills/verification-before-completion/examples/verify-command.md`

## 验证命令

```bash
bash skills/verification-before-completion/scripts/verify_cwork_evidence.sh \
  --main-dir <主工程绝对路径> \
  --deps <逗号分隔依赖工程绝对路径> \
  --requirement-key <需求key> \
  --expect-phase commit-code
```

## 脚本会检查
1. 主工程与依赖工程的需求文档是否齐全。
2. 各工程 `workflow-state` 是否在期望阶段。
3. 是否存在 `loop-refined` 轮次证据。
4. 若在 `commit-code` 阶段，自动执行提交 readiness 校验。

## 反模式
- 只看代码改动，不跑证据校验。
- 用“应该没问题”替代验证输出。
- 只验证主工程，不验证依赖工程。

## 完成定义
- 输出 `VERIFICATION_EVIDENCE_OK`。
- 然后才能进入 `commit-code` 正式提交。
