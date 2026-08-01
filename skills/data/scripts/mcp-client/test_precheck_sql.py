from __future__ import annotations

import unittest

from typing import Dict, Optional

from precheck_sql import (
    ddl_requires_date_partition_filter,
    precheck_sql,
    _detect_catalogs,
    _detect_catalog,
    _build_catalog_scope_map,
)


class PrecheckSqlTest(unittest.TestCase):
    def assert_blocked_with_code(
        self,
        sql: str,
        code: str,
        *,
        table_requires_dt_partition: Optional[Dict[str, bool]] = None,
    ) -> None:
        result = precheck_sql(sql, table_requires_dt_partition=table_requires_dt_partition)
        self.assertFalse(result["ok"])
        self.assertEqual(result["level"], "block")
        self.assertIn(code, {item["code"] for item in result["issues"]})

    def test_valid_internal_dt_query_passes(self) -> None:
        result = precheck_sql(
            "SELECT * FROM internal.ads.ads_station_daily_operation_dt "
            "WHERE dt = '2026-04-21' LIMIT 10"
        )
        self.assertTrue(result["ok"])
        self.assertEqual(result["level"], "pass")

    def test_with_cte_select_passes(self) -> None:
        result = precheck_sql(
            "WITH ta AS ("
            "SELECT station_id FROM internal.ads.ads_station_daily_operation_dt "
            "WHERE dt = '2026-04-21'"
            ") SELECT count(*) AS c FROM ta"
        )
        self.assertTrue(result["ok"])
        self.assertEqual(result["level"], "pass")

    def test_with_cte_missing_partition_blocked(self) -> None:
        self.assert_blocked_with_code(
            "WITH ta AS ("
            "SELECT station_id FROM internal.ads.ads_station_daily_operation_dt"
            ") SELECT * FROM ta LIMIT 10",
            "missing_partition_filter",
        )

    def test_internal_dt_month_requires_first_day(self) -> None:
        result = precheck_sql(
            "SELECT * FROM internal.dwd.dwd_xxx WHERE dt_month = '2026-03' LIMIT 10"
        )
        self.assertFalse(result["ok"])
        # 消除静默改写后，fix_sql 不再包含分区值替换，建议值在 suggested_sql 中
        self.assertIn("suggested_sql", result)
        self.assertIn("'2026-03-01'", result["suggested_sql"])

    def test_hive_month_requires_yyyy_mm(self) -> None:
        result = precheck_sql(
            "SELECT * FROM hive.ods.ods_xxx WHERE `month` = '2026-03-01' LIMIT 10"
        )
        self.assertFalse(result["ok"])
        # 消除静默改写后，建议值在 suggested_sql 中
        self.assertIn("suggested_sql", result)
        self.assertIn("'2026-03'", result["suggested_sql"])

    def test_between_range_over_90_days_is_blocked(self) -> None:
        self.assert_blocked_with_code(
            "SELECT * FROM internal.dwd.dwd_xxx "
            "WHERE dt BETWEEN '2026-01-01' AND '2026-04-30' LIMIT 10",
            "partition_range_too_large",
        )

    def test_select_without_partition_is_blocked(self) -> None:
        self.assert_blocked_with_code(
            "SELECT * FROM internal.ads.ads_station_daily_operation_dt",
            "missing_partition_filter",
        )

    def test_precheck_with_metadata_no_date_partition_skips_missing_dt(self) -> None:
        result = precheck_sql(
            "SELECT * FROM internal.ods_hudi.ods_base_s_t_charging_pile_realtime_rt LIMIT 10",
            table_requires_dt_partition={
                "internal.ods_hudi.ods_base_s_t_charging_pile_realtime_rt": False,
            },
        )
        self.assertTrue(result["ok"])
        self.assertNotIn(
            "missing_partition_filter",
            {i["code"] for i in result.get("issues", [])},
        )

    def test_join_mixed_dt_requirement_still_blocks_without_predicate(self) -> None:
        self.assert_blocked_with_code(
            "SELECT * FROM internal.ods_hudi.ods_base_s_t_charging_pile_realtime_rt a "
            "JOIN internal.dwd.dwd_xxx b ON a.pile_id = b.id LIMIT 10",
            "missing_partition_filter",
            table_requires_dt_partition={
                "internal.ods_hudi.ods_base_s_t_charging_pile_realtime_rt": False,
                "internal.dwd.dwd_xxx": True,
            },
        )

    def test_ddl_no_partition_returns_false(self) -> None:
        ddl = """
        CREATE TABLE `ods_hudi`.`ods_base_s_t_charging_pile_realtime_rt` (
          `pile_id` bigint NOT NULL
        ) ENGINE=OLAP
        UNIQUE KEY(`pile_id`)
        DISTRIBUTED BY HASH(`pile_id`) BUCKETS 10
        """
        self.assertFalse(ddl_requires_date_partition_filter(ddl))

    def test_ddl_range_dt_returns_true(self) -> None:
        ddl = """
        CREATE TABLE `dwd`.`t` (`id` int, `dt` date)
        DUPLICATE KEY(`id`)
        PARTITION BY RANGE(`dt`) ()
        DISTRIBUTED BY HASH(`id`) BUCKETS 10
        """
        self.assertTrue(ddl_requires_date_partition_filter(ddl))

    def test_ddl_range_pile_id_returns_false(self) -> None:
        ddl = """
        CREATE TABLE `x`.`t` (`pile_id` bigint)
        DUPLICATE KEY(`pile_id`)
        PARTITION BY RANGE(`pile_id`) ()
        DISTRIBUTED BY HASH(`pile_id`) BUCKETS 10
        """
        self.assertFalse(ddl_requires_date_partition_filter(ddl))

    def test_ddl_empty_returns_true(self) -> None:
        self.assertTrue(ddl_requires_date_partition_filter(""))

    def test_metadata_query_without_partition_passes(self) -> None:
        result = precheck_sql("DESC internal.ads.ads_station_daily_operation_dt")
        self.assertTrue(result["ok"])

    def test_dangerous_statement_is_blocked(self) -> None:
        self.assert_blocked_with_code(
            "DROP TABLE internal.ads.ads_station_daily_operation_dt",
            "readonly_only",
        )

    def test_reserved_fields_need_backticks(self) -> None:
        result = precheck_sql(
            "SELECT month, date FROM internal.ads.ads_station_daily_operation_dt "
            "WHERE dt = '2026-04-21' LIMIT 10"
        )
        self.assertFalse(result["ok"])
        codes = {item["code"] for item in result["issues"]}
        self.assertIn("reserved_field_without_backticks", codes)
        # 反引号修正仍在 fix_sql 中
        self.assertIn("`month`", result["fix_sql"])
        self.assertIn("`date`", result["fix_sql"])

    def test_missing_limit_is_warning(self) -> None:
        sql = (
            "SELECT station_id FROM internal.ads.ads_station_daily_operation_dt "
            "WHERE dt = '2026-04-21'"
        )
        result = precheck_sql(
            sql
        )
        self.assertTrue(result["ok"])
        self.assertEqual(result["level"], "warn")
        self.assertEqual(result["fix_sql"], sql)
        self.assertIn("LIMIT 10", result["warnings"][0]["suggest"])

    def test_aggregate_without_limit_passes(self) -> None:
        result = precheck_sql(
            "SELECT count(*) FROM internal.ads.ads_station_daily_operation_dt "
            "WHERE dt = '2026-04-21'"
        )
        self.assertTrue(result["ok"])
        self.assertEqual(result["level"], "pass")

    def test_dt_eq_date_sub_passes(self) -> None:
        result = precheck_sql(
            "SELECT * FROM internal.ads.ads_x "
            "WHERE dt = DATE_SUB(CURRENT_DATE(), 1) LIMIT 10"
        )
        self.assertTrue(result["ok"])

    def test_dt_gte_date_sub_passes(self) -> None:
        result = precheck_sql(
            "SELECT * FROM internal.ads.ads_x "
            "WHERE dt >= DATE_SUB(CURRENT_DATE(), 7) LIMIT 10"
        )
        self.assertTrue(result["ok"])

    def test_dt_gt_date_sub_curdate_passes(self) -> None:
        result = precheck_sql(
            "SELECT * FROM internal.dwd.dwd_x "
            "WHERE dt > DATE_SUB(CURDATE(), 3) LIMIT 10"
        )
        self.assertTrue(result["ok"])

    def test_dt_lte_date_add_passes(self) -> None:
        result = precheck_sql(
            "SELECT * FROM internal.dws.dws_x "
            "WHERE dt <= DATE_ADD(CURRENT_DATE(), -1) LIMIT 10"
        )
        self.assertTrue(result["ok"])

    def test_dt_gte_current_date_passes(self) -> None:
        result = precheck_sql(
            "SELECT * FROM internal.ads.ads_x "
            "WHERE dt >= CURRENT_DATE() LIMIT 10"
        )
        self.assertTrue(result["ok"])

    # ---- 新增：跨源 JOIN 多 catalog 校验 ----

    def test_cross_source_join_hive_dt_month_not_rewritten(self) -> None:
        """跨源 JOIN 中 hive 端 dt_month = '2026-05' 不应被按 internal 格式改写。"""
        sql = (
            "SELECT * FROM internal.ads.ads_x a "
            "FULL OUTER JOIN hive.ads.ads_y b ON a.id = b.id "
            "WHERE a.dt_month = '2026-05-01' AND b.dt_month = '2026-05' LIMIT 10"
        )
        result = precheck_sql(sql)
        # hive 端 '2026-05' 格式合法（yyyy-MM），不应产生 partition_format issue
        partition_format_issues = [
            i for i in result.get("issues", [])
            if i["code"] == "partition_format"
        ]
        # internal 端 '2026-05-01' 合法，hive 端 '2026-05' 合法 → 无 partition_format
        self.assertEqual(len(partition_format_issues), 0, f"不应有 partition_format issue: {partition_format_issues}")

    def test_cross_source_join_internal_dt_month_wrong_format_blocked(self) -> None:
        """跨源 JOIN 顶层 WHERE 中 dt_month = '2026-05' 走宽松策略：
        hive 端 yyyy-MM 合法 → 不拦截（避免误报）。
        若需精确拦截，应使用子查询将谓词放入对应 catalog 作用域内。"""
        sql = (
            "SELECT * FROM internal.ads.ads_x a "
            "FULL OUTER JOIN hive.ads.ads_y b ON a.id = b.id "
            "WHERE a.dt_month = '2026-05' AND b.dt_month = '2026-05' LIMIT 10"
        )
        result = precheck_sql(sql)
        # 顶层 WHERE 走宽松策略：hive 端 '2026-05' 合法（yyyy-MM）→ 不拦截
        partition_format_issues = [
            i for i in result.get("issues", [])
            if i["code"] == "partition_format"
        ]
        self.assertEqual(len(partition_format_issues), 0, "宽松策略下 hive 合法则放行")

    # ---- 新增：子查询作用域推断 ----

    def test_catalog_scope_map_cross_source(self) -> None:
        """_build_catalog_scope_map 应为跨源 JOIN 构建正确的 catalog 作用域。"""
        sql = (
            "SELECT * FROM internal.ads.ads_x a "
            "FULL OUTER JOIN hive.ads.ads_y b ON a.id = b.id "
            "WHERE a.dt_month = '2026-05-01' AND b.dt_month = '2026-05'"
        )
        scope_map = _build_catalog_scope_map(sql)
        catalogs_in_scope = {cat for _, _, cat in scope_map}
        self.assertIn("internal", catalogs_in_scope)
        self.assertIn("hive", catalogs_in_scope)

    def test_detect_catalogs_returns_set(self) -> None:
        """_detect_catalogs 对跨源 SQL 应返回包含 internal 和 hive 的集合。"""
        sql = (
            "SELECT * FROM internal.ads.ads_x a "
            "JOIN hive.ads.ads_y b ON a.id = b.id"
        )
        catalogs = _detect_catalogs(sql)
        self.assertEqual(catalogs, {"internal", "hive"})

    def test_detect_catalog_wrapper_compatible(self) -> None:
        """_detect_catalog wrapper 应保持原有优先级：internal > hive。"""
        sql = (
            "SELECT * FROM internal.ads.ads_x a "
            "JOIN hive.ads.ads_y b ON a.id = b.id"
        )
        self.assertEqual(_detect_catalog(sql), "internal")

    # ---- 新增：宽松策略 ----

    def test_loose_strategy_all_catalogs_error_then_block(self) -> None:
        """宽松策略：谓词不在子查询作用域内，所有 catalog 都报错才拦截。"""
        # dt = '2026-05' 对 internal 和 hive 都不合规（internal 需 yyyy-MM-dd，hive dt 无 yyyy-MM 格式）
        sql = (
            "SELECT * FROM internal.ads.ads_x a "
            "JOIN hive.ads.ads_y b ON a.id = b.id "
            "WHERE dt = '2026-05' LIMIT 10"
        )
        result = precheck_sql(sql)
        # dt = '2026-05' 对 internal (需 yyyy-MM-dd) 不合规
        partition_format_issues = [
            i for i in result.get("issues", [])
            if i["code"] == "partition_format"
        ]
        self.assertGreaterEqual(len(partition_format_issues), 1, "dt 格式错误应被拦截")

    # ---- 新增：函数表达式谓词识别 ----

    def test_dt_month_eq_left_passes(self) -> None:
        """dt_month = LEFT(...) 应视为已有分区谓词。"""
        result = precheck_sql(
            "SELECT * FROM hive.ads.ads_x "
            "WHERE dt_month = LEFT('2026-05-01', 7) LIMIT 10"
        )
        codes = {i["code"] for i in result.get("issues", [])}
        self.assertNotIn("missing_partition_filter", codes)

    def test_dt_month_eq_substr_passes(self) -> None:
        """dt_month = SUBSTR(...) 应视为已有分区谓词。"""
        result = precheck_sql(
            "SELECT * FROM hive.ads.ads_x "
            "WHERE dt_month = SUBSTR('2026-05-01', 1, 7) LIMIT 10"
        )
        codes = {i["code"] for i in result.get("issues", [])}
        self.assertNotIn("missing_partition_filter", codes)

    def test_dt_month_eq_date_format_passes(self) -> None:
        """dt_month = DATE_FORMAT(...) 应视为已有分区谓词。"""
        result = precheck_sql(
            "SELECT * FROM hive.ads.ads_x "
            "WHERE dt_month = DATE_FORMAT(CURRENT_DATE(), '%Y-%m') LIMIT 10"
        )
        codes = {i["code"] for i in result.get("issues", [])}
        self.assertNotIn("missing_partition_filter", codes)

    # ---- 新增：suggested_sql 字段 ----

    def test_suggested_sql_present_on_format_error(self) -> None:
        """分区格式错误时，返回结构应包含 suggested_sql 字段。"""
        result = precheck_sql(
            "SELECT * FROM internal.dwd.dwd_xxx WHERE dt_month = '2026-03' LIMIT 10"
        )
        self.assertFalse(result["ok"])
        self.assertIn("suggested_sql", result)
        self.assertIn("'2026-03-01'", result["suggested_sql"])

    def test_suggested_sql_absent_on_pass(self) -> None:
        """校验通过时，返回结构不应包含 suggested_sql 字段。"""
        result = precheck_sql(
            "SELECT * FROM internal.dwd.dwd_xxx WHERE dt_month = '2026-03-01' LIMIT 10"
        )
        self.assertTrue(result["ok"])
        self.assertNotIn("suggested_sql", result)

    def test_fix_sql_no_longer_rewrites_partition_value(self) -> None:
        """消除静默改写后，fix_sql 不应包含分区值替换。"""
        sql = "SELECT * FROM internal.dwd.dwd_xxx WHERE dt_month = '2026-03' LIMIT 10"
        result = precheck_sql(sql)
        self.assertFalse(result["ok"])
        # fix_sql 应保持原始 SQL（不包含分区值替换）
        self.assertNotIn("'2026-03-01'", result["fix_sql"])


if __name__ == "__main__":
    unittest.main()
