---
name: init
description: 初始化多工程需求工作区。把当前工程设为主工程，收集依赖服务目录与 feature 分支名，校验分支规则，从最新 master 创建分支，并自动生成主工程和依赖工程的需求/计划/改动文档。
---

# Init

## 目标
在开始实现前，建立统一的多工程执行上下文，保证分支、文档、依赖边界一致。

## 必须收集的信息（按顺序）
1. 主工程目录：默认当前工作目录。
2. 依赖服务工程目录：让用户逐个提供绝对路径，直到明确结束。
3. feature 分支全名：必须满足以下规则。
4. 需求标识：`requirement_key`，只允许小写字母和下划线。
5. 需求标题：一句话描述。

## feature 分支命名规则
- 必须 `feature_` 开头。
- 只能包含英文字母和下划线。
- 不能包含数字、中文、短横线。
- 下划线分段后，每段必须是小驼峰风格（首字母小写，后续可大写）。
- 示例：`feature_userCenterExport`、`feature_userCenterExport_chargeFlowAlign`

## 执行动作
在信息收集完成后，执行：

```bash
bash skills/init/scripts/init_requirement_workspace.sh \
  --main-dir <主工程绝对路径> \
  --deps <逗号分隔依赖工程绝对路径> \
  --feature-branch <feature_...> \
  --requirement-key <需求key> \
  --requirement-title "<需求标题>"
```

## 执行约束
- 必须基于最新 `master` 创建分支；`master` 不存在则中断并提示用户处理。
- 强制切换：如果仓库存在未提交变更或切换冲突，自动回退当前改动后继续切换。
- 文档必须同时写入主工程和依赖工程。
- 必须生成过程记录和拆分动作记录文件。

## 强制切换规则
- 先拉取远程最新 `master`。
- 将本地 `master` 强制对齐到 `origin/master`。
- 目标 `feature` 分支不存在时，从对齐后的 `master` 新建。
- 目标 `feature` 分支已存在时，直接强制切换到该分支。
- 回退动作会丢弃当前仓库未提交内容，包含未跟踪文件。

## 结果确认
执行完成后，返回：
1. 主工程文档目录。
2. 每个依赖工程文档目录。
3. 分支创建结果（主工程 + 依赖工程）。
4. 过程记录文件：`04-process-record.md`。
5. 拆分动作记录文件：`05-split-actions.md`，依赖工程 `99-dispatch-receipt.md`。
6. 下一步提示：进入 `brainstorming`。
