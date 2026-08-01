from __future__ import annotations

import re
from datetime import date
from typing import Any, Dict, List, Optional, Sequence, Set, Tuple


READ_ONLY_PREFIXES = ("select", "with", "show", "desc", "describe", "explain")
BLOCKED_PREFIXES = ("insert", "update", "delete", "drop", "alter", "create", "truncate")
DATE_PARTITION_FIELDS = ("dt", "dt_month", "month")
RESERVED_FIELDS = {
    "month",
    "date",
    "order",
    "key",
    "value",
    "type",
    "status",
    "index",
    "table",
    "column",
    "user",
    "password",
    "host",
    "port",
    "schema",
    "database",
    "view",
    "partition",
    "offset",
    "limit",
}

_RE_INTERNAL_DT_MONTH_EQ = re.compile(
    r"\bdt_month\s*=\s*'(\d{4}-\d{2}(?:-\d{2})?|\d{6})'",
    re.IGNORECASE,
)
_RE_MONTH_EQ = re.compile(
    r"(?:`month`|month)\s*=\s*'(\d{4}-\d{2}(?:-\d{2})?|\d{6})'",
    re.IGNORECASE,
)
_RE_DT_EQ = re.compile(r"\bdt\s*=\s*'(\d{4}-\d{2}(?:-\d{2})?)'", re.IGNORECASE)
_RE_HIVE_DT_MONTH_EQ = re.compile(
    r"\bdt_month\s*=\s*'(\d{4}-\d{2}(?:-\d{2})?|\d{6})'",
    re.IGNORECASE,
)
_RE_TABLE_REF = re.compile(
    r"\b(?:from|join)\s+("
    r"(?:internal|hive|[a-zA-Z0-9_]+_jdbc_catalog)\.[a-zA-Z0-9_]+\.[a-zA-Z0-9_]+"
    r"|(?:ods|dwd|dws|ads|dim|ods_[a-zA-Z0-9_]+_cdc)\.[a-zA-Z0-9_]+"
    r")",
    re.IGNORECASE,
)
# dt 单日标量：与 'yyyy-MM-dd' 字面量等价，执行时仍为 DATE 类型点查（分区裁剪仍可能依赖优化器）
_DT_FIELD = r"(?:`dt`|\bdt\b)"
_DT_DAY_EXPR_BODY = rf"(?:" \
    rf"DATE_SUB\s*\(\s*CURRENT_DATE\s*\(\s*\)\s*,\s*-?\s*\d+\s*\)" \
    rf"|DATE_ADD\s*\(\s*CURRENT_DATE\s*\(\s*\)\s*,\s*-?\s*\d+\s*\)" \
    rf"|DATE_SUB\s*\(\s*CURDATE\s*\(\s*\)\s*,\s*-?\s*\d+\s*\)" \
    rf"|DATE_ADD\s*\(\s*CURDATE\s*\(\s*\)\s*,\s*-?\s*\d+\s*\)" \
    rf"|CURDATE\s*\(\s*\)" \
    rf"|CURRENT_DATE\s*\(\s*\)" \
    rf")"
_RE_DT_EQ_SINGLE_DAY_EXPR = re.compile(
    rf"{_DT_FIELD}\s*=\s*{_DT_DAY_EXPR_BODY}",
    re.IGNORECASE,
)
# dt 范围谓词：dt (>=|>|<=|<) DATE_SUB/DATE_ADD/CURRENT_DATE — 视为已命中分区过滤
_RE_DT_RANGE_DAY_EXPR = re.compile(
    rf"{_DT_FIELD}\s*(?:>=|>|<=|<)\s*{_DT_DAY_EXPR_BODY}",
    re.IGNORECASE,
)
# dt_month 函数表达式：dt_month = LEFT/SUBSTR/SUBSTRING/DATE_FORMAT/TRUNC(...)
# 视为已命中 dt_month 分区过滤（避免误报 missing_partition_filter）
_DT_MONTH_FIELD = r"(?:`dt_month`|\bdt_month\b)"
_DT_MONTH_FUNC_BODY = rf"(?:" \
    rf"LEFT\s*\(" \
    rf"|SUBSTR\s*\(" \
    rf"|SUBSTRING\s*\(" \
    rf"|DATE_FORMAT\s*\(" \
    rf"|TRUNC\s*\(" \
    rf")"
