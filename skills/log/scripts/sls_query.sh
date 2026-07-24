#!/usr/bin/env bash
set -euo pipefail

# 查询阿里云 SLS 日志(ROA 签名)
# 用法:
#   sls_query.sh <env> list                         列出 logstore
#   sls_query.sh <env> logs <logstore> [query] [line] [from_s] [to_s]   查日志(秒级时间戳)
#   sls_query.sh <env> count <logstore> [query] [from_s] [to_s]         统计条数
#   env: test / uat / prod / 或直接传 project 名
#   时间缺省=最近10分钟; line 缺省=10

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_common.sh
source "$SCRIPT_DIR/_common.sh"

[[ $# -ge 2 ]] || { sed -n '2,9p' "$0"; fail "用法: $0 <env> {list|logs|count} ..."; }
ENV="$1"; ACTION="$2"; shift 2
PROJECT=$(get_sls_project "$ENV")

case "$ACTION" in
  list)
    echo ">>> SLS ListLogstores (env=$ENV project=$PROJECT)"
    sls_call "$PROJECT" GET "/logstores"
    ;;

  logs)
    LOGSTORE="${1:?need logstore}"; QUERY="${2:-*}"; LINE="${3:-10}"
    FROM="${4:-$(($(now_s)-600))}"; TO="${5:-$(now_s)}"
    QE=$(urlenc_sls "$QUERY"); LE=$(urlenc_sls "$LOGSTORE")
    resource="/logstores/${LE}?from=${FROM}&line=${LINE}&offset=0&query=${QE}&to=${TO}&type=log"
    echo ">>> SLS GetLogs (env=$ENV logstore=$LOGSTORE query=$QUERY line=$LINE from=$FROM to=$TO)"
    sls_call "$PROJECT" GET "$resource"
    ;;

  count)
    LOGSTORE="${1:?need logstore}"; QUERY="${2:-*}"
    FROM="${3:-$(($(now_s)-600))}"; TO="${4:-$(now_s)}"
    QE=$(urlenc_sls "$QUERY"); LE=$(urlenc_sls "$LOGSTORE")
    resource="/logstores/${LE}?from=${FROM}&query=${QE}&to=${TO}&type=histogram"
    echo ">>> SLS GetHistograms (env=$ENV logstore=$LOGSTORE query=$QUERY from=$FROM to=$TO)"
    sls_call "$PROJECT" GET "$resource" \
      | python3 -c '
import sys, json
raw = sys.stdin.read()
try:
    d = json.loads(raw)
except Exception:
    print(raw[:500]); sys.exit()
if isinstance(d, list):
    total = sum(h.get("count", 0) for h in d)
    print("总条数: %d" % total)
    # 给出有流量的时间片分布(最多5个)
    busy = [h for h in d if h.get("count", 0) > 0]
    for h in busy[:5]:
        print("  %s -> %s : %d" % (h.get("from"), h.get("to"), h.get("count")))
    print("(共 %d 个时间片有流量)" % len(busy))
else:
    print(json.dumps(d, ensure_ascii=False)[:500])
'
    ;;

  *) fail "未知动作: $ACTION (支持 list/logs/count)";;
esac
