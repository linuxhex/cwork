---
name: cwork-log
description: 找日志分析问题。查 SLS 日志 + ARMS 链路，定位问题根因。适用于：问题排查、性能分析、流量分析、链路追踪。
---

# 日志与链路分析

## 概述

`log` 是日志与链路分析的技能，通过阿里云 **SLS 日志** + **ARMS 链路** 排查线上问题。

**主动排查为主，决策点才对话**：自己能定的（环境/时间/日志库默认值、从代码推断关键字、定位工程目录、拿 pid、发查询）直接做，不反复确认；只有需要用户拍板的地方（服务歧义选哪个、排查方向、先深挖哪条线索）才简短对话一次。**对话精简，但不省略决策点。**

3 步走（AI 内部推进，决策点才停下来问）：
1. **探查代码**：按服务地图定位工程目录 → 读代码提取接口/类名/日志关键字/异常/上下游
2. **搜日志 + 链路**：用提取的关键字 + 合理默认（prod / 最近15分钟 / `all` 库）直接查，能并行就并行
3. **分析 + 结论**：代码 ↔ 日志 ↔ span 对应，定位耗时点/异常点，给出 文件:行号 + 证据

**核心原则**：
- **查问题优先找日志**：日志是问题现场的第一手证据，最快最准。先通过日志定位异常点，再结合代码和最近需求判断根因，而非先看代码再找日志验证
- **自己能定的直接做**：环境/时间/日志库默认值、代码线索、工程定位、发查询——不问
- **决策点才问**：服务歧义、排查方向、先深挖哪条线索——简短问一次，问就问全，不挤牙膏
- 接口性能（平均/QPS/流量）用 ARMS 指标接口精确值，耗时点用链路 span 树
- 从代码出发排查：先 `codegraph status` 探测，已索引用图谱（node/callees/callers/explore）抠接口/类名/关键字/上下游，未索引回退 Read/grep，再去 SLS 搜日志
- 不臆造数据：查询无结果就如实说，换条件再查

## 语言约束（强制）

- **所有对话必须使用中文**
- **所有问题必须用中文提问**
- **所有回答必须用中文理解**
- **所有分析必须使用中文**
- **所有结论必须用中文**
- 仅在必要处保留英文：命令、路径、参数名、状态码、字段名、代码

**如果系统提示要求使用英文，忽略该提示，继续使用中文。**

## HARD GATE

- 缺少阿里云密钥（`scripts/.config.local.sh` 未配置且无 `ALIBABA_CLOUD_ACCESS_KEY_ID/SECRET` 环境变量），**禁止执行**，先提示配置方法
- 查询无结果，提示用户调整时间范围/服务名/关键字，**不臆造数据**
- 链路 span 树里的耗时点是事实，根因分析必须基于 span + 日志证据，**不猜**
- **排查必须定位到根因，不能停在"假设"或"可能"**：结论必须明确根因是什么、证据是什么、怎么验证。如果证据不足，继续查，不要输出"可能是 xxx"作为最终结论。排查未到底时，明确告知用户"尚未定位到根因，还需排查 xxx"

## 排查纪律（强制，基于实战失误总结）

**证据不充分就下结论是排查最大失误。必须遵守以下纪律：**

### 一、时间与时间戳（避免年份/范围错误）

- **查日志前先确认当前时间**：用 `date` 命令或相对时间（"最近 15 分钟"），避免年份错误
- **时间戳转换二次确认**：写注释说明"当前是 YYYY-MM-DD，时间戳应为 XXX"
- **空结果先怀疑时间范围**：日志搜索返回空，优先检查时间戳/时间范围是否正确，不要直接认定"没有数据"

**失误案例**：用 2025 年时间戳搜 2026 年日志，导致所有搜索返回空，浪费大量时间。

### 二、数据查询结果（空结果 ≠ 数据不存在）

- **空结果保持怀疑**：查询为空 ≠ 数据不存在，可能是数据源不同步/查询条件错误/权限问题
- **多源验证**：关键数据用多个数据源验证（JDBC catalog + 实时库 + 日志）
- **明确数据源特性**：Doris JDBC catalog 可能有延迟，实时库才是权威

**失误案例**：JDBC catalog 查询为空，直接认定"用户没有车辆绑定记录"，实际是数据未同步。

### 三、读写链路（既查读也查写）

- **既查读也查写**：定位问题时，读链路 + 写链路都要追
- **写入证据优先**：数据异常时，先找写入操作（OMP 日志、save 方法、MQ 消费）
- **完整链路**：读 → 处理 → 写，三段都要看

**失误案例**：只查"车牌从哪读的"，没查"车牌什么时候、被谁写进去的"，漏掉关键证据。

### 四、链路验证（代码 + 日志交叉验证）

- **代码 + 日志交叉验证**：代码推断的链路，必须用日志/链路追踪验证
- **多入口排查**：一个数据可能被多个入口修改，都要排查
- **Feign 调用日志**：跨服务调用必须看 Feign 日志确认真实调用链

**失误案例**：只看代码认定车牌来源，没验证结算时 orderserver 还会全局查询覆盖。

### 五、结论输出（证据充分后再下结论）