_RE_DT_MONTH_EQ_FUNC_EXPR = re.compile(
    rf"{_DT_MONTH_FIELD}\s*=\s*{_DT_MONTH_FUNC_BODY}",
    re.IGNORECASE,
)
_RE_ANY_FULL_TABLE = re.compile(
    r"\b((?:internal|hive|[a-zA-Z0-9_]+_jdbc_catalog)\.[a-zA-Z0-9_]+\.[a-zA-Z0-9_]+)\b",
    re.IGNORECASE,
)


def _extract_from_join_table_refs(sql: str, catalog: Optional[str]) -> Set[str]:
    """FROM/JOIN 后的表引用；internal 下支持 db.table 简写。"""
    refs: Set[str] = set()
    for m in _RE_TABLE_REF.finditer(sql):
        r = m.group(1).lower().strip("`")
        if r.count(".") == 2:
            refs.add(r)
        elif r.count(".") == 1 and catalog == "internal":
            layer, tbl = r.split(".", 1)
            refs.add(f"internal.{layer}.{tbl}")
        else:
            refs.add(r)
    return refs


def internal_hive_table_refs(sql: str, catalog: Optional[str]) -> Set[str]:
    """internal.* / hive.* 全名集合，供分区闸门与 mcp_client 拉 SHOW CREATE TABLE 使用。"""
    refs = _extract_from_join_table_refs(sql, catalog)
    for m in _RE_ANY_FULL_TABLE.finditer(sql):
        refs.add(m.group(1).lower())
    out: Set[str] = set()
    for rl in refs:
        if rl.startswith("internal.") or rl.startswith("hive."):
            out.add(rl)
    return out


def ddl_requires_date_partition_filter(ddl: str) -> bool:
    """
    根据 SHOW CREATE TABLE 返回的 DDL，判断该表是否按 dt / dt_month / month 做分区（需 SQL 中带对应谓词）。
    无分区定义或非上述日期分区键则返回 False；DDL 为空则保守返回 True。
    """
    if not ddl or not str(ddl).strip():
        return True

    d = str(ddl)
    if not (
        re.search(r"\bPARTITION\s+BY\b", d, re.I)
        or re.search(r"\bAUTO\s+PARTITION\s+BY\b", d, re.I)
        or re.search(r"\bPARTITIONED\s+BY\b", d, re.I)
    ):
        return False

    pos: Optional[int] = None
    for pat in (
        r"\bPARTITION\s+BY\s+(?:RANGE|LIST)\b",
        r"\bAUTO\s+PARTITION\s+BY\s+RANGE\b",
        r"\bPARTITIONED\s+BY\b",
    ):
        m = re.search(pat, d, re.I)
        if m:
            pos = m.end()
            break
    if pos is None:
        return False

    window = d[pos : pos + 8000]
    if re.search(r"\b(dt_month|`dt_month`)\b", window, re.I):
        return True
    if re.search(r"(?<![\w`])`?dt`?(?![\w`])", window, re.I):
        return True
    if re.search(r"(?<![\w`])`?month`?(?![\w`])", window, re.I):
        return True
    return False


def partition_predicate_needed_internal_hive_refs(sql: str) -> Optional[Set[str]]:
    """
    当返回非空 set：SELECT 已命中 internal/hive 表且 SQL 中尚无日期分区谓词，需结合 SHOW CREATE 判断是否拦截。
    返回 None：无需拉元数据（非目标 SELECT、已有分区谓词、或非 internal/hive）。
    """
    raw = sql or ""
    normalized = _normalize_sql(raw)
    if _first_keyword(normalized) not in ("select", "with"):
        return None
    if not _RE_TABLE_REF.search(normalized):
        return None
    catalogs = _detect_catalogs(normalized)
    if not (catalogs & {"internal", "hive"}):
        return None
    if _has_partition_predicate(normalized):
        return None
    # 取主 catalog 用于 internal_hive_table_refs 的简写推断
    primary_catalog = _detect_catalog(normalized)
    refs = internal_hive_table_refs(normalized, primary_catalog)
    return refs if refs else None


def _issue(code: str, message: str, field: str = "", found: str = "", suggest: str = "") -> Dict[str, str]:
    payload = {"code": code, "message": message}
    if field:
        payload["field"] = field
    if found:
        payload["found"] = found
    if suggest:
        payload["suggest"] = suggest
    return payload


