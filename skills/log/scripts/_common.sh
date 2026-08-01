#!/usr/bin/env bash
# =============================================================================
# cwork-log 共用模块: 阿里云密钥加载 + SLS(ROA签名) / ARMS(RPC签名) 调用封装
# 仅供其他脚本 source:  source "$SCRIPT_DIR/_common.sh"
#
# 配置来源(优先级, 高 -> 低):
#   1. 环境变量(同名): ALIBABA_CLOUD_ACCESS_KEY_ID/SECRET, SLS_ENDPOINT,
#      SLS_PROJECT_TEST/UAT/PROD, ARMS_REGION
#   2. 同目录 .config.local.sh(本工程内, 已 gitignore, 复制自 config.example.sh)
#   缺失则 fail 提示配置方法
# =============================================================================

# 本地配置(基于本文件位置定位, 与调用者工作目录无关)
# .config.local.sh 内用 ${VAR:=值} 语法: 环境变量同名时优先, 否则用配置值
_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.config.local.sh
[ -f "$_COMMON_DIR/.config.local.sh" ] && source "$_COMMON_DIR/.config.local.sh"

fail() { echo "ERROR: $*" >&2; exit 1; }
require_cmd() { command -v "$1" >/dev/null 2>&1 || fail "缺少命令: $1 (请先安装)"; }

load_credentials() {
  AK_ID="${ALIBABA_CLOUD_ACCESS_KEY_ID:-}"
  AK_SECRET="${ALIBABA_CLOUD_ACCESS_KEY_SECRET:-}"
  [[ -n "$AK_ID" && -n "$AK_SECRET" ]] || \
    fail "未配置阿里云密钥: 请执行 cp scripts/config.example.sh scripts/.config.local.sh 并填入 AK/SK, 或 export ALIBABA_CLOUD_ACCESS_KEY_ID / ALIBABA_CLOUD_ACCESS_KEY_SECRET"
}

get_sls_endpoint() { echo "${SLS_ENDPOINT:-cn-hangzhou.log.aliyuncs.com}"; }

get_sls_project() {  # $1=环境 test/uat/prod, 或直接传 project 名
  local env="${1:-prod}" v=""
  case "$env" in
    test) v="${SLS_PROJECT_TEST:-}" ;;
    uat)  v="${SLS_PROJECT_UAT:-}" ;;
    prod) v="${SLS_PROJECT_PROD:-}" ;;
    *)    v="$env" ;;
  esac
  [[ -n "$v" ]] || fail "未配置环境 [$env] 的 SLS project: 请在 scripts/.config.local.sh 设置 SLS_PROJECT_$(echo "$env" | tr '[:lower:]' '[:upper:]')"
  echo "$v"
}

# ---- SLS ROA 签名 ----
# 用法: sls_call <project> <GET|POST> <resource含query>
#   resource 中的 query 值应为 URL 编码后的值（curl 发请求用）
#   签名时自动将 query 值解码回原始值（SLS ROA 签名规范：签名用未编码的 resource）
sls_call() {
  require_cmd python3; require_cmd curl
  load_credentials
  local project="$1" verb="$2" resource="$3"
  local endpoint; endpoint=$(get_sls_endpoint)
  local date; date=$(LC_ALL=C TZ=GMT date '+%a, %d %b %Y %H:%M:%S GMT')
  # AK 经环境变量传给 python(避免出现在 ps 的 argv); 签名也由 python 计算
  # 签名时：resource 中的 URL 编码值解码回原始值（SLS ROA 签名要求用未编码的 resource）
  local auth
  auth=$(AK_ID="$AK_ID" AK_SECRET="$AK_SECRET" python3 - "$verb" "$date" "$resource" <<'PY'
import sys, os, hmac, hashlib, base64, urllib.parse
ak_id, ak_secret = os.environ['AK_ID'], os.environ['AK_SECRET']
verb, date, resource = sys.argv[1:4]
# SLS ROA 签名规范：签名用未编码的 resource（将 URL 编码的 query 值解码回原始值）
# 只解码 query 值，不解码 query key 和路径
if '?' in resource:
    path, query = resource.split('?', 1)
    pairs = []
    for part in query.split('&'):
        k, _, v = part.partition('=')
        pairs.append(k + '=' + urllib.parse.unquote_plus(v) if _ else part)
    resource_for_sign = path + '?' + '&'.join(pairs)
else:
    resource_for_sign = resource
sts = "%s\n\n\n%s\nx-log-apiversion:0.6.0\nx-log-signaturemethod:hmac-sha1\n%s" % (verb, date, resource_for_sign)
sig = base64.b64encode(hmac.new(ak_secret.encode(), sts.encode(), hashlib.sha1).digest()).decode()
print("LOG %s:%s" % (ak_id, sig))
PY
)
  curl -s --connect-timeout 5 --max-time 30 -X "$verb" \
    -H "Host: ${project}.${endpoint}" \
    -H "Date: ${date}" \
    -H "x-log-apiversion: 0.6.0" \
    -H "x-log-signaturemethod: hmac-sha1" \
    -H "Authorization: ${auth}" \
    "https://${project}.${endpoint}${resource}"
}

# Java URLEncoder 兼容编码(SLS query 值用: 字母数字/_.-* 不编码, 空格变+)
urlenc_sls() {
  python3 -c 'import sys,urllib.parse as u;print(u.quote_plus(sys.argv[1],safe="*"))' "$1"
}

# ---- ARMS RPC 签名(SignatureV1) ----
# 用法: arms_call <Action> [key=value ...]
# endpoint region 取自 ARMS_REGION(脚本侧应设置); RegionId 作为 API 参数随 key=value 传
arms_call() {
  require_cmd python3; require_cmd curl
  load_credentials
  local action="$1"; shift
  local region="${ARMS_REGION:-cn-hangzhou}"
  local endpoint="arms.${region}.aliyuncs.com"
  local query
  query=$(AK_ID="$AK_ID" AK_SECRET="$AK_SECRET" python3 - "$region" "$action" "$@" <<'PY'
import sys, os, hmac, hashlib, base64, urllib.parse, datetime, random
ak_id, ak_secret = os.environ['AK_ID'], os.environ['AK_SECRET']
region, action = sys.argv[1:3]
params = {
    'Format':'JSON','Version':'2019-08-08','AccessKeyId':ak_id,
    'SignatureMethod':'HMAC-SHA1','SignatureVersion':'1.0',
    'Timestamp': datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    'SignatureNonce':''.join(random.choices('0123456789abcdefghijklmnopqrstuvwxyz', k=16)),
    'RegionId':region, 'Action':action,
}
for kv in sys.argv[3:]:
    k, _, v = kv.partition('='); params[k] = v
pe = lambda s: urllib.parse.quote(str(s), safe='-_.~')
canon = '&'.join(f'{pe(k)}={pe(params[k])}' for k in sorted(params))
sts = 'GET&' + pe('/') + '&' + pe(canon)
sig = base64.b64encode(hmac.new((ak_secret + '&').encode(), sts.encode(), hashlib.sha1).digest()).decode()
print(canon + '&Signature=' + pe(sig))
PY
)
  curl -s --connect-timeout 5 --max-time 30 "https://${endpoint}/?${query}"
}

# 取当前毫秒时间戳(macOS date 不支持 %N, 用 python3)
now_ms() { python3 -c 'import time; print(int(time.time()*1000))'; }
now_s() { date +%s; }