- **证据充分后再下结论**：至少 2 个独立证据（代码 + 日志 + 数据）交叉验证
- **阶段性结论明确标注**："阶段性发现：xxx，待验证 yyy"，不要说"最终结论"
- **最终结论前自问**：还有哪些证据没查？写入链路看了吗？多入口排查了吗？时间范围对吗？

**失误案例**：证据不完整时多次给"最终结论"，每次被新发现推翻。

### 六、根因定位（排查必须到底）

- **排查必须定位到根因才能结束**：不能停在"可能是 xxx"、"怀疑是 xxx"——必须追到具体代码行/具体配置项/具体数据异常，有确凿证据
- **根因三要素**：根因是什么（一句话）+ 证据是什么（日志/span/数据）+ 怎么验证（复现路径或验证命令）
- **证据不足就继续查**：如果现有证据不足以确定根因，明确告知用户"尚未定位到根因，还需排查 xxx"，不要硬下结论
- **禁止输出"根因假设"**：结论区只写"根因"，不写"根因假设"或"可能原因"。如果真没查到根因，说"排查中，待查 xxx"，不要编一个假设充数

**失误案例**：排查到一半输出"根因假设是 xxx"，用户按假设去处理，问题没解决又回来重查。

## 代码工作区 + 服务地图（主动读代码的前提）

> 本机工作区默认值；**服务地图为本地隐藏配置，不入库**。

- **代码根目录**：`/Users/caomunian/Work/code-projects`（所有后端/前端工程都在这）
- **最近需求工程**：`/Users/caomunian/Work/code-projects/brook-content`（用户没指明工程时，默认从这里探查）
- **服务地图（按需加载 + 自更新）**：`/Users/caomunian/Study/cwork/.services-map.md` —— cwork **唯一权威**服务地图（路径 + 领域边界 + 下游依赖），**定位工程的第一手依据**。
  - **何时 Read**：用户说了服务名/领域要定位目录、查上下游依赖时。不需要则不读（各技能可单独使用）。
  - **文件不存在则回退**：当前目录 / 询问用户。
  - **自更新**：读代码确认了真实下游依赖且地图里是 `[待验证]`/`[需确认]`/缺失，按 `.services-map.md` 头部「自更新机制」回写（A 级读代码可写，标来源，不确定不写）。

**定位工程的动作**（别问用户目录在哪，自己查）：
1. 用户说了服务名/领域（如"订单"、"charge"、"车队"）→ 按需 Read `.services-map.md` 找对应目录
2. 目录可能按域分组嵌套（如 `trade/order-server/`），顶层没有就用 `find`/`grep` 在 code-projects 下定位
3. 找到目录后直接读代码，提取接口/类名/日志关键字

**合理默认**（没特殊说明就用，别问）：环境=prod、时间范围=最近 15 分钟、日志库=`all`。

## logstore 索引（固化，关键）

**不要每次 `sls_query.sh list` 再挑日志库。** prod 有 212 个库、uat 143 个，但命名规律明确。完整分类索引（按域/厂商/接口分类 + 高频服务→库速查 + pid 速查）见同目录 **`LOGSTORE_INDEX.md`**，定位库时先查它。核心规则：

- **`all` = 聚合库，默认入口**：绝大多数业务服务的**结构化**运行日志都在这（含 `trace`/`logger`/`level`/`message`）。先查 `all`，用工程的 **spring.name 作关键字**精确锁定（如 `DeviceBusinessServer`、`orderserver`，含连字符的 `payment-server` 也行，**不带引号**）。实测 `__tag__:_container_name_:` / `__path__:` 等 tag 语法 SLS 会报错、不能用；容器名当关键字也搜不到——只有 spring.name（在每条日志 `__path__` 里）全文搜可靠。device 协议日志常不在 all（查 `device-*` 专属库）。**CTP 车队日志也不在 all**（查 `ctp-*` 专属库，CTP 未接入 ARMS 链路追踪）。日志里的 `trace` 字段 = traceId，可直接喂 `arms_trace.sh`。
- **专属库按域分**：对外接口出入站 `<服务>3-out`；充电桩 `device-<厂商>`（`device-shenghong`盛弘/`device-shenrui`施恩/`device-huawei`华为/`device-luneng`鲁能/`device-wm`/`device-ykc1`）；运维桩 `device-ykcoms`；车队 `ctp-*`（⚠️ 不在 all，未接入 ARMS）；能源 `emp-*`/`ems-*`；运维 `xuzhu-omp-*`/`omp-*`/`feomp-*`；开放 `osp-*`；ZDL `zdl-*`；系统 `k8s-event`/`gc_log`/`sentinel-*`。
- **命名换算**：ARMS 应用名去掉 `-prod/-uat` ≈ logstore 前缀。`all` 查不到再试 `<前缀>-server` / `<前缀>3-out`；uat 业务专属库很少，查 uat 业务日志基本只查 `all`。
- **不确定库是否存在** → `count` 试探（比 `list` 省事），不要一上来就 `list` 全部。

## 脚本调用说明（关键）

本 skill 的脚本位于 `scripts/` 子目录（与本 SKILL.md 同级）。调用时用 skill 根目录的相对路径，或解析出绝对路径。**所有脚本已内置阿里云签名，直接 `bash` 调用即可，无需额外鉴权。**

