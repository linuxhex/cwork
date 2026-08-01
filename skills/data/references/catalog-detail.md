# Catalog 与分区格式细则

## Catalog 体系

| Catalog | 类型 | 典型用途 |
|---|---|---|
| `internal` | Doris 内部数仓 | 默认首选，查分层模型 |
| `hive` | Hive 元数据 | 历史离线数据 |
| `*_jdbc_catalog` | 外部业务库映射 | 数仓无等价表时兜底 |

## internal 数仓分层

| 库 | 层级 | 示例 |
|---|---|---|
| `internal.ads` | ADS 应用层 | `ads_station_daily_operation_dt` |
| `internal.dws` | DWS 汇总层 | `dws_act_user_service_order_anal_dt` |
| `internal.dwd` | DWD 明细层 | `dwd_biz_income_order_detail_dt` |
| `internal.dim` | DIM 维度层 | `dim_equip_station` |
| `internal.ods` / `internal.ods_*_cdc` | ODS 贴源层 | `ods_order_cdc.*` |

## 分区字段格式（重点）

| Catalog | 分区字段 | 格式 | 示例 |
|---|---|---|---|
| `internal` | `dt` | `yyyy-MM-dd` | `2026-04-21` |
| `internal` | `dt_month` | `yyyy-MM-01` | `2026-04-01` |
| `internal` | ``month`` | `yyyy-MM-01` | `2026-04-01` |
| `hive` | `dt` | `yyyy-MM-dd` | `2026-04-21` |
| `hive` | ``month`` / `dt_month` | `yyyy-MM` | `2026-04` |

> `internal` 与 `hive` 的月分区格式不同，混用会导致分区裁剪失效。

## 常见格式错误

```sql
-- 错误：internal dt_month 使用 yyyy-MM
WHERE dt_month = '2026-03'

-- 正确
WHERE dt_month = '2026-03-01'

-- 错误：hive month 使用 yyyy-MM-01
WHERE `month` = '2026-04-01'

-- 正确
WHERE `month` = '2026-04'
```

## 查询前确认分区键

```sql
SHOW CREATE TABLE internal.ods_finance_cdc.ods_finance_d_t_user_flow;
DESC internal.dwd.dwd_order_settle_model;
```


---

# 完整 Catalog 体系（从 SKILL.md 迁移）

## Catalog 体系

业务人员通常只知道业务库表名（如 `ads_station_daily_operation_dt`），需要知道该查哪个 catalog。

### 三大 Catalog

| Catalog | 类型 | 含义 | 何时使用 |
|---------|------|------|----------|
| `internal` | Doris 内部 | **数仓主存储**，DWD/DWS/DIM/ADS/ODS 层表都在这 | **默认首选**，查数仓分层表 |
| `hive` | Hive Metastore | Hive 上的历史/离线数据 | 查 `hive` 库下的旧版表，或 hive 独有的表 |
| `*_jdbc_catalog` | JDBC 外部 | 各业务系统 MySQL/ClickHouse 等的映射 | 查业务系统实时数据（订单、财务等） |

### internal 数仓分层

| 库 | 层 | 含义 | 示例表 |
|----|-----|------|--------|
| `internal.ads` | ADS | 应用层，面向业务的汇总宽表 | `ads_station_daily_operation_dt` |
| `internal.dws` | DWS | 轻度汇总层，按维度预聚合 | `dws_act_user_service_order_anal_dt` |
| `internal.dwd` | DWD | 明细宽表层，清洗后的事实表 | `dwd_biz_income_order_detail_dt` |
| `internal.dim` | DIM | 维表层，缓慢变化维度 | `dim_equip_station` |
| `internal.ods` | ODS | 原始数据层，贴源同步 | `ods_charge_cdc.*` |
| `internal.ods_*_cdc` | ODS-CDC | 各业务系统 CDC 入湖 | `ods_order_cdc.*` |

### 常用 JDBC Catalog（查业务系统实时数据）

| Catalog | 对接系统 | 用途 |
|---------|----------|------|
| `order_jdbc_catalog` | 订单系统 MySQL | 实时订单查询 |
| `finance_jdbc_catalog` | 财务系统 | 财务数据 |
| `basicdata_jdbc_catalog` | 基础数据 | 电站/设备基础信息 |
| `bigdata_jdbc_catalog` | 大数据平台 | 平台元数据 |
| `clickhouse_jdbc_catalog` | ClickHouse | 实时分析数据 |
| `price_center_jdbc_catalog` | 价格中心 | 电价/服务费 |
| `business_adb_jdbc_catalog` | 业务 ADB | 业务分析库 |
| `activity_polardb_jdbc_catalog` | 活动 PolarDB | 活动数据 |

### 如何选择 Catalog

```
业务问题 → 我要查什么？
  ├─ 数仓汇总指标（收入/电量/毛利） → internal.ads
  ├─ 数仓明细数据（订单明细） → internal.dwd
  ├─ 维度信息（电站/城市/组织） → internal.dim
  ├─ 历史离线数据（hive 独有表） → hive.dwd / hive.ods
  └─ 业务系统实时数据（订单/财务） → *_jdbc_catalog
```

### 表名全路径格式

```sql
-- internal 数仓表（最常用）
internal.dim.dim_equip_station

-- hive 表
hive.dwd.dwd_xxx
hive.ods.ods_xxx

-- JDBC 外部表
order_jdbc_catalog.db_name.table_name
finance_jdbc_catalog.db_name.table_name
```

### 业务表名 → 全路径映射

业务人员说表名时，按以下规则补全：
1. **ADS 层表**（`ads_` 开头）→ `internal.ads.<表名>`
3. **DWS 层表**（`dws_` 开头）→ `internal.dws.<表名>`
2. **DWD 层表**（`dwd_` 开头）→ `internal.dwd.<表名>`
4. **DIM 层表**（`dim_` 开头）→ `internal.dim.<表名>`
5. **ODS 层表**（`ods_` 开头）→ `internal.ods.<表名>`
6. **不确定** → 先 `SHOW TABLES FROM internal.<层>` 查找

---

