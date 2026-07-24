#!/usr/bin/env bash
set -euo pipefail

# 查询接口性能: 调用次数/平均耗时/P99/QPS/错误率(回答"接口有没有流量 + P99 + 平均耗时")
# 用法: arms_traces.sh <pid> [分钟] [接口关键字]
#   数据源: appstat.incall(精确 rt/count/qps/errorrate) + SearchTraces(聚合 P99)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_common.sh
source "$SCRIPT_DIR/_common.sh"
load_credentials

PID="${1:?用法: arms_traces.sh <pid> [分钟] [接口关键字]}"
MINS="${2:-15}"
OP="${3:-}"
REGION="${ARMS_REGION:-cn-hangzhou}"

NOW=$(now_ms); FROM=$((NOW - 10#$MINS*60*1000))
TMPM="$(mktemp)"; TMPT="$(mktemp)"
trap 'rm -f "$TMPM" "$TMPT"' EXIT

# 1. appstat.incall: 精确 rt/count/qps/errorrate(按 rpc 接口维度)
# 2. SearchTraces: 取 trace 用于聚合 P99(每批最多100条)
# 两次调用相互独立, 并行发起省一次往返; 各写独立 temp 文件无竞争
arms_call QueryMetricByPage RegionId="$REGION" \
  StartTime="$FROM" EndTime="$NOW" IntervalInSec=60000 \
  Metric=appstat.incall \
  Measures.1=rt Measures.2=count Measures.3=qps Measures.4=errorrate \
  Dimensions.1=rpc \
  Filters.1.Key=pid Filters.1.Value="$PID" \
  Filters.2.Key=regionId Filters.2.Value="$REGION" > "$TMPM" 2>/dev/null &
arms_call SearchTraces RegionId="$REGION" Pid="$PID" \
  StartTime="$FROM" EndTime="$NOW" Reverse=true > "$TMPT" 2>/dev/null &
wait || true   # 任一失败也容忍(下游 python 已处理空响应并显式报错)

python3 - "$TMPM" "$TMPT" "$MINS" "$PID" "$OP" <<'PY'
import sys, json, re
def load(path):
    try:
        raw = open(path).read()
        m = re.search(r"\{.*", raw, re.S)
        return json.loads(m.group(0)) if m else {}
    except Exception:
        return {}
md = load(sys.argv[1]); td = load(sys.argv[2])
mins, pid, op = sys.argv[3], sys.argv[4], sys.argv[5]
# 校验 ARMS 响应: 鉴权失败/网络错误不被误报为"无流量"
for _name, _d in (("appstat.incall", md), ("SearchTraces", td)):
    _code = _d.get("Code")
    if _code not in (None, 200, "200"):
        print(">>> %s 调用失败: Code=%s %s" % (_name, _code, _d.get("Message", "")))
        print(">>> (鉴权/权限失败已显式报错, 不会误报为无流量; 请检查 AK 权限)")
        sys.exit()
if not md:
    print(">>> appstat.incall 无有效响应(网络失败?)"); sys.exit()

# appstat.incall 按 rpc 聚合(多个时间片汇总)
agg = {}
for it in (md.get("Data", {}).get("Items") or []):
    rpc = it.get("rpc", "")
    if not rpc: continue
    a = agg.setdefault(rpc, {"count": 0.0, "rt_sum": 0.0, "rt_n": 0.0, "qps_sum": 0.0, "err_sum": 0.0})
    c = float(it.get("count") or 0)
    a["count"] += c
    if c > 0:
        a["rt_sum"] += float(it.get("rt") or 0) * c
        a["rt_n"] += c
    a["qps_sum"] += float(it.get("qps") or 0)
    a["err_sum"] += float(it.get("errorrate") or 0)

# SearchTraces 聚合每个接口的耗时分布(算 P99/P95/avg)
dur = {}
for t in (td.get("TraceInfos") or []):
    o = t.get("OperationName", "")
    if not o: continue
    dur.setdefault(o, []).append(int(t.get("Duration") or 0))
def pct(lst, p):
    if not lst: return None
    lst = sorted(lst); k = max(0, int(len(lst) * p) - 1)
    return lst[k]

print(">>> 接口性能 (最近 %s 分钟, pid=%s)" % (mins, pid))
print("%-42s %8s %8s %8s %8s %8s" % ("接口", "调用次数", "平均ms", "P99ms", "QPS", "错误率%"))
rows = []
for rpc, a in agg.items():
    if op and op.lower() not in rpc.lower(): continue
    avg = a["rt_sum"] / a["rt_n"] if a["rt_n"] else 0
    rows.append((rpc, a["count"], avg, pct(dur.get(rpc, []), 0.99), a["qps_sum"], a["err_sum"]))
rows.sort(key=lambda x: -x[1])
if not rows:
    print("(未取到接口指标, 可能: 该 pid 最近无流量 / appstat.incall 无权限 / 指标未上报)")
for rpc, c, avg, p99, qps, err in rows[:25]:
    ps = "%d" % p99 if p99 is not None else "n/a"
    print("%-42s %8.0f %8.1f %8s %8.3f %8.2f" % (rpc[:42], c, avg, ps, qps, err))
# 整体调用链耗时分位(SearchTraces 的 trace 总耗时, 作为慢度参考)
all_d = sorted([int(t.get("Duration") or 0) for t in (td.get("TraceInfos") or [])])
if all_d:
    print("\n整体调用链耗时分位(最近%d条trace): avg=%dms  P50=%dms  P95=%dms  P99=%dms  max=%dms" % (
        len(all_d), sum(all_d)//len(all_d), pct(all_d,0.5), pct(all_d,0.95), pct(all_d,0.99), all_d[-1]))
print("(平均/QPS/错误率来自 appstat.incall 精确值; 每接口P99需接口名与trace OperationName 对齐, 未对齐显示 n/a)")
PY
echo "ARMS_TRACES_DONE"
