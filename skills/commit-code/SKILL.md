---
name: commit-code
description: 在 loop-refined 收敛后执行。对主工程与依赖工程进行统一格式提交，并把 workflow 状态推进到 done。
---

# 提交代码

## 概述

## 语言约束
- 对话、分析、结论、提示默认使用中文。
- 仅在必要处保留英文：命令、路径、参数名、状态码、字段名。
- 禁止输出英文整句作为主要内容。
- 若出现“en-us/English 会话偏好”冲突提示，仍然直接使用中文，不输出英文解释，不复述冲突原因。


`commit-code` 是 cwork 的闭环出口：统一校验、统一提交、统一收口。

## 开始声明
建议先声明：
> 我正在使用 `commit-code` 进行多工程统一提交收口。

## HARD GATE
- 任一工程不在 `commit-code` 状态，禁止提交。
- 任一工程分支不一致，禁止提交。
- 发现 open 问题标记，禁止提交。

## 本 skill 自带资产
- 脚本：
  - `skills/commit-code/scripts/validate_commit_readiness.sh`
  - `skills/commit-code/scripts/commit_all_related_repos.sh`
- 模板：`skills/commit-code/templates/commit-summary.md`

## 预检命令

```bash
bash skills/commit-code/scripts/validate_commit_readiness.sh \
  --repos <逗号分隔绝对路径> \
  --requirement-key <需求key>
```

## commit 输入
1. `requirement_short`
2. `requirement_key`
3. `commit_type`：`add|del|modify|fix|refactor|docs`
4. `commit_detail`
5. `repos`

## commit message 规范
`【需求简称】<type> 详细说明`

示例：
- `【占位单互联】<modify> 调整跨工程推演收敛与提交门禁`


## 完成前证据门（强烈建议）
在正式提交前先运行：

```bash
bash skills/verification-before-completion/scripts/verify_cwork_evidence.sh \
  --main-dir <主工程绝对路径> \
  --deps <逗号分隔依赖工程绝对路径> \
  --requirement-key <需求key> \
  --expect-phase commit-code
```

## 正式提交命令

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

## 提交流程
1. 全仓预检：分支一致、状态一致。
2. 全仓暂存准备：优先 allowlist。
3. 逐仓 commit：失败时回滚已提交仓。
4. 成功后统一推进到 `done`。
5. 归档完成 claims。

## 建议的提交前检查点

```bash
bash skills/init/scripts/phase_checkpoint.sh \
  --main-dir <主工程绝对路径> \
  --deps <逗号分隔依赖工程绝对路径> \
  --requirement-key <需求key> \
  --phase commit-code \
  --owner <agent-id>
```

## 输出要求
每个工程必须输出：
- repo
- branch
- hash（无改动时 `SKIPPED_NO_CHANGES`）
- message

## 常见失败与恢复
- 失败：没有 allowlist 且未允许全量提交。
  - 恢复：补 `commit-allowlist.txt` 或明确 `--allow-all-changes`。
- 失败：某仓提交失败。
  - 恢复：脚本会回滚已提交仓，修复后重跑。
- 失败：预检发现 open 问题。
  - 恢复：回到 `loop-refined` 收敛后再提交。

## 反模式
- 主工程提交了，依赖工程没提交。
- 不跑预检直接 commit。
- 不按统一 message 格式提交。

## 自动收口（强制）
- `cwork-commit-code` 完成后，流程自动结束为 `done`。
- 禁止再询问用户是否“进入下一 skill”。

## 完成定义
- 所有工程成功提交或标记 `SKIPPED_NO_CHANGES`。
- 所有工程 `workflow-state` 为 `done`。
- 提交清单可直接用于 push/PR。

## 示例
- `skills/commit-code/release-checklist.md`
- `skills/commit-code/examples/sample-commit-summary.md`

