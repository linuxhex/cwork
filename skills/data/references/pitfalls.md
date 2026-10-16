# 常见坑与排查清单

## 1) 漏分区条件

症状：查询超时或全表扫描。  
处理：先查分区键，再加 `dt` / `dt_month` / ``month`` 过滤。

## 2) 分区格式写错

- `internal.dt_month` 必须 `yyyy-MM-01`
- `hive.month` 通常是 `yyyy-MM`

## 3) 关键词字段未加反引号

字段名如 `month`, `date`, `order`, `type`, `status` 必须用反引号。

## 4) 超过时间范围

日期分区表查询范围超过 90 天会被规则拦截或性能显著下降。

## 5) 直接查 JDBC 业务库

优先先探查 internal/hive 等价表；仅在无等价表时才查 JDBC。

## 5.5) 跨 catalog 关联

一条 SQL 混用多个 catalog（如 `internal.dwd.xxx JOIN order_jdbc_catalog.db.yyy`）会被 precheck 直接拦截（`cross_catalog_join`）。

原因：Doris 跨 catalog JOIN 需把外部 catalog 数据全量拉取到 coordinator，大表关联极易 OOM/超时。

正确做法：
- 分别查各 catalog，各取回小结果集（≤1000 行），本地关联
- 或优先用 internal 等价表替代 jdbc/hive 表（见 `jdbc-fallback.md`）

## 5.6) 无 WHERE 全表扫描

每条 SELECT 必须带 WHERE 过滤（会被 precheck 拦截，code=`full_table_scan`，LIMIT 不豁免）。

原因：分区校验只覆盖 internal/hive 的 dt 分区表，jdbc catalog（无分区概念）和 internal 非 dt 分区表靠此规则兜底；无过滤大表查询是数据源被打挂/超时的最常见来源。

要点：
- WHERE 条件用分区列或业务键（order_no/record_id 等高选择性字段），配 LIMIT
- 与 `missing_partition_filter` 可能双报——补一个分区 WHERE 即同消
- 全表行数统计改用带时间/分区条件的 count

## 6) 大结果集直接 query

建议先 `get_query_count`：

- <=100: 直接查
- 100~1000: 查前 100 + 告知总量
- >1000: 用 `create_oss_export_task_async`

## 7) prod 忽略 EXPLAIN

prod 必须先 EXPLAIN 并按风险分级处理：

- 低风险：可自动执行
- 中风险：需确认
- 高风险：必须明确“确认执行”
