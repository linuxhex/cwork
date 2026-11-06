#!/usr/bin/env bash
# cwork-note: 查指定日期云效【预计工时】（只读）
# 链路（2026-11-05 实测，与云效页面一致：莲子 11-05 预计 8h）：
#   1. export_insight_expected_work_time 组织级预计工时导出
#      start_time/end_time 传日期即可（服务端按排期日过滤，单日通常 <200 条，一次拉全）
#      → 返回 value(分钟), workitem_id, project_id, is_deleted
#      注意：该接口的 next_token 不翻页（重复返回首页），故只用首页 max_results=200
#   2. 用 workitem_id 批量反查归属：list_workitems + conditions 按 identifier CONTAINS 做 OR 过滤
#      （预计记录的 recorder_id 是 24 位 hex，与 accountId 不互通；改走 workitem.assigned_to）
#      条件分组过多会 400 / 触发流控，故 15 个一组分块、并发 3、失败指数退避重试
#   3. 过滤 assigned_to == 目标 accountId，汇总 value/60 = 小时
# 用法: yunxiao_worktime.sh [日期 yyyy-MM-dd] [成员名|accountId]
#   不传日期默认今天；不传成员默认「莲子」。
# 输出: date/records/total_seconds/total_hours/account_id/member/status/detail 行，退出码 0。
# 依赖：alibabacloud-devops20210625（pip install --user）；缺则 fail-open 报无法检查。
# 时区：gmt_create/gmt_start 为 UTC 毫秒；日期按 Asia/Shanghai 的排期日匹配。
# 禁止臆造工时数：查不到就如实报 0 / 无法检查。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REQUIREMENT_DIR="${CWORK_HOME:-$HOME/.claude/skills/cwork-requirement}/skills/requirement/scripts"
if [ ! -f "$REQUIREMENT_DIR/_common.sh" ]; then
  REQUIREMENT_DIR="/Users/caomunian/Study/cwork/skills/requirement/scripts"
fi
# shellcheck source=_common.sh
source "$REQUIREMENT_DIR/_common.sh"

DATE="${1:-$(date +%Y-%m-%d)}"
USER_HINT="${2:-${YUNXIAO_ACCOUNT_ID:-${YUNXIAO_MEMBER_NAME:-莲子}}}"
ORG=$(get_org_id)

emit_empty() {
  echo "date=${DATE}"
  echo "records=0"
  echo "total_seconds=0"
  echo "total_hours=0.00"
  echo "account_id=${ACCOUNT_ID:-}"
  echo "member=${USER_HINT}"
  echo "status=$1"
  exit 0
}

# 检查 Python SDK 是否可用
if ! python3 -c 'import alibabacloud_devops20210625' 2>/dev/null; then
  emit_empty "无法检查（缺 alibabacloud-devops20210625 SDK，pip install --user alibabacloud-devops20210625）"
fi

# 解析成员名 → accountId（复用 cwork-requirement 的 members 接口）
# 注意：不能用 `printf | python3 - <<'PY'`——heredoc 会抢占 stdin，导致 python 读到空。
# 改为把成员 JSON 写临时文件，python 从 argv 读路径。
resolve_account_id() {
  local hint="$1"
  if [[ "$hint" =~ ^[0-9]{6,}$ ]]; then
    echo "$hint"
    return 0
  fi
  local members_json tmp
  members_json=$(devops_call "/organization/${ORG}/members" "maxResults=200" 2>/dev/null || true)
  tmp=$(mktemp)
  printf '%s' "$members_json" > "$tmp"
  HINT="$hint" python3 - "$tmp" <<'PY'
import json, os, sys
hint = os.environ.get("HINT", "").strip()
try:
    with open(sys.argv[1], encoding="utf-8") as f:
        data = json.load(f)
except Exception:
    print("")
    raise SystemExit
members = data.get("members") or []
exact, partial = [], []
for m in members:
    name = (m.get("organizationMemberName") or "").strip()
    aid = (m.get("accountId") or "").strip()
    if not aid:
        continue
    if name == hint:
        exact.append(aid)
    elif hint and hint in name:
        partial.append(aid)
print((exact or partial or [""])[0])
PY
  rm -f "$tmp"
}

ACCOUNT_ID=$(resolve_account_id "$USER_HINT" || true)
if [ -z "$ACCOUNT_ID" ]; then
  emit_empty "无法检查（找不到成员「${USER_HINT}」）"
fi

# 主流程：导出预计工时 → 批量反查 workitem 归属 → 汇总目标成员的预计工时
AK_ID="$AK_ID" AK_SECRET="$AK_SECRET" python3 - "$ORG" "$ACCOUNT_ID" "$USER_HINT" "$DATE" <<'PY'
import os, sys, json, time, datetime

