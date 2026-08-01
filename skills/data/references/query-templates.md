# 查询模板 & 常见关键词字段

> 所有查询统一走 `scripts/mcp-client/mcp_client.py` CLI（自带 SQL 前置校验：分区过滤/关键词反引号/只读/日期范围/替代表建议）。调用前先 `cd scripts/mcp-client`，或用绝对路径。

## 查询模板

### 配置就绪检查（首次/排查必跑）
```bash
python3 mcp_client.py setup-check
# {"ready": true} → 可用；{"ready": false, ...} → 按 action 初始化
```

### 查表结构
```bash
python3 mcp_client.py show-create --table internal.ads.ads_station_daily_operation_dt
# 或直接 DESC
python3 mcp_client.py query --sql "DESC internal.ads.ads_station_daily_operation_dt"
```

### 查数据（必须带分区过滤）
```bash
python3 mcp_client.py query --sql "SELECT * FROM internal.ads.ads_station_daily_operation_dt WHERE dt = '2026-04-21' LIMIT 100"
# 动态日期
python3 mcp_client.py query --sql "SELECT * FROM internal.ads.ads_station_daily_operation_dt WHERE dt >= DATE_SUB(CURRENT_DATE(), 7) LIMIT 100"
```

### 查数据量（不拉明细，先看规模）
```bash
python3 mcp_client.py count --sql "SELECT * FROM internal.ads.ads_station_daily_operation_dt WHERE dt = '2026-04-21'"
```

### 大结果集导出（>1000 行走异步）
```bash
python3 mcp_client.py export-async --sql "SELECT * FROM internal.dwd.dwd_biz_income_order_detail_dt WHERE dt BETWEEN '2026-04-01' AND '2026-04-30'"
python3 mcp_client.py export-status --task-id <task_id>
```

### 从文件执行（长 SQL）
```bash
python3 mcp_client.py query --sql-file ./my.sql
```

## 结果分级（默认仅展示前 10 行）

| 规模（get_query_count） | 处理 |
|---|---|
| ≤ 100 | 直接 `query` 拉全量 |
| 100 ~ 1000 | `query` 拉前 100 并告知总量 |
| > 1000 | `export-async` 异步导出到 OSS |

## 常见关键词字段

以下字段名是 Doris 保留关键词，使用时**必须加反引号**（不加会语法报错；`mcp_client.py` 的 precheck 会提示）：

`month`, `date`, `order`, `key`, `value`, `type`, `status`, `index`, `table`, `column`, `user`, `password`, `host`, `port`, `schema`, `database`, `view`, `partition`, `offset`, `limit`
