# 核心明细表参考

本文件存放业务口径参考，不属于查询强制规则。

## 明细查询优先级

1. ADS/DWS（有现成指标时优先）
2. DWD（明细标准层）
3. ODS（仅补字段或排障）
4. JDBC 业务库（最后兜底）

## 订单明细核心表

| 表 | 全路径 | 时效 | 分区 | 适用场景 |
|---|---|---|---|---|
| dwd_order_settle_model | `internal.dwd.dwd_order_settle_model` | T+1 | `dt` | 结算成功订单，字段较全 |
| dwd_order_history_details_dt_realtime_rt | `internal.dwd_hudi.dwd_order_history_details_dt_realtime_rt` | 实时 | `dt` | 实时且只要结算成功 |
| dwd_order_history_details_partial_update_middle | `internal.dwd.dwd_order_history_details_partial_update_middle` | 实时 | `record_id` | 需要全部状态 |

## 使用建议

- 聚合查询（SUM/COUNT/GROUP BY）优先找 ADS/DWS 对应报表
- ODS/JDBC 多表 JOIN 慢时，优先寻找 DWD 宽表替代
- 替代后需做同口径一致性验证

## 一致性验证模板

```sql
-- 原始（明细聚合）
SELECT SUM(income)
FROM internal.dwd.dwd_biz_income_order_detail_dt
WHERE dt = '2026-04-21';

-- 替代（汇总表）
SELECT SUM(income)
FROM internal.ads.ads_station_daily_operation_dt
WHERE dt = '2026-04-21';
```


---

# 完整核心明细表规则（从 SKILL.md 迁移）

## ⚠️ 核心明细表优先使用规则

**直接查 ODS 层或业务库表查明细数据时，注意以下原则：**

- ODS 层是贴源同步的原始数据，未清洗、未关联维度，多表 JOIN 查询慢且结果可能不可靠
- 业务库表（`order_jdbc_catalog`、`finance_jdbc_catalog` 等）直接查会影响业务系统性能
- **如需业务库字段不在现有 DWD 表中，提需求让数仓团队补充，非必要不直接读业务库**
- **优先使用 DWD 宽表 → DWS 汇总 → ADS 报表**，从上往下选
- **简单查询（<300行 SQL、单表查询）可以直接查 ODS**，不强制替代

### 执行前强制替代检查（新增）

对 `ODS` / `*_jdbc_catalog` SQL，必须先做以下判断，再决定是否执行原 SQL：

1. 是否出现以下任一特征（命中即进入“必须提示替代”）：
   - 多表 `JOIN`
   - `GROUP BY` + 聚合函数（`SUM`/`COUNT`/`AVG`）
   - 月级/跨月时间范围查询（如 `dt_month` 区间）
   - 已出现超时、慢查询、或历史上同类 SQL 慢
2. 若命中，必须先输出“替代表建议”，至少包含：
   - 推荐表（按优先级）：`DWD` → `DWS` → `ADS`
   - 推荐原因（性能/口径稳定性/减少 JOIN）
   - 是否可直接替换（字段齐全/需补字段）
3. 若命中但**未给出替代表建议**，不得直接执行原 SQL。
4. 仅在以下条件之一满足时，才允许继续执行原 SQL：
   - 用户明确要求“先按原 SQL 跑”
   - 当前无可用替代表，且已向用户说明原因

**标准回复模板（命中强制替代时先说）：**

```text
检测到当前 SQL 属于 ODS/JDBC 复杂查询（JOIN/聚合/跨月范围），按规范先给替代表建议：
1) 首选 <table_a>（原因...）
2) 备选 <table_b>（原因...）
若你确认先跑原 SQL，我再按原语句执行。
```

### 订单明细核心表（按场景选择）

| 表 | 全路径 | 时效 | 分区 | 适用场景 |
|----|--------|------|------|----------|
| **dwd_order_settle_model** | `internal.dwd.dwd_order_settle_model` | T+1 | `dt`（结算日 yyyy-MM-dd） | **首选**。结算成功的订单明细 + 优惠券/引流/抽成/技术服务费/营销补贴 |
| **dwd_order_history_details_dt_realtime_rt** | `internal.dwd_hudi.dwd_order_history_details_dt_realtime_rt` | 实时 | `dt`（trade_time 日期 yyyy-MM-dd） | 需要实时数据时。只含结算成功（trade_status IN 10,11） |
| **dwd_order_history_details_partial_update_middle** | `internal.dwd.dwd_order_history_details_partial_update_middle` | 实时全量 | `record_id` | 需要全部订单状态（含未结算）时。按 record_id 分区 |

