"""
query-server MCP 通用调用脚本（HTTP + JSON-RPC + SSE 兼容解析）。

用途：
- 统一封装 query-server 工具调用
- 统一处理 SSE/JSON 响应解析
- 统一返回结构，避免各自实现导致行为不一致

环境变量：
- MCP_BASE_URL: query-server 地址（如 http://host:port）
- MCP_USER:     MCP 鉴权用户名（对应 X-User-Name）
- MCP_PASS:     MCP 鉴权密码（对应 X-Password）
"""

from __future__ import annotations

import argparse
import json
import os
import re
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple

from precheck_sql import (
    ddl_requires_date_partition_filter,
    partition_predicate_needed_internal_hive_refs,
    precheck_sql,
)

try:
    import httpx
except ModuleNotFoundError:  # pragma: no cover - used in minimal Python runtimes
    httpx = None  # type: ignore[assignment]


DEFAULT_BASE_URL = ""
DEFAULT_CONFIG_FILENAME = ".mcp_config.json"  # 点开头, 本地凭证, 已 gitignore


@dataclass
class MCPConfig:
    base_url: str
    user: str
    password: str
    timeout: int = 30

    @classmethod
    def from_sources(cls, config_file: Optional[str] = None) -> "MCPConfig":
        """
        配置优先级：
        1) 环境变量（MCP_BASE_URL/MCP_USER/MCP_PASS/MCP_TIMEOUT）
        2) config_file JSON（默认 .mcp_config.json，含 base_url/user/password/timeout）
        3) 内置默认值
        """
        file_cfg = _load_config_file(config_file)
        return cls(
            base_url=(os.getenv("MCP_BASE_URL") or file_cfg.get("base_url", "") or DEFAULT_BASE_URL).rstrip("/"),
            user=os.getenv("MCP_USER", file_cfg.get("user", "")),
            password=os.getenv("MCP_PASS", file_cfg.get("password", "")),
            timeout=int(os.getenv("MCP_TIMEOUT", str(file_cfg.get("timeout", 30)))),
        )


def _default_config_path() -> Path:
    """默认配置文件路径：同目录优先，没有则回 CWORK_HOME 源仓库。

    IDE 安装场景下 bin/cwork.js 的 SENSITIVE_PATTERNS 过滤了 .mcp_config.json，
    同目录没有凭证；此时若设了 CWORK_HOME，回源仓库读同一份，避免每个 IDE 重复配置。
    """
    local_path = Path(__file__).resolve().parent / DEFAULT_CONFIG_FILENAME
    if local_path.exists():
        return local_path
    cwork_home = os.getenv("CWORK_HOME")
    if cwork_home:
        home_path = Path(cwork_home) / "skills" / "data" / "scripts" / "mcp-client" / DEFAULT_CONFIG_FILENAME
        if home_path.exists():
            return home_path
    return local_path


def _load_config_file(config_file: Optional[str] = None) -> Dict[str, Any]:
    path = Path(config_file) if config_file else _default_config_path()
    if not path.exists():
        import warnings
        warnings.warn(
            f"⚠️ {path} 不存在，请先执行: "
            f"python mcp_client.py init-config --user <用户名> --password <密码>"
            f"；或 export CWORK_HOME=<cwork 源仓库路径> 复用源仓库凭证",
            stacklevel=2,
        )
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as e:  # noqa: BLE001
        raise ValueError(f"配置文件读取失败: {path} ({e})")