def _normalize_sql(sql: str) -> str:
    return re.sub(r"\s+", " ", sql.strip()).strip()


def _first_keyword(sql: str) -> str:
    s = sql.lstrip()
    m = re.match(r"([a-zA-Z]+)", s)
    return m.group(1).lower() if m else ""


def _detect_catalogs(sql: str) -> Set[str]:
    """返回 SQL 中出现的所有 catalog 集合（internal / hive / jdbc）。"""
    catalogs: Set[str] = set()
    s = sql.lower()
    if " internal." in f" {s} ":
        catalogs.add("internal")
    if " hive." in f" {s} ":
        catalogs.add("hive")
    if "_jdbc_catalog." in s:
        catalogs.add("jdbc")
    if re.search(
        r"\b(?:from|join)\s+(?:ods|dwd|dws|ads|dim|ods_[a-zA-Z0-9_]+_cdc)\.[a-zA-Z0-9_]+",
        s,
        re.IGNORECASE,
    ):
        catalogs.add("internal")
    return catalogs


def _detect_catalog(sql: str) -> Optional[str]:
    """向后兼容 wrapper：返回优先级最高的单个 catalog。"""
    catalogs = _detect_catalogs(sql)
    # 保持原有优先级：internal > hive > jdbc
    for c in ("internal", "hive", "jdbc"):
        if c in catalogs:
            return c
    return None


def _build_catalog_scope_map(sql: str) -> List[Tuple[int, int, str]]:
    """基于 FROM/JOIN 表引用构建子查询级 catalog 作用域映射。

    返回 List[(start_pos, end_pos, catalog)]，每个三元组表示一个
    FROM/JOIN 子查询在 SQL 中的位置及其所属 catalog。

    end_pos 为该 FROM/JOIN 子句的结束位置（保守估计到下一个
    WHERE/JOIN/ON/GROUP/ORDER/LIMIT/HAVING 关键词或 SQL 末尾）。
    """
    scope_map: List[Tuple[int, int, str]] = []
    # 找到所有 FROM/JOIN ... table_ref 的位置
    _RE_FROM_JOIN = re.compile(
        r"\b(from|join)\s+("
        r"(?:internal|hive|[a-zA-Z0-9_]+_jdbc_catalog)\.[a-zA-Z0-9_]+\.[a-zA-Z0-9_]+"
        r"|(?:ods|dwd|dws|ads|dim|ods_[a-zA-Z0-9_]+_cdc)\.[a-zA-Z0-9_]+"
        r")",
        re.IGNORECASE,
    )
    # 子句结束边界关键词
    _RE_CLAUSE_BOUNDARY = re.compile(
        r"\b(?:where|on|and|or|join|left|right|full|inner|cross|group|order|limit|having|union|except|intersect)\b",
        re.IGNORECASE,
    )

    for m in _RE_FROM_JOIN.finditer(sql):
        start_pos = m.start()
        table_ref = m.group(2).lower().strip("`")
        # 推断 catalog
        if table_ref.startswith("internal.") or table_ref.count(".") == 1 and not table_ref.startswith(("hive.", "jdbc")):
            catalog = "internal"
        elif table_ref.startswith("hive."):
            catalog = "hive"
        elif "_jdbc_catalog." in table_ref:
            catalog = "jdbc"
        else:
            # db.table 简写默认 internal
            catalog = "internal"
        # 找子句结束位置：从 match 末尾往后找下一个边界关键词
        rest = sql[m.end():]
        boundary = _RE_CLAUSE_BOUNDARY.search(rest)
        if boundary:
            end_pos = m.end() + boundary.start()
        else:
            end_pos = len(sql)
        scope_map.append((start_pos, end_pos, catalog))

    return scope_map


def _suggest_month_first_day(value: str) -> str:
    if re.fullmatch(r"\d{6}", value):
        return f"{value[:4]}-{value[4:]}-01"
    if re.fullmatch(r"\d{4}-\d{2}", value):
        return f"{value}-01"
    return value


def _suggest_hive_month(value: str) -> str:
    if re.fullmatch(r"\d{6}", value):
        return f"{value[:4]}-{value[4:]}"
    if re.fullmatch(r"\d{4}-\d{2}-\d{2}", value):
        return value[:7]
    return value


