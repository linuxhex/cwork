# 源表 → 数仓表映射速查

本文件用于**从源库表名反查数仓等价表**。场景：代码里看到源表（如 `yunkc_order.order_d_t_settle_info`），需要查大数据里的数据。

---

## 一、库级映射（源库 → 数仓 ODS 库）

### 存在的库

| 源库 | JDBC Catalog | internal ODS 库 | hive ODS 库 | 状态 |
|------|--------------|-----------------|-------------|------|
| `yunkc_order` | `order_jdbc_catalog.yunkc_order` | `internal.ods_order_cdc` | `hive.ods` | ✅ 存在（27 张表） |
| `yunkc_finance` | `finance_jdbc_catalog.yunkc_finance` | `internal.ods_finance_cdc` | `hive.ods` | ✅ 存在（193 张表） |
| `yunkc_base` | `base_jdbc_catalog.yunkc_base` | `internal.ods_base_cdc` | `hive.ods` | ✅ 存在（200+ 张表） |
| `yunkc_activity` | `activity_polardb_jdbc_catalog.yunkc_activity` | `internal.ods_activity_cdc` | `hive.ods` | ✅ 存在（85 张表） |

### 不存在的库（按通用规则推导）

| 源库 | JDBC Catalog | internal ODS 库（不存在） | 说明 |
|------|--------------|---------------------------|------|
| `yunkc_basicdata` | `basicdata_jdbc_catalog.yunkc_basicdata` | `internal.ods_basicdata_cdc` | ❌ 库不存在，只能查 JDBC 或 hive |
| `yunkc_price` | `price_center_jdbc_catalog.yunkc_price` | `internal.ods_price_cdc` | ❌ 库不存在，只能查 JDBC 或 hive |

---

## 二、表级映射（源表 → 数仓 DWD 宽表）

**优先级最高**：如果源表有对应的 DWD 宽表，直接查 DWD（字段更全、性能更好）。

### 订单明细相关（汇入 `dwd_order_history_details_dt_realtime_rt`）

| 源库.源表 | 数仓 DWD 宽表 | 说明 |
|-----------|---------------|------|
| `yunkc_order.order_s_t_charging_record_history` | `internal.dwd_hudi.dwd_order_history_details_dt_realtime_rt` | 充电记录 |
| `yunkc_order.order_d_t_settle_info` | 同上 | 结算信息 |
| `yunkc_order.order_d_t_user_charging_info_history` | 同上 | 用户充电信息 |
| `yunkc_order.order_d_t_car_charging_info_history` | 同上 | 车辆充电信息 |
| `yunkc_order.order_d_t_sharing_info` | 同上 | 分账信息 |
| `yunkc_order.order_s_t_third_charging_record_history` | 同上 | 第三方充电记录 |
| `yunkc_order.order_d_t_jfpg_info` | 同上 | 积分派购信息 |
| `yunkc_order.order_d_t_fleet_settle_info` | 同上 | 车队结算信息 |
| `yunkc_order.order_d_t_operator_jfpg_info` | 同上 | 运营商积分派购信息 |
| `yunkc_finance.finance_d_t_saas_sharing_flow` | 同上 | SaaS 分账流水 |
| `yunkc_finance.finance_d_t_referral_traffic_commissions_income` | 同上 | 引流抽成收入 |

### 结算明细相关（汇入 `dwd_order_settle_model`，T+1 首选）

| 源库.源表 | 数仓 DWD 宽表 | 说明 |
|-----------|---------------|------|
| `yunkc_finance.finance_d_t_technical_service_fee_expend` | `internal.dwd.dwd_order_settle_model` | 技术服务费 |
| `yunkc_finance.finance_d_t_operator_summary_clear_detail` | 同上 | 运营商结算明细 |
| `yunkc_finance.finance_d_t_operator_summary_clear_record` | 同上 | 运营商结算记录 |
| `yunkc_finance.finance_d_t_operator_wait_clear_order` | 同上 | 待结算订单 |
| `yunkc_finance.finance_d_t_marketing_allowance_expend` | 同上 | 营销补贴 |

---

## 三、表级映射（源表 → 数仓 ODS 表）

**优先级次之**：如果源表没有 DWD 宽表，查 ODS 贴源表。

### yunkc_order → internal.ods_order_cdc（27 张表）

