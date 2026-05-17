# cwork 技能体系

多工程微服务开发工作流，最小化人工介入，最大化自动执行。

---

## 一、概述

### 核心原则

| 原则 | 说明 |
|------|------|
| 最少确认 | 需求分析阶段对话式，其他阶段自动执行 |
| 最少文件 | 每个工程只维护 1 个 workflow-state.json |
| 最快速度 | 推演在内存中执行，不写中间文档 |
| 自动流转 | 阶段间自动衔接，无需人工触发 |

### 技能结构

```
cwork-init      → 初始化工作区
cwork-implement → 需求分析 + 执行实现 + 推演收敛
cwork-commit    → 提交所有工程
```

---

## 二、完整流程

```
┌─────────────────────────────────────────────────────┐
│  /cwork-init                                        │
├─────────────────────────────────────────────────────┤
│  问题1: 需求名称是什么？                              │
│  → 用户回答                                         │
│  问题2: 分支名称是什么？                             │
│  → 用户回答                                         │
│  问题3: 依赖工程目录名有哪些？                        │
│  → 用户回答                                         │
│                                                     │
│  执行：                                             │
│  ├─ 查找工程完整路径                                 │
│  ├─ 校验所有工程                                    │
│  ├─ 切换分支                                        │
│  └─ 写 workflow-state.json                          │
└─────────────────────────────────────────────────────┘
                         │
                         ▼ 自动
┌─────────────────────────────────────────────────────┐
│  /cwork-implement                                   │
├─────────────────────────────────────────────────────┤
│  第一步：需求分析（对话式，逐步提问）                  │
│  ├─ 探索项目上下文                                   │
│  ├─ 提出澄清问题（每次一个）                          │
│  ├─ 提出 2-3 种方案                                  │
│  ├─ 展示设计，获得批准                               │
│  └─ 记录分析结果                                    │
│                                                     │
│  第二步：执行实现（一把梭哈，多 agent 并行）           │
│  ├─ 主 agent 处理主工程                              │
│  ├─ agent-A 处理 user-service                       │
│  ├─ agent-B 处理 order-service                      │
│  └─ 每个工程独立记录视角                              │
│                                                     │
│  第三步：推演收敛（一把梭哈，自动循环）                 │
│  ├─ Round 1: 推演 → 发现问题 → 修复                  │
│  ├─ Round 2: 推演 → 发现问题 → 修复                  │
│  └─ Round N: 推演 → 无问题 → 收敛                    │
└─────────────────────────────────────────────────────┘
                         │
                         ▼ 自动
┌─────────────────────────────────────────────────────┐
│  /cwork-commit                                      │
├─────────────────────────────────────────────────────┤
│  ├─ 检查 workflow-state                             │
│  ├─ 检查分支一致性                                   │
│  ├─ 提交所有工程                                    │
│  └─ 更新状态为 done                                  │
└─────────────────────────────────────────────────────┘
                         │
                         ▼
                      完成
```

---

## 三、技能详解

### 3.1 cwork-init

**作用**：初始化工作区，切换分支，建立文档目录。

**对话流程**：

```
问题1: 需求名称是什么？
回答: 用户导出

问题2: 分支名称是什么？（以 feature_ 开头）
回答: feature_userExport

问题3: 依赖工程目录名有哪些？
回答: user-service,order-service
```

**执行内容**：
1. 从当前目录向上查找依赖工程完整路径
2. 校验所有工程是否为 git 仓库
3. 强制回退本地改动（reset --hard + clean -fd）
4. 切换或创建 feature 分支
5. 写 workflow-state.json

**分支命名规则**：
- 必须以 `feature_` 开头
- 仅允许字母和下划线
- 正确：`feature_userExport`、`feature_chargeFlow`
- 错误：`feature-user`、`feature123`

**路径查找逻辑**：

用户只需输入目录名，脚本自动向上查找：

```
当前目录: /Users/dev/project/main/src/service
用户输入: user-service

查找顺序:
1. ./user-service
2. ../user-service
3. ../../user-service
4. ../../../user-service
5. 找到 git 仓库则返回
```

---

### 3.2 cwork-implement

**作用**：需求分析 + 执行实现 + 推演收敛。

#### 第一步：需求分析（对话式）

**检查清单**：

1. 探索项目上下文 — 检查文件、文档、最近的 commit
2. 提供视觉伴侣（如果涉及视觉问题）
3. 提出澄清问题 — 每次一个
4. 提出 2-3 种方案 — 附带权衡分析
5. 展示设计 — 分节展示，获得批准
6. 记录分析结果

**核心原则**：

- **每次一个问题** — 不要同时抛出多个问题
- **优先选择题** — 比开放式问题更容易回答
- **探索替代方案** — 始终提出 2-3 种方案
- **增量验证** — 展示设计，获得批准后再继续