def _parse_date(value: str, fmt: str) -> Optional[date]:
    try:
        if fmt == "yyyy-MM-dd" and re.fullmatch(r"\d{4}-\d{2}-\d{2}", value):
            year, month, day = map(int, value.split("-"))
            return date(year, month, day)
        if fmt == "yyyy-MM" and re.fullmatch(r"\d{4}-\d{2}", value):
            year, month = map(int, value.split("-"))
            return date(year, month, 1)
    except ValueError:
        return None
    return None


def _expected_format(catalog: Optional[str], field: str) -> Optional[str]:
    normalized = field.lower().strip("`")
    if normalized == "dt":
        return "yyyy-MM-dd"
    if catalog == "internal" and normalized in {"dt_month", "month"}:
        return "yyyy-MM-01"
    if catalog == "hive" and normalized in {"dt_month", "month"}:
        return "yyyy-MM"
    return None


def _value_matches_format(value: str, fmt: str) -> bool:
    if fmt == "yyyy-MM-dd":
        return re.fullmatch(r"\d{4}-\d{2}-\d{2}", value) is not None
    if fmt == "yyyy-MM-01":
        return re.fullmatch(r"\d{4}-\d{2}-01", value) is not None
    if fmt == "yyyy-MM":
        return re.fullmatch(r"\d{4}-\d{2}", value) is not None
    return True


def _suggest_value(value: str, fmt: str) -> str:
    if fmt == "yyyy-MM-01":
        return _suggest_month_first_day(value)
    if fmt == "yyyy-MM":
        return _suggest_hive_month(value)
    if fmt == "yyyy-MM-dd":
        return "例如 2026-04-21"
    return value


def _date_range_days(values: Sequence[str], fmt: str) -> Optional[int]:
    parsed = [_parse_date(v, "yyyy-MM-dd" if fmt == "yyyy-MM-01" else fmt) for v in values]
    if any(v is None for v in parsed):
        return None
    assert parsed[0] is not None and parsed[-1] is not None
    return abs((parsed[-1] - parsed[0]).days)


def _extract_partition_predicates(sql: str) -> List[Tuple[str, str, List[str]]]:
    predicates: List[Tuple[str, str, List[str]]] = []
    fields = r"(?:dt_month|dt|`month`|month)"
    field_ref = rf"(?<![\w`])({fields})(?![\w`])"
    value = r"'([^']+)'"

    for m in re.finditer(rf"{field_ref}\s+between\s+{value}\s+and\s+{value}", sql, re.IGNORECASE):
        predicates.append((m.group(1).strip("`").lower(), "between", [m.group(2), m.group(3)]))

    for m in re.finditer(rf"{field_ref}\s+in\s*\(([^)]*)\)", sql, re.IGNORECASE):
        values = re.findall(value, m.group(2))
        predicates.append((m.group(1).strip("`").lower(), "in", values))

    for m in re.finditer(rf"{field_ref}\s*(=|>=|<=|>|<)\s*{value}", sql, re.IGNORECASE):
        predicates.append((m.group(1).strip("`").lower(), m.group(2), [m.group(3)]))

    return predicates


def _has_partition_predicate(sql: str) -> bool:
    if len(_extract_partition_predicates(sql)) > 0:
        return True
    # 与 dt = 'yyyy-MM-dd' 等价的单日表达式（如 T-1），仍视为已命中 dt 分区过滤
    if _RE_DT_EQ_SINGLE_DAY_EXPR.search(sql) is not None:
        return True
    # dt >= / > / <= / < DATE_SUB/DATE_ADD/CURRENT_DATE — 范围谓词，视为已命中分区过滤
    if _RE_DT_RANGE_DAY_EXPR.search(sql) is not None:
        return True
    # dt_month = LEFT/SUBSTR/SUBSTRING/DATE_FORMAT/TRUNC(...) — 函数表达式谓词，视为已命中分区过滤
    # 注意：DATE_FORMAT(dt_month, '%Y-%m') = '2026-05' 这种函数包裹字段的形式无法识别，
    # 仍会触发 missing_partition_filter，属于已知限制
    if _RE_DT_MONTH_EQ_FUNC_EXPR.search(sql) is not None:
        return True
    return False


