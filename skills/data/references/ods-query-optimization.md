# ODS 层查询优化与命中检查

ODS 层数据量大，查询性能严重依赖分区裁剪和分桶命中。查询前必须确认：

## 检查项

| 检查项 | 说明 | 影响 |
|--------|------|------|
| **分区键** | `SHOW CREATE TABLE` 查看 `PARTITION BY` | 不命中分区 → 全表扫描，极慢 |
| **分桶键** | `DISTRIBUTED BY HASH` 查看 | 不命中分桶 → 所有 bucket 都扫，慢 |
| **索引** | `SHOW INDEX` 查看 bitmap/inverted 索引 | 不命中索引 → 无加速 |

## 典型问题：非分区/分桶字段过滤

```sql
-- ❌ 问题：uid 不是分区键(dt_month)也不是分桶键(flow_id)，单 uid 过滤仍需扫全分区所有 bucket
SELECT * FROM internal.ods_finance_cdc.ods_finance_d_t_user_flow
WHERE uid = 986093 AND dt_month >= '2026-03-01'
ORDER BY create_time DESC LIMIT 50
-- 耗时 204s

-- ✅ 优化1：精确指定 dt_month（分区裁剪）
WHERE uid = 986093 AND dt_month = '2026-04-01'

-- ✅ 优化2：优先用 DWD 宽表（dwd_order_settle_model 已预关联，分桶更优）
```

## ODS 查询优化规则

1. **必须命中分区键**（`dt`、`dt_month`、`month`），且范围尽量小
2. **尽量命中分桶键**（通常为主键或业务 ID），单条查询效果最佳
3. **非分区非分桶字段过滤** → 即使有分区裁剪，仍需扫该分区所有 bucket，数据量大时慢
4. **优先用 DWD 宽表** → DWD 已清洗+预关联，分桶策略更优，查询更快