| 源表 | internal ODS 表 | 说明 |
|------|-----------------|------|
| `order_d_t_bms_fault_data` | `ods_order_d_t_bms_fault_data` | BMS 故障数据 |
| `order_d_t_car_charging_info` | `ods_order_d_t_car_charging_info` | 车辆充电信息 |
| `order_d_t_car_charging_info_history` | `ods_order_d_t_car_charging_info_history` | 车辆充电信息历史 |
| `order_d_t_charge_ending_data` | `ods_order_d_t_charge_ending_data` | 充电结束数据 |
| `order_d_t_discount_info` | `ods_order_d_t_discount_info` | 折扣信息 |
| `order_d_t_elec_card` | `ods_order_d_t_elec_card` | 电卡 |
| `order_d_t_elec_card_history` | `ods_order_d_t_elec_card_history` | 电卡历史 |
| `order_d_t_error_data` | `ods_order_d_t_error_data` | 错误数据 |
| `order_d_t_fleet_settle_info` | `ods_order_d_t_fleet_settle_info` | 车队结算信息 |
| `order_d_t_hand_shaking_data` | `ods_order_d_t_hand_shaking_data` | 握手数据 |
| `order_d_t_history_order_ext` | `ods_order_d_t_history_order_ext` | 历史订单扩展 |
| `order_d_t_jfpg_info` | `ods_order_d_t_jfpg_info` | 积分派购信息 |
| `order_d_t_operator_discount_info` | `ods_order_d_t_operator_discount_info` | 运营商折扣信息 |
| `order_d_t_operator_jfpg_info` | `ods_order_d_t_operator_jfpg_info` | 运营商积分派购信息 |
| `order_d_t_operator_settle_deal_info` | `ods_order_d_t_operator_settle_deal_info` | 运营商结算处理信息 |
| `order_d_t_order_charging_activity_info` | `ods_order_d_t_order_charging_activity_info` | 订单充电活动信息 |
| `order_d_t_ori_price_settle_deal_info` | `ods_order_d_t_ori_price_settle_deal_info` | 原价结算处理信息 |
| `order_d_t_pay_detail` | `ods_order_d_t_pay_detail` | 支付明细 |
| `order_d_t_settle_deal_info` | `ods_order_d_t_settle_deal_info` | 结算处理信息 |
| `order_d_t_settle_info` | `ods_order_d_t_settle_info` | 结算信息 |
| `order_d_t_sharing_info` | `ods_order_d_t_sharing_info` | 分账信息 |
| `order_d_t_user_charging_info_history` | `ods_order_d_t_user_charging_info_history` | 用户充电信息历史 |
| `order_s_t_charging_record_history` | `ods_order_s_t_charging_record_history` | 充电记录历史 |
| `order_s_t_insurance_order` | `ods_order_s_t_insurance_order` | 保险订单 |
| `order_s_t_third_charging_record_history` | `ods_order_s_t_third_charging_record_history` | 第三方充电记录历史 |
| `order_s_t_user_service_order` | `ods_order_s_t_user_service_order` | 用户服务订单 |
| `order_s_t_user_service_order_attr` | `ods_order_s_t_user_service_order_attr` | 用户服务订单属性 |

### yunkc_finance → internal.ods_finance_cdc（常用表，共 193 张）