def _infer_predicate_catalog(
    pred_start: int,
    scope_map: List[Tuple[int, int, str]],
    catalogs: Set[str],
) -> Tuple[Optional[str], bool]:
    """根据谓词位置推断其所属 catalog。

    返回 (catalog, inferred)：
    - catalog: 推断出的 catalog（可能为 None）
    - inferred: 是否成功推断（False 表示走宽松策略）
    """
    # 找谓词落在哪个子查询作用域内
    matched_catalogs: Set[str] = set()
    for start, end, cat in scope_map:
        if start <= pred_start < end:
            matched_catalogs.add(cat)

    if len(matched_catalogs) == 1:
        return next(iter(matched_catalogs)), True
    if len(matched_catalogs) > 1:
        # 谓词跨多个子查询作用域，无法确定唯一归属
        return None, False
    # 谓词不在任何子查询作用域内（如顶层 WHERE）
    return None, False


def _check_partition_values(
    catalogs: Set[str],
    sql: str,
    fixed_sql: str,
    scope_map: Optional[List[Tuple[int, int, str]]] = None,
) -> Tuple[List[Dict[str, str]], str, Optional[str]]:
    """多 catalog 分区值校验。

    返回 (issues, fixed_sql, suggested_sql)：
    - issues: 校验问题列表
    - fixed_sql: 仅含反引号修正的 SQL（不再静默改写分区值）
    - suggested_sql: 建议修正后的完整 SQL（含分区值修正），仅在存在格式问题时填充
    """
    issues: List[Dict[str, str]] = []
    suggested_sql: Optional[str] = None
    predicates = _extract_partition_predicates(sql)

    for field, op, values in predicates:
        # 获取谓词在 SQL 中的位置用于 catalog 推断
        # 通过重新搜索获取 match 位置
        pred_start = _find_predicate_position(sql, field, op, values)
        pred_catalog, inferred = _infer_predicate_catalog(
            pred_start, scope_map or [], catalogs
        )

        if inferred and pred_catalog:
            # 谓词归属明确，按该 catalog 校验
            fmt = _expected_format(pred_catalog, field)
            if not fmt:
                continue
            for raw in values:
                if not _value_matches_format(raw, fmt):
                    suggest = _suggest_value(raw, fmt)
                    issues.append(
                        _issue(
                            "partition_format",
                            f"{pred_catalog}.{field} 格式应为 {fmt}",
                            field=field,
                            found=raw,
                            suggest=suggest,
                        )
                    )
                    # 构造 suggested_sql（不修改 fixed_sql）
                    if suggest and not suggest.startswith("例如"):
                        if suggested_sql is None:
                            suggested_sql = fixed_sql
                        suggested_sql = suggested_sql.replace(f"'{raw}'", f"'{suggest}'", 1)
        else:
            # 无法推断归属，宽松策略：对所有 catalog 分别校验，仅当全部报错才拦截
            format_issues_per_value: Dict[str, List[Dict[str, str]]] = {}
            suggest_per_value: Dict[str, str] = {}
            for raw in values:
                per_catalog_ok = []
                last_issue = None
                last_suggest = ""
                for cat in catalogs:
                    fmt = _expected_format(cat, field)
                    if not fmt:
                        per_catalog_ok.append(True)
                        continue
                    if _value_matches_format(raw, fmt):
                        per_catalog_ok.append(True)
                    else:
                        per_catalog_ok.append(False)
                        last_issue = _issue(
                            "partition_format",
                            f"{cat}.{field} 格式应为 {fmt}",
                            field=field,
                            found=raw,
                            suggest=_suggest_value(raw, fmt),
                        )
                        last_suggest = _suggest_value(raw, fmt)
                # 仅所有 catalog 都报错才拦截
                if per_catalog_ok and not any(per_catalog_ok):
                    issues.append(last_issue)
                    if last_suggest and not last_suggest.startswith("例如"):
                        suggest_per_value[raw] = last_suggest
            # 构造 suggested_sql
            if suggest_per_value:
                if suggested_sql is None:
                    suggested_sql = fixed_sql
                for raw, suggest in suggest_per_value.items():
                    suggested_sql = suggested_sql.replace(f"'{raw}'", f"'{suggest}'", 1)

        # 范围校验（取能推断的 catalog，否则取主 catalog）
        check_catalog = pred_catalog if inferred and pred_catalog else _detect_catalog(sql)
        fmt = _expected_format(check_catalog, field)
        if fmt and op in {"between", "in"} and len(values) >= 2:
            days = _date_range_days(values, fmt)
            if days is not None and days > 90:
                issues.append(
                    _issue(
                        "partition_range_too_large",
                        "日期分区查询范围不能超过 90 天",
                        field=field,
                        found=f"{values[0]}..{values[-1]}",
                        suggest="缩小到 90 天内，或拆分为多段查询/导出任务",
                    )
                )

    # hive 端 dt_month → `month` 检查：当推断为 hive 或宽松策略下 catalogs 含 hive 时触发
    hive_check = False
    if "hive" in catalogs:
        # 检查是否谓词推断为 hive catalog 或无法推断
        hive_match = _RE_HIVE_DT_MONTH_EQ.search(sql)
        if hive_match:
            pred_start = hive_match.start()
            pred_catalog, inferred = _infer_predicate_catalog(
                pred_start, scope_map or [], catalogs
            )
            if (inferred and pred_catalog == "hive") or not inferred:
                hive_check = True

    if hive_check:
        m = _RE_HIVE_DT_MONTH_EQ.search(sql)
        if m:
            raw = m.group(1)
            suggest = _suggest_hive_month(raw)
            issues.append(
                _issue(
                    "hive_month_field",
                    "hive 表通常应使用 `month` 分区字段，且格式为 yyyy-MM",
                    field="dt_month",
                    found=raw,
                    suggest=suggest,
                )
            )
            # suggested_sql 中也做 dt_month → `month` 替换
            if suggested_sql is None:
                suggested_sql = fixed_sql
            suggested_sql = re.sub(r"\bdt_month\b", "`month`", suggested_sql, count=1, flags=re.IGNORECASE)
            suggested_sql = suggested_sql.replace(f"'{raw}'", f"'{suggest}'", 1)

    return issues, fixed_sql, suggested_sql