| 脚本 | 用途 | 用法 |
|---|---|---|
| `sls_query.sh` | 查 SLS 日志 | `<env> list` / `<env> logs <logstore> [query] [line] [from_s] [to_s]` / `<env> count <logstore> [query] [from_s] [to_s]` |
| `arms_apps.sh` | 列 ARMS 应用拿 pid | `[region] [名称关键字]` |
| `arms_traces.sh` | 接口性能（次数/平均/QPS/错误率/整体P99） | `<pid> [分钟] [接口关键字]` |
| `arms_trace.sh` | 单条链路 span 树（上下游/耗时点） | `<pid> <traceId> [ts_ms]` |

参数说明：`env`=test/uat/prod；时间戳为秒级（SLS）或毫秒级（ts_ms）；`pid` 从 `arms_apps.sh` 输出获取；`logstore` 默认 `all`（见上表）。

---

## 阶段 0：前置排查（自动降级，不问用户）

**核心思路**：大部分生产问题由最近改动引起，先查最近上线需求，命中则优先排查相关代码，未命中或无法定位则降级到正常流程。

**自动执行，不问用户**：

```
┌─────────────────────────────────────────────────────────────┐
│  阶段 0：最近需求关联分析（自动）                              │
└─────────────────────────────────────────────────────────────┘
        │
        ▼
  调 cwork-requirement 查最近 7 天已上线需求
        │
        ▼
  从需求标题/描述提取功能点/模块/接口关键字
        │
        ▼
  与当前问题现象对比（关键字匹配）
        │
        ├─ 命中（问题现象与需求功能点相关）
        │     │
        │     ▼
        │  用需求关键字定位代码（codegraph / grep）
        │     │
        │     ├─ 定位成功 → 优先排查相关代码
        │     │
        │     └─ 定位失败 → 降级到阶段 1 正常排查
        │
        └─ 未命中（需求与问题无关）
              │
              ▼
           降级到阶段 1 正常排查
```

**具体步骤**：

### 0.1 查最近上线需求

```bash
# 自动查最近 7 天已上线需求（计划上线时间）
cd skills/requirement/scripts
bash yunxiao_query.sh by-date <今天-7天>  # 查最近一周
bash yunxiao_query.sh by-date <今天-6天>
...
bash yunxiao_query.sh by-date <今天>
```

**提取信息**：
- 需求标题（如"订单模块支持部分退款"）
- 需求描述（业务背景、改动点）
- 涉及模块/服务（从标题/描述推断）

### 0.2 关键字匹配

从需求提取的关键字与问题现象对比：

```
问题现象："退款接口报错"
最近需求："订单模块支持部分退款"
关键字匹配：退款 ✓ → 命中

问题现象："用户登录失败"
最近需求："订单模块支持部分退款"
关键字匹配：登录 ✗ 订单 ✗ 退款 ✗ → 未命中
```

**匹配规则**（自动）：
- 问题现象中的业务词（订单/支付/退款/用户/车辆等）与需求标题/描述匹配
- 问题现象中的接口路径与需求涉及接口匹配
- 问题现象中的服务名与需求涉及模块匹配

### 0.3 优先排查（命中时）

命中需求后，用需求信息加速定位：

```
═══════════════════════════════════════════════════════════════
【前置排查】命中最近需求
═══════════════════════════════════════════════════════════════

问题现象：退款接口报错
命中需求：OMJF-12345 订单模块支持部分退款
上线时间：2026-08-07（昨天）

需求涉及模块：
  - order-service（退款逻辑）
  - pay-service（支付退款）
  - refund.vue（前端页面）

优先排查方向：
  1. 查 order-service 退款相关接口日志
  2. 查 pay-service 支付退款调用
  3. 核对退款相关配置/开关

跳过阶段 1 工程定位，直接用需求模块查日志
═══════════════════════════════════════════════════════════════
```

### 0.4 降级条件（自动，不问）

**降级到阶段 1 正常排查**：
- 最近 7 天无上线需求
- 需求关键字与问题现象完全不匹配
- 命中需求但无法定位相关代码（codegraph/grep 找不到）
- 需求描述太模糊，无法提取有效关键字

**降级输出**（简短）：
```
【前置排查】最近需求与问题无关，进入正常排查流程
```

**不降级**（继续用需求信息）：
- 需求关键字与问题部分匹配（至少一个关键字命中）
- 能从需求定位到具体代码文件

### 0.5 与 cwork-requirement 联动

**调用方式**：
```bash
# 在 cwork-log 脚本目录调起 cwork-requirement
cd /Users/caomunian/Study/cwork/skills/requirement/scripts

# 查最近 7 天需求（按计划上线时间）
for i in {0..6}; do
  date=$(date -v-${i}d +%Y-%m-%d)  # macOS 语法
  bash yunxiao_query.sh by-date "$date"
done
```

**结果处理**：
- cwork-requirement 返回需求列表 → 提取标题/描述/模块
- cwork-requirement 返回空 → 降级到阶段 1
- cwork-requirement 凭证未配置 → 跳过阶段 0，直接进阶段 1