| 源表 | internal ODS 表 | 说明 |
|------|-----------------|------|
| `finance_d_t_user_flow` | `ods_finance_d_t_user_flow` | 用户流水 |
| `finance_d_t_user_wallet` | `ods_finance_d_t_user_wallet` | 用户钱包 |
| `finance_d_t_operator_clear_config` | `ods_finance_d_t_operator_clear_config` | 运营商结算配置 |
| `finance_d_t_operator_cleared_record` | `ods_finance_d_t_operator_cleared_record` | 运营商已结算记录 |
| `finance_d_t_operator_withdraw_bill` | `ods_finance_d_t_operator_withdraw_bill` | 运营商提现账单 |
| `finance_d_t_order_clearing` | `ods_finance_d_t_order_clearing` | 订单结算 |
| `finance_d_t_payment_record` | `ods_finance_d_t_payment_record` | 支付记录 |
| `finance_d_t_refund_confirm_record` | `ods_finance_d_t_refund_confirm_record` | 退款确认记录 |
| `finance_d_t_saas_sharing_flow` | `ods_finance_d_t_saas_sharing_flow` | SaaS 分账流水 |
| `finance_d_t_technical_service_fee_expend` | `ods_finance_d_t_technical_service_fee_expend` | 技术服务费支出 |
| `finance_d_t_marketing_allowance_expend` | `ods_finance_d_t_marketing_allowance_expend` | 营销补贴支出 |
| `finance_d_t_operator_summary_clear_detail` | `ods_finance_d_t_operator_summary_clear_detail` | 运营商结算明细 |
| `finance_d_t_operator_summary_clear_record` | `ods_finance_d_t_operator_summary_clear_record` | 运营商结算记录 |
| `finance_d_t_operator_wait_clear_order` | `ods_finance_d_t_operator_wait_clear_order` | 待结算订单 |
| `finance_d_t_referral_traffic_commissions_income` | `ods_finance_d_t_referral_traffic_commissions_income` | 引流抽成收入 |
| `finance_d_t_bank_account_flow` | `ods_finance_d_t_bank_account_flow` | 银行账户流水 |
| `finance_d_t_company_flow` | `ods_finance_d_t_company_flow` | 公司流水 |
| `finance_d_t_third_pay_info` | `ods_finance_d_t_third_pay_info` | 第三方支付信息 |
| `finance_d_t_third_refund_info` | `ods_finance_d_t_third_refund_info` | 第三方退款信息 |

> 完整 193 张表见附录"ods_finance_cdc 完整表清单"

### yunkc_base → internal.ods_base_cdc（常用表，共 200+ 张）

| 源表 | internal ODS 表 | 说明 |
|------|-----------------|------|
| `base_s_t_charging_station` | `ods_base_s_t_charging_station` | 充电站 |
| `base_s_t_charging_pile` | `ods_base_s_t_charging_pile` | 充电桩 |
| `base_s_t_charging_gun` | `ods_base_s_t_charging_gun` | 充电枪 |
| `base_s_t_station_operator` | `ods_base_s_t_station_operator` | 电站运营商 |
| `base_d_t_charging_station_price` | `ods_base_d_t_charging_station_price` | 电站价格 |
| `base_d_t_charging_pile_price` | `ods_base_d_t_charging_pile_price` | 电桩价格 |
| `base_d_t_station_attribute` | `ods_base_d_t_station_attribute` | 电站属性 |
| `base_d_t_station_revenue_sharing` | `ods_base_d_t_station_revenue_sharing` | 电站分润 |
| `base_d_t_ctp_account` | `ods_base_d_t_ctp_account` | CTP 账户 |
| `base_d_t_operator_ext` | `ods_base_d_t_operator_ext` | 运营商扩展信息 |

> 完整 200+ 张表见附录"ods_base_cdc 完整表清单"

### yunkc_activity → internal.ods_activity_cdc（常用表，共 85 张）

**⚠️ 注意**：源表前缀不统一，有 `crm_t_xxx`、`crm_d_t_xxx`、`crm_s_t_xxx` 和 `t_xxx` 四种：
- `yunkc_activity.crm_t_coupon` → `internal.ods_activity_cdc.ods_crm_t_coupon`
- `yunkc_activity.t_flow_fee` → `internal.ods_activity_cdc.ods_t_flow_fee`

反查时：先去掉 `yunkc_activity.` 前缀，然后加 `ods_` 前缀。

| 源表 | internal ODS 表 | 说明 |
|------|-----------------|------|
| `crm_t_coupon` | `ods_crm_t_coupon` | 优惠券 |
| `crm_t_coupon_activity` | `ods_crm_t_coupon_activity` | 优惠券活动 |
| `crm_t_user_coupon` | `ods_crm_t_user_coupon` | 用户优惠券 |
| `crm_t_issue_coupon_activity` | `ods_crm_t_issue_coupon_activity` | 发券活动 |
| `crm_d_t_charge_activity` | `ods_crm_d_t_charge_activity` | 充电活动 |
| `crm_t_station_discount_activity` | `ods_crm_t_station_discount_activity` | 电站折扣活动 |
| `t_flow_fee` | `ods_t_flow_fee` | 流量费 |
| `t_operator_fee` | `ods_t_operator_fee` | 运营商费用 |
| `t_technical_service_fee` | `ods_t_technical_service_fee` | 技术服务费 |

