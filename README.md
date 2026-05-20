# cwork

面向多工程联动研发的自动化 workflow 技能体系。

## 核心特点

| 特点 | 说明 |
|------|------|
| 对话式需求分析 | 逐步提问，每次一个问题，获得批准后才执行 |
| 多工程并行处理 | 每个依赖工程开独立 agent，并行执行互不干扰 |
| 逻辑推演替代测试 | 用逻辑推演替代单元测试，自动发现问题修复 |
| 自动衔接 | 每个阶段完成后自动进入下一阶段，无需手动触发 |
| 全中文对话 | 所有分析、提问、结论都用中文 |

## 技能结构（对外暴露）

```
cwork-init      → 初始化工作区（唯一入口）
cwork-implement → 需求分析 + 编写计划 + 执行计划 + 推演收敛
cwork-commit    → 提交所有工程
```

## 完整流程

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
│  ├─ 自动查找工程完整路径                             │
│  ├─ 校验所有工程                                    │
│  ├─ 切换分支                                        │
│  └─ 写 workflow-state.json                          │
└─────────────────────────────────────────────────────┘
                         │
                         ▼ 自动衔接
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
│  第二步：编写计划                                    │
│  ├─ 列出文件结构                                    │
│  ├─ 拆分小步骤任务                                  │
│  ├─ 编写任务代码                                    │
│  └─ 自检计划完整性                                  │
│                                                     │
│  第三步：执行计划（多 agent 并行）                    │
│  ├─ 加载并审查计划                                   │
│  ├─ 主 agent 处理主工程                              │
│  ├─ agent-A 处理 user-service                       │
│  ├─ agent-B 处理 order-service                      │
│  └─ 每个工程独立记录视角                              │
│                                                     │
│  第四步：推演收敛（逻辑推演替代测试）                  │
│  ├─ Round 1: 推演 → 发现问题 → 修复                  │
│  ├─ Round 2: 推演 → 发现问题 → 修复                  │
│  └─ Round N: 推演 → 无问题 → 收敛                    │
└─────────────────────────────────────────────────────┘
                         │
                         ▼ 自动衔接
┌─────────────────────────────────────────────────────┐
│  /cwork-commit                                      │
├─────────────────────────────────────────────────────┤
│  ├─ 检查 workflow-state                             │
│  ├─ 检查分支一致性                                   │
│  ├─ 提交所有工程（commit + push）                    │
│  └─ 更新状态为 done                                  │
└─────────────────────────────────────────────────────┘
                         │
                         ▼
                      完成
```

## 安装

```bash
# 复制到目标工具的 skills 目录
node /path/to/cwork/bin/cwork.js --tool auto

# 或指定工具安装
node bin/cwork.js --tool codex

# 卸载
node bin/cwork.js --uninstall --tool codex
```

支持工具：`codex` / `claude` / `cursor` / `gemini` / `qoder` / `windsurf` / `aider` / `opencode` / `qwen` / `antigravity` / `hermes` / `trae` / `kiro` / `openclaw` / `cline` / `copilot`

安装后技能名会加前缀 `cwork-`（例如 `cwork-init`、`cwork-implement`），避免和已有 skills 冲突。

## 使用示例

```
用户: /cwork-init

Claude: 需求名称是什么？
用户: 用户导出

Claude: 分支名称是什么？（以 feature_ 开头，如 feature_userExport）
用户: feature_userExport

Claude: 依赖工程目录名有哪些？（多个用逗号分隔，没有则回车跳过）
用户: user-service,order-service

Claude: [自动执行初始化，然后进入 implement]
```

## 文档结构

主工程 `docs/requirements/{requirement_key}/`：
- `workflow-state.json` — 内部状态，不提交
- `analysis.md` — 需求分析文档，提交
- `changes.md` — 改动简述，提交
- `plan.md` — 实现计划，提交

依赖工程 `docs/requirements/{requirement_key}/{service_name}/`：
- `workflow-state.json` — 内部状态，不提交
- `analysis.md` — 需求分析文档（从本工程视角），提交
- `changes.md` — 改动简述，提交
- `plan.md` — 实现计划，提交

## 推演收敛覆盖面

| 检查项 | 说明 |
|--------|------|
| 主路径闭环 | 正常流程是否完整执行 |
| 异常处理 | 超时、失败、重试是否处理 |
| 契约一致 | 跨工程接口字段是否匹配 |
| 边界条件 | 空数据、大数据量、特殊字符等 |
| 并发防重 | 重复请求是否防重 |
| 数据一致性 | 跨工程数据是否一致 |

## 关键规则

1. **init 是唯一入口**，禁止跳过
2. **分支命名严格**：必须 `feature_`/`hotfix_`/`bugfix_`/`refactor_` 开头
3. **需求分析必须完成**：未获得用户批准前不会执行实现
4. **计划禁止占位符**：不能写"待定"、"TODO"等
5. **每个工程独立记录**：从各自视角记录分析和改动
6. **不需要编写测试用例**：用逻辑推演替代
7. **implement 过程中禁止提交代码**：所有提交由 cwork-commit 统一处理

## 多服务需求拆分

当需求涉及多个服务时，cwork 会站在每个服务的定位角度，将需求拆分成多个需求理解和改动计划：

| 原则 | 说明 |
|------|------|
| 每个服务独立视角 | 从本服务的职责定位理解需求 |
| 每个服务独立分支 | 所有服务工程都切换到同一 feature 分支 |
| 每个服务独立文档 | 每个服务有独立的 analysis.md、plan.md、changes.md |
| 契约明确 | 服务间的调用关系和数据结构必须明确 |

**示例**：主服务需要调用 user-service 和 order-service

```
主服务视角：我需要提供导出入口，调用 user-service 获取用户数据，调用 order-service 获取订单数据
user-service 视角：主服务需要我提供用户数据，我需要新增 /user/data 接口
order-service 视角：主服务需要我提供订单数据，我需要新增 /order/list 接口
```

## 如何使用

### 第一步：初始化

```
/cwork-init
```

Claude 会依次提问：
1. 需求名称是什么？
2. 分支名称是什么？（以 feature_ 开头）
3. 依赖工程目录名有哪些？（多个用逗号分隔，没有则回车跳过）

回答完后自动执行初始化，然后自动进入 implement。

### 第二步：实现（自动衔接）

```
/cwork-implement
```

Claude 会：
1. **需求分析**：逐步提问，每次一个问题，获得批准后才继续
2. **编写计划**：为每个服务独立编写实现计划
3. **执行计划**：多 agent 并行，每个工程一个独立 agent
4. **推演收敛**：逻辑推演替代测试，自动发现问题并修复

完成后自动进入 commit。

### 第三步：提交（自动衔接）

```
/cwork-commit
```

自动提交所有服务工程，不确认。

### 完整示例

```
用户: /cwork-init

Claude: 需求名称是什么？
用户: 用户导出

Claude: 分支名称是什么？（以 feature_ 开头，如 feature_userExport）
用户: feature_userExport

Claude: 依赖工程目录名有哪些？（多个用逗号分隔，没有则回车跳过）
用户: user-service,order-service

Claude: 
[执行初始化]
- 查找工程路径 ✓
  - 主工程: /Users/dev/project/main-service
  - user-service: /Users/dev/project/user-service
  - order-service: /Users/dev/project/order-service
- 切换分支 ✓
- 创建需求文档目录 ✓

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

...（继续需求分析，获得批准后执行）

Claude: [推演收敛完成，自动进入 commit]

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

## 详细文档

详见 `docs/USAGE.md`