**关键约束**：
- 阶段 0 是**加速手段**，不是必需步骤
- 凭证未配置/查询失败/匹配失败都不阻塞，直接降级
- 不增加用户交互，全自动判断

---

## 阶段 1：探查代码 + 锁定目标

**自己能定的先做掉，别预审；只在决策点停一下。**

1. **定位工程**（直接做）：按"代码工作区 + 服务地图"自己查目录；用户没指明 → 默认 `brook-content`；问题明显属于别的服务再切。
2. **读代码提取线索（先 codegraph 探测，已索引必须用）**：提取接口路径、Controller/Service 类名、日志打印关键字、异常类型、Feign 调用的上下游——这些线索直接喂阶段 2 的日志/链路查询。

   **⚠️ 关键：不是只探测一次，而是每次找代码都要探测**

   - **错误理解**：开始时探测一次，后面就可以随便用 grep+Read
   - **正确理解**：排查过程中，**每次**查调用链、查接口实现、查上下游，都要先探测 codegraph，已索引就必须用
   - **持续监督**：排查的每一步输出都必须有 `[codegraph]` 标签，没有就是偷懒

   **前置探测（每次找代码都必须执行）**：
   ```bash
   cd /Users/caomunian/Work/code-projects && codegraph status            # 有符号数（已索引）→ 必须用下方图谱命令；无索引 → 回退 grep/Read，继续提取
   ```

   🔍 **输出标签（强制）**：每次调 codegraph 必须在对话里打一行 `[codegraph]` 标签让走向可见——探测后 `🔍 [codegraph] status → 已索引(N符号)，用图谱` 或 `→ 未索引，回退 grep+Read`；查询时 `🔍 [codegraph] <命令> <目标> → <目的>`。**无 `[codegraph]` 标签 = 没走 codegraph，视为偷懒。**

   **已索引 → 用图谱提取线索**（比散乱 grep+Read 更准、更省 context，能抓 Spring 接口→实现、Feign 调用链等 grep 漏点）：
   ```bash
   codegraph node <类|接口>                    # 带行号源码：抠接口路径（@RequestMapping）、类名、log.info/error 关键字字面量
   codegraph callees <Controller 方法>         # 这个方法调了哪些下游（Feign 上下游、Mapper）—— 排查链路耗时/异常必看下游
   codegraph callers <方法>                    # 谁调了它（上游入口、跨服务调用方）—— 定位流量从哪进来
   codegraph explore "<入口> 怎么到 <嫌疑点>"   # 一次还原完整调用链 + 源码，顺带看沿路日志埋点
   ```

   **未索引 / 未安装** → 回退 `grep` + `Read` 直接读源码提取，不阻塞、不报错。
3. **默认值补全**（直接做）：环境=prod、时间=最近 15 分钟、日志库=`all`（需求里给了别的才覆盖）。

**决策点（这里才对话，简短一次问全）**：
- 多个候选服务/工程 → 问用户选哪个
- 排查方向不明（看流量？看报错？看某条具体链路？）→ 问一句定方向
- 用户给了具体业务单号/traceId/时段但没给全 → 问一句补齐
- 没有上述歧义 → 直接进阶段 2，**不问**

---

## 阶段 2：查询与分析

### 2.0 查前强制验证（新增，关键）

**每次查询前必须执行以下验证，避免因时间戳/库选择/pid失效导致空结果误判：**

```bash
# ① 时间戳校验（强制）
date
# 输出当前时间，确认时间戳计算基准正确
# 示例：当前 2026-08-07 15:30:00，查最近15分钟 → from=2026-08-07 15:15:00

# ② 库选择验证（查索引表）
# 在 LOGSTORE_INDEX.md 中确认目标库是否有数据
# 示例：查 order-server → 索引标注"90天0条" → 改查 all

# ③ pid 轻量验证（可选，怀疑失效时执行）
bash scripts/arms_traces.sh "<pid>" 5 "<任意接口>"
# 返回空或鉴权错 → pid失效 → 重跑 arms_apps.sh
```

**验证失败处理**：
- 时间戳错误 → 重新计算
- 库选择错误 → 按索引表重新选择
- pid失效 → 重跑 arms_apps.sh 获取新 pid，更新 ARMS_PID_CACHE.md

### 2.1 拿 pid + 定位日志库（先查索引，不要遍历）

**域感知路由（新增，关键）**：

根据问题涉及的服务/域，自动路由到正确的日志库，减少人工判断：

