# cwork 使用指南

## 一、整体架构

### 1.1 设计理念

cwork 是面向多工程联动研发的自动化工作流技能体系，核心特点：

| 特点 | 说明 |
|------|------|
| 对话式需求分析 | 逐步提问，每次一个问题，获得批准后才执行 |
| 多服务需求拆分 | 站在每个服务视角独立分析需求，生成独立文档 |
| 多工程并行处理 | 每个依赖工程开独立 agent，并行执行互不干扰 |
| 逻辑推演替代测试 | 用逻辑推演替代单元测试，自动发现问题修复 |
| 自动衔接 | 每个阶段完成后自动进入下一阶段，无需手动触发 |
| 全中文对话 | 所有分析、提问、结论都用中文 |

### 1.2 技能结构（对外暴露 3 个）

```
cwork-init      → 初始化工作区，多服务分支切换（唯一入口）
cwork-implement → 需求分析 + 编写计划 + 执行计划 + 推演收敛
cwork-commit    → 提交所有服务工程
```

**注意**：`cwork-implement` 内部包含四个阶段（brainstorming、writing-plans、executing-plans、loop-refined），但这些内部技能不对外暴露，用户只需调用 `/cwork-implement`。

---

## 二、多服务需求拆分（核心机制）

### 2.1 概述

当需求涉及多个服务时，cwork 会站在每个服务的定位角度，将需求拆分成多个需求理解和改动计划。

### 2.2 拆分原则

1. **每个服务独立视角**：从本服务的职责定位理解需求
2. **每个服务独立分支**：所有服务工程都切换到同一 feature 分支
3. **每个服务独立文档**：每个服务有独立的 analysis.md、plan.md、changes.md
4. **契约明确**：服务间的调用关系和数据结构必须明确

### 2.3 拆分流程

```
┌─────────────────────────────────────────────────────────────────┐
│  cwork-init：多服务初始化                                         │
├─────────────────────────────────────────────────────────────────┤
│  主工程：创建分支 feature_userExport                              │
│         创建目录 docs/requirements/user-export/                  │
│                                                                 │
│  user-service：创建分支 feature_userExport                       │
│                创建目录 docs/requirements/user-export/user-service/│
│                                                                 │
│  order-service：创建分支 feature_userExport                      │
│                 创建目录 docs/requirements/user-export/order-service/│
└─────────────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│  cwork-implement：多服务需求拆分                                   │
├─────────────────────────────────────────────────────────────────┤
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  主服务视角分析                                             │  │
│  ├───────────────────────────────────────────────────────────┤  │
│  │  需求理解：                                                 │  │
│  │  - 作为主服务，我需要提供什么功能？                           │  │
│  │  - 我需要调用哪些依赖服务？                                  │  │
│  │  - 我需要编排什么流程？                                     │  │
│  │                                                            │  │
│  │  改动范围：                                                 │  │
│  │  - 新增/修改哪些接口？                                      │  │
│  │  - 新增/修改哪些逻辑？                                      │  │
│  │                                                            │  │
│  │  契约定义：                                                 │  │
│  │  - 调用 user-service 的 /user/data 接口                    │  │
│  │  - 请求：{ userId: String }                                │  │
│  │  - 响应：{ userInfo: {...}, exportTime: Date }             │  │
│  │                                                            │  │
│  │  输出：docs/requirements/user-export/analysis.md           │  │
│  └───────────────────────────────────────────────────────────┘  │
│                         │                                       │
│                         ▼                                       │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  user-service 视角分析                                     │  │
│  ├───────────────────────────────────────────────────────────┤  │
│  │  需求理解（从 user-service 视角）：                          │  │
│  │  - 主服务需要我提供什么数据？                                │  │
│  │  - 我需要新增/修改什么接口？                                 │  │
│  │  - 我需要查询哪些数据？                                     │  │
│  │                                                            │  │
│  │  改动范围：                                                 │  │
│  │  - 新增 /user/data 接口                                    │  │
│  │  - 新增用户数据聚合逻辑                                      │  │
│  │                                                            │  │
│  │  契约响应：                                                 │  │
│  │  - 响应字段：userInfo, exportTime                          │  │
│  │  - 数据来源：用户表 + 消费记录表                              │  │
│  │                                                            │  │
│  │  输出：docs/requirements/user-export/user-service/analysis.md│  │
│  └───────────────────────────────────────────────────────────┘  │
│                         │                                       │
│                         ▼                                       │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  order-service 视角分析                                    │  │
│  ├───────────────────────────────────────────────────────────┤  │
│  │  需求理解（从 order-service 视角）：                         │  │
│  │  - 主服务需要我提供什么数据？                                │  │
│  │  - 我需要新增/修改什么接口？                                 │  │
│  │  - 我需要查询哪些数据？                                     │  │
│  │                                                            │  │
│  │  输出：docs/requirements/user-export/order-service/analysis.md│  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│  cwork-commit：多服务提交                                         │
├─────────────────────────────────────────────────────────────────┤
│  user-service：                                                 │
│    → git commit -m "【用户导出】<add> 新增用户数据查询接口"         │
│    → git push origin feature_userExport                         │
│                                                                 │
│  order-service：                                                │
│    → git commit -m "【用户导出】<add> 新增订单查询接口"             │
│    → git push origin feature_userExport                         │
│                                                                 │
│  main-service：                                                 │
│    → git commit -m "【用户导出】<add> 新增导出功能"                │
│    → git push origin feature_userExport                         │
└─────────────────────────────────────────────────────────────────┘
```