CHUNK = 15          # 每批 identifier 数量（过大触发 400 / 流控）
WORKERS = 3         # 并发上限（云效按用户流控，>4 易 Throttling.User）
TRY = 4             # 单个请求重试次数

def call(fn, *args):
    """云效限流下的带退避重试：0.6s/1.2s/1.8s..."""
    last = None
    for i in range(TRY):
        try:
            return fn(*args)
        except Exception as ex:  # noqa: BLE001 - 限流/网络都重试
            last = ex
            time.sleep(0.6 * (i + 1))
    raise last

def emit(date, account_id, member, records, total_hours, status):
    total_seconds = int(total_hours * 3600)
    print(f"date={date}")
    print(f"records={len(records)}")
    print(f"total_seconds={total_seconds}")
    print(f"total_hours={total_hours:.2f}")
    print(f"account_id={account_id}")
    print(f"member={member}")
    print(f"status={status}")
    for r in records:
        t = datetime.datetime.utcfromtimestamp(r["gmt_create"] / 1000).strftime("%H:%M")
        print(f"  detail={t}Z\t{r['spent']}h\t[{r['project']}]\t{r['subject']}")

def scan_worktime(ak_id, ak_secret, org, target_user, hint, date_str):
    from concurrent.futures import ThreadPoolExecutor
    from alibabacloud_devops20210625.client import Client
    from alibabacloud_devops20210625 import models
    from alibabacloud_tea_openapi.models import Config

    client = Client(Config(access_key_id=ak_id, access_key_secret=ak_secret,
                           endpoint="devops.cn-hangzhou.aliyuncs.com"))

    # 1. 组织级预计工时导出（服务端按排期日过滤，单日一次拉全；next_token 不翻页，只用首页）
    try:
        resp = call(client.export_insight_expected_work_time, org,
                    models.ExportInsightExpectedWorkTimeRequest(
                        start_time=f"{date_str} 00:00:00",
                        end_time=f"{date_str} 23:59:59",
                        max_results=200))
        exports = [e for e in (resp.body.result or []) if str(getattr(e, "is_deleted", "N")) != "Y"]
    except Exception as e:
        emit(date_str, target_user, hint, [], 0.0, f"无法检查（export API 失败: {e}）")
        return

    if not exports:
        emit(date_str, target_user, hint, [], 0.0, "无预计工时记录")
        return

    # 2. 批量反查 workitem 归属（identifier CONTAINS 的 OR 分组；按块并发）
    ids = sorted({e.workitem_id for e in exports if getattr(e, "workitem_id", None)})
    project_ids = sorted({e.project_id for e in exports if getattr(e, "project_id", None)})
    chunks = [ids[i:i + CHUNK] for i in range(0, len(ids), CHUNK)]

    def scan(job):
        pid, cat, chunk = job
        id_set = set(chunk)
        groups = [[{"fieldIdentifier": "identifier", "operator": "CONTAINS",
                    "value": [i], "className": "string", "format": "input"}] for i in chunk]
        body = models.ListWorkitemsRequest(
            space_type="Project", space_identifier=pid, category=cat,
            conditions=json.dumps({"conditionGroups": groups}), max_results=200)
        out = {}
        try:
            rr = call(client.list_workitems, org, body)
        except Exception:
            return out
        for w in (rr.body.workitems or []):
            if w.identifier in id_set:
                out[w.identifier] = (
                    getattr(w, "assigned_to", None),
                    getattr(w, "subject", "") or "",
                    getattr(w, "space_name", "") or "",
                )
        return out

    jobs = [(p, c, ch) for p in project_ids for c in ("Req", "Task", "Bug") for ch in chunks]
    wi_map = {}
    if jobs:
        with ThreadPoolExecutor(max_workers=WORKERS) as ex:
            for m in ex.map(scan, jobs):
                wi_map.update(m)

    # 3. 过滤 assigned_to == 目标 accountId，汇总 value/60
    records = []
    for e in exports:
        assigned, subject, project = wi_map.get(e.workitem_id, (None, "", ""))
        if assigned != target_user:
            continue
        records.append({
            "project": project or "云效",
            "subject": subject or e.workitem_id,
            "spent": (getattr(e, "value", 0) or 0) / 60.0,
            "gmt_create": getattr(e, "gmt_create", 0) or 0,
        })

    records.sort(key=lambda r: r["gmt_create"])
    total_hours = sum(r["spent"] for r in records)
    status = "满8h" if total_hours >= 8 else f"未满({total_hours:.1f}/8h)"
    emit(date_str, target_user, hint, records, total_hours, status)

ak_id = os.environ["AK_ID"]
ak_secret = os.environ["AK_SECRET"]
org, account_id, hint, date = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
scan_worktime(ak_id, ak_secret, org, account_id, hint, date)
PY