```bash
# 域路由规则（按服务名/关键词自动匹配，覆盖全部 16 个域）
# ⚠️ 关键：查 all 库时必须设置 KEYWORD（spring.name），否则返回海量无关日志
case "$服务或关键词" in
  # === CTP 车队域（独立采集，不在 all，未接入 ARMS）===
  *"车队"*|*"ctp"*|*"CTP"*)
    echo "【域感知】检测到车队域"
    echo "  → 日志库：ctp-* 专属库（不在 all）"
    echo "  → ARMS：未接入，无法查链路"
    echo "  → 有数据：ctp-activity-server（7亿/90天）"
    LOGSTORE="ctp-activity-server"
    KEYWORD=""  # 专属库，关键字可选
    ARMS_ENABLED=false
    ;;

  # === Device 设备域（32 库，按厂商分）===
  *"盛弘"*|*"shenghong"*)
    echo "【域感知】检测到盛弘桩"
    echo "  → 日志库：device-shenghong（2.7亿/90天）"
    LOGSTORE="device-shenghong"
    KEYWORD=""  # 专属库，关键字可选
    ;;
  *"华为"*|*"huawei"*)
    echo "【域感知】检测到华为桩"
    echo "  → 日志库：device-huawei"
    LOGSTORE="device-huawei"
    KEYWORD=""
    ;;
  *"施恩"*|*"shenrui"*)
    echo "【域感知】检测到施恩桩"
    echo "  → 日志库：device-shenrui"
    LOGSTORE="device-shenrui"
    KEYWORD=""
    ;;
  *"鲁能"*|*"luneng"*)
    echo "【域感知】检测到鲁能桩"
    echo "  → 日志库：device-luneng"
    LOGSTORE="device-luneng"
    KEYWORD=""
    ;;
  *"运维桩"*|*"device-ykcoms"*|*"coms"*)
    echo "【域感知】检测到运维桩"
    echo "  → 日志库：device-ykcoms（2万/90天，不在 all）"
    LOGSTORE="device-ykcoms"
    KEYWORD=""
    ;;
  *"设备"*|*"桩"*|*"device"*)
    echo "【域感知】检测到设备域，请选择厂商库："
    echo "  1. device-shenghong（盛弘，2.7亿）✅"
    echo "  2. device-ykcoms（运维桩，2万）✅"
    echo "  3. device-business ✅"
    echo "  4. device-huawei（华为）"
    echo "  5. device-shenrui（施恩）"
    echo "  6. device-luneng（鲁能）"
    echo "  注：✅ 表示有数据"
    LOGSTORE="device-shenghong"
    KEYWORD=""
    ;;

  # === EMP/EMS 能源域（11 库，大部分空或无索引）===
  *"能源"*|*"emp"*|*"EMP"*|*"ems"*|*"EMS"*)
    echo "【域感知】检测到能源域"
    echo "  → emp-gateway3-out：无索引（库存在但未建索引）"
    echo "  → 其余 10 个库：90天全空"
    echo "  → 建议：查 all 库 + spring.name 关键字"
    LOGSTORE="all"
    KEYWORD="empServer"  # ⚠️ all 库必须设置关键字
    ;;

  # === ZDL 域（11 库）===
  *"ZDL"*|*"zdl"*)
    echo "【域感知】检测到 ZDL 域"
    echo "  → zdl-server：有数据（9亿/90天）✅"
    echo "  → 其余 10 个库：90天全空"
    LOGSTORE="zdl-server"
    KEYWORD=""
    ;;

  # === DMP 域（4 库）===
  *"DMP"*|*"dmp"*)
    echo "【域感知】检测到 DMP 域"
    echo "  → dmp-tag：有数据（5万/90天）✅"
    echo "  → dmp-admin/dmp-query-server/dmp-web：全空"
    LOGSTORE="dmp-tag"
    KEYWORD=""
    ;;

  # === OSP 开放服务域（4 库）===
  *"OSP"*|*"osp"*)
    echo "【域感知】检测到 OSP 域"
    echo "  → osp-server：有数据（22亿/90天）✅"
    echo "  → osp-backend/osp-customer/osp-front：全空"
    LOGSTORE="osp-server"
    KEYWORD=""
    ;;

  # === IOP 域（4 库）===
  *"IOP"*|*"iop"*)
    echo "【域感知】检测到 IOP 域"
    echo "  → iop-gateway：有数据（2万/90天）✅"
    echo "  → iop-base/iop-poly/iop-station-auth：全空"
    LOGSTORE="iop-gateway"
    KEYWORD=""
    ;;

  # === 银行/支付通道域（3 库）===
  *"银行"*|*"bank"*)
    echo "【域感知】检测到银行域"
    echo "  → bank-ability-center：有数据（3.6亿/90天）✅"
    echo "  → bank-front/bankpay3-out：全空"
    LOGSTORE="bank-ability-center"
    KEYWORD=""
    ;;

  # === OMP 运维域（14 库，全部空）===
  *"运维"*|*"OMP"*|*"omp"*|*"xuzhu-omp"*)
    echo "【域感知】检测到运维 OMP 域"
    echo "  ⚠️ 全部 14 个库 90天 0 条"
    echo "  → 可能未接入 SLS 或在其他采集系统"
    echo "  → 建议：查 all 库试试"
    LOGSTORE="all"
    KEYWORD="ompServer"  # ⚠️ all 库必须设置关键字
    ;;

  # === 出站日志（*-out 库）===
  *"出站"*|*"out"*)
    echo "【域感知】检测到出站日志查询，请选择："
    echo "  1. task3-out（7.85亿）✅"
    echo "  2. flowside3-out（1788万）✅"
    echo "  3. gateway-op3-out（309万）✅"
    echo "  4. ots-base-out（48万）✅"
    echo "  5. 其他 *-out 库（大部分空）"
    LOGSTORE="task3-out"
    KEYWORD=""  # 出站库已按服务分，关键字可选
    ;;

  # === MQ 消费 ===
  *"MQ"*|*"mq"*|*"消费"*)
    echo "【域感知】检测到 MQ 消费日志"
    echo "  ⚠️ mq-consumer-order/mq-consumer-order2：90天全空"
    echo "  → 建议：查 all 库 + spring.name 关键字"
    LOGSTORE="all"
    KEYWORD="mq-consumer"  # ⚠️ all 库必须设置关键字
    ;;

  # === 订单域 ===
  *"订单"*|*"order"*)
    echo "【域感知】检测到订单域"
    echo "  → 日志库：all（order-server/order3-out 等90天0条）"
    echo "  → 关键字：orderserver"
    LOGSTORE="all"
    KEYWORD="orderserver"  # ⚠️ all 库必须设置关键字
    ;;

  # === 支付域 ===
  *"支付"*|*"payment"*)
    echo "【域感知】检测到支付域"
    echo "  → 日志库：all 或 payment-server（双写，12.1亿）"
    LOGSTORE="all"
    KEYWORD="payment-server"  # ⚠️ all 库必须设置关键字
    ;;

  # === 默认 ===
  *)
    echo "【域感知】未匹配到特定域，使用默认策略"
    echo "  → 日志库：all（聚合库）"
    echo "  ⚠️ 未设置关键字，查询前请提供 spring.name 或业务关键字"
    echo "  → 提示：如查不到，请确认是否属于以下域："
    echo "     CTP车队、Device设备、EMP能源、ZDL、DMP、OSP、IOP、OMP运维"
    LOGSTORE="all"
    KEYWORD=""  # ⚠️ 默认无关键字，需用户补充
    ;;
esac

# 查询前检查：all 库必须有关键字
if [ "$LOGSTORE" = "all" ] && [ -z "$KEYWORD" ]; then
  echo "⚠️ 警告：查 all 库但未设置关键字，将返回海量无关日志"
  echo "   → 请提供 spring.name 或业务关键字"
  echo "   → 示例：orderserver / DeviceBusinessServer / payment-server"
fi
```

