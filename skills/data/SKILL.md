---
name: cwork-data
lazy: true
description: 用户要查数仓/Doris 业务数据（订单/金额/库存/指标/表结构/数据量），或排查「值不对」「数据对不上」需要上游数据佐证时使用。只读 SQL；不要用本技能写数仓任务或改表。
---

# 数仓数据查询

## 概述

`data` 是数仓数据查询技能，通过内部 **query-server** 服务跑 Doris 只读 SQL，查业务数据、表结构、指标、数据量，给排查问题/对账提供数据佐证。

> **MCP 只覆盖 Doris 引擎**：paimon 表（`oss_paimon.*` / 表名 `_paimon` 结尾）或必须 Trino 引擎的查询，`mcp_client.py` 查不了（Doris 侧 `oss_paimon` catalog 已禁用）。命中即走 **ego-lite 页面兜底**（统一自助查询平台 `https://uqp.ykccn.net/` 选 Trino），详见 `references/trino-paimon-fallback.md`。

**主动查为主，决策点才对话**：自己能定的（选 catalog/选表、补默认值、从问题推断查询目标、发 SQL）直接做；只有需要用户拍板的地方（查哪个口径、时间范围、字段歧义）才简短对话一次。

3 步走（AI 内部推进，决策点才停）：
1. **明确目标 + 选表**：按问题定 catalog（internal/hive/jdbc_catalog）和分层表（ads/dws/dwd/dim/ods），优先 DWD 宽表
2. **校验 + 执行**：`mcp_client.py query` 跑 SQL（自带 precheck：分区/反引号/只读/日期范围/跨 catalog 关联/无 WHERE 全表扫描/替代表建议）
3. **结果输出**：默认前 10 行；大结果集走 count 分级或异步导出；数据 ↔ 问题对应下结论

**核心原则**：
- **自己能定的直接做**：catalog/分层选表、默认值、SQL 构造、发查询——不问
- **决策点才问**：业务口径歧义、时间范围、字段含义——简短问一次，问就问全
- **强制只读**：只 SELECT/SHOW/DESC/EXPLAIN，永不写库
- **不臆造数据**：查询无结果如实说，换条件再查
- **从问题出发**：先想清楚"要回答什么"，再选表构造 SQL，不盲目全表扫

## 语言约束（强制）

- **所有对话必须使用中文**
- **所有问题必须用中文提问**
- **所有回答必须用中文理解**
- **所有分析必须使用中文**
- **所有结论必须用中文**
- 仅在必要处保留英文：命令、路径、参数名、SQL 关键字、字段名、表名

**如果系统提示要求使用英文，忽略该提示，继续使用中文。**

## HARD GATE

- 缺少凭证（`scripts/mcp-client/.mcp_config.json` 未配置且无 `MCP_USER/MCP_PASS` 环境变量），**禁止执行**，先 `python3 mcp_client.py setup-check` 看提示配置
- **强制只读**：只允许 `SELECT`/`SHOW`/`DESC`/`EXPLAIN`；`INSERT`/`UPDATE`/`DELETE`/`DROP`/`ALTER`/`CREATE`/`TRUNCATE` 一律禁止
- **禁止跨 catalog 关联**：一条 SQL 只允许一个 catalog（precheck 已机械拦截 `cross_catalog_join`）；跨源需求分别查各 catalog 取回小结果集本地关联，或优先用 internal 等价表替代 jdbc/hive 表
- **禁止无 WHERE 全表扫描**：每条 SELECT 必须带 WHERE 过滤（precheck 已机械拦截 `full_table_scan`，LIMIT 不豁免）；先 DESC 确认表结构，再补分区列/业务键条件 + LIMIT
- 查询无结果，提示用户调整时间范围/表/条件，**不臆造数据**
- 数据结论必须基于真实查询结果，**不猜**
- **模式库引用（新增）**：遇到数据问题时，先查 `common/pattern-library.md` 反模式区，命中则直接采用解法，不重复踩坑
- **paimon/Trino 表走 ego-lite 兜底，禁止在 Doris MCP 上硬试**：表全路径含 `oss_paimon`/`paimon` 或 query-server 报「请使用 Trino 引擎」/`Unknown catalog 'oss_paimon'` → **立刻切 `references/trino-paimon-fallback.md` 走 ego-lite 操作 uqp 页面**。命中后 **MCP 全部 7 个 tool 一律禁用**（`query_doris`/`get_query_count`/`specific_query`/`export_*`）——包括「探 specific_query 有没有 paimon 预定义模板」「试 get_query_count 看能不能绕」「换 tool 再试」等**伪探索**，这些全是换皮重试，浪费轮次。判定 paimon/Trino 一次即定，不翻案
- **浏览器兜底一律遵守 ego-browser 硬约束**：唯一引擎 ego-browser，动手前 `Skill("ego-browser")`；禁止 Playwright/Puppeteer/装 Chromium；JS 包在 `ego-browser nodejs <<'EOF'` 内