> 完整 85 张表见附录"ods_activity_cdc 完整表清单"

---

## 四、反查流程（源表 → 数仓表）

**核心逻辑：先走表级映射，取不到再走库级映射**

```
源表 yunkc_order.order_d_t_xxx →
  1. 【表级映射】查"二、表级映射（源表 → DWD）"是否有对应 DWD 宽表
     → 有则直接查 DWD（性能最好，字段最全）
  
  2. 【表级映射】查"三、表级映射（源表 → ODS）"是否有对应 ODS 表
     → 有则验证时效：SELECT MAX(dt) FROM internal.ods_order_cdc.ods_order_d_t_xxx
     → 存在且数据最新 → 查 ODS
  
  3. 【库级映射】按"一、库级映射"找到对应的 internal ODS 库
     → internal.ods_order_cdc 存在 → 构造表名：ods_order_d_t_xxx
     → 验证表是否存在：SHOW TABLES FROM internal.ods_order_cdc LIKE '%order_d_t_xxx%'
     → 存在 → 验证时效 → 查询
  
  4. 【兜底】internal 不存在 → 查 hive ODS：hive.ods.ods_order_d_t_xxx_de
  
  5. 【最后兜底】hive 也没有 → 只能查 JDBC（慢，慎用）
```

### 验证时效 SQL

```sql
-- 检查 ODS 表最新数据日期
SELECT MAX(dt) FROM internal.ods_order_cdc.ods_order_d_t_settle_info

-- 如果最新日期 = 昨天或今天 → ✅ 可用
-- 如果最新日期过期较多（如 1 个月前）→ ⚠️ 可能已停用，需确认
```

---

## 五、使用示例

### 示例 1：源表有对应 DWD 宽表

**场景**：代码里看到 `yunkc_order.order_d_t_settle_info`，想查结算信息

**步骤**：
1. 查"二、表级映射（源表 → DWD）" → 发现有 `dwd_order_history_details_dt_realtime_rt`
2. **直接查 DWD 宽表**：
   ```sql
   SELECT * FROM internal.dwd_hudi.dwd_order_history_details_dt_realtime_rt 
   WHERE dt = '2026-08-08' 
   LIMIT 10
   ```

### 示例 2：源表有对应 ODS 表

**场景**：代码里看到 `yunkc_order.order_d_t_pay_detail`，想查支付明细

**步骤**：
1. 查"二、表级映射（源表 → DWD）" → 没找到
2. 查"三、表级映射（源表 → ODS）" → 发现有 `ods_order_d_t_pay_detail`
3. **直接查 ODS**：
   ```sql
   SELECT * FROM internal.ods_order_cdc.ods_order_d_t_pay_detail 
   WHERE dt = '2026-08-08' 
   LIMIT 10
   ```

### 示例 3：源表不在映射里，走库级映射

**场景**：代码里看到 `yunkc_order.order_d_t_new_table`，想查新表

**步骤**：
1. 查"二、表级映射（源表 → DWD）" → 没找到
2. 查"三、表级映射（源表 → ODS）" → 没找到
3. 按"一、库级映射" → `yunkc_order` 对应 `internal.ods_order_cdc`
4. 构造 ODS 表名：`ods_order_d_t_new_table`
5. 验证是否存在：
   ```sql
   SHOW TABLES FROM internal.ods_order_cdc LIKE '%new_table%'
   ```
6. 存在 → 查询；不存在 → 查 hive 或 JDBC

### 示例 4：源库不存在 internal ODS

**场景**：代码里看到 `yunkc_basicdata.basicdata_d_t_xxx`，想查基础数据

**步骤**：
1. 查"一、库级映射" → `yunkc_basicdata` 对应的 `internal.ods_basicdata_cdc` 不存在
2. 直接查 hive ODS：`hive.ods.ods_basicdata_d_t_xxx_da`
3. hive 也没有 → 只能查 JDBC：`basicdata_jdbc_catalog.yunkc_basicdata.basicdata_d_t_xxx`

---

## 六、注意事项

1. **优先级**：DWD 宽表 > ODS 表（表级映射） > ODS 表（库级映射推导） > hive ODS > JDBC
2. **ODS 表分区字段**：大多数 ODS 表是 `dt` 日分区，但财务部分表是 `dt_month` 月分区，查询前用 `SHOW CREATE TABLE` 确认
3. **JDBC 是最后兜底**：直接查 JDBC 业务库会影响 OLTP 性能且慢，非必要不用
4. **本文件映射持续更新**：发现新映射关系时请补充