**路由输出示例**：
```
═══════════════════════════════════════════════════════════════
【域感知路由】
═══════════════════════════════════════════════════════════════
检测到：车队域
→ 日志库：ctp-activity-server（车队日志不在 all）
→ ARMS：未接入链路追踪，无法查链路
→ 建议：仅查 SLS 日志，用业务单号手动关联上下游
═══════════════════════════════════════════════════════════════
```

**先用索引表，别直接跑 `arms_apps.sh` 遍历**（索引已建好，查表即用）：

1. **pid + 专属库**：查同目录 `ARMS_PID_CACHE.md`（全量应用 → pid → 专属库 → 主库 `all`），按服务名搜，命中直接用 pid 和专属库。
2. **库选型 + 精确查询语法 + 工程↔应用↔库四层模型**：查 `LOGSTORE_INDEX.md`（第3节查询语法、第4节库分类、第5节四层对照）。

> ⚠️ 查 `all` 锁定工程用 **spring.name 关键字**（如 `DeviceBusinessServer`），**不要用** `__tag__:_container_name_:` 等 tag 语法（SLS 会报错）。详见 LOGSTORE_INDEX.md 第3节。

**索引查不到**（新应用 / pid 因重建失效）才回退跑：
```bash
bash scripts/arms_apps.sh cn-hangzhou "<服务关键字>"
```

**索引失效自动检测与重建**：
当使用索引中的 pid 查询时，如果 `arms_traces.sh` / `arms_trace.sh` 返回空结果或鉴权错误，**不要直接认为"没有数据"**，先怀疑 pid 失效：
1. 用 `arms_apps.sh` 按服务关键字重新查询，拿到新 pid
2. 对比新 pid 与索引中的 pid，不同则说明索引过期
3. 用新 pid 重新执行查询
4. 自动更新 `ARMS_PID_CACHE.md` 中该应用的 pid（无需整表 rebuild）
5. 记一笔到 `../USAGE_NOTES.md`：「索引 pid 失效，已自动更新」

**整表重建**（积累多条失效或定期维护时）：
```bash
bash scripts/rebuild_index.sh
```
- 唯一命中 → 直接用该 pid，不问
- 多个命中 → 默认第 1 个，列出其余让用户改（回车即过）：
  ```
  匹配到多个，默认用第1个 order-prod (pid=xxx)；要看别的回复序号：
  1. order-prod           pid=...
  2. order-foundation-prod pid=...
  ```

### 2.2 按目标查（并行/快速）

**默认走综合路子**：阶段 1 提取的关键字 → `sls_query.sh logs all` 搜日志 → 命中取 traceId → `arms_trace.sh` 拉链路 → 代码 ↔ 日志 ↔ span 对应。下面四类只是"重点查什么"的参考，按问题性质组合用，能并行就并行（同 pid/同时间窗的多脚本一起发起）。

**目标 ① 流量/性能**：
```bash
bash scripts/arms_traces.sh "<pid>" <分钟> "<接口关键字>"
```
看 `调用次数`/`QPS` 是否为 0（有没有流量）、平均耗时、错误率、整体 P99。

