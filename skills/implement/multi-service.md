# 多服务需求拆分

> **按需加载**：本文件由 implement SKILL.md 在识别到多服务场景时 Read 加载，不随 SKILL.md 一起全量加载。

## 拆分原则

1. **每个服务独立视角**：从本服务的职责定位理解需求
2. **契约明确**：服务间的调用关系和数据结构必须明确
3. **独立文档**：每个服务有独立的 analysis.md、plan.md、changes.md
4. **独立分支**：每个服务工程都要创建/切换到同一 feature 分支——**必须走 `cwork-common/git-guard.md` 防护命令序列**：建分支后立即纠正 upstream（只能是 `origin/<同名分支>`），验证通过再继续

## 多服务初始化（识别到多服务后、需求分析前，一次完成）

对每个涉及的服务工程，按序执行：

1. **定位工程路径**：优先 Bash `printf "%s/.services-map.md\n" "$CWORK_HOME"` 展开后 Read 服务地图按名匹配；地图未命中/标 `[需确认]` → 从当前目录逐级向上查找同名目录兜底；仍找不到 → 问用户，禁止猜
2. **校验**：确认目录是 git 仓库（`git -C <目录> rev-parse --is-inside-work-tree`），不是则停下报告
3. **备份本地改动**：`git stash`（有未提交改动时；stash 后告知用户备份位置）
4. **创建/切换 feature 分支**：`git fetch origin && git checkout -b feature/<YYYYMMDD>-<需求短名> origin/master`（已在同名分支则复用）；建分支后按 git-guard 纠正并验证 upstream
5. **建文档目录**：`<工程>/docs/requirements/{requirement_key}/`
6. **全部服务就位后**：触发 codegraph 图谱更新 `codegraph sync "${CODE_WORKSPACE:-$HOME/Work/code-projects}"`（未装/锁占用则跳过不阻塞；禁止 -q 静默吞错），保证后续分析用最新图谱
7. **写各服务 workflow-state.json**（含 requirement_id、multi_service_mode: true、main_service、dependent_services）

## 拆分流程

```
┌─────────────────────────────────────────────────────────────────┐
│  主服务视角分析                                                  │
├─────────────────────────────────────────────────────────────────┤
│  需求理解：                                                      │
│  - 作为主服务，我需要提供什么功能？                                │
│  - 我需要调用哪些依赖服务？                                       │
│  - 我需要编排什么流程？                                          │
│                                                                 │
│  改动范围：                                                      │
│  - 新增/修改哪些接口？                                           │
│  - 新增/修改哪些逻辑？                                           │
│                                                                 │
│  契约定义：                                                      │
│  - 调用 user-service 的 /user/data 接口                         │
│  - 请求：{ userId: String }                                     │
│  - 响应：{ userInfo: {...}, exportTime: Date }                  │
└─────────────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│  依赖服务视角分析（每个依赖服务独立）                              │
├─────────────────────────────────────────────────────────────────┤
│  需求理解（从本服务视角）：                                       │
│  - 主服务需要我提供什么数据？                                     │
│  - 我需要新增/修改什么接口？                                      │
│  - 我需要查询哪些数据？                                          │
│                                                                 │
│  改动范围 + 契约响应                                             │
└─────────────────────────────────────────────────────────────────┘
```

## 文档结构（多服务）

```
主工程：
主工程/docs/requirements/user-export/
├── workflow-state.json      # 内部状态（包含 requirement_id）
├── analysis.md              # 主服务视角的需求分析
├── plan.md                  # 主服务的实现计划
└── changes.md               # 主服务的改动简述

依赖工程（在各自工程目录下）：
{dep-service}/docs/requirements/user-export/
├── workflow-state.json      # 内部状态（包含 requirement_id）
├── analysis.md              # 本服务视角的需求分析
├── plan.md                  # 本服务的实现计划
└── changes.md               # 本服务的改动简述
```

**注意**：每个服务的 workflow-state.json 都必须包含 requirement_id 字段。

## analysis.md 示例（不同视角）

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

**依赖服务** `docs/requirements/user-export/user-service/analysis.md`：
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

## 契约对齐

1. 检查主服务的调用契约和依赖服务的响应契约是否一致
2. 检查字段名、类型、必填性是否匹配
3. 发现不一致时协调修正