def init_config_file(
    user: str,
    password: str,
    base_url: str = "",
    timeout: int = 30,
    config_file: Optional[str] = None,
) -> Path:
    """首次初始化本地配置文件（由 agent/用户执行一次即可）。"""
    path = Path(config_file) if config_file else _default_config_path()
    payload: Dict[str, Any] = {
        "base_url": base_url,
        "user": user,
        "password": password,
        "timeout": timeout,
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    return path


def setup_check(config_file: Optional[str] = None) -> Dict[str, Any]:
    """检查配置是否就绪，供 skill 加载时调用。

    Returns:
        {"ready": True} 或 {"ready": False, "reason": ..., "action": ...}
    """
    config_path = Path(config_file) if config_file else _default_config_path()
    if not config_path.exists():
        return {
            "ready": False,
            "reason": f"{config_path} 不存在",
            "action": f"python mcp_client.py init-config --user <用户名> --password <密码>",
        }
    try:
        cfg = MCPConfig.from_sources(config_file=config_file)
    except Exception as e:  # noqa: BLE001
        return {
            "ready": False,
            "reason": f"配置读取失败: {e}",
            "action": "检查 mcp_config.json 格式，或重新 init-config",
        }
    if not cfg.user or not cfg.password:
        return {
            "ready": False,
            "reason": "凭证为空（user/password 未配置）",
            "action": f"python mcp_client.py init-config --user <用户名> --password <密码>",
        }
    return {"ready": True, "config_path": str(config_path), "user": cfg.user}


def _decode_result_text(data: dict) -> Any:
    """
    query-server 常见结构：
      {"result":{"content":[{"text":"{...json...}"}]}}
    若 text 为 JSON 字符串则反序列化，否则原样返回。
    """
    try:
        text = data["result"]["content"][0]["text"]
    except (KeyError, IndexError, TypeError):
        return data
    if not isinstance(text, str):
        return text
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        return text


def _parse_mcp_response(raw_text: str, content_type: str) -> Any:
    """
    兼容两类返回：
    1) application/json
    2) text/event-stream（SSE，逐行 data:）
    """
    ct = (content_type or "").lower()
    if "application/json" in ct:
        parsed = json.loads(raw_text)
        return _decode_result_text(parsed)

    if "text/event-stream" in ct or raw_text.lstrip().startswith("event:"):
        for line in raw_text.splitlines():
            s = line.strip()
            if not s.startswith("data:"):
                continue
            payload = s[5:].strip()
            try:
                outer = json.loads(payload)
            except json.JSONDecodeError:
                continue
            return _decode_result_text(outer)
        return None

    # 兜底：尽量按 json 解析
    try:
        parsed = json.loads(raw_text)
        return _decode_result_text(parsed)
    except json.JSONDecodeError:
        return raw_text


class QueryServerMCPClient:
    def __init__(self, config: Optional[MCPConfig] = None, config_file: Optional[str] = None):
        self.cfg = config or MCPConfig.from_sources(config_file=config_file)
        if not self.cfg.user or not self.cfg.password:
            raise ValueError(
                "query-server 凭证未配置（user/password 为空）。"
                "请先执行: python mcp_client.py init-config --user <用户名> --password <密码>"
            )
        self._headers = {
            "Content-Type": "application/json",
            "Accept": "application/json, text/event-stream",
            "X-User-Name": self.cfg.user,
            "X-Password": self.cfg.password,
        }
        self._schema_cache: Dict[str, Set[str]] = {}

    def call_tool(self, tool_name: str, arguments: Dict[str, Any], timeout: Optional[int] = None) -> Dict[str, Any]:
        """
        统一返回：
        {
          "success": bool,
          "data": Any,
          "error": str | None,
          "meta": {"tool": str, "elapsed_ms": int}
        }
        """
        payload = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "tools/call",
            "params": {"name": tool_name, "arguments": arguments},
        }
        begin = time.perf_counter()
        request_timeout = timeout or self.cfg.timeout
        try:
            if httpx is not None:
                resp = httpx.post(
                    f"{self.cfg.base_url}/mcp",
                    headers=self._headers,
                    json=payload,
                    timeout=request_timeout,
                )
                resp.raise_for_status()
                raw_text = resp.text
                content_type = resp.headers.get("content-type", "")
            else:
                req = urllib.request.Request(
                    f"{self.cfg.base_url}/mcp",
                    data=json.dumps(payload).encode("utf-8"),
                    headers=self._headers,
                    method="POST",
                )
                with urllib.request.urlopen(req, timeout=request_timeout) as resp:
                    raw_text = resp.read().decode("utf-8", errors="replace")
                    content_type = resp.headers.get("content-type", "")
            parsed = _parse_mcp_response(raw_text, content_type)
            elapsed = int((time.perf_counter() - begin) * 1000)
            if parsed is None:
                return {
                    "success": False,
                    "data": None,
                    "error": "响应解析失败：未找到可用 data 事件",
                    "meta": {"tool": tool_name, "elapsed_ms": elapsed},
                }
            return {
                "success": True,
                "data": parsed,
                "error": None,
                "meta": {"tool": tool_name, "elapsed_ms": elapsed},
            }
        except TimeoutError:
            elapsed = int((time.perf_counter() - begin) * 1000)
            return {
                "success": False,
                "data": None,
                "error": f"请求超时（>{request_timeout}s）",
                "meta": {"tool": tool_name, "elapsed_ms": elapsed},
            }
        except urllib.error.URLError as e:
            elapsed = int((time.perf_counter() - begin) * 1000)
            reason = getattr(e, "reason", e)
            return {
                "success": False,
                "data": None,
                "error": f"请求失败: {reason}",
                "meta": {"tool": tool_name, "elapsed_ms": elapsed},
            }
        except Exception as e:  # noqa: BLE001
            elapsed = int((time.perf_counter() - begin) * 1000)
            if httpx is not None and isinstance(e, httpx.TimeoutException):
                return {
                    "success": False,
                    "data": None,
                    "error": f"请求超时（>{request_timeout}s）",
                    "meta": {"tool": tool_name, "elapsed_ms": elapsed},
                }
            if httpx is not None and isinstance(e, httpx.HTTPStatusError):
                return {
                    "success": False,
                    "data": None,
                    "error": f"HTTP {e.response.status_code}: {e.response.text[:300]}",
                    "meta": {"tool": tool_name, "elapsed_ms": elapsed},
                }
            return {
                "success": False,
                "data": None,
                "error": str(e),
                "meta": {"tool": tool_name, "elapsed_ms": elapsed},
            }

    # ---- 常用语义化封装（可按需扩展） ----

    @staticmethod
    def _precheck_block_payload(tool_name: str, check: Dict[str, Any]) -> Dict[str, Any]:
        """校验失败时仍带上 warnings，便于与分区等拦截信息一并返回。"""
        warnings = check.get("warnings") or []
        meta: Dict[str, Any] = {"tool": tool_name, "phase": "precheck"}
        if warnings:
            meta["precheck_warnings"] = warnings
        suggested = check.get("suggested_sql") or check.get("fix_sql") or ""
        err_lines = [
            f"{check['reason']} | issues={check['issues']} | 建议SQL: {suggested}",
        ]
        return {
            "success": False,
            "data": None,
            "error": "\n".join(err_lines),
            "meta": meta,
        }

    def _resolve_table_requires_dt_partition(self, sql: str) -> Optional[Dict[str, bool]]:
        """对缺日期分区谓词的 internal/hive SELECT，按 SHOW CREATE TABLE 判断是否仍要求 dt 等过滤。"""
        refs = partition_predicate_needed_internal_hive_refs(sql)
        if refs is None:
            return None
        out: Dict[str, bool] = {}
        for ref in refs:
            ddl = self._get_create_table_sql_text(ref)
            if not ddl:
                out[ref] = True
            else:
                out[ref] = ddl_requires_date_partition_filter(ddl)
        return out

    def _checked_sql(self, tool_name: str, sql: str) -> Tuple[Optional[Dict[str, Any]], str, List[Dict[str, Any]]]:
        if tool_name not in {"query_doris", "get_query_count", "create_oss_export_task_async"}:
            return None, sql, []
        table_req = self._resolve_table_requires_dt_partition(sql)
        check = precheck_sql(sql, table_requires_dt_partition=table_req)
        if not check["ok"]:
            return (
                QueryServerMCPClient._precheck_block_payload(tool_name, check),
                sql,
                [],
            )
        warnings = check.get("warnings", [])
        checked_sql = check.get("fix_sql") or sql
        if tool_name != "query_doris" and warnings:
            checked_sql = sql
        return None, checked_sql, warnings

    @staticmethod
    def _extract_internal_point_lookup(sql: str) -> Optional[Tuple[str, str, str]]:
        s = sql.strip().lower()
        if not s.startswith("select") or " from internal." not in f" {s} ":
            return None
        if " where " not in f" {s} ":
            return None
        if " and " in s or " or " in s:
            return None

        m_table = re.search(r"\bfrom\s+internal\.([a-zA-Z0-9_]+)\.([a-zA-Z0-9_]+)", sql, re.IGNORECASE)
        m_where = re.search(r"\bwhere\s+`?([a-zA-Z0-9_]+)`?\s*=\s*(?:'[^']*'|[0-9]+)", sql, re.IGNORECASE)
        if not m_table or not m_where:
            return None
        return m_table.group(1), m_table.group(2), m_where.group(1).lower()

    @staticmethod
    def _map_internal_to_jdbc(internal_db: str, internal_table: str) -> Optional[str]:
        if not internal_table.startswith("ods_"):
            return None
        source_table = internal_table[4:]
        mapping = {
            "ods_base_cdc": ("base_jdbc_catalog", "yunkc_base"),
            "ods_order_cdc": ("order_jdbc_catalog", "yunkc_order"),
            "ods_finance_cdc": ("finance_jdbc_catalog", "yunkc_finance"),
        }
        if internal_db not in mapping:
            return None
        catalog, db = mapping[internal_db]
        return f"{catalog}.{db}.{source_table}"

    @staticmethod
    def _extract_indexed_columns_from_ddl(ddl: str, mysql_mode: bool) -> Set[str]:
        cols: Set[str] = set()

        patterns = [
            r"PRIMARY KEY\s*\(([^)]*)\)",
            r"UNIQUE KEY\s*\(([^)]*)\)",
            r"INDEX\s+[a-zA-Z0-9_`]+\s*\(([^)]*)\)",
            r"KEY\s+`?[a-zA-Z0-9_]+`?\s*\(([^)]*)\)",
            r"DISTRIBUTED BY HASH\s*\(([^)]*)\)",
        ]
        for p in patterns:
            for m in re.finditer(p, ddl, re.IGNORECASE):
                raw = m.group(1)
                for item in raw.split(","):
                    c = item.strip().strip("`").strip('"')
                    c = re.sub(r"\(\d+\)$", "", c)  # mysql 索引长度，如 user_account(20)
                    if c:
                        cols.add(c.lower())
        if mysql_mode:
            return cols
        return cols

    def _get_create_table_sql_text(self, full_table: str) -> Optional[str]:
        resp = self.call_tool("query_doris", {"sql": f"SHOW CREATE TABLE {full_table}"})
        if not resp.get("success"):
            return None
        try:
            rows = resp["data"]["result"]["data"]
            return rows[0][1] if rows and len(rows[0]) > 1 else None
        except Exception:
            return None

    def _index_gap_advice(self, sql: str) -> Optional[Dict[str, Any]]:
        parsed = self._extract_internal_point_lookup(sql)
        if not parsed:
            return None
        internal_db, internal_table, where_col = parsed
        jdbc_table = self._map_internal_to_jdbc(internal_db, internal_table)
        if not jdbc_table:
            return None

        internal_full = f"internal.{internal_db}.{internal_table}"
        internal_ddl = self._get_create_table_sql_text(internal_full)
        jdbc_ddl = self._get_create_table_sql_text(jdbc_table)
        if not internal_ddl or not jdbc_ddl:
            return None

        internal_idx_cols = self._extract_indexed_columns_from_ddl(internal_ddl, mysql_mode=False)
        jdbc_idx_cols = self._extract_indexed_columns_from_ddl(jdbc_ddl, mysql_mode=True)
        if where_col in jdbc_idx_cols and where_col not in internal_idx_cols:
            return {
                "success": False,
                "data": None,
                "error": (
                    "internal 点查索引校验提示：业务库有索引但 internal 缺失对应索引。"
                    f" 请大数据同时为内表增加索引。"
                    f" 内表: {internal_full}，字段: {where_col}；业务表: {jdbc_table}"
                ),
                "meta": {"tool": "query_doris", "phase": "index_advice"},
            }
        return None

    @staticmethod
    def _extract_sql_fields(sql: str) -> Set[str]:
        s = sql.lower()
        fields: Set[str] = set()
        stopwords = {
            "select", "from", "where", "join", "left", "right", "inner", "outer", "on",
            "and", "or", "group", "by", "order", "limit", "as", "desc", "asc",
            "sum", "count", "avg", "min", "max", "cast", "round", "decimal",
            "distinct", "case", "when", "then", "else", "end",
        }

        # alias.field
        for m in re.finditer(r"\b[a-zA-Z_][a-zA-Z0-9_]*\.([a-zA-Z_][a-zA-Z0-9_]*)\b", s):
            col = m.group(1).lower()
            if col not in stopwords:
                fields.add(col)

        # common bare fields used in predicates/group/order
        for m in re.finditer(r"\b([a-zA-Z_][a-zA-Z0-9_]*)\s*(=|>|<|>=|<=|between)\b", s):
            col = m.group(1).lower()
            if col not in stopwords:
                fields.add(col)
        for m in re.finditer(r"\bgroup\s+by\s+([a-zA-Z_][a-zA-Z0-9_]*)\b", s):
            col = m.group(1).lower()
            if col not in stopwords:
                fields.add(col)
        return fields

    def _get_table_columns(self, full_table: str) -> Set[str]:
        if full_table in self._schema_cache:
            return self._schema_cache[full_table]
        resp = self.call_tool("query_doris", {"sql": f"DESC {full_table}"})
        cols: Set[str] = set()
        try:
            rows = resp["data"]["result"]["data"]
            for row in rows:
                if row and row[0]:
                    cols.add(str(row[0]).lower())
        except Exception:
            cols = set()
        self._schema_cache[full_table] = cols
        return cols

    def _replacement_advice(self, sql: str) -> Optional[Dict[str, Any]]:
        s = sql.lower()
        is_ods_or_jdbc = (" ods_" in f" {s} ") or ("_jdbc_catalog." in s)
        if not is_ods_or_jdbc:
            return None

        has_join = " join " in f" {s} "
        has_group_agg = (" group by " in f" {s} ") and any(fn in s for fn in ("sum(", "count(", "avg("))
        has_month_range = ("dt_month >" in s) or ("dt_month >=" in s) or ("dt_month <" in s) or ("dt_month <=" in s) or (" between " in f" {s} " and "dt_month" in s)

        hit_reasons = []
        if has_join:
            hit_reasons.append("多表JOIN")
        if has_group_agg:
            hit_reasons.append("GROUP BY + 聚合")
        if has_month_range:
            hit_reasons.append("月级/跨月范围查询")

        if not hit_reasons:
            return None

        # 订单明细场景：三张核心表按字段匹配度动态排序
        if ("ods_order_" in s) or ("order_jdbc_catalog." in s):
            candidates = [
                {
                    "table": "internal.dwd.dwd_order_settle_model",
                    "priority": "首选",
                    "reason": "T+1 明细宽表，字段较全，减少 ODS 多表 JOIN",
                    "replaceable": "大多数订单明细/结算分析可直接替换，缺字段时需补字段",
                },
                {
                    "table": "internal.dwd_hudi.dwd_order_history_details_dt_realtime_rt",
                    "priority": "备选",
                    "reason": "实时明细（结算成功），查询性能通常优于 ODS 关联",
                    "replaceable": "仅适用于结算成功订单场景",
                },
                {
                    "table": "internal.dwd.dwd_order_history_details_partial_update_middle",
                    "priority": "备选",
                    "reason": "实时全量状态明细，覆盖未结算/失败等状态",
                    "replaceable": "适用于需要全状态订单的场景，需按 record_id 约束",
                },
            ]
            required_fields = self._extract_sql_fields(sql)
            ranked: List[Dict[str, Any]] = []
            for item in candidates:
                cols = self._get_table_columns(item["table"])
                score = len(required_fields & cols) if cols else 0
                ranked.append({**item, "match_score": score, "required_cnt": len(required_fields)})
            suggestions = sorted(ranked, key=lambda x: x["match_score"], reverse=True)
        else:
            suggestions = [
                {
                    "table": "internal.dwd.<候选宽表>",
                    "priority": "首选",
                    "reason": "优先 DWD 宽表，减少 ODS/JDBC 复杂 JOIN",
                    "replaceable": "需确认字段是否齐全",
                },
                {
                    "table": "internal.dws.<候选汇总表>",
                    "priority": "备选",
                    "reason": "聚合口径场景优先 DWS",
                    "replaceable": "需确认维度/指标口径一致",
                },
                {
                    "table": "internal.ads.<候选报表>",
                    "priority": "备选",
                    "reason": "报表口径优先 ADS，查询最轻量",
                    "replaceable": "需确认业务口径一致",
                },
            ]

        lines = [
            "检测到当前 SQL 属于 ODS/JDBC 复杂查询，按规范先给替代表建议：",
            f"命中特征：{', '.join(hit_reasons)}",
        ]
        for i, item in enumerate(suggestions, start=1):
            score_info = ""
            if "match_score" in item:
                score_info = f"，字段匹配度: {item['match_score']}/{item['required_cnt']}"
            lines.append(
                f"{i}) {item['priority']} {item['table']}（原因：{item['reason']}；可替换性：{item['replaceable']}{score_info}）"
            )
        lines.append("如需先按原 SQL 执行，请明确回复：先按原 SQL 跑。")

        return {
            "success": False,
            "data": None,
            "error": "\n".join(lines),
            "meta": {"tool": "query_doris", "phase": "replacement_advice"},
        }

    def query(self, sql: str) -> Dict[str, Any]:
        blocked, checked_sql, warnings = self._checked_sql("query_doris", sql)
        if blocked:
            return blocked
        replacement = self._replacement_advice(checked_sql)
        if replacement:
            return replacement
        advice = self._index_gap_advice(checked_sql)
        if advice:
            return advice
        result = self.call_tool("query_doris", {"sql": checked_sql})
        if warnings:
            result.setdefault("meta", {})["precheck_warnings"] = warnings
            result["meta"]["executed_sql"] = checked_sql
        return result

    @staticmethod
    def rows_as_dicts(result: Dict[str, Any]) -> List[Dict[str, Any]]:
        """将分离格式的 meta+data 按需合并为带列名的 dict 列表。

        适用于小结果集（<1000行）的便捷访问；大结果集建议直接用
        result['data']['result']['meta'] + result['data']['result']['data']
        按索引取值，避免 N×M key 重复开销。

        Args:
            result: query() 返回值

        Returns:
            [{col1: v1, col2: v2, ...}, ...]
        """
        try:
            inner = result["data"]["result"]
            meta = inner.get("meta")
            rows = inner.get("data")
            if not meta or not rows or not isinstance(rows, list):
                return []
            col_names = [m["name"] for m in meta if isinstance(m, dict) and "name" in m]
            if not col_names:
                return []
            return [dict(zip(col_names, row)) for row in rows if isinstance(row, list)]
        except (KeyError, TypeError, IndexError):
            return []

    def count(self, sql: str) -> Dict[str, Any]:
        blocked, checked_sql, warnings = self._checked_sql("get_query_count", sql)
        if blocked:
            return blocked
        result = self.call_tool("get_query_count", {"sql": checked_sql})
        if warnings:
            result.setdefault("meta", {})["precheck_warnings"] = warnings
            result["meta"]["executed_sql"] = checked_sql
        return result

    def export_async(self, sql: str, oss_path: Optional[str] = None) -> Dict[str, Any]:
        blocked, checked_sql, warnings = self._checked_sql("create_oss_export_task_async", sql)
        if blocked:
            return blocked
        args: Dict[str, Any] = {"sql": checked_sql}
        if oss_path:
            args["oss_path"] = oss_path
        result = self.call_tool("create_oss_export_task_async", args, timeout=120)
        if warnings:
            result.setdefault("meta", {})["precheck_warnings"] = warnings
            result["meta"]["executed_sql"] = checked_sql
        return result

    def export_status(self, task_id: str) -> Dict[str, Any]:
        return self.call_tool("get_doris_export_status", {"task_id": task_id})


