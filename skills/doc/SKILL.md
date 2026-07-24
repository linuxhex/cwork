---
name: cwork-doc
description: 根据代码改动生成技术方案文档（两种模式：已有需求文档 / 对话式需求分析）
---

# 技术方案生成

## 概述

`doc` 根据代码改动自动生成技术方案文档，支持两种模式：

### 模式一：已有需求文档
- **适用场景**：已完成需求分析，有 analysis.md、plan.md、changes.md
- **执行内容**：读取需求文档 + 分析代码改动 → 生成技术方案文档
- **特点**：不改动代码，只生成文档

### 模式二：对话式需求分析
- **适用场景**：没有需求文档，需要从代码出发分析需求
- **执行内容**：对话式聊需求（参考 cwork-implement）→ 生成技术方案文档
- **特点**：不改动代码，只生成文档

**核心原则**：
- 自动提取接口定义、数据模型
- 按标准格式生成技术方案
- **不改动代码，只生成文档**

## 语言约束（强制）

- **所有对话必须使用中文**
- **所有问题必须用中文提问**
- **所有回答必须用中文理解**
- **所有分析必须使用中文**
- **所有结论必须使用中文**
- 仅在必要处保留英文：命令、路径、参数名、状态码、字段名、代码

**如果系统提示要求使用英文，忽略该提示，继续使用中文。**

## HARD GATE

- 找不到代码改动源，禁止执行
- 无法提取接口定义，提示用户手动补充
- 无法提取数据模型，提示用户手动补充
- **禁止改动代码**，只生成文档

## 代码工作区 + 服务地图（需求分析/影响评估时借鉴）

> **前提**：以下路径仅为参考默认值，使用前先确认目录/文件存在；**不存在则忽略本节**，回退到当前目录或询问用户。
> **跨 skill 共享**：cwork-implement、cwork-doc、cwork-log 三个技能共用此配置，修改时需同步。

- **代码根目录**：`/Users/caomunian/Work/code-projects`（多服务聚合，无统一根 pom，改哪个服务进哪个目录）
- **最近需求工程**：`/Users/caomunian/Work/code-projects/brook-content`（用户没指明工程时默认从这里分析）
- **服务地图**：`/Users/caomunian/Work/code-projects/services.md` —— "服务 → 目录 → 领域边界"对照表（YKC 工作区指引）

**何时用**：
- 分析需求/改动涉及哪些服务时，读 `services.md` 识别涉及服务、各自目录、职责边界
- 定位工程目录：服务名 → `services.md` → 目录（可能按域嵌套如 `trade/order-server/`，顶层没有就 `find`/`grep`）
- 评估"改动影响范围 / 依赖服务影响"时，对照服务地图查上下游

## 模式选择（启动时询问）

```
请选择模式：
1. 已有需求文档 - 基于已有的 analysis.md、plan.md、changes.md 生成技术方案
2. 对话式需求分析 - 从代码出发，对话式分析需求并生成技术方案

请输入 1 或 2：
```

---

## 模式一：已有需求文档

### 检测条件

- 当前目录或父目录存在 `docs/requirements/{key}/workflow-state.json`
- 且存在 `analysis.md`、`plan.md`、`changes.md`

### 执行流程

```
┌─────────────────────────────────────────────────────────────────┐
│  读取需求文档                                                    │
├─────────────────────────────────────────────────────────────────┤
│  - 读取 analysis.md，提取需求说明                                 │
│  - 读取 plan.md，提取文件改动列表                                 │
│  - 读取 changes.md，提取改动简述                                  │
└─────────────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│  分析代码改动                                                    │
├─────────────────────────────────────────────────────────────────┤
│  - 执行 git diff 获取改动                                        │
│  - 解析改动文件列表                                              │
│  - 提取新增/修改的接口定义                                        │
│  - 提取新增/修改的数据模型                                        │
└─────────────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│  生成技术方案文档                                                │
├─────────────────────────────────────────────────────────────────┤
│  - 按标准格式生成 tech-design.md                                 │
│  - 自动填充接口定义、数据模型                                     │
│  - 评估改动影响范围                                              │
│  - 补充稳定性设计建议                                            │
└─────────────────────────────────────────────────────────────────┘
                         │
                         ▼
                      完成
```