### 各表详情

#### 1. dwd_order_settle_model（首选 T+1）
- **全路径**: `internal.dwd.dwd_order_settle_model`
- **时效**: T+1
- **分区**: `dt` = 结算日（yyyy-MM-dd）
- **数据范围**: 按 trade_time（结算时间）的订单明细
- **包含**: 订单数据 + 结算数据 + 引流抽成费用 + 优惠券活动折扣 + 技术服务费 + 营销补贴
- **替代**: 替代 `hive.dwd.dwd_order_income_costs_model`（旧版 hive 表，不再使用）
- **来源表**:
  - dwd_hudi.dwd_order_history_details_dt_realtime_rt（基础明细）
  - ods_finance_cdc.ods_finance_d_t_technical_service_fee_expend（技术服务费）
  - ods_finance_cdc.ods_finance_d_t_operator_summary_clear_detail（运营商结算明细）
  - ods_finance_cdc.ods_finance_d_t_operator_summary_clear_record（运营商结算记录）
  - ods_finance_cdc.ods_finance_d_t_operator_wait_clear_order（待结算订单）
  - ods_finance_cdc.ods_finance_d_t_marketing_allowance_expend（营销补贴）

#### 2. dwd_order_history_details_dt_realtime_rt（实时）
- **全路径**: `internal.dwd_hudi.dwd_order_history_details_dt_realtime_rt`
- **时效**: 实时
- **分区**: `dt` = trade_time 日期（yyyy-MM-dd）
- **数据范围**: 只含结算成功订单（trade_status IN (10, 11)）
- **包含**: 订单数据 + 结算数据 + 分账 + 引流抽成
- **来源表**（业务库原始表，**禁止直接查**）:
  - yunkc_order.order_s_t_charging_record_history（充电记录）
  - yunkc_order.order_d_t_settle_info（结算信息）
  - yunkc_order.order_d_t_user_charging_info_history（用户充电信息）
  - yunkc_order.order_d_t_car_charging_info_history（车辆充电信息）
  - yunkc_order.order_d_t_sharing_info（分账信息）
  - yunkc_order.order_s_t_third_charging_record_history（第三方充电记录）
  - yunkc_order.order_d_t_jfpg_info（积分派购信息）
  - yunkc_order.order_d_t_fleet_settle_info（车队结算信息）
  - yunkc_order.order_d_t_operator_jfpg_info（运营商积分派购信息）
  - yunkc_finance.finance_d_t_saas_sharing_flow（SaaS 分账流水）
  - yunkc_finance.finance_d_t_referral_traffic_commissions_income（引流抽成收入）

#### 3. dwd_order_history_details_partial_update_middle（实时全量）
- **全路径**: `internal.dwd.dwd_order_history_details_partial_update_middle`
- **时效**: 实时全量
- **分区**: `record_id`（非日期分区，查询时需指定 record_id 范围或配合其他条件）
- **数据范围**: 包含全部 trade_status（含未结算、结算中、结算失败等）
- **来源表**: 同 dwd_order_history_details_dt_realtime_rt

### 查明细数据选择流程

```
需要查订单明细 →
  ├─ T+1 就够 → dwd_order_settle_model（首选，字段最全）
  ├─ 需要实时 + 只要结算成功 → dwd_hudi.dwd_order_history_details_dt_realtime_rt
  ├─ 需要实时 + 全部状态 → dwd.dwd_order_history_details_partial_update_middle
  └─ 需要汇总指标 → 先看 ADS/DWS 层有没有现成报表
```

### 字段名映射（ODS → DWD）

ODS 层字段名与 DWD 宽表字段名可能不同，查询时需注意：

| ODS 字段名 | DWD 字段名 | 说明 |
|-----------|-----------|------|
| `record_number` | `sql_number` | 充电订单号 |