### 2.4 文档结构（多服务）

```
主工程 docs/requirements/user-export/
├── workflow-state.json      # 内部状态
├── analysis.md              # 主服务视角的需求分析
├── plan.md                  # 主服务的实现计划
└── changes.md               # 主服务的改动简述

user-service docs/requirements/user-export/user-service/
├── workflow-state.json      # 内部状态
├── analysis.md              # user-service 视角的需求分析
├── plan.md                  # user-service 的实现计划
└── changes.md               # user-service 的改动简述

order-service docs/requirements/user-export/order-service/
├── workflow-state.json      # 内部状态
├── analysis.md              # order-service 视角的需求分析
├── plan.md                  # order-service 的实现计划
└── changes.md               # order-service 的改动简述
```

### 2.5 analysis.md 示例（不同视角）

**主工程** `docs/requirements/user-export/analysis.md`：
```markdown
# 需求分析（主服务视角）

## 需求背景
用户需要导出自己的历史数据，包括基本信息和订单数据。

## 本服务职责
- 提供统一的导出入口
- 编排调用 user-service 和 order-service
- 生成导出文件并返回下载链接

## 对依赖服务的调用
- 调用 user-service 的 /user/data 接口获取用户基本信息
- 调用 order-service 的 /order/list 接口获取订单数据

## 契约定义（调用方视角）

### 调用 user-service
- 接口：POST /user/data
- 请求：{ "userId": "string" }
- 响应：{ "userInfo": {...}, "exportTime": "date" }

### 调用 order-service
- 接口：POST /order/list
- 请求：{ "userId": "string", "limit": 10000 }
- 响应：{ "orderList": [...], "totalCount": 100 }

## 本服务改动
- 新增 /export 接口
- 新增导出任务调度逻辑
- 新增文件生成逻辑

## 风险点
- 大数据量导出可能超时，需要异步处理
- 并发导出需要防重
```

**user-service** `docs/requirements/user-export/user-service/analysis.md`：
```markdown
# 需求分析（user-service 视角）

## 需求背景
主服务需要获取用户数据用于导出功能。

## 本服务职责
- 提供用户数据查询接口
- 聚合用户基本信息和消费记录

## 被主服务调用
- 接口：POST /user/data
- 调用方：主服务
- 用途：获取用户数据用于导出

## 契约定义（被调用方视角）

### /user/data 接口
- 请求：{ "userId": "string" }
- 响应：{ "userInfo": {...}, "exportTime": "date" }
- 说明：返回用户基本信息，exportTime 为数据导出时间

## 本服务改动
- 新增 /user/data 接口
- 新增用户数据聚合逻辑

## 注意事项
- 需要校验用户权限
- 数据量大的情况需要分页
```