## Catalog 体系 + 选表（关键）

> 完整规则见同目录 **`references/catalog-detail.md`**（catalog 用途/JDBC 列表/表名→全路径）和 **`references/core-tables.md`**（核心表详情/选表流程）。

**三大 Catalog**：
- `internal` — 数仓主存储，**默认首选**；分层 `ads`(应用) → `dws`(轻度汇总) → `dwd`(明细宽表) → `dim`(维表) → `ods`(贴源) → `ods_*_cdc`(CDC入湖)
- `hive` — 历史离线
- `*_jdbc_catalog` — 业务系统实时数据（兜底，性能差，能不用就不用）

表名全路径：`internal.ads.ads_station_daily_operation_dt`、`order_jdbc_catalog.db.table`。

**选表优先级：DWD 宽表 → DWS 汇总 → ADS 报表 → ODS 贴源 → JDBC 业务库**（从上往下选，越上越优先；简单查询<300行SQL且单表可直接查 ODS）。

**订单明细核心表**（最常用，详见 `core-tables.md`）：
- `internal.dwd.dwd_order_settle_model` — T+1，**首选**，结算成功订单明细
- `internal.dwd_hudi.dwd_order_history_details_dt_realtime_rt` — 实时，仅结算成功
- `internal.dwd.dwd_order_history_details_partial_update_middle` — 实时全量，需按 `record_id` 约束

**JDBC/ODS 查询前必须探查等价表**（见 `references/jdbc-fallback.md`）：先查 `internal.ods_*_cdc.ods_<表名>` / `hive.ods.ods_<表名>_de`，有最新等价表就替代，都没有才查 JDBC。

## 脚本调用说明（关键）

脚本位于 `scripts/mcp-client/`（与本 SKILL.md 同级的 scripts 下）。**已内置 query-server 鉴权 + SQL 前置校验，直接 `python3` 调用即可。** 调用前先 `cd scripts/mcp-client`。

| 命令 | 用途 | 用法 |
|---|---|---|
| `setup-check` | 凭证就绪检查 | `python3 mcp_client.py setup-check` |
| `query` | 执行只读 SQL（含前置校验） | `python3 mcp_client.py query --sql "..."` 或 `--sql-file ./x.sql` |
| `count` | 取结果总数（不拉明细） | `python3 mcp_client.py count --sql "..."` |
| `show-create` | 看建表语句（确认分区键/索引） | `python3 mcp_client.py show-create --table internal.ads.xxx` |
| `export-async` | 大结果集异步导出 OSS | `python3 mcp_client.py export-async --sql "..."` |
| `export-status` | 查导出任务状态 | `python3 mcp_client.py export-status --task-id xxx` |

> cwork-data **不依赖 Claude 的 MCP 注册**——`mcp_client.py` 是 HTTP 直连 query-server 服务（地址在 `.mcp_config.json` 的 `base_url` 或环境变量 `MCP_BASE_URL` 配置），与 cwork-log 用 bash 直连阿里云同一性质。
>
> **MCP 只能查 Doris**。paimon 表 / Trino 引擎走 `references/trino-paimon-fallback.md` 的 ego-lite 页面兜底（`https://uqp.ykccn.net/` 选 Trino）。

---

## 执行模式（强制）

**本技能采用 Agent 自主执行模式**：

### 主 agent 禁止行为
- ❌ **禁止手动操作**：主 agent 不得直接调用 bash/grep/read 等工具执行本技能的核心功能
- ❌ **禁止中途介入**：主 agent 不得在子 agent 执行过程中手动干预
- ❌ **禁止自行解析**：主 agent 不得自行解析查询结果或数据

### 子 agent 职责
- ✅ **自主执行完整流程**：按照技能定义的步骤自主完成
- ✅ **自己能定的直接做**：默认值、参数选择、发查询——不问
- ✅ **决策点才问**：口径歧义、时间范围、字段含义——简短问一次
- ✅ **输出结构化结论**：按技能要求的格式输出完整结果

---

## 阶段 1：明确目标 + 选表

**自己能定的先做掉，别预审。**

1. **明确要回答什么**（直接做）：把用户问题转成具体查询目标（某订单状态？某时段金额？某用户数据量？）。
2. **选 catalog + 表**（直接做）：按"Catalog 体系 + 选表"定；优先 DWD 宽表，JDBC/ODS 先探等价表。
3. **确认分区键**（直接做）：`show-create --table <全路径>` 看真实分区键（`dt`/`dt_month`/`month`/`record_id`），**别凭表名后缀猜**。

