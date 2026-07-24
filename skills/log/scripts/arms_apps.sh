#!/usr/bin/env bash
set -euo pipefail

# 列出 ARMS 应用并拿到 pid(对话式阶段2用于确认目标服务)
# 用法: arms_apps.sh [region] [名称关键字]
#   region 缺省=cn-hangzhou(或环境变量 ARMS_REGION); 关键字缺省=列全部

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_common.sh
source "$SCRIPT_DIR/_common.sh"
load_credentials   # 密钥缺失立即 fail(避免被下游 2>/dev/null 吞掉)

REGION="${1:-${ARMS_REGION:-cn-hangzhou}}"
ARMS_REGION="$REGION"   # 让命令行传入的 region 同时作用于 endpoint 网关(arms_call 读 ARMS_REGION)
KEYWORD="${2:-}"

TMPJSON="$(mktemp)"
trap 'rm -f "$TMPJSON"' EXIT

echo ">>> ARMS ListTraceApps (region=$REGION${KEYWORD:+, 过滤: $KEYWORD})"
arms_call ListTraceApps RegionId="$REGION" > "$TMPJSON" 2>/dev/null || true
python3 - "$TMPJSON" "$KEYWORD" <<'PY'
import sys, json, re
raw = open(sys.argv[1]).read() if sys.argv[1] else ""
kw = sys.argv[2] if len(sys.argv) > 2 else ""
m = re.search(r"\{.*", raw, re.S)
if not m:
    print("调用失败: 无有效响应(网络/鉴权失败), 原始输出: %s" % raw[:200]); sys.exit()
d = json.loads(m.group(0))
code = d.get("Code")
if code not in (None, 200, "200"):
    print("调用失败: Code=%s %s" % (code, d.get("Message", ""))); sys.exit()
apps = d.get("TraceApps") or []
if kw:
    apps = [a for a in apps if kw.lower() in str(a.get("AppName","")).lower()]
print("共 %d 个应用:" % len(apps))
for a in sorted(apps, key=lambda x: x.get("AppName","")):
    print("  %-28s pid=%-32s appId=%s  type=%s" % (
        str(a.get("AppName","?"))[:28], a.get("Pid","?"), a.get("AppId","?"), a.get("Type","?")))
PY
echo "ARMS_APPS_DONE"
