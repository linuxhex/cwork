#!/usr/bin/env bash
set -euo pipefail

# 查询单条调用链详情: span 调用树(回答"上下游是什么服务 + 耗时点在哪")
# 用法: arms_trace.sh <pid> <traceId> [ts_ms]
#   ts_ms 是 trace 产生时刻(毫秒), 用来定位存储分片; 缺省则不带时间(可能失败)
#   通常从 arms_traces 的输出或 SearchTraces 拿到 traceId + Timestamp 后调用

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_common.sh
source "$SCRIPT_DIR/_common.sh"
load_credentials

PID="${1:?用法: arms_trace.sh <pid> <traceId> [ts_ms]}"
TID="${2:?need traceId}"
TS="${3:-}"
REGION="${ARMS_REGION:-cn-hangzhou}"

TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT

if [[ -n "$TS" ]]; then
  ST=$((TS - 600000)); ET=$((TS + 600000))
  arms_call GetTrace RegionId="$REGION" TraceID="$TID" StartTime="$ST" EndTime="$ET" > "$TMP" 2>/dev/null || true
else
  arms_call GetTrace RegionId="$REGION" TraceID="$TID" > "$TMP" 2>/dev/null || true
fi

python3 - "$TMP" <<'PY'
import sys, json, re
raw = open(sys.argv[1]).read()
m = re.search(r"\{.*", raw, re.S)
if not m:
    print("GetTrace 无有效响应(网络失败/缺 ts_ms), 原始: %s" % raw[:200]); sys.exit()
d = json.loads(m.group(0))
if d.get("Code") not in (None, 200, "200"):
    print("GetTrace 失败: Code=%s %s" % (d.get("Code"), d.get("Message")))
    print("(提示: 需要 trace 产生时刻 ts_ms 来定位数据, 传第3个参数)"); sys.exit()
spans = d.get("Spans") or []
if not spans:
    print("无 span 数据"); sys.exit()

RPCTYPE = {0:"Local",9:"HTTP",11:"HTTP-Srv",12:"Spring",13:"Redis",14:"SQL",
           20:"Dubbo",23:"Kafka",30:"RPC",33:"Async",40:"MQ"}
byparent, ids = {}, set()
for s in spans:
    sid = s.get("SpanId") or ""
    ids.add(sid)
    byparent.setdefault(s.get("ParentSpanId") or "", []).append(s)
def tags(s): return {t.get("Key"): t.get("Value") for t in (s.get("TagEntryList") or [])}
def kind(s):
    tg = tags(s)
    return tg.get("call.kind") or RPCTYPE.get(s.get("RpcType"), "rpc"+str(s.get("RpcType","")))
# 找耗时最长的 span(耗时点)
top = max(spans, key=lambda x: x.get("Duration", 0))

print("===== 调用链 span 树 (共 %d 个节点) =====" % len(spans))
printed = set()
def walk(parent, depth):
    for s in sorted(byparent.get(parent, []), key=lambda x: (x.get("Timestamp",0), x.get("Duration",0))):
        sid = s.get("SpanId") or ""
        if sid in printed: continue
        printed.add(sid)
        dur = s.get("Duration", 0)
        tg = tags(s)
        err = "  <ERROR>" if (tg.get("otel.status_code")=="ERROR" or str(tg.get("error")).lower() in ("true","1")) else ""
        extra = []
        for k in ("messaging.destination","db.statement","endpoint","server.address","url"):
            if k in tg: extra.append("%s=%s" % (k.split(".")[-1], str(tg[k])[:30]))
        mark = "  <<< 耗时点" if s is top and dur > 50 else ""
        print("  "*depth + "[%6sms] %-22s %-32s [%s]%s%s%s" % (
            dur, (s.get("ServiceName","?") or "")[:22], (s.get("OperationName","?") or "")[:32],
            kind(s), err, ("  "+", ".join(extra) if extra else ""), mark))
        walk(sid, depth+1)
roots = [s for s in spans if (s.get("ParentSpanId") or "") not in ids]
if not roots: roots = [s for s in spans if not s.get("ParentSpanId")] or [spans[0]]
for r in roots: walk(r.get("SpanId") or "", 0)

# 汇总上下游
svcs = {}
for s in spans:
    sv = s.get("ServiceName","?")
    svcs[sv] = svcs.get(sv, 0) + 1
print("\n涉及服务(上下游): " + ", ".join("%s(%d)" % (k,v) for k,v in sorted(svcs.items(), key=lambda x:-x[1])))
print("最慢 span: %s/%s = %dms" % (top.get("ServiceName"), top.get("OperationName"), top.get("Duration",0)))
PY
echo "ARMS_TRACE_DONE"