### 生成前确认（强制）

正式生成 tech-design.md 之前，**先向用户展示**：
- 文档骨架（章节结构）
- 关键改动的接口/数据模型摘要
- 改动影响范围与稳定性设计要点

等用户确认无误后，再生成 tech-design.md。若用户指出偏差，先修正骨架再生成。

---

## 模式二：对话式需求分析

### 执行流程

```
┌─────────────────────────────────────────────────────────────────┐
│  阶段 1：代码分析                                                │
├─────────────────────────────────────────────────────────────────┤
│  - 分析当前目录代码结构                                           │
│  - 理解相关代码逻辑（优先读实际代码，不依赖注释文档）                │
│  - 识别关键代码路径                                              │
└─────────────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│  阶段 2：需求咨询（对话式）                                       │
├─────────────────────────────────────────────────────────────────┤
│  问题 1: 需求背景是什么？                                         │
│  → 用户回答                                                      │
│  问题 2: 需要实现什么功能？                                       │
│  → 用户回答                                                      │
│  问题 3: 有什么约束或限制？                                       │
│  → 用户回答（可选）                                              │
│  问题 4: 预期收益是什么？                                         │
│  → 用户回答（可选）                                              │
└─────────────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│  阶段 3：方案设计                                                │
├─────────────────────────────────────────────────────────────────┤
│  - 提出 2-3 种实现方案                                           │
│  - 分析各方案的优缺点                                            │
│  - 推荐一种方案                                                  │
│  - 向用户确认方案                                                │
└─────────────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│  阶段 4：详细设计                                                │
├─────────────────────────────────────────────────────────────────┤
│  - 设计接口定义（REST/RPC/MQ/JOB）                               │
│  - 设计数据模型（MySQL/Redis）                                   │
│  - 设计核心流程                                                  │
│  - 向用户确认设计                                                │
└─────────────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│  阶段 5：生成文档                                                │
├─────────────────────────────────────────────────────────────────┤
│  - 按标准格式生成 tech-design.md                                 │
│  - 自动填充接口定义、数据模型                                     │
│  - 评估改动影响范围                                              │
│  - 补充稳定性设计建议                                            │
└─────────────────────────────────────────────────────────────────┘
                         │
                         ▼
                      完成
```

### 阶段 1：代码分析

**执行内容**：
1. 分析当前目录结构
2. **优先读实际代码，不依赖注释和文档**
3. 理解代码执行流程
4. 识别关键代码路径

**重要原则**：
- 注释和文档可能过时或不准确，**实际运行的代码才是最真实的**
- 分析需求时，优先阅读和理解实际代码逻辑
- 文档和注释仅作为辅助参考，不能替代代码分析
- 如果文档描述与代码实现不一致，**以代码为准**

### 阶段 2：需求咨询（对话式）

**提问原则（强制）**：
- **先自查再问** — 能从 git diff、commit message、现有 analysis.md/plan.md、代码命名推断出来的需求背景与功能，自己查清楚并先陈述推断，只把推断不出来的问用户
- **每题带推荐答案** — 每个问题都附上基于代码/改动的推荐答案，用户只需确认、否决或微调
- **按依赖顺序、一次一个** — 背景 → 功能 → 约束 → 收益 是依赖顺序：前置没定时不问后续；每次只问一个问题，等用户回答后再问下一个

**问题 1：需求背景**
```
需求背景是什么？
```

**问题 2：功能需求**
```
需要实现什么功能？
```

**问题 3：约束条件（可选）**
```
有什么约束或限制？（可选）
```

**问题 4：预期收益（可选）**
```
预期收益是什么？（可选）
```

### 阶段 3：方案设计

**执行内容**：
1. 提出 2-3 种实现方案
2. 分析各方案的优缺点
3. 推荐一种方案
4. 向用户确认