---

## 附录：完整表清单

### ods_order_cdc 完整表清单（27 张）

```
ods_order_d_t_bms_fault_data
ods_order_d_t_car_charging_info
ods_order_d_t_car_charging_info_history
ods_order_d_t_charge_ending_data
ods_order_d_t_discount_info
ods_order_d_t_elec_card
ods_order_d_t_elec_card_history
ods_order_d_t_error_data
ods_order_d_t_fleet_settle_info
ods_order_d_t_hand_shaking_data
ods_order_d_t_history_order_ext
ods_order_d_t_jfpg_info
ods_order_d_t_operator_discount_info
ods_order_d_t_operator_jfpg_info
ods_order_d_t_operator_settle_deal_info
ods_order_d_t_order_charging_activity_info
ods_order_d_t_ori_price_settle_deal_info
ods_order_d_t_pay_detail
ods_order_d_t_settle_deal_info
ods_order_d_t_settle_info
ods_order_d_t_sharing_info
ods_order_d_t_user_charging_info_history
ods_order_s_t_charging_record_history
ods_order_s_t_insurance_order
ods_order_s_t_third_charging_record_history
ods_order_s_t_user_service_order
ods_order_s_t_user_service_order_attr
```

### ods_finance_cdc 完整表清单（193 张）

```
ods_clearing_acquirer_settle_route
ods_clearing_add_purchase_config
ods_clearing_add_purchase_gradient_slot
ods_clearing_bill_settle_pay_fact
ods_clearing_business_advance_bill
ods_clearing_cncb_file_batch
ods_clearing_cncb_file_detail
ods_clearing_cncb_file_result_830
ods_clearing_cncb_fund_allocation_detail
ods_clearing_cncb_fund_allocation_record
ods_clearing_cncb_fund_fact_account
ods_clearing_cncb_fund_fact_account_flow
ods_clearing_cncb_fund_usage_account
ods_clearing_cncb_fund_usage_account_flow
ods_clearing_cncb_fund_usage_demand_snapshot
ods_clearing_cncb_inbound_fund_record
ods_clearing_cncb_ledger_prepay_detail
ods_clearing_cncb_ledger_prepay_record
ods_clearing_cncb_withdraw_trade_detail
ods_clearing_cncb_withdraw_trade_record
ods_clearing_cpo_global_cycle_config
ods_clearing_insurance_acceptance_event
ods_clearing_internal_business_wallet
ods_clearing_internal_business_wallet_trade_flow
ods_clearing_settle_route
ods_clearing_tp_clearing_bill
ods_clearing_tp_wallet
ods_clearing_tp_wallet_flow
ods_clearing_tp_withdraw_bill
ods_cpo_clearing_bill_deposit_inventory
ods_cpo_clearing_wallet_day_summary_flow
ods_cpo_compliance_rectification_list
ods_cpo_expenses_clearing_bill
ods_cpo_monthly_revenue_expense_bill
ods_cpo_monthly_revenue_expense_station_bill
ods_cpo_monthly_service_bill
ods_cpo_monthly_service_bill_adjust_record
ods_cpo_monthly_service_summary_whitelist
ods_cpo_operation_income_gray_list
ods_cpo_shs_share_summary_bill
ods_cpo_station_share_config
ods_cpo_station_share_config_history
ods_cpo_station_share_shs_rule
ods_cpo_station_shs_roster
ods_cpo_station_shs_share_bill
ods_finance_d_t_abnormal_event_record
ods_finance_d_t_alarm
ods_finance_d_t_alarm_notify
ods_finance_d_t_bank_account_flow
ods_finance_d_t_bank_clear_log
ods_finance_d_t_bank_code
ods_finance_d_t_bank_direct_trade_record
ods_finance_d_t_bank_withdraw_account
ods_finance_d_t_bill_apply
ods_finance_d_t_bill_apply_adjustment
ods_finance_d_t_bill_apply_and_operator_info
ods_finance_d_t_bill_apply_and_record_info
ods_finance_d_t_bill_apply_history
ods_finance_d_t_bill_apply_old_bak
ods_finance_d_t_bill_invoice_fail_export
ods_finance_d_t_bill_invoice_info
ods_finance_d_t_bill_invoice_info_detail
ods_finance_d_t_bill_invoice_info_his
ods_finance_d_t_cancel_bill_record
ods_finance_d_t_citic_account_event
ods_finance_d_t_citic_account_process
ods_finance_d_t_citic_account_version
ods_finance_d_t_citic_bank_card
ods_finance_d_t_citic_user_account
ods_finance_d_t_clear_cycle_config
ods_finance_d_t_clear_cycle_relation
ods_finance_d_t_clear_subsidy_summary_record
ods_finance_d_t_clearing_page_version
ods_finance_d_t_clearing_wallet
ods_finance_d_t_clearing_wallet_adjust_addition
ods_finance_d_t_clearing_wallet_adjust_record
ods_finance_d_t_clearing_wallet_adjust_relation
ods_finance_d_t_clearing_wallet_trade_flow
ods_finance_d_t_cloud_direct_withdraw_bill
ods_finance_d_t_cmb_anonymous_fund_adjust_flow
ods_finance_d_t_cmb_anonymous_fund_adjust_order
ods_finance_d_t_cmb_anonymous_fund_register
ods_finance_d_t_cmb_refund_confirm_record
ods_finance_d_t_cmb_user_sign_record
ods_finance_d_t_company_flow
ods_finance_d_t_company_flow_month_sum
ods_finance_d_t_data_migration_record
ods_finance_d_t_day_recharge_summary
ods_finance_d_t_entry_collect_day
ods_finance_d_t_entry_collect_relation
ods_finance_d_t_entry_sharing_flow
ods_finance_d_t_flow_side_day_summary
ods_finance_d_t_flow_side_payment_info
ods_finance_d_t_flow_withdraw_record
ods_finance_d_t_free_consume_record
ods_finance_d_t_fund_management_record
ods_finance_d_t_fund_poll_notify
ods_finance_d_t_gray_user
ods_finance_d_t_interconnectivity_order
ods_finance_d_t_interconnectivity_trade_flow
ods_finance_d_t_interconnectivity_trade_record
ods_finance_d_t_internal_clearing_bill
ods_finance_d_t_invest_service_fee
ods_finance_d_t_invoice_item_config
ods_finance_d_t_main_org_flow
ods_finance_d_t_marketing_allowance_expend
ods_finance_d_t_occupancy_fee_commissions_income
ods_finance_d_t_operator_apply_invoice_record
ods_finance_d_t_operator_bank_info
ods_finance_d_t_operator_change_card_record
ods_finance_d_t_operator_charge_wallet
ods_finance_d_t_operator_clear_config
ods_finance_d_t_operator_clear_config_record
ods_finance_d_t_operator_cleared_record
ods_finance_d_t_operator_clearing_relation_order
ods_finance_d_t_operator_clearing_relation_order_202103
ods_finance_d_t_operator_deposit_bank_info
ods_finance_d_t_operator_deposit_bank_info_history
ods_finance_d_t_operator_deposit_bank_info_net_person
ods_finance_d_t_operator_flow_month_sum
ods_finance_d_t_operator_invoice_config
ods_finance_d_t_operator_month_settle_config
ods_finance_d_t_operator_saas_sharing_wallet
ods_finance_d_t_operator_summary_clear_deposit_inventory
ods_finance_d_t_operator_summary_clear_detail
ods_finance_d_t_operator_summary_clear_record
ods_finance_d_t_operator_wait_clear_order
ods_finance_d_t_operator_withdraw_balance
ods_finance_d_t_operator_withdraw_bill
ods_finance_d_t_operator_withdraw_bill_detail
ods_finance_d_t_operator_withdraw_bill_service_flow
ods_finance_d_t_operator_withdraw_cycle_config
ods_finance_d_t_operator_withdraw_cycle_config_history
ods_finance_d_t_operator_withdraw_record
ods_finance_d_t_operator_withdraw_record_relation_order
ods_finance_d_t_order_clearing
ods_finance_d_t_order_clearing_202103
ods_finance_d_t_order_clearing_fail_record
ods_finance_d_t_order_subsidy_record
ods_finance_d_t_org_marketing_flow
ods_finance_d_t_org_marketing_freeze_record
ods_finance_d_t_org_marketing_wallet
ods_finance_d_t_org_quota_flow
ods_finance_d_t_org_quota_wallet
ods_finance_d_t_org_rights_flow
ods_finance_d_t_org_rights_wallet
ods_finance_d_t_pay_bank_record
ods_finance_d_t_pay_channel_config
ods_finance_d_t_pay_company
ods_finance_d_t_pay_confirm_record
ods_finance_d_t_pay_order
ods_finance_d_t_payment_record
ods_finance_d_t_personal_data_migration_trade_record
ods_finance_d_t_platform_service_flow
ods_finance_d_t_platform_service_summary_record
ods_finance_d_t_platform_withdraw_clear_relation
ods_finance_d_t_platform_withdraw_record
ods_finance_d_t_referral_traffic_commissions_income
ods_finance_d_t_refund_confirm_record
ods_finance_d_t_reopen_bill_record
ods_finance_d_t_repayment_bill
ods_finance_d_t_repayment_collection_account
ods_finance_d_t_repayment_commission_record
ods_finance_d_t_repayment_config
ods_finance_d_t_repayment_frozen_inventory
ods_finance_d_t_repayment_withdraw_record
ods_finance_d_t_reserve_coupon_record
ods_finance_d_t_retail_clear_order
ods_finance_d_t_saas_pay_record
ods_finance_d_t_saas_pay_record_detail
ods_finance_d_t_saas_sharing_flow
ods_finance_d_t_sell_elec_flow
ods_finance_d_t_sell_flow_withdraw_rela
ods_finance_d_t_sharing_withdraw_record
ods_finance_d_t_special_subject
ods_finance_d_t_station_income_day_summary
ods_finance_d_t_station_income_share_plan
ods_finance_d_t_station_income_share_plan_relation
ods_finance_d_t_station_profit_sharing_config
ods_finance_d_t_station_proxy
ods_finance_d_t_station_proxy_his
ods_finance_d_t_sub_account_trade_flow
ods_finance_d_t_sub_account_trade_record
ods_finance_d_t_sub_account_trade_result
ods_finance_d_t_super_bank_code
ods_finance_d_t_technical_service_fee_expend
ods_finance_d_t_third_order
ods_finance_d_t_third_order_detail
ods_finance_d_t_third_pay_add_on_info
ods_finance_d_t_third_pay_info
ods_finance_d_t_third_pay_notify
ods_finance_d_t_third_refund_info
ods_finance_d_t_tp_charge_flow
ods_finance_d_t_tp_income_share_plan
ods_finance_d_t_tp_payment_record
ods_finance_d_t_tp_trade_order
ods_finance_d_t_trade_company_clear_order
ods_finance_d_t_user_anonymous_bank_account_task
ods_finance_d_t_user_flow
ods_finance_d_t_user_flow_20210426
ods_finance_d_t_user_flow_extend
ods_finance_d_t_user_flow_month_sum
ods_finance_d_t_user_pay_order
ods_finance_d_t_user_quota_flow
ods_finance_d_t_user_refund_order
ods_finance_d_t_user_refund_record
ods_finance_d_t_user_repayment_record
ods_finance_d_t_user_sign_contract_record
ods_finance_d_t_user_wallet
ods_finance_d_t_withdraw_free_count
ods_finance_d_t_withdraw_service_fee
ods_finance_d_t_withdraw_verification_record
ods_finance_d_t_ykc_flow
ods_finance_org_pay_config
ods_finance_pay_area_merchant_relation
ods_finance_s_t_account_subject_company
ods_finance_s_t_account_subject_config
ods_finance_s_t_account_subject_link_operator
ods_finance_s_t_account_subject_quota
ods_finance_s_t_account_subject_quota_change_flow
ods_finance_s_t_bank_config
ods_finance_s_t_capital_account_balance_history
ods_finance_s_t_collection_company
ods_finance_s_t_directional_transfer_account_flow
ods_finance_s_t_org_rights_invoice
ods_finance_s_t_task
ods_finance_s_t_trade_company_merchant
ods_finance_s_t_transfer_account_record
ods_finance_s_t_transfer_account_record_flow
ods_finance_s_t_user_anonymous_bank_account
ods_finance_s_t_user_anonymous_bank_account_fail_record
ods_finance_s_t_user_anonymous_mbr
ods_finance_s_t_user_repayment_clear
ods_payment_pay_order
ods_payment_pay_order_merchant
ods_payment_pre_order
ods_payment_pre_order_service_order_detail
ods_payment_refund_order
ods_payment_surplus_refund_record
ods_payment_surplus_refund_relation
```