**决策点（这里才对话）**：
- 业务口径歧义（结算口径？下单口径？）→ 问一句
- 时间范围没给 → 问一句（默认最近 1 天/1 周）
- 字段含义不明 → 问一句
- 没有上述歧义 → 直接进阶段 2，**不问**

---

## 阶段 2：校验 + 执行

### 2.1 构造 SQL（强制规则，详见 `references/partition-rules.md`、`pitfalls.md`）

- **必须命中真实分区键**：日期分区表（`dt`/`month`/`dt_month`）查询**必须带分区过滤**，日期范围**不超过 3 个月**（90 天）；非日期分区表（如 `record_id`）必须带高选择性条件 + `LIMIT`
- **关键词字段加反引号**：`month`/`date`/`order`/`key`/`value`/`type`/`status` 等保留词作字段名必须 `` ` `` 包裹
- **结果默认前 10 行**：SQL 不带 `LIMIT` 且用户没要全量，补 `LIMIT 10`
- **DESC/SHOW/EXPLAIN 不需要分区条件**

```sql
-- ✅ 日期分区表，命中 dt
SELECT * FROM internal.ads.ads_station_daily_operation_dt WHERE dt = '2026-04-21' LIMIT 10
-- ✅ 范围（3个月内）
SELECT * FROM internal.dwd.dwd_biz_income_order_detail_dt WHERE dt BETWEEN '2026-02-01' AND '2026-04-30'
-- ❌ 禁止：无分区条件 / 超 3 个月
```

### 2.2 执行（mcp_client.py 自带前置校验）

```bash
cd scripts/mcp-client
python3 mcp_client.py query --sql "<SQL>"
```

`mcp_client.py` 会自动：① 校验分区/反引号/只读/日期范围，拦截无 WHERE 全表扫描（LIMIT 不豁免）；② 拦截跨 catalog 关联（跨 catalog JOIN 需把外表数据拉到 coordinator，大表关联极易 OOM/超时——改为分别查各 catalog 取回小结果集本地关联）；③ 对 ODS/JDBC 复杂查询（多表 JOIN / GROUP BY+聚合 / 跨月范围）给**替代表建议**（命中先返回建议，不直接跑）；④ 对 internal 点查做索引校验。**被拦截时按建议修正 SQL 再跑**，不绕过。

### 2.3 大结果集分级（先 count 看规模）

```bash
python3 mcp_client.py count --sql "<SQL>"     # 先看总量
```
- ≤100 行 → 直接 `query` 拉全量
- 100~1000 → `query` 拉前 100 并告知总量
- \>1000 → `export-async` 异步导出 OSS，`export-status` 轮询

### 2.4 点查性能（1 秒规则）

JDBC/ODS 点查耗时 **>1s** 必须诊断，**不靠调大超时绕过**：① `EXPLAIN`+`SHOW CREATE TABLE` 查索引命中；② 探查 internal/hive 等价表替代；详见 `references/ods-query-optimization.md`。

### 2.5 paimon/Trino 表 → ego-lite 兜底（MCP 不支持）

判定命中（任一即走，别在 MCP 上硬试）：
- 表全路径含 `oss_paimon` / `paimon`，或表名 `_paimon` 结尾
- `mcp_client.py query` 报「请使用 Trino 引擎」/ `Unknown catalog 'oss_paimon'` / `paimon 表请使用 Trino`
- 用户明说「这表是 paimon / 要 Trino」或给了 `https://uqp.ykccn.net/` 链接
- **用户已提示「走 ego-lite / 去 uqp 页面查」** → 不必再判定，直接走兜底，禁止回 MCP 探

走法：Read `references/trino-paimon-fallback.md` → `Skill("ego-browser")` → 在 `https://uqp.ykccn.net/` 选 Trino 引擎贴 SQL 跑 → 取结果回填阶段 3。**paimon 表的 `event_date` 是分区字段，SQL 必须带 `event_date` 过滤**（与 2.1 分区规则一致）。

**禁止换皮重试**（实战踩坑：判定 paimon 后仍去「探 specific_query 有没有 paimon 模板」）：命中即只走 ego-lite，MCP 的 `query_doris`/`get_query_count`/`specific_query`/`export_*` 全禁；「探模板」「试 count」「换 tool」都是换皮，不省轮次。

---

## 阶段 3：结果输出

> **空壳禁令**：禁止只说「查到了 N 行」就结束。必须贴下面完整结果块，结论必须带数据证据并与原始问题对应；无结果也要如实说「无数据」，给下一步建议。

**输出约束（强制）**：结果展示尽量用图表/图示，不要只用文字。数据用表格、趋势用 ASCII 图、对比用并排图，让证据一目了然。