**示例对话**：

```
Agent: 这个需求的背景是什么？为什么要做？
用户: 需要支持用户导出自己的数据

Agent: 具体要解决什么问题？现在的痛点是什么？
用户: 用户无法导出历史订单和消费记录

Agent: 涉及哪些模块？
A. 仅主工程
B. 主工程 + user-service
C. 主工程 + user-service + order-service
用户: B

Agent: 有没有跨工程的接口变更？
A. 新增接口
B. 修改现有接口
C. 无接口变更
用户: A

Agent: 我提出 2 种方案：
方案1: 在主工程新增导出接口，调用 user-service 获取数据
方案2: 在 user-service 新增导出接口，主工程转发请求
推荐方案1，因为主工程负责业务编排。
用户: 同意方案1

Agent: 展示设计：
- 主工程：新增 /export 接口，调用 user-service
- user-service：新增 /user/data 接口返回用户数据
是否正确？
用户: 正确
```

#### 第二步：执行实现（一把梭哈）

**多 agent 并行**：

```
主 agent:
├─ 处理主工程改动
└─ 写入主工程 workflow-state.json

agent-A (user-service):
├─ 处理 user-service 改动
└─ 写入 user-service workflow-state.json

agent-B (order-service):
├─ 处理 order-service 改动
└─ 写入 order-service workflow-state.json
```

**每个工程独立记录视角**：

```json
// 主工程 workflow-state.json
{
  "phase": "implement",
  "perspective": "main",
  "analysis": {
    "本工程改动": ["新增导出接口", "修改查询逻辑"],
    "对依赖工程的调用": ["调用 user-service 的 /user/data 接口"],
    "契约变更": ["新增字段 exportTime"]
  }
}

// user-service workflow-state.json
{
  "phase": "implement",
  "perspective": "dependency",
  "analysis": {
    "本工程改动": ["新增 /user/data 接口"],
    "被主工程调用": ["主工程调用 /user/data 接口"],
    "契约变更": ["响应新增字段 exportTime"]
  }
}
```

#### 第三步：推演收敛（一把梭哈）

**自动循环**：

```
round = 1
while round <= 5:
    推演：
    - 主路径闭环？
    - 异常处理？
    - 契约一致？（跨工程）
    - 边界条件？
    - 并发防重？
    
    if 有问题:
        修复
        round += 1
    elif 上轮也无问题:
        break  # 收敛
    else:
        round += 1
```

**推演覆盖面**：

| 检查项 | 说明 |
|--------|------|
| 主路径闭环 | 正常流程是否完整 |
| 异常处理 | 超时、失败、重试是否处理 |
| 契约一致 | 跨工程接口是否匹配 |
| 边界条件 | 空数据、大数据量等 |
| 并发防重 | 重复请求是否防重 |

---

### 3.3 cwork-commit

**作用**：自动提交所有工程。

**执行内容**：
1. 检查 workflow-state 是否为 commit
2. 检查所有工程分支是否一致
3. 生成 commit message
4. 提交所有工程
5. 更新状态为 done

**commit message 格式**：

```
【{需求简称}】<{type}> {说明}
```

**示例**：

```
【用户导出】<add> 新增用户数据导出功能
```

**type 可选值**：

| type | 说明 |
|------|------|
| add | 新增功能 |
| del | 删除功能 |
| modify | 修改功能 |
| fix | 修复问题 |
| refactor | 重构 |
| docs | 文档 |

---

## 四、文件结构

### 产物

每个工程维护 3 个文件：

```
主工程:
docs/requirements/{requirement_key}/
├── workflow-state.json  # 内部状态，不提交
├── analysis.md          # 需求分析文档，提交
└── changes.md           # 改动简述，提交

依赖工程:
docs/requirements/{requirement_key}/
├── workflow-state.json  # 内部状态，不提交
├── analysis.md          # 需求分析文档（从本工程视角），提交
└── changes.md           # 改动简述，提交
```

### workflow-state.json（内部状态，不提交）

```json
{
  "phase": "init|implement|commit|done",
  "requirement_key": "用户导出",
  "feature_branch": "feature_userExport",
  "updated_at": "2026-05-17 12:00:00"
}
```

**加入 .gitignore**：
```
docs/requirements/*/workflow-state.json
```

### analysis.md（需求分析文档，提交）

**主工程视角**：

```markdown
# 需求分析

## 需求背景
用户需要导出自己的历史数据。

## 核心问题
- 用户无法导出订单数据
- 用户无法导出消费记录

## 解决方案
在主工程新增导出接口，编排调用 user-service 和 order-service。

## 本工程改动
- 新增 /export 接口
- 新增导出任务调度逻辑

## 对依赖工程的调用
- 调用 user-service 的 /user/data 获取用户数据
- 调用 order-service 的 /order/list 获取订单数据

## 契约变更
- 新增请求字段：exportType
- 新增响应字段：exportUrl

## 风险点
- 大数据量导出可能超时，需要异步处理
- 并发导出需要防重

## 验收标准
- 用户可导出订单和消费记录
- 导出文件格式为 CSV
```

