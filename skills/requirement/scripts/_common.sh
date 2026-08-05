#!/usr/bin/env bash
# =============================================================================
# cwork-requirement 共用模块: 阿里云密钥加载 + 云效 DevOps ROA 签名调用封装
# 仅供其他脚本 source:  source "$SCRIPT_DIR/_common.sh"
#
# 配置来源(优先级, 高 -> 低):
#   1. 环境变量(同名): ALIBABA_CLOUD_ACCESS_KEY_ID/SECRET,
#      YUNXIAO_ORG_ID, YUNXIAO_PROJECT_ID, YUNXIAO_REGION,
#      YUNXIAO_PLANNED_RELEASE_TIME_FIELD_ID, YUNXIAO_PLANNED_TEST_TIME_FIELD_ID
#   2. 同目录 .config.local.sh(本工程内, 已 gitignore, 复制自 config.example.sh)
#      缺失则 fail 提示配置方法
#
# 绝对只读: devops_call 只封装 GET, 代码结构上不存在任何写路径(POST/PUT/DELETE)。
#
# 签名算法: 阿里云 ROA V2 签名(与 SLS ROA 签名类似但头部不同)
#   StringToSign = HTTPMethod\n Accept\n ContentMD5\n ContentType\n Date\n
#                  CanonicalizedHeaders(x-acs-* 排序 key:value\n)
#                  CanonicalizedResource(URI?sortedQueryString)
#   Signature = Base64(HMAC-SHA1(SK, StringToSign))
#   Authorization = "acs <AK_ID>:<Signature>"
# =============================================================================

# 本地配置(基于本文件位置定位, 与调用者工作目录无关)
_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.config.local.sh
[ -f "$_COMMON_DIR/.config.local.sh" ] && source "$_COMMON_DIR/.config.local.sh"

fail() { echo "ERROR: $*" >&2; exit 1; }
require_cmd() { command -v "$1" >/dev/null 2>&1 || fail "缺少命令: $1 (请先安装)"; }

# ---- source 时立即校验凭证 ----
AK_ID="${ALIBABA_CLOUD_ACCESS_KEY_ID:-}"
AK_SECRET="${ALIBABA_CLOUD_ACCESS_KEY_SECRET:-}"
[[ -n "$AK_ID" && -n "$AK_SECRET" ]] || \
  fail "未配置阿里云密钥: 请执行 cp scripts/config.example.sh scripts/.config.local.sh 并填入 AK/SK, 或 export ALIBABA_CLOUD_ACCESS_KEY_ID / ALIBABA_CLOUD_ACCESS_KEY_SECRET"

YUNXIAO_ORG="${YUNXIAO_ORG_ID:-}"
[[ -n "$YUNXIAO_ORG" ]] || \
  fail "未配置云效组织ID: 请在 scripts/.config.local.sh 设置 YUNXIAO_ORG_ID, 或 export YUNXIAO_ORG_ID"

YUNXIAO_PROJECT="${YUNXIAO_PROJECT_ID:-}"

get_region() { echo "${YUNXIAO_REGION:-cn-hangzhou}"; }
get_org_id() { echo "$YUNXIAO_ORG"; }
get_project_id() {
  [[ -n "$YUNXIAO_PROJECT" ]] || \
    fail "未配置云效项目ID: 请在 scripts/.config.local.sh 设置 YUNXIAO_PROJECT_ID, 或 export YUNXIAO_PROJECT_ID"
  echo "$YUNXIAO_PROJECT"
}
get_release_time_field_id() { echo "${YUNXIAO_PLANNED_RELEASE_TIME_FIELD_ID:-}"; }
get_test_time_field_id() { echo "${YUNXIAO_PLANNED_TEST_TIME_FIELD_ID:-}"; }

# ---- 云效 DevOps ROA V2 签名 ----
# 用法: devops_call <path> [query_key=value ...]
#   path: API 路径, 如 /organization/{orgId}/listWorkitems
#   query: 查询参数, 自动拼接到 URL 并参与签名
#   只封装 GET, 绝对只读
devops_call() {
  require_cmd python3; require_cmd curl
  local api_path="$1"; shift
  local region; region=$(get_region)
  local endpoint="devops.${region}.aliyuncs.com"

  # python 算签名 + 编码 query(AK/SK 经环境变量传入, 不出现在 ps argv)
  local signed
  signed=$(AK_ID="$AK_ID" AK_SECRET="$AK_SECRET" python3 - "$endpoint" "$api_path" "$@" <<'PY'
import sys, os, hmac, hashlib, base64, urllib.parse, datetime, uuid

ak_id = os.environ['AK_ID']
ak_secret = os.environ['AK_SECRET']
endpoint = sys.argv[1]
api_path = sys.argv[2]

# 构建查询参数(已 URL 编码)
query_params = {}
for kv in sys.argv[3:]:
    k, _, v = kv.partition('=')
    if v:
        query_params[k] = v

# 规范化查询字符串(按 key 排序, 签名用原始值不编码)
if query_params:
    sorted_keys = sorted(query_params.keys())
    # 签名用: 原始值, 不编码
    canonical_query = '&'.join(f'{k}={query_params[k]}' for k in sorted_keys)
    # 发送用: URL 编码
    full_query = '&'.join(
        f'{urllib.parse.quote(k, safe="")}={urllib.parse.quote(query_params[k], safe="-_.~")}'
        for k in sorted_keys
    )
    canonical_resource = f'{api_path}?{canonical_query}'
else:
    canonical_resource = api_path
    full_query = ''

# 时间戳(GMT 格式)
date = datetime.datetime.now(datetime.timezone.utc).strftime('%a, %d %b %Y %H:%M:%S GMT')
nonce = str(uuid.uuid4())

# x-acs-* 头部(按 key 排序, 不含 x-acs-signature-version)
acs_headers = {
    'x-acs-signature-method': 'HMAC-SHA1',
    'x-acs-signature-nonce': nonce,
    'x-acs-version': '2021-06-25',
}
canonical_headers = ''.join(f'{k}:{v}\n' for k, v in sorted(acs_headers.items()))

# StringToSign
string_to_sign = (
    f'GET\n'
    f'application/json\n'    # Accept
    f'\n'                     # Content-MD5 (空)
    f'\n'                     # Content-Type (空)
    f'{date}\n'
    f'{canonical_headers}'
    f'{canonical_resource}'
)

# 签名
sig = base64.b64encode(
    hmac.new(ak_secret.encode('utf-8'), string_to_sign.encode('utf-8'), hashlib.sha1).digest()
).decode('utf-8')

authorization = f'acs {ak_id}:{sig}'

# 输出: date\tnonce\tauthorization\tversion\tquery
print(f'{date}\t{nonce}\t{authorization}\t{acs_headers["x-acs-version"]}\t{full_query}')
PY
)

  local date nonce authorization version query
  date=$(printf '%s' "$signed" | cut -f1)
  nonce=$(printf '%s' "$signed" | cut -f2)
  authorization=$(printf '%s' "$signed" | cut -f3)
  version=$(printf '%s' "$signed" | cut -f4)
  query=$(printf '%s' "$signed" | cut -f5)

  local url="https://${endpoint}${api_path}"
  [[ -n "$query" ]] && url="${url}?${query}"

  curl -s --connect-timeout 10 --max-time 60 \
    -H "Accept: application/json" \
    -H "Date: ${date}" \
    -H "Host: ${endpoint}" \
    -H "x-acs-signature-nonce: ${nonce}" \
    -H "x-acs-version: ${version}" \
    -H "x-acs-signature-method: HMAC-SHA1" \
    -H "Authorization: ${authorization}" \
    "${url}"
}