---

## 三、技能详解

### 3.1 cwork-init

**作用**：初始化工作区，对话式收集信息，自动查找工程路径，为所有服务工程创建/切换分支。

**对话流程**：

```
用户: /cwork-init

Claude: 需求名称是什么？
用户: 用户导出

Claude: 分支名称是什么？（以 feature_ 开头，如 feature_userExport）
用户: feature_userExport

Claude: 依赖工程目录名有哪些？（多个用逗号分隔，没有则回车跳过）
用户: user-service,order-service

Claude: [自动执行初始化]
```

**执行内容**（多服务场景）：
1. 查找主工程和所有依赖工程完整路径
2. 校验所有工程是否为 git 仓库
3. **为每个服务工程执行**：
   - 备份本地改动（git stash）
   - 创建/切换到同一 feature 分支
   - 创建需求文档目录
4. 写入各服务的 workflow-state.json
5. 自动进入 implement

**分支命名规则**：
- 必须以 `feature_`、`hotfix_`、`bugfix_`、`refactor_` 开头
- 允许字母、数字和下划线
- 示例：`feature_userExport`、`feature_userExport_v2`、`hotfix_loginError`

---

### 3.2 cwork-implement

**作用**：需求分析 + 编写计划 + 执行计划 + 推演收敛。

**内部包含四个阶段**：

#### 内部阶段一：需求分析（brainstorming）

**检查清单**（按顺序执行）：

1. **探索项目上下文** — 检查文件、文档、最近的 commit
2. **提供视觉伴侣**（如果主题涉及视觉问题）— 独立消息
3. **提出澄清问题** — 每次一个，了解目的/约束/成功标准
4. **提出 2-3 种方案** — 附带权衡分析和推荐
5. **展示设计** — 按复杂度分节展示，每节展示后获得用户批准
6. **多服务需求拆分** — 站在每个服务视角分析需求
7. **写入各服务的 analysis.md**

**核心原则**：
- 每次一个问题
- 优先选择题
- 严格遵循 YAGNI
- 探索替代方案
- 增量验证
- **多服务独立视角**

#### 内部阶段二：编写计划（writing-plans）

为每个服务独立编写计划：
- 主服务：写入 `docs/requirements/{key}/plan.md`
- 依赖服务：写入 `docs/requirements/{key}/{service_name}/plan.md`

#### 内部阶段三：执行计划（executing-plans）

**多工程并行架构**：

```
┌─────────────────────────────────────────────────────────────┐
│                     主代理（协调者）                          │
│  - 加载所有工程计划                                            │
│  - 维护跨工程契约清单                                          │
│  - 协调子代理执行                                              │
│  - 验证契约一致性                                              │
└─────────────────────────────────────────────────────────────┘
         │                    │                    │
         ▼                    ▼                    ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│ 子代理-A         │  │ 子代理-B         │  │ 子代理-C         │
│ 主工程           │  │ user-service     │  │ order-service   │
└─────────────────┘  └─────────────────┘  └─────────────────┘
```

#### 内部阶段四：推演收敛（loop-refined）

**推演循环**（至少 2 轮）：

```
Round 1:
- 主路径闭环 ✓
- 异常处理 ✗ → 修复
- 契约一致 ✓
- 边界条件 ✗ → 修复
- 并发防重 ✓
- 数据一致性 ✓

Round 2: 全部通过 ✓

Round 3: 全部通过 ✓ → 收敛
```

---

### 3.3 cwork-commit

**作用**：推演收敛后自动提交所有服务工程，不确认。

**执行内容**（多服务场景）：
1. 检查所有服务工程分支是否一致
2. **为每个服务工程执行**：
   - 生成 commit message（从本服务视角）
   - 提交代码和文档
   - 推送到远程