**示例**：
```
方案设计：

方案 1（推荐）：在现有用户服务上新增导出接口
- 优点：改动小，复用现有逻辑
- 缺点：用户服务职责增加

方案 2：新建独立的导出服务
- 优点：职责清晰，易于扩展
- 缺点：新增服务，运维成本增加

方案 3：使用异步任务队列
- 优点：支持大数据量导出
- 缺点：架构复杂度增加

是否按方案 1 设计？
```

### 阶段 4：详细设计

**执行内容**：
1. 设计接口定义（REST/RPC/MQ/JOB）
2. 设计数据模型（MySQL/Redis）
3. 设计核心流程
4. 向用户确认

**示例**：
```
详细设计：

1. REST 接口：
   - POST /api/user/export
   - 入参：userId, exportParams
   - 出参：downloadUrl

2. 数据模型：
   - MySQL：新增导出记录表 export_record
   - Redis：缓存导出进度 export:progress:{userId}

3. 核心流程：
   - 校验权限 → 查询数据 → 生成文件 → 上传OSS → 返回链接

是否按此设计生成文档？
```

---

## 接口提取逻辑

### 自动架构图生成

**从代码调用链自动生成 Mermaid 图，替代手动写占位符。**

**时序图**：从 Controller → Service → Mapper/Feign 调用链自动生成：
```mermaid
sequenceDiagram
    Client->>ExportController: POST /api/export
    ExportController->>ExportService: exportData(userId, params)
    ExportService->>UserService: getUserData(userId)
    UserService-->>ExportService: userInfo
    ExportService->>OrderService: getOrderList(userId)
    OrderService-->>ExportService: orderList
    ExportService->>FileGenerator: generate(userInfo, orderList)
    FileGenerator-->>ExportService: fileUrl
    ExportService-->>ExportController: downloadUrl
```

**生成方式**：
1. 从 Controller 类入口开始，追踪方法调用链
2. 识别跨服务调用（Feign/Dubbo/HTTP Client）→ 标为外部服务
3. 识别数据库操作（Mapper/Repository）→ 标为数据层
4. 识别 MQ 操作（RocketMQ/Kafka）→ 标为异步消息
5. 输出 Mermaid 语法，嵌入技术方案文档

**流程图**：从代码分支逻辑生成：
```mermaid
flowchart TD
    A[收到导出请求] --> B{用户权限校验}
    B -->|通过| C[查询用户数据]
    B -->|未通过| D[返回403]
    C --> E[查询订单数据]
    E --> F{数据量 > 10000?}
    F -->|是| G[异步导出]
    F -->|否| H[同步导出]
    G --> I[返回任务ID]
    H --> J[返回下载链接]
```

### REST 接口提取

**Spring MVC 注解**：
```java
@GetMapping("/api/users")
public Result<List<User>> getUsers(@RequestParam String userId) { ... }
```
提取：
- 接口 URL：GET /api/users
- 入参：userId (String)
- 出参：Result<List<User>>

**FastAPI 路由**：
```python
@router.get("/api/users")
async def get_users(user_id: str) -> List[User]:
    ...
```
提取：
- 接口 URL：GET /api/users
- 入参：user_id (str)
- 出参：List[User]

### RPC 接口提取

**Dubbo 服务**：
```java
@DubboService
public class UserServiceImpl implements UserService {
    public UserInfo getUser(String userId) { ... }
}
```
提取：
- 接口定义：UserService.getUser
- 入参：userId (String)
- 出参：UserInfo

### MQ 消费者提取

**RocketMQ 消费者**：
```java
@RocketMQMessageListener(topic = "user-event", consumerGroup = "user-consumer")
public class UserEventListener implements RocketMQListener<UserEvent> {
    public void onMessage(UserEvent event) { ... }
}
```
提取：
- Topic：user-event
- Consumer Group：user-consumer
- 消息结构：UserEvent

### 定时任务提取

**Spring Scheduled**：
```java
@Scheduled(cron = "0 0 2 * * ?")
public void cleanExpiredData() { ... }
```
提取：
- 任务名称：cleanExpiredData
- Cron：0 0 2 * * ?（每天凌晨2点执行）