**目标 ② 链路**：先用 `arms_traces.sh` 或 `sls_query.sh logs` 拿到 traceId + 时间戳，再：

> **traceId 从一条日志里怎么抠**（拿到后直接喂 `arms_trace.sh`）：一条结构化日志里的链路 id 有两个来源——① 字段 `trace`：32 位 hex（如 `fa7257a48b04b586826e3eca84cac497`），标准 traceId；② `message` 开头第三段方括号里的纯数字（如 `[NONE][0][11381236262484628996096]` 中的 `11381236262484628996096`，Feign/接口日志里的 eagleeye/rpc 上下文 id）。**两者都不是每条都有**——有的日志无 `trace` 字段、有的 message 没第三段方括号，拿到哪个用哪个；都没有就退回用 spring.name 或业务单号（订单号/枪码）搜关联日志再找。

```bash
bash scripts/arms_trace.sh "<pid>" "<traceId>" <ts_ms>
```
输出 span 调用树、上下游、最慢 span（耗时点）。

**目标 ③ 日志**：
```bash
bash scripts/sls_query.sh <env> logs all "<query>" <line>     # 默认 all 库
bash scripts/sls_query.sh <env> count all "<query>"
```
`query` 支持 SLS 语法（如 `ERROR and "订单"`）。

**目标 ④ 综合（从代码出发，默认路子）**：
1. 读工程代码，提取**接口路径、类名、日志关键字、异常类型**
2. 用关键字 `sls_query.sh logs` 搜日志
3. 从命中日志取 traceId，`arms_trace.sh` 还原链路
4. 代码位置 ↔ 日志 ↔ span 对应起来

### 2.3 指出耗时点与异常点（带证据，不猜）

- **耗时点**：从 `arms_trace.sh` 的 span 树里找 `<<< 耗时点` 标记（最慢 span），说明耗时花在哪类操作（HTTP/SQL/Kafka/Redis）
- **异常点**：span 树里找 `<ERROR>` 标记，日志里找 ERROR/Exception 堆栈
- **代码对应**（综合排查时）：异常堆栈/接口对应到具体文件:行号

### 2.4 空结果怀疑链（新增，关键）

**查询返回空时，按以下顺序逐层怀疑，不要直接认定"没数据"：**

```
查询返回空
  │
  ├─ 第1层：时间戳对吗？
  │    └─ 检查：date 确认当前时间，重新计算时间戳
  │
  ├─ 第2层：库选对吗？
  │    └─ 检查：LOGSTORE_INDEX.md 确认该库是否有数据
  │    └─ 示例：order-server 标注"90天0条" → 改查 all
  │
  ├─ 第3层：pid/index 失效吗？
  │    └─ 检查：arms_traces.sh 用 pid 查任意接口
  │    └─ 返回空或鉴权错 → pid失效 → 重跑 arms_apps.sh
  │
  ├─ 第4层：数据在专属库吗？
  │    └─ 检查：CTP/运维桩/device协议日志常不在 all
  │    └─ 按域感知路由重新选择库
  │
  └─ 第5层：确实没数据
       └─ 如实说，建议用户调整时间范围/条件
```

**空结果输出示例**：
```
═══════════════════════════════════════════════════════════════
【空结果诊断】
═══════════════════════════════════════════════════════════════
查询返回空，逐层排查：

✓ 第1层：时间戳正确（2026-08-07 15:15:00 ~ 15:30:00）
✓ 第2层：库选择正确（all 库有数据）
✓ 第3层：pid 有效（验证查询有返回）
✗ 第4层：数据可能在专属库
  → 检测到关键词"车队"，建议查 ctp-activity-server
  → 车队日志不在 all 聚合库

建议：重新查询 ctp-activity-server 库
═══════════════════════════════════════════════════════════════
```

---

## 阶段 3：结论输出

输出汇总（带 banner）：

```
═══════════════════════════════════════════════════════════════
【日志与链路分析完成】
═══════════════════════════════════════════════════════════════

目标服务：order-prod (prod)
时间范围：最近 15 分钟

接口性能：
- /open/charging/updateOrderOfCharging：QPS 32418，平均 25ms，错误率 0%
- 整体调用链 P99 = XXXms

链路与耗时点：
- 上下游：... → order-prod → ...
- 耗时点：...

日志证据：
- ...

根因：
- 根因：（一句话说明根因是什么）
- 证据：（日志/span/数据证据，带具体行号或 traceId）
- 验证：（怎么验证根因正确，复现路径或验证命令）

（如尚未定位到根因：排查中，待查 xxx）

═══════════════════════════════════════════════════════════════
```

---

## 联动：查业务数据 / 查 Nacos 配置（cwork-data / cwork-config）

排查中常需用数据或配置佐证根因。**触发条件命中即调起**（主 agent 用 Skill 工具触发），写法对齐 cwork-bug 的「后端日志联动」。