def _find_predicate_position(sql: str, field: str, op: str, values: List[str]) -> int:
    """在 SQL 中查找指定谓词的起始位置，用于 catalog 归属推断。"""
    fields = r"(?:dt_month|dt|`month`|month)"
    field_ref = rf"(?<![\w`])({fields})(?![\w`])"
    value = r"'([^']+)'"

    if op == "between":
        pat = rf"{field_ref}\s+between\s+{value}\s+and\s+{value}"
    elif op == "in":
        pat = rf"{field_ref}\s+in\s*\(([^)]*)\)"
    else:
        pat = rf"{field_ref}\s*{re.escape(op)}\s*{value}"

    m = re.search(pat, sql, re.IGNORECASE)
    return m.start() if m else 0


def _select_list(sql: str) -> str:
    m = re.search(r"\bselect\b(.*?)\bfrom\b", sql, re.IGNORECASE | re.DOTALL)
    return m.group(1) if m else ""


def _check_reserved_fields(sql: str, fixed_sql: str) -> Tuple[List[Dict[str, str]], str]:
    issues: List[Dict[str, str]] = []
    select_part = _select_list(sql)
    if not select_part:
        return issues, fixed_sql

    for field in sorted(RESERVED_FIELDS):
        if re.search(rf"(?<![`.\w]){re.escape(field)}(?![`(\w])", select_part, re.IGNORECASE):
            issues.append(
                _issue(
                    "reserved_field_without_backticks",
                    "Doris 关键词字段需使用反引号",
                    field=field,
                    found=field,
                    suggest=f"`{field}`",
                )
            )
            fixed_sql = re.sub(
                rf"(?<![`.\w]){re.escape(field)}(?![`(\w])",
                f"`{field}`",
                fixed_sql,
                count=1,
                flags=re.IGNORECASE,
            )

    return issues, fixed_sql


def _has_limit(sql: str) -> bool:
    return re.search(r"\blimit\s+\d+\b", sql, re.IGNORECASE) is not None


def _is_aggregate_query(sql: str) -> bool:
    s = sql.lower()
    return any(fn in s for fn in ("count(", "sum(", "avg(", "min(", "max(")) or " group by " in f" {s} "


def _limit_suggestion(sql: str) -> str:
    stripped = sql.strip().rstrip(";")
    return f"{stripped} LIMIT 10"