3. 更新所有服务工程状态为 done

**commit message 格式**：

```
【{需求简称}】<{type}> {说明}
```

**示例**：
```
主工程：【用户导出】<add> 新增导出功能
user-service：【用户导出】<add> 新增用户数据查询接口
order-service：【用户导出】<add> 新增订单查询接口
```

---

## 四、完整流程示例

```
用户: /cwork-init

Claude: 需求名称是什么？
用户: 用户导出

Claude: 分支名称是什么？（以 feature_ 开头）
用户: feature_userExport

Claude: 依赖工程目录名有哪些？
用户: user-service,order-service

Claude: 
[执行初始化...]
- 查找工程路径 ✓
  - 主工程: /Users/dev/project/main-service
  - user-service: /Users/dev/project/user-service
  - order-service: /Users/dev/project/order-service
- 校验所有工程 ✓
- 为每个服务工程切换分支 ✓
  - main-service: feature_userExport
  - user-service: feature_userExport
  - order-service: feature_userExport
- 创建需求文档目录 ✓
- 写入 workflow-state.json ✓

[自动进入 implement]

Claude: 我正在分析项目上下文...

Claude: 这个导出功能的核心目的是什么？
A. 导出用户个人数据（合规要求）
B. 导出用户消费记录（运营需求）
C. 导出用户订单数据（用户自助）

用户: A

Claude: 导出的数据范围包括哪些？
A. 基本信息 + 消费记录
B. 基本信息 + 订单数据
C. 全部数据

用户: B

Claude: 我建议采用以下方案：

方案一（推荐）：主工程编排，依赖工程提供数据接口
- 优点：职责清晰，易于维护
- 缺点：需要修改依赖工程

推荐方案一，是否采用？

用户: 是

Claude: [展示设计，获得批准后进行多服务需求拆分]

## 主服务视角分析
- 本服务职责：提供导出入口，编排调用
- 对依赖服务的调用：user-service、order-service
- 契约定义：...
- 写入 docs/requirements/user-export/analysis.md

## user-service 视角分析
- 本服务职责：提供用户数据查询接口
- 被主服务调用：/user/data
- 契约响应：...
- 写入 docs/requirements/user-export/user-service/analysis.md

## order-service 视角分析
- 本服务职责：提供订单查询接口
- 被主服务调用：/order/list
- 契约响应：...
- 写入 docs/requirements/user-export/order-service/analysis.md

Claude: [编写各服务的实现计划]

Claude: [执行计划，多 agent 并行]

Claude: [推演收敛]

Claude: [自动进入 commit]

Claude: 
提交完成！

main-service:
  分支：feature_userExport
  提交：abc123 【用户导出】<add> 新增导出功能
  推送：✓

user-service:
  分支：feature_userExport
  提交：def456 【用户导出】<add> 新增用户数据查询接口
  推送：✓

order-service:
  分支：feature_userExport
  提交：ghi789 【用户导出】<add> 新增订单查询接口
  推送：✓

状态：done
```

---

## 五、注意事项

### 5.1 关键规则

1. **init 是唯一入口**，禁止跳过
2. **分支命名严格**：必须以 `feature_`/`hotfix_`/`bugfix_`/`refactor_` 开头
3. **需求分析必须完成**：未获得用户批准前不会执行实现
4. **计划禁止占位符**：不能写"待定"、"TODO"等
5. **多服务独立视角**：每个服务从自己的职责定位理解需求
6. **多服务独立分支**：所有服务工程都要切换到同一 feature 分支
7. **多服务独立文档**：每个服务有独立的 analysis.md、plan.md、changes.md
8. **不需要编写测试用例**：用逻辑推演替代
9. **implement 过程中禁止提交代码**：所有提交由 cwork-commit 统一处理

### 5.2 安全保护

- init 会自动备份每个服务工程的本地改动（git stash）
- 可通过 `git stash pop` 恢复

### 5.3 .gitignore 配置

```
docs/requirements/*/workflow-state.json
.cwork/backup/
```