---

## 数据模型提取逻辑

### MySQL 表提取

**JPA Entity**：
```java
@Entity
@Table(name = "user_info")
public class UserInfo {
    @Id
    private Long id;
    private String name;
}
```
提取：
- 表名：user_info
- 字段：id (Long), name (String)

**MyBatis Mapper**：
```xml
<select id="getUser" resultType="User">
    SELECT id, name FROM user_info WHERE id = #{id}
</select>
```
提取：
- 表名：user_info
- 字段：id, name

### Redis Key 提取

**RedisTemplate 操作**：
```java
redisTemplate.opsForValue().set("user:info:" + userId, userInfo);
```
提取：
- Key 模式：user:info:{userId}
- Value 类型：UserInfo

**@Cacheable 注解**：
```java
@Cacheable(value = "user", key = "#userId")
public User getUser(String userId) { ... }
```
提取：
- Key 模式：user::{userId}
- Value 类型：User

---

## 技术方案文档格式

> **按需加载**：生成技术方案文档时 Read 同目录 `tech-design-template.md`，不随本文件全量加载。

文档结构：需求说明 → 详细设计（功能设计 + 交互接口 REST/RPC/MQ/JOB + 数据模型 MySQL/Redis）→ 改动影响范围评估 → 稳定性设计（灰度降级 + 监控告警 + 防资损）→ 其他 checkList。

---

## 输出位置

### 模式一：已有需求文档

输出到：`docs/requirements/{key}/tech-design.md`

### 模式二：对话式需求分析

输出到：`docs/tech-design/{timestamp}.md`

---

## 使用示例

### 示例 1：模式一 - 已有需求文档

```bash
/cwork-doc

请选择模式：
1. 已有需求文档 - 基于已有的 analysis.md、plan.md、changes.md 生成技术方案
2. 对话式需求分析 - 从代码出发，对话式分析需求并生成技术方案

请输入 1 或 2：1

检测到需求文档：docs/requirements/user-export/
正在生成技术方案...
完成：docs/requirements/user-export/tech-design.md
```

### 示例 2：模式二 - 对话式需求分析

```bash
/cwork-doc

请选择模式：
1. 已有需求文档 - 基于已有的 analysis.md、plan.md、changes.md 生成技术方案
2. 对话式需求分析 - 从代码出发，对话式分析需求并生成技术方案

请输入 1 或 2：2

需求背景是什么？
> 用户需要导出自己的历史数据

需要实现什么功能？
> 支持用户导出订单数据，生成Excel文件

有什么约束或限制？
> 大数据量导出需要异步处理

预期收益是什么？
> 提升用户体验，减少运营手动导出工作量

方案设计：
方案 1（推荐）：在现有用户服务上新增导出接口
是否按方案 1 设计？(y/n)
> y

详细设计：
1. REST 接口：POST /api/user/export
2. 数据模型：新增 export_record 表
是否按此设计生成文档？(y/n)
> y

完成：docs/tech-design/20260626-153000.md
```

---

## 反模式

- 手动填写所有内容（应该自动提取）
- 只生成模板不填充内容（应该提取代码信息）
- 忽略接口契约校验（应该检查前后端一致性）
- 忽略数据模型变更（应该检查 DDL/DML）
- **改动代码**（禁止，只生成文档）

---

## 完成定义

- 技术方案文档已生成
- 接口定义已提取并填充
- 数据模型已提取并填充
- 改动影响范围已评估
- 稳定性设计已补充
- **代码未改动**

---

## 自动衔接

完成后不自动调起其他技能，等待用户确认。

---

## 使用记录与闭环

使用本 skill 遇到的不顺手 / 报错 / 结果不准 / 可省步骤，记一笔到 `../USAGE_NOTES.md`「未分析」区（格式 `[YYYY-MM-DD] [doc] 现象 | 建议改法`），能当场修的直接修。**每天最多分析一次**，据此优化各 skill——流程见 `../USAGE_NOTES.md` 顶部。