def precheck_sql(
    sql: str,
    *,
    table_requires_dt_partition: Optional[Dict[str, bool]] = None,
) -> Dict[str, Any]:
    """
    查询前置校验：
    - 阻断非只读 SQL（含 WITH ... SELECT 的 CTE，首词为 with）
    - 阻断数据查询缺分区、分区格式错误、日期范围超过 90 天
    - table_requires_dt_partition：由 mcp_client 根据 SHOW CREATE TABLE 解析填入；
      为 None 时仍要求带 dt/dt_month/month 谓词（保守，供单测与无元数据场景）
    - 阻断常见 Doris 关键词字段未加反引号
    - 对未带 LIMIT 的普通 SELECT 给出 warning 和建议 SQL
    """
    raw_sql = sql or ""
    normalized = _normalize_sql(raw_sql)
    fixed_sql = raw_sql
    issues: List[Dict[str, str]] = []
    warnings: List[Dict[str, str]] = []

    if not normalized:
        return {
            "ok": False,
            "level": "block",
            "reason": "SQL 为空",
            "issues": [_issue("empty_sql", "SQL 不能为空")],
            "warnings": [],
            "fix_sql": raw_sql,
        }

    first = _first_keyword(normalized)
    catalogs = _detect_catalogs(normalized)
    catalog = _detect_catalog(normalized)  # 主 catalog，用于向后兼容逻辑

    if first in BLOCKED_PREFIXES or not first:
        issues.append(
            _issue(
                "readonly_only",
                "只允许 SELECT/WITH/SHOW/DESC/EXPLAIN 等只读操作",
                found=first or normalized[:20],
            )
        )
    elif first not in READ_ONLY_PREFIXES:
        issues.append(
            _issue(
                "unsupported_statement",
                "不支持的 SQL 类型，仅允许只读查询",
                found=first,
            )
        )

    is_select = first in ("select", "with")
    metadata_query = first in {"show", "desc", "describe", "explain"}
    has_tables = _RE_TABLE_REF.search(normalized) is not None

    need_missing_partition = False
    if (
        is_select
        and has_tables
        and (catalogs & {"internal", "hive"})
        and not _has_partition_predicate(normalized)
    ):
        if table_requires_dt_partition is None:
            need_missing_partition = True
        else:
            ih_refs = internal_hive_table_refs(normalized, catalog)
            if not ih_refs:
                need_missing_partition = True
            elif any(table_requires_dt_partition.get(r, True) for r in ih_refs):
                need_missing_partition = True

    if need_missing_partition:
        issues.append(
            _issue(
                "missing_partition_filter",
                "数据查询必须包含分区字段过滤条件",
                suggest="先用 DESC/SHOW CREATE TABLE 确认真实分区键，再补充 dt/dt_month/`month` 等过滤",
            )
        )

    if not metadata_query:
        scope_map = _build_catalog_scope_map(normalized)
        partition_issues, fixed_sql, suggested_sql = _check_partition_values(
            catalogs, normalized, fixed_sql, scope_map
        )
        issues.extend(partition_issues)
    else:
        suggested_sql = None

    if is_select:
        reserved_issues, fixed_sql = _check_reserved_fields(normalized, fixed_sql)
        issues.extend(reserved_issues)

    if is_select:
        if not _has_limit(normalized) and not _is_aggregate_query(normalized):
            suggestion = _limit_suggestion(fixed_sql)
            warnings.append(
                _issue(
                    "missing_limit",
                    "普通 SELECT 未限制返回行数，如仅需预览可手动补 LIMIT 10",
                    suggest=suggestion,
                )
            )

    if issues:
        result: Dict[str, Any] = {
            "ok": False,
            "level": "block",
            "reason": "SQL 前置校验失败",
            "issues": issues,
            "warnings": warnings,
            "fix_sql": fixed_sql,
        }
        if suggested_sql:
            result["suggested_sql"] = suggested_sql
        return result

    if warnings:
        return {
            "ok": True,
            "level": "warn",
            "reason": "SQL 前置校验通过，但有优化建议",
            "issues": [],
            "warnings": warnings,
            "fix_sql": fixed_sql,
        }

    return {
        "ok": True,
        "level": "pass",
        "reason": "",
        "issues": [],
        "warnings": [],
        "fix_sql": raw_sql,
    }