def _build_cli() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="query-server MCP 通用客户端")
    sub = parser.add_subparsers(dest="cmd")

    p_init = sub.add_parser("init-config", help="初始化本地配置文件")
    p_init.add_argument("--user", required=True, help="MCP 用户名")
    p_init.add_argument("--password", required=True, help="MCP 密码")
    p_init.add_argument("--base-url", default="", help="query-server 地址，如 http://host:port")
    p_init.add_argument("--timeout", type=int, default=30, help="请求超时秒数")
    p_init.add_argument("--config-file", default="", help="配置文件路径（可选）")

    p_demo = sub.add_parser("demo", help="运行演示查询")
    p_demo.add_argument("--config-file", default="", help="配置文件路径（可选）")

    p_query = sub.add_parser("query", help="执行 query_doris")
    p_query.add_argument("--sql", default="", help="SQL 字符串")
    p_query.add_argument("--sql-file", default="", help="SQL 文件路径（utf-8）")
    p_query.add_argument("--config-file", default="", help="配置文件路径（可选）")

    p_count = sub.add_parser("count", help="执行 get_query_count")
    p_count.add_argument("--sql", default="", help="SQL 字符串")
    p_count.add_argument("--sql-file", default="", help="SQL 文件路径（utf-8）")
    p_count.add_argument("--config-file", default="", help="配置文件路径（可选）")

    p_export = sub.add_parser("export-async", help="执行 create_oss_export_task_async")
    p_export.add_argument("--sql", default="", help="SQL 字符串")
    p_export.add_argument("--sql-file", default="", help="SQL 文件路径（utf-8）")
    p_export.add_argument("--oss-path", default="", help="OSS 导出路径（可选）")
    p_export.add_argument("--config-file", default="", help="配置文件路径（可选）")

    p_status = sub.add_parser("export-status", help="查询导出任务状态")
    p_status.add_argument("--task-id", required=True, help="导出任务 task_id")
    p_status.add_argument("--config-file", default="", help="配置文件路径（可选）")

    p_show_create = sub.add_parser("show-create", help="执行 SHOW CREATE TABLE")
    p_show_create.add_argument("--table", required=True, help="全路径表名，如 internal.ads.xxx")
    p_show_create.add_argument("--config-file", default="", help="配置文件路径（可选）")

    p_setup_check = sub.add_parser("setup-check", help="检查配置是否就绪")
    p_setup_check.add_argument("--config-file", default="", help="配置文件路径（可选）")

    return parser