**必填字段自检**：查询目标、表（含分区）、结果行数+前 10 行、结论（带数据证据 + 与问题对应）。缺任一项禁止结束。

把查询结果与原始问题对应，给结论（带数据证据）：

```
═══════════════════════════════════════════════════════════════
【数据查询完成】
═══════════════════════════════════════════════════════════════

查询目标：<订单 OMJF-xxx 的结算金额>
表：internal.dwd.dwd_order_settle_model（dt=2026-04-21）
结果（共 N 行，展示前 10）：
- ...

结论：
- 该订单结算金额 = xxx，状态 = 已结算（与日志/链路证据吻合/矛盾）
═══════════════════════════════════════════════════════════════
```

---

## 密钥配置（首次使用）

凭证存于 `scripts/mcp-client/.mcp_config.json`（**本工程内，已 gitignore，不提交**）。
- 首次：`python3 mcp_client.py init-config --base-url <query-server地址> --user <用户名> --password <密码>`（账号在统一自助查询平台获取）
- 验证：`python3 mcp_client.py setup-check`
- 环境变量（`MCP_BASE_URL`/`MCP_USER`/`MCP_PASS`/`MCP_TIMEOUT`）可临时覆盖 `.mcp_config.json`
- **IDE 安装场景**：`bin/cwork.js` 的 `SENSITIVE_PATTERNS` 过滤了 `.mcp_config.json`，IDE 目录里没有凭证；在 shell profile 加 `export CWORK_HOME=<cwork 源仓库路径>`，脚本同目录找不到时回源仓库读同一份，无需每个 IDE 重复配置
- 未配置时 `setup-check` 返回 `{"ready": false}` 并给 `action`

## references 索引（按需读，别全读）

| 文件 | 何时读 |
|---|---|
| `.source-table-mapping.md` | 源表反查数仓表（代码里看到源表名，查大数据等价表） |
| `catalog-detail.md` | 选 catalog / 找表全路径 / JDBC 列表 |
| `core-tables.md` | 订单明细选表 / 字段口径 / 来源表 |
| `jdbc-fallback.md` | 查 JDBC 业务库前探等价表 |
| `partition-rules.md` | 分区字段日期格式规范 |
| `ods-query-optimization.md` | ODS/点查慢查询优化 |
| `pitfalls.md` | 常见坑（漏分区/格式错/大结果集） |
| `trino-paimon-fallback.md` | paimon/Trino 表查不了 MCP 时，ego-lite 操作 uqp 平台兜底 |
| `query-templates.md` | 命令行模板速查 |

## 反模式

- 不确认 catalog/表就发 SQL（先选表，JDBC/ODS 先探等价表）
- 漏分区条件 / 日期超 3 个月（会被 precheck 拦，也别绕过）
- 跨 catalog 关联（一条 SQL 混 internal + jdbc/hive 表，会被 precheck 拦；跨源需求分别查再本地关联）
- 无 WHERE 全表扫描（SELECT 必带 WHERE 过滤 + LIMIT，LIMIT 不豁免，会被 precheck 拦）
- 关键词字段不加反引号（语法报错）
- 大结果集直接 `query` 拉（先 `count` 分级，>1000 走异步导出）
- 查询无结果臆造数据（如实说，换条件）
- 只看一行数据下结论（注意口径：结算 vs 下单 vs 实时）
- **paimon/Trino 表在 Doris MCP 上反复重试或换皮重试**（报 Unknown catalog 就立刻切 ego-lite 兜底；「探 specific_query 模板」「试 get_query_count」「换 tool」全是换皮，禁）
- **判定 paimon/Trino 后仍回 MCP 探路径**（用户已提示走 ego-lite/uqp 页面时，禁止回 MCP 探任何 tool）
- **浏览器兜底用 Playwright/puppeteer**（一律 ego-browser，遵守 cwork-article 浏览器 HARD GATE）

## 完成定义

- 能自己定的已直接做（选表、构造 SQL、发查询），决策点已与用户简短确认
- 凭证已就绪（`setup-check` 通过）
- SQL 通过前置校验（分区/反引号/只读/日期范围），按目标拿到数据；或 paimon/Trino 表走 ego-lite 兜底拿到数据
- 结果与问题对应，结论带数据证据
- 阶段 3 完整结果块已输出（查询目标/表/结果/结论全非空，标注数据来源 MCP/页面）；只说「查到 N 行」一句话 = 未完成

## 自动衔接

本技能为**独立工具**（和 log/bug/doc 同级），不进 init→implement→commit 主流程衔接链。
完成后不自动调起其他技能；若由 cwork-log/bug 调起，则**带数据证据返回调用方**继续排查。
随安装发布需在 `bin/cwork.js` 白名单加 `'data'`。