### ods_activity_cdc 完整表清单（85 张）

```
ods_crm_d_t_app_notice_config
ods_crm_d_t_app_notice_record_0107
ods_crm_d_t_appreciation_plan
ods_crm_d_t_appreciation_plan_flow_side_gun_info
ods_crm_d_t_appreciation_plan_graded
ods_crm_d_t_appreciation_plan_migrate_result
ods_crm_d_t_appreciation_plan_scope
ods_crm_d_t_charge_activity
ods_crm_d_t_charge_station_scope
ods_crm_d_t_offline_card_relation
ods_crm_d_t_offline_pile_relation
ods_crm_d_t_platform_notice_config
ods_crm_d_t_platform_notice_record
ods_crm_d_t_supervision_plan
ods_crm_d_t_supervision_plan_gun_info
ods_crm_d_t_timing_charge_config_relation
ods_crm_d_t_timing_charge_gun_record
ods_crm_d_t_timing_charge_startup_record
ods_crm_d_t_timing_ready_charge_record
ods_crm_s_t_app_notice
ods_crm_s_t_help_document
ods_crm_s_t_offline_card_record
ods_crm_s_t_platform_notice
ods_crm_s_t_timing_charge_config
ods_crm_sell_elec_station_relation
ods_crm_t_activity_issue_coupon_detail
ods_crm_t_activity_user_scope
ods_crm_t_advertising_user_scope
ods_crm_t_app_marketing_advertising
ods_crm_t_app_marketing_advertising_city
ods_crm_t_contract_config
ods_crm_t_contract_config_city_relation
ods_crm_t_contract_config_operator_relation
ods_crm_t_contract_operator_sign
ods_crm_t_coupon
ods_crm_t_coupon_activity
ods_crm_t_coupon_station_scope
ods_crm_t_elec_card
ods_crm_t_equity_activity_config
ods_crm_t_issue_coupon_activity
ods_crm_t_issue_coupon_activity_record
ods_crm_t_issue_coupon_activity_user_scope
ods_crm_t_pc_marketing_advertising
ods_crm_t_pc_marketing_advertising_operator
ods_crm_t_recharge_activity_config
ods_crm_t_recharge_activity_issue_coupon_detail
ods_crm_t_recharge_activity_vector
ods_crm_t_register_city_scope
ods_crm_t_saas_service_charge_config
ods_crm_t_scan_activity_config
ods_crm_t_scan_activity_user_scope
ods_crm_t_sell_elec_plan
ods_crm_t_single_issue_coupon_activity
ods_crm_t_station_discount_activity
ods_crm_t_station_discount_activity_station_scope
ods_crm_t_station_discount_activity_time_interval
ods_crm_t_station_discount_activity_user_scope
ods_crm_t_station_time_period_activity
ods_crm_t_station_time_period_rule_rela
ods_crm_t_station_time_period_user_rela
ods_crm_t_user_activity_record
ods_crm_t_user_coupon
ods_crm_t_user_coupon_copy
ods_member_equity_flow
ods_t_activity_reward_record
ods_t_car_team_user_activity_record
ods_t_drainage_fee
ods_t_flow_fee
ods_t_flow_fee_choose_detail
ods_t_flow_fee_choose_station_detail
ods_t_flow_fee_choose_tag_detail
ods_t_flow_fee_discount
ods_t_flow_fee_discount_price
ods_t_flow_gun_info
ods_t_flow_plan
ods_t_flow_plan_scope
ods_t_operator_fee
ods_t_operator_fee_choose_detail
ods_t_operator_fee_choose_org_detail
ods_t_operator_fee_choose_tag_detail
ods_t_operator_fee_discount
ods_t_prize_opportunity
ods_t_rebate_activity
ods_t_technical_service_fee
ods_t_technical_service_fee_discount
ods_t_technical_service_fee_operator
ods_t_technical_service_fee_station
ods_user_growth_task_progress
```

> ods_base_cdc 完整表清单（200+ 张）因篇幅较长，使用时按库级映射推导或通过 `SHOW TABLES FROM internal.ods_base_cdc` 查询。
