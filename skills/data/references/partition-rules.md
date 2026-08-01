# 分区字段日期格式规范

不同 catalog 的分区字段格式不同，**格式错误会导致分区裁剪失效或查询异常**。具体表的分区格式需通过 `DESC` 或 `SHOW CREATE TABLE` 确认。

## 各 catalog 分区格式

| Catalog | 分区字段 | 格式 | 示例 | 说明 |
|---------|----------|------|------|------|
| `internal` | `dt` | `yyyy-MM-dd` | `'2026-04-21'` | 按日分区，默认 T-1（昨天） |
| `internal` | `dt_month` | `yyyy-MM-01` | `'2026-04-01'` | 按月分区，默认当月1号 |
| `internal` | `month` | `yyyy-MM-01` | `'2026-04-01'` | 按月分区（关键词，需反引号） |
| `hive` | `dt` | `yyyy-MM-dd` | `'2026-04-21'` | 按日分区 |
| `hive` | `month` / `dt_month` | `yyyy-MM` | `'2026-04'` | ⚠️ hive 月分区格式不同于 internal |

> **关键区别**：internal 的 `dt_month` 格式是 `yyyy-MM-01`（如 `'2026-04-01'`），hive 的 `month`/`dt_month` 格式是 `yyyy-MM`（如 `'2026-04'`）。混用会导致分区裁剪失效。

## ⚠️ 常见格式错误

```sql
-- ❌ internal 表 dt_month 缺少日部分
WHERE dt_month >= '2026-03'
-- Doris 无法正确解析为分区值，分区裁剪失效

-- ✅ internal 表 dt_month 必须是 yyyy-MM-01
WHERE dt_month = '2026-03-01'
WHERE dt_month >= '2026-03-01'

-- ❌ internal 表 dt 用了月格式
WHERE dt = '2026-04'

-- ✅ internal 表 dt 必须是 yyyy-MM-dd
WHERE dt = '2026-04-21'

-- ✅ internal 表 dt：与单日字面量等价的日期表达式（仍为单日 DATE，如 T-1）
WHERE dt = DATE_SUB(CURRENT_DATE(), 1)
WHERE dt = DATE_ADD(CURRENT_DATE(), -1)

-- ✅ internal 表 dt：范围谓词 + 动态日期表达式（视为已命中分区过滤）
WHERE dt >= DATE_SUB(CURRENT_DATE(), 7)
WHERE dt > DATE_SUB(CURDATE(), 3)
WHERE dt <= DATE_ADD(CURRENT_DATE(), -1)
WHERE dt >= CURRENT_DATE()

-- ❌ hive 表 month 用了 internal 格式
WHERE `month` = '2026-04-01'

-- ✅ hive 表 month 用 yyyy-MM 格式
WHERE `month` = '2026-04'
```

## ⚠️ 后缀不等于分区类型

表名后缀 `_di` / `_mi` 仅是命名惯例，**不保证与实际分区字段一致**。查询前必须 `DESC` / `SHOW CREATE TABLE` 确认真实分区键。

**已知例外**：

| 表 | 后缀 | 实际分区 | 说明 |
|----|------|---------|------|
| `dwd_gaode_member_real_range_detail_di` | `_di` | `dt_month` | 月分区，非日分区 |
| `dwd_gaode_member_order_station_detail_di` | `_di` | `dt_month` | 月分区，非日分区 |
| `dwd_gaode_member_month_bridge_di` | `_di` | `dt_month` | 月分区，非日分区 |
| `ads_gaode_member_month_metric_di` | `_di` | `dt_month` | 月分区，非日分区 |

> **规则**：禁止根据表名后缀猜测分区字段，必须先查 DDL 再写谓词。

## 确认具体表的分区格式

不同表的分区字段可能不同，查询前应先确认：

```sql
-- 方法1：查看建表语句，找 PARTITION BY 行
SHOW CREATE TABLE internal.ods_finance_cdc.ods_finance_d_t_user_flow
-- 结果：PARTITION BY RANGE(`dt_month`)  → 分区字段是 dt_month

-- 方法2：查看表结构
DESC internal.dwd.dwd_order_settle_model
-- 找 Key 列中标记为分区键的字段
```

## 日期范围查询注意事项

- **精确分区优于范围分区**：`dt = '2026-04-21'` 优于 `dt BETWEEN '2026-04-01' AND '2026-04-30'`
- **范围查询必须用对应 catalog 的完整格式**
- **跨月范围用 BETWEEN**：`dt BETWEEN '2026-03-23' AND '2026-04-12'`
- **uni 平台对范围查询有额外开销**：`>=` / `BETWEEN` 比 `=` 慢很多，如需多月数据优先用 UNION ALL

```sql
-- ❌ uni平台范围查询可能极慢（204s）
WHERE uid = 986093 AND dt_month >= '2026-03-01'

-- ✅ 精确分区（4s）
WHERE uid = 986093 AND dt_month = '2026-04-01'

-- ✅ 如需多月，用 UNION ALL 绕过范围查询
SELECT ... WHERE uid = 986093 AND dt_month = '2026-03-01'
UNION ALL
SELECT ... WHERE uid = 986093 AND dt_month = '2026-04-01'
ORDER BY create_time DESC LIMIT 50
```