**user-service 视角**：

```markdown
# 需求分析（user-service 视角）

## 需求背景
主工程需要获取用户数据用于导出。

## 本工程改动
- 新增 /user/data 接口
- 新增用户数据聚合逻辑

## 被主工程调用
- 主工程调用 /user/data 接口获取用户数据

## 契约变更
- 响应新增字段：exportTime, dataRange

## 注意事项
- 需要校验用户权限
- 数据量大的情况需要分页
```

### changes.md（改动简述，提交）

**主工程**：

```markdown
# 改动简述

## 改动内容
- 新增 /export 接口
- 新增导出任务调度逻辑
- 新增异步导出队列

## 涉及文件
- src/controller/ExportController.java
- src/service/ExportService.java
- src/queue/ExportQueue.java

## 推演结论
- 轮次：3
- 发现问题：2 个（已修复）
  - 问题1：未处理空数据情况
  - 问题2：并发导出未防重
```

**user-service**：

```markdown
# 改动简述（user-service 视角）

## 改动内容
- 新增 /user/data 接口
- 新增用户数据聚合逻辑

## 涉及文件
- src/controller/UserDataController.java
- src/service/UserDataService.java

## 推演结论
- 轮次：2
- 发现问题：1 个（已修复）
  - 问题1：未校验用户权限
```

---

## 五、使用示例

### 场景：新增用户导出功能

**涉及工程**：
- 主工程：当前目录
- 依赖工程：user-service, order-service

**执行过程**：

```
用户: /cwork-init

Agent: 需求名称是什么？
用户: 用户导出

Agent: 分支名称是什么？（以 feature_ 开头）
用户: feature_userExport

Agent: 依赖工程目录名有哪些？
用户: user-service,order-service

[init 执行]
- 查找工程路径... OK
- 切换分支 feature_userExport... OK
- 写 workflow-state.json... OK

[自动进入 implement]

Agent: 这个需求的背景是什么？
用户: 需要支持用户导出自己的数据

Agent: 具体要解决什么问题？
用户: 用户无法导出历史订单和消费记录

... (需求分析对话)

Agent: 展示设计：
- 主工程：新增 /export 接口
- user-service：新增 /user/data 接口
是否正确？
用户: 正确

[执行实现]
- 主 agent: 处理主工程
- agent-A: 处理 user-service
- agent-B: 处理 order-service

[推演收敛]
- Round 1: 发现问题 - 未处理空数据
- Round 2: 无问题 - 收敛

[自动进入 commit]

[提交]
- main: abc123
- user-service: def456
- order-service: ghi789

完成
```

---

## 六、对比

| 项目 | 传统方式 | cwork 方式 |
|------|---------|-----------|
| 技能数量 | 9 个阶段 | 3 个阶段 |
| 人工确认 | 6+ 次 | 需求分析阶段对话式，其他自动 |
| 文件数量 | 每工程 8+ 文件 | 每工程 1 文件 |
| 中间文档 | 多个阶段文档 | 无 |
| 推演方式 | 运行测试脚本 | LLM 逻辑推演 |
| 提交流程 | 手动确认 | 自动提交 |
| 多工程处理 | 手动切换目录 | 多 agent 并行 |

---

## 七、注意事项

1. **init 会强制回退本地改动**：执行前确保本地改动已提交或可丢弃

2. **分支命名严格**：必须 `feature_` 开头，仅字母和下划线

3. **推演不运行测试**：纯逻辑推演，最多编译检查语法

4. **需求分析必须完成**：未获得用户批准前不会执行实现

5. **每个工程独立记录**：从各自视角记录分析和改动

---

## 八、常见问题

### Q: 如何跳过某个依赖工程？

A: 在问题 3 时，不输入该工程即可。

### Q: 推演发现问题后会自动修复吗？

A: 会。推演循环会自动修复问题，直到收敛或达到最大轮次（5 轮）。

### Q: 多 agent 并行时如何保证契约一致？

A: 主 agent 先输出契约规范，子 agent 按规范实现。推演阶段主 agent 统一检查跨工程契约一致性。

### Q: 如果中途失败怎么办？

A: workflow-state.json 记录了当前阶段，可以从失败点继续。

---

## 九、安装

```bash
# 复制到 qoder skills 目录
cp -r cwork/skills/* ~/.qoder/skills/
```

安装后可用：
- `/cwork-init`
- `/cwork-implement`
- `/cwork-commit`