def _read_sql_arg(sql: str, sql_file: str) -> str:
    if sql_file:
        return Path(sql_file).read_text(encoding="utf-8").strip()
    return (sql or "").strip()


if __name__ == "__main__":
    cli = _build_cli()
    args = cli.parse_args()

    if args.cmd == "init-config":
        saved = init_config_file(
            user=args.user,
            password=args.password,
            base_url=args.base_url or "",
            timeout=args.timeout,
            config_file=args.config_file or None,
        )
        print(f"配置已写入: {saved}")
    elif args.cmd == "setup-check":
        result = setup_check(config_file=(getattr(args, "config_file", "") or None))
        print(json.dumps(result, ensure_ascii=False, indent=2))
    elif args.cmd == "demo" or args.cmd is None:
        client = QueryServerMCPClient(config_file=(getattr(args, "config_file", "") or None))
        explain_sql = (
            "EXPLAIN SELECT * FROM internal.ads.ads_station_daily_operation_dt "
            "WHERE dt = '2026-04-21' LIMIT 10"
        )
        print(json.dumps(client.query(explain_sql), ensure_ascii=False, indent=2))
    else:
        client = QueryServerMCPClient(config_file=(getattr(args, "config_file", "") or None))
        result: Dict[str, Any]

        if args.cmd == "query":
            sql_text = _read_sql_arg(args.sql, args.sql_file)
            if not sql_text:
                raise ValueError("query 模式必须提供 --sql 或 --sql-file")
            result = client.query(sql_text)
        elif args.cmd == "count":
            sql_text = _read_sql_arg(args.sql, args.sql_file)
            if not sql_text:
                raise ValueError("count 模式必须提供 --sql 或 --sql-file")
            result = client.count(sql_text)
        elif args.cmd == "export-async":
            sql_text = _read_sql_arg(args.sql, args.sql_file)
            if not sql_text:
                raise ValueError("export-async 模式必须提供 --sql 或 --sql-file")
            result = client.export_async(sql_text, args.oss_path or None)
        elif args.cmd == "export-status":
            result = client.export_status(args.task_id)
        elif args.cmd == "show-create":
            result = client.query(f"SHOW CREATE TABLE {args.table}")
        else:
            raise ValueError(f"不支持的命令: {args.cmd}")

        print(json.dumps(result, ensure_ascii=False, indent=2))
