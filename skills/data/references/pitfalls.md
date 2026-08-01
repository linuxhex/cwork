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