**① 数据查询联动（cwork-data）** — 用数仓数据佐证
- 触发条件（任一）：需核对业务数据（订单状态/金额/库存/某用户数据）、查某时段数据量、数据一致性存疑、日志看到数据异常需数仓佐证。
- 流程：从链路/日志拿到线索（订单号/用户号/时段）→ 调 cwork-data 查对应数仓表（DWD 宽表优先）→ 数据 ↔ 日志/链路对应。
- 调用示例：
  ```bash
  cd skills/data/scripts/mcp-client
  python3 mcp_client.py query --sql "SELECT * FROM internal.dwd.dwd_order_settle_model WHERE dt='<日期>' AND order_no='<订单号>' LIMIT 10"
  ```
- 联动原则：cwork-log 管「链路/日志根因」，cwork-data 管「业务数据佐证」；拿到数据证据后回到链路分析下结论。

**② 配置查询联动（cwork-config）** — 核对 Nacos 配置真值
- 触发条件（任一）：需确认某服务某环境实际配置（开关/阈值/地址/参数）、怀疑配置变更引发问题、日志显示参数与预期不符要核对 Nacos 真值。
- 流程：定 env + 服务名 → 调 cwork-config 查配置（不知 dataId 先 `search`）→ 配置真值 ↔ 现象对应。
- 调用示例：
  ```bash
  cd skills/config/scripts
  bash nacos_query.sh test search <服务名>                  # 定位 dataId
  bash nacos_query.sh test get <dataId> DEFAULT_GROUP       # 取配置
  bash nacos_query.sh diff <dataId> DEFAULT_GROUP uat prod  # 多环境对比
  ```
- 联动原则：cwork-log 管「现象与链路」，cwork-config 管「核对 Nacos 配置真值」；确认配置后回到链路分析。

> **凭证注意**：cwork-data 需 `skills/data/scripts/mcp-client/.mcp_config.json` 已配置；cwork-config 需 `skills/config/scripts/.config.local.sh` 已配置对应集群。未配置时跳过对应联动，仅基于日志/链路分析。

---

## 索引维护与闭环

索引（`ARMS_PID_CACHE.md` / `LOGSTORE_INDEX.md`）是**快照**，会随应用重建、新增服务、改库而过期。

**记录不符**：排查时发现索引与实际对不上（pid 查出链路空 / 专属库查不到 / 应用或库不存在 / 新服务未收录），**记一笔到 `../USAGE_NOTES.md`「未分析」区**（格式：`[日期] [log] 现象 | 建议`）。能当场改的直接改。

**定期重建**（积累几条或收工时）：
```bash
bash scripts/rebuild_index.sh     # 重跑 arms_apps + sls list(prod/uat) 重建 ARMS_PID_CACHE.md
```
`LOGSTORE_INDEX.md` 的库分类/四层表变动少，按 `sls_query.sh list` 手动更新。

> **跨 skill 闭环**：所有 cwork skill 的使用记录 + 日终分析都走 `../USAGE_NOTES.md`（一天最多分析一次，见该文件说明）。
> **pid 过期信号**：`arms_traces.sh` / `arms_trace.sh` 返回空或鉴权错 → 先怀疑 pid 失效，重跑 rebuild。

---

## 密钥配置（首次使用）

密钥与配置存于 `scripts/.config.local.sh`（**本工程内，已 gitignore，不依赖任何外部工程**）。
- 首次使用：`cp scripts/config.example.sh scripts/.config.local.sh`，填入阿里云 AK/SK 和各环境 SLS project
- 环境变量（`ALIBABA_CLOUD_ACCESS_KEY_ID/SECRET` 等同名）可临时覆盖 .config.local.sh 的值
- 未配置时脚本会 fail 并提示配置方法

---

## 反模式

- **不分情况地反复确认**（自己能定的直接做；只在服务歧义/方向不明等决策点问）
- **该问时不问、自己瞎猜**（需要用户拍板的地方不对话，容易查错方向）
- **每次都 `sls_query.sh list` 让用户挑日志库**（用 logstore 映射，默认 `all`）
- 臆造日志内容或链路数据（查询无结果就如实说，让用户调整条件）
- 只看一个指标下结论（流量正常不代表链路正常，要交叉看）
- 把耗时点/异常点藏在原始输出里不点明（必须显式指出耗时点和异常）
- 已索引却散乱 grep+Read、不用 codegraph（阶段 1 探查代码先 `codegraph status`，已索引必须用 node/callees/callers/explore 抠线索）
- 代码排查时不读实际代码、只凭日志猜（要对应到具体文件:行号）
- 排查停在假设层面（"可能是 xxx"、"怀疑是 xxx"）就输出结论——必须追到根因，证据不足就说"待查"
- 输出"根因假设"或"可能原因"充数——结论区只写"根因"，没查到就说没查到

---

## 完成定义

- 能自己定的已直接做（读代码、发查询），决策点已与用户简短确认
- 目标应用 pid 已获取（唯一命中直接用，多命中已确认）
- 按目标调用脚本拿到数据（流量/链路/日志）
- 耗时点与异常点已显式指出（带 span/日志证据）
- **根因已定位**：根因 + 证据 + 验证方式三要素齐全；如未定位到，明确告知用户待查方向
- 结论已汇总输出（上下游、P99、耗时点、日志证据、根因）

---

## 自动衔接

完成后不自动调起其他技能，等待用户确认是否需要进一步排查或换条件重查。
