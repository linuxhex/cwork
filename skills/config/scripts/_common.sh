#!/usr/bin/env bash
# =============================================================================
# cwork-config 共用模块: 凭证加载 + Nacos Spas 签名 + 只读 GET 调用封装
# 仅供其他脚本 source:  source "$SCRIPT_DIR/_common.sh"
#
# 配置来源(优先级, 高 -> 低):
#   1. 环境变量(同名): NACOS_ADDR_<CLUSTER>/NACOS_AK_<CLUSTER>/NACOS_SK_<CLUSTER>
#      以及 NACOS_CONTEXT_PATH(默认 /nacos)
#   2. 同目录 .config.local.sh(本工程内, 已 gitignore, 复制自 config.example.sh)
#      缺失则 fail 提示配置方法
#
# ⚠️ 绝对只读: nacos_call 只封装 GET, 代码结构上不存在任何写路径(POST/PUT/DELETE)。
#    即使用户要求写 Nacos, 也拒绝——写操作走 devops 工程的受控写路径(带 JWT/审批)。
#
# Spas 签名算法: 精确复刻 nacos-client 1.4.1 的 SpasAdapter.getSignHeaders 字节码:
#   signData = (含 tenant 键 且 含 group 键) ? tenant+"+"+group
#            : (含 group 键 且 group 非空)   ? group
#            : ""
#   signature = signData 为空 ? base64(HmacSHA1(SK, ts))
#                             : base64(HmacSHA1(SK, signData+"+"+ts))
#   请求头: Spas-AccessKey=AK, Timestamp=ts(毫秒), Spas-Signature=signature
# =============================================================================

# 本地配置(基于本文件位置定位, 与调用者工作目录无关)
_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.config.local.sh
[ -f "$_COMMON_DIR/.config.local.sh" ] && source "$_COMMON_DIR/.config.local.sh"

fail() { echo "ERROR: $*" >&2; exit 1; }
require_cmd() { command -v "$1" >/dev/null 2>&1 || fail "缺少命令: $1 (请先安装)"; }

# env 简写 -> namespace(devops 工程命名空间枚举)
env_to_namespace() {
  case "$1" in
    dev)     echo "dev" ;;
    opendev) echo "opendev" ;;
    test)    echo "k8s-test" ;;
    uat)     echo "k8s-uat" ;;
    prod)    echo "k8s-prod" ;;
    *)       echo "$1" ;;   # 未知简写则当作 namespace 直传
  esac
}

# namespace -> 集群(k8s-prod 独立生产集群+独立凭证, 其余共用非生产)
namespace_to_cluster() {
  case "$1" in
    k8s-prod) echo "PROD" ;;
    *)        echo "NONPROD" ;;
  esac
}

# 加载集群凭证到 NACOS_ADDR/NACOS_AK/NACOS_SK(校验非空)
# 用 ${!var} 间接引用: cluster=NONPROD → 读 NACOS_ADDR_NONPROD 等
load_cluster_cred() {
  local cluster="$1"
  local addr_var="NACOS_ADDR_${cluster}" ak_var="NACOS_AK_${cluster}" sk_var="NACOS_SK_${cluster}"
  local addr="${!addr_var:-}" ak="${!ak_var:-}" sk="${!sk_var:-}"
  [[ -n "$addr" && -n "$ak" && -n "$sk" ]] || \
    fail "未配置集群 [$cluster] 的 Nacos 凭证: 请在 scripts/.config.local.sh 设置 NACOS_ADDR_${cluster}/NACOS_AK_${cluster}/NACOS_SK_${cluster} (复制自 config.example.sh, 凭证来自 devops 工程 NacosConfig.java)"
  NACOS_ADDR="$addr"; NACOS_AK="$ak"; NACOS_SK="$sk"
}

# 只读 GET 调用 Nacos OpenAPI(自带 Spas 签名)
# 用法: nacos_call <namespace> <api_path> [key=value ...]
#   namespace 仅用于选集群凭证; 是否带 tenant 由调用方通过 key=value 决定
#   api_path 如 /v1/cs/configs ; params 自动 URL 编码; context path 取 NACOS_CONTEXT_PATH(默认 /nacos)
nacos_call() {
  require_cmd python3; require_cmd curl
  local namespace="$1" api="$2"; shift 2
  local cluster; cluster=$(namespace_to_cluster "$namespace")
  load_cluster_cred "$cluster"
  local ctx="${NACOS_CONTEXT_PATH:-/nacos}"

  # python 算签名 + 编码 query(AK/SK 经环境变量传入, 不出现在 ps argv)
  local signed
  signed=$(NACOS_AK="$NACOS_AK" NACOS_SK="$NACOS_SK" python3 - "$api" "$@" <<'PY'
import sys, os, hmac, hashlib, base64, urllib.parse, time
ak = os.environ['NACOS_AK']; sk = os.environ['NACOS_SK']
api = sys.argv[1]
params = {}
for kv in sys.argv[2:]:
    k, _, v = kv.partition('='); params[k] = v

# ---- SpasAdapter.getSignHeaders(Map) 精确复刻 ----
sign_data = ''
if 'tenant' in params and 'group' in params:
    sign_data = str(params.get('tenant') or '') + '+' + str(params.get('group') or '')
elif 'group' in params and str(params.get('group') or '').strip() != '':
    sign_data = str(params.get('group') or '')
# ---- getSignHeaders(String): isBlank 判断 ----
ts = str(int(time.time() * 1000))
to_sign = ts if sign_data.strip() == '' else (sign_data + '+' + ts)
sig = base64.b64encode(hmac.new(sk.encode('utf-8'), to_sign.encode('utf-8'), hashlib.sha1).digest()).decode('utf-8')

query = urllib.parse.urlencode(params, encoding='utf-8')
# 用 \t 分隔 query / ts / sig
print(query + '\t' + ts + '\t' + sig)
PY
)
  local query ts sig
  query=$(printf '%s' "$signed" | cut -f1)
  ts=$(printf '%s' "$signed" | cut -f2)
  sig=$(printf '%s' "$signed" | cut -f3)

  # 绝对只读: 只发 GET
  curl -s --connect-timeout 5 --max-time 30 \
    -H "Spas-AccessKey: ${NACOS_AK}" \
    -H "Timestamp: ${ts}" \
    -H "Spas-Signature: ${sig}" \
    "http://${NACOS_ADDR}${ctx}${api}?${query}"
}
