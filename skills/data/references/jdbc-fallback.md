# JDBC 业务库查询前必须探查数仓等价表

直接查 JDBC 业务库（`order_jdbc_catalog`、`finance_jdbc_catalog` 等）**影响 OLTP 性能且速度慢**，查询前必须先探查是否有数仓等价表。

## 探查流程

```
需要查业务库表 →
  1. 确认表名（如 order_d_t_battery_check_report_content）
  2. 探查 hive 等价表：hive.ods.ods_<表名>_de 或 hive.ods.ods_<表名>_da
  3. 探查 internal 等价表：internal.ods_<xx>_cdc.ods_<表名>（可能带 _da/_de 后缀）
  4. 如果有 internal 表 → 检查是否有最新数据（查 max(dt) 或 max(dt_month)）
  5. 如果有 internal 表且数据最新 → 用 internal 表替代 JDBC 查询
  6. 如果只有 hive 表 → 用 hive 表替代（比 JDBC 快）
  7. 如果都无等价表 → 只能用 JDBC，但需评估影响
```

## 表名映射规则

| JDBC 表位置 | hive 等价表 | internal 等价表 |
|-------------|-------------|----------------|
| `order_jdbc_catalog.yunkc_order.<表名>` | `hive.ods.ods_<表名>_de` | `internal.ods_order_cdc.ods_<表名>` |
| `finance_jdbc_catalog.yunkc_finance.<表名>` | `hive.ods.ods_<表名>_de` | `internal.ods_finance_cdc.ods_<表名>` |
| `base_jdbc_catalog.yunkc_base.<表名>` | `hive.ods.ods_<表名>_da` | `internal.ods_base_cdc.ods_<表名>` |

> **注意**：hive 表名通常带 `_de`（CDC 日志表）或 `_da`（日全量快照表）后缀，internal 表名可能不带后缀。

## 验证 internal 表数据时效

```sql
-- 检查 ODS 表最新数据日期
SELECT MAX(dt) FROM internal.ods_order_cdc.ods_order_d_t_settle_info
SELECT MAX(dt_month) FROM internal.ods_finance_cdc.ods_finance_d_t_user_flow
```

- 如果最新日期 = 昨天或今天 → ✅ 可用
- 如果最新日期过期较多 → ⚠️ 可能已停用，需确认

## 示例

```
用户查: select count(*) from order_jdbc_catalog.yunkc_order.order_d_t_battery_check_report_content where soh_param is not null

探查:
  1. hive: hive.ods.ods_order_d_t_battery_check_report_content_de → ❌ 不存在
  2. internal: internal.ods_order_cdc.ods_order_d_t_battery_check_report_content → ❌ 不存在
  3. 结论: 只能查 JDBC，但 count(*) 全表扫描极慢，建议改为查 DWD/DWS 汇总表或限制条件
```