### 聚合查询优化建议

当用户查询的是**聚合数据**（SUM/COUNT/AVG 等），建议使用上层汇总表替代明细表查询：

1. **用户在明细表（ODS/DWD）上做聚合** → 建议用 DWS/ADS 汇总表直接查
2. **SQL 含 GROUP BY + 聚合函数** → 优先查 ADS/DWS 是否有现成报表
3. **替代前后必须保证逻辑及结果一致，不能遗漏数据**

**聚合查询优化流程：**

```
用户在明细表上做聚合查询 →
  1. 识别聚合维度（GROUP BY 字段）和指标（SUM/COUNT 字段）
  2. 调用 dmp-sql-graph__query_upstream 查该表的上游依赖
  3. 在依赖中找 ADS/DWS 层汇总表（优先 ADS）
  4. 验证汇总表是否包含相同维度和指标
  5. 如果包含 → 建议用汇总表替代，并**对比验证结果一致性**
  6. 如果不包含或维度/指标缺失 → 不替代，保持原查询
```

**⚠️ 替代一致性验证（必须执行）：**

替代前后必须对比验证，确保逻辑和结果一致：

```sql
-- 验证方法：同一天同一条件下，两边结果必须相等
-- 原始查询（明细表聚合）
SELECT SUM(income) FROM internal.dwd.dwd_biz_income_order_detail_dt WHERE dt = '2026-04-21'

-- 替代查询（汇总表）
SELECT SUM(income) FROM internal.ads.ads_station_daily_operation_dt WHERE dt = '2026-04-21'

-- 如果两边结果不一致 → 不能替代，需排查差异原因
```

**示例：**
```
用户在 dwd_order_settle_model 上 GROUP BY dt, biz_1 SUM(income) →
  query_upstream('dwd_order_settle_model') →
  发现下游 ADS: ads_station_daily_operation_dt →
  验证 ADS 是否有 dt, biz_1, income 字段 →
  对比两边 SUM(income) 是否一致 →
  一致 → 建议用 ADS 替代，查询更快
  不一致 → 不替代，说明差异原因
```

直接查 ODS 或 JDBC 业务库表**不是禁止**，但在以下情况建议优化为 DWD 宽表：

1. **查询慢**：ODS 多表 JOIN 性能差，DWD 宽表已预关联，查询更快
2. **SQL 过于复杂**：超过 300 行的 SQL，通常可以用 1 个 DWD 宽表替代多个 ODS JOIN，大幅简化
3. **影响业务库性能**：直接查 JDBC catalog 业务库会影响 OLTP 系统性能
4. **即使尚未超时，只要命中“执行前强制替代检查”也必须先提示替代，再决定是否执行原 SQL**

**优化流程：**

```
用户查 ODS/JDBC 表，且满足以下任一条件 →
  ├─ 查询慢 / 超时
  ├─ SQL 超过 300 行
  └─ 查的是 JDBC 业务库表
→ 建议优化：
  1. 调用 dmp-sql-graph__query_upstream 查该表的上游依赖
  2. 在依赖中找 DWD/DWS 层宽表（优先 DWD）
  3. 如果找到 → 建议用户用 DWD 宽表替代，并说明哪些字段可用、SQL 可简化多少
  4. 如果没找到或 DWD 缺字段 → 提需求让数仓团队补充
```

**执行闸门补充（强制）：**
- 命中“执行前强制替代检查”时，agent 首次响应必须先给替代表建议，不能直接开跑原 SQL
- 若用户未确认“坚持原 SQL”，默认先执行替代方案 SQL（优先 DWD）

**血缘接口调用方式：**
- `dmp-sql-graph__query_upstream(table_name)` — 查上游依赖（支持中文表名）
- `dmp-sql-graph__query_path(table_a, table_b)` — 查两表关联路径
- `dmp-sql-graph__query_join_keys(table_a, table_b)` — 查两表 JOIN 键

**示例：**
```
用户查 5 个 ODS 表 JOIN（300+ 行 SQL）→
  query_upstream('ods_order_d_t_settle_info') →
  发现下游 DWD: dwd_order_settle_model →
  建议用 DWD 宽表替代，300 行 SQL → 30 行
```

---

