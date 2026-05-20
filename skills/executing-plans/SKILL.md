---
name: cwork-executing-plans
description: 执行实现计划，多工程并行处理
---

# 执行计划

## 概述

加载计划，批判性审查，执行所有任务，完成后报告。

**开始时宣布：** "我正在使用 executing-plans 技能来实现此计划。"

## 语言约束（强制）

- **所有对话必须使用中文**
- **所有问题必须用中文提问**
- **所有回答必须用中文理解**
- 仅在必要处保留英文：命令、路径、参数名、状态码、字段名、代码

## HARD GATE

- workflow-state 不是 writing-plans 或 executing-plans，禁止执行
- 未完成计划编写，禁止执行
- **执行过程中禁止提交代码**，所有提交由 cwork-commit 统一处理

## 流程

### 步骤 1：加载并审查计划

1. 读取主工程计划文件：`docs/requirements/{requirement_key}/plan.md`
2. 读取所有依赖工程计划文件：`docs/requirements/{requirement_key}/{service_name}/plan.md`
3. 批判性审查——识别计划中的任何问题或疑虑
4. 如果有疑虑：在开始之前向用户提出
5. 如果没有疑虑：创建 TodoWrite 并继续

**审查时重点检查：**
- 步骤之间是否有依赖遗漏？
- 是否有隐含的环境假设？
- 跨工程契约是否一致？

### 步骤 2：执行任务（多 agent 并行）

对于每个任务：

```
主工程：主 agent 直接处理

依赖工程：每个依赖工程开一个独立 agent
- agent-A 处理 user-service
- agent-B 处理 order-service
- 并行执行，互不干扰
```

**每个任务的节奏：**
1. **标记为进行中** — 更新 TodoWrite
2. **理解目标** — 重读任务描述，明确完成标准
3. **执行实现** — 严格按照计划步骤执行
4. **标记为已完成** — 更新 TodoWrite

**批量审查检查点：**
- 每完成 3 个任务后，暂停回顾：整体方向还对吗？
- 如果发现前面的实现有问题，先修复再继续

### 步骤 3：处理异常

**依赖缺失：**
```
任务 3 需要 Redis 连接，但计划中没有提及。
→ 停止执行
→ 向用户报告并建议插入配置步骤
```

**指令不清：**
- 不要猜测意图
- 列出你的理解和困惑，让用户澄清
- 等待回复后再继续

### 步骤 4：多工程协调

**跨工程契约检查：**
- 主工程调用的接口是否在依赖工程中实现？
- 请求/响应字段是否匹配？
- 是否有遗漏的字段或类型不一致？

**协调机制：**
1. 主 agent 维护契约清单
2. 每个依赖工程 agent 完成后，主 agent 验证契约
3. 发现不一致时，通知对应 agent 修复

## 文档路径规则（强制）

每个工程的文档必须写到对应路径，不得窜到其他工程目录：

**主工程**：
```
docs/requirements/{requirement_key}/
├── analysis.md
├── changes.md
└── plan.md
```

**依赖工程**：
```
docs/requirements/{requirement_key}/{service_name}/
├── analysis.md
├── changes.md
└── plan.md
```

## 每个工程的记录视角（强制）

**每个工程必须从自己的定位视角写文档，不得遗漏。**

主 agent 负责主工程文档，每个依赖工程 agent 负责对应工程文档：

**主工程** (`docs/requirements/{requirement_key}/changes.md`)：
```markdown
# 改动简述

## 改动内容
- 新增导出接口
- 修改查询逻辑

## 涉及文件
- src/controller/ExportController.java
- src/service/ExportService.java

## 对依赖工程的调用
- 调用 user-service 的 /user/data 接口
```

**user-service** (`docs/requirements/{requirement_key}/user-service/changes.md`)：
```markdown
# 改动简述（user-service 视角）

## 改动内容
- 新增 /user/data 接口实现

## 涉及文件
- src/controller/UserDataController.java

## 被主工程调用
- 主工程调用 /user/data 接口获取用户数据
```

## 输出完整性检查（强制）

执行完成后必须检查：

```
主工程文档：
✓ docs/requirements/{requirement_key}/analysis.md
✓ docs/requirements/{requirement_key}/changes.md
✓ docs/requirements/{requirement_key}/plan.md

依赖工程文档（每个依赖工程）：
✓ docs/requirements/{requirement_key}/{service_name}/analysis.md
✓ docs/requirements/{requirement_key}/{service_name}/changes.md
✓ docs/requirements/{requirement_key}/{service_name}/plan.md
```

**如有缺失，立即补充对应文档。**

## 自动衔接

完成后自动调起 `cwork-loop-refined` 进行推演收敛，不询问用户。
