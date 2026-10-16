#!/usr/bin/env bash
# _common.sh — Jenkins + 云效 认证 + curl 封装（cwork-deploy 共享）

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# 使用 curl 完整路径，避免 source 时 PATH 问题
CURL="${CURL:-$(which curl 2>/dev/null || echo /usr/bin/curl)}"

# ── 加载凭证 ──
load_config() {
  local cfg="$SCRIPT_DIR/.config.local.sh"
  if [[ -f "$cfg" ]]; then
    # shellcheck source=/dev/null
    source "$cfg"
  fi

  # CWORK_HOME 回源仓库读凭证（IDE 安装场景）
  if [[ -z "${JENKINS_USER:-}" || -z "${JENKINS_PASS:-}" ]] && [[ -n "${CWORK_HOME:-}" ]]; then
    local src_cfg="$CWORK_HOME/skills/deploy/scripts/.config.local.sh"
    if [[ -f "$src_cfg" ]]; then
      # shellcheck source=/dev/null
      source "$src_cfg"
    fi
  fi

  # 凭证检查延迟到实际调用时（jenkins_ensure_config / yx_ensure_config）
}

# ============================================================
# Jenkins REST API 封装（基本认证）
# ============================================================

# ── 确保 Jenkins 凭证就绪 ──
jenkins_ensure_config() {
  if [[ -z "${JENKINS_USER:-}" || -z "${JENKINS_PASS:-}" ]]; then
    echo "错误: Jenkins 凭证未配置" >&2
    echo "  cp $SCRIPT_DIR/config.example.sh $SCRIPT_DIR/.config.local.sh" >&2
    echo "  然后编辑 .config.local.sh 填入 JENKINS_USER / JENKINS_PASS" >&2
    exit 1
  fi
}

# ── Jenkins job 路径（支持文件夹作业，如 "测试环境/OMP"） ──
# "测试环境/OMP" → "/job/%E6%B5%8B%E8%AF%95%E7%8E%AF%E5%A2%83/job/OMP"；"order-server" → "/job/order-server"
jenkins_job_path() {
  local jobName="$1"
  python3 -c "
import urllib.parse, sys
segs = sys.argv[1].split('/')
print(''.join('/job/' + urllib.parse.quote(seg, safe='') for seg in segs))
" "$jobName"
}

# ── Jenkins 基本认证参数 ──
jenkins_auth_args() {
  echo "-u ${JENKINS_USER}:${JENKINS_PASS}"
}

# ── 带鉴权的 Jenkins GET 请求 ──
# 用法: jenkins_get "/job/xxx/lastBuild/buildNumber"
jenkins_get() {
  jenkins_ensure_config
  local path="$1"
  shift
  local url="${JENKINS_URL:-http://172.16.98.169:18001}"
  url="${url%/}"

  $CURL -s -u "${JENKINS_USER}:${JENKINS_PASS}" "${url}${path}" "$@"
}

# ── 获取 Jenkins CSRF crumb（与 session cookie 绑定） ──
# Jenkins 开 CSRF 保护时 POST 必须带 crumb；crumb 与 session cookie 绑定，
# 单带 crumb 仍 403，必须同一会话先 GET crumbIssuer 存 cookie，POST 时同时带 crumb + cookie。
# 输出三行: crumbRequestField / crumb / cookie文件路径；失败 return 1（部分实例关闭 CSRF 时调用方可降级）
jenkins_crumb() {
  local url="${JENKINS_URL:-http://172.16.98.169:18001}"
  url="${url%/}"
  local cookie_file
  cookie_file=$(mktemp "${TMPDIR:-/tmp}/jenkins-crumb-cookie.XXXXXX")

  local crumb_json
  crumb_json=$($CURL -s -c "$cookie_file" -u "${JENKINS_USER}:${JENKINS_PASS}" \
    "${url}/crumbIssuer/api/json" 2>/dev/null || echo "")

  local crumb field
  crumb=$(echo "$crumb_json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('crumb',''))" 2>/dev/null || echo "")
  field=$(echo "$crumb_json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('crumbRequestField','Jenkins-Crumb'))" 2>/dev/null || echo "Jenkins-Crumb")

  if [[ -z "$crumb" ]]; then
    rm -f "$cookie_file"
    return 1
  fi

  echo "$field"
  echo "$crumb"
  echo "$cookie_file"
}

# ── 带鉴权 + CSRF crumb 的 Jenkins POST 请求 ──
# 用法: jenkins_post "/job/xxx/buildWithParameters" --data-urlencode "key=value"
# 自带 crumb + session cookie（解决 POST 403），检查 HTTP 状态码：非 2xx/3xx 输出错误到 stderr 并 return 1
jenkins_post() {
  jenkins_ensure_config
  local path="$1"
  shift
  local url="${JENKINS_URL:-http://172.16.98.169:18001}"
  url="${url%/}"

  local crumb_field="" crumb_val="" crumb_cookie=""
  local crumb_info
  if crumb_info=$(jenkins_crumb 2>/dev/null); then
    crumb_field=$(echo "$crumb_info" | sed -n '1p')
    crumb_val=$(echo "$crumb_info" | sed -n '2p')
    crumb_cookie=$(echo "$crumb_info" | sed -n '3p')
  fi

  local crumb_args=()
  [[ -n "$crumb_field" && -n "$crumb_val" ]] && crumb_args+=(-H "${crumb_field}: ${crumb_val}")
  [[ -n "$crumb_cookie" && -f "$crumb_cookie" ]] && crumb_args+=(-b "$crumb_cookie")

  local raw http_code body
  raw=$($CURL -s -w $'\n%{http_code}' -u "${JENKINS_USER}:${JENKINS_PASS}" -X POST \
    "${crumb_args[@]}" "$@" "${url}${path}" 2>/dev/null)
  http_code=$(echo "$raw" | tail -n1)
  body=$(echo "$raw" | sed '$d')

  [[ -n "$crumb_cookie" ]] && rm -f "$crumb_cookie"

  if [[ "$http_code" =~ ^2 || "$http_code" =~ ^3 ]]; then
    echo "$body"
    return 0
  fi

  echo "Jenkins POST 失败: HTTP ${http_code} → ${url}${path}" >&2
  [[ -n "$body" ]] && echo "$body" | head -5 >&2
  return 1
}

# ============================================================
# 云效 AppStack OpenAPI 封装（x-yunxiao-token 认证）
# ============================================================

# ── 确保云效凭证就绪 ──
yx_ensure_config() {
  if [[ -z "${YX_TOKEN:-}" || -z "${YX_ORG_ID:-}" ]]; then
    echo "错误: 云效凭证未配置" >&2
    echo "  cp $SCRIPT_DIR/config.example.sh $SCRIPT_DIR/.config.local.sh" >&2
    echo "  然后编辑 .config.local.sh 填入 YX_TOKEN / YX_ORG_ID / YX_DOMAIN" >&2
    exit 1
  fi
}

# ── 云效 API base URL ──
# 输出: https://{domain}/oapi/v1/appstack/organizations/{orgId}
yx_base_url() {
  local domain="${YX_DOMAIN:-openapi-rdc.aliyuncs.com}"
  local orgId="${YX_ORG_ID:-}"
  echo "https://${domain}/oapi/v1/appstack/organizations/${orgId}"
}

# ── 云效 GET 请求 ──
# 用法: yx_get "/apps:search?name=order"
yx_get() {
  yx_ensure_config
  local path="$1"
  shift
  $CURL -s -H "x-yunxiao-token: ${YX_TOKEN}" "$(yx_base_url)${path}" "$@"
}

# ── 云效 POST 请求 ──
# 用法: yx_post "/apps/order-server/releaseWorkflows/xxx/releaseStages/yyy:execute" -d '{"params":{"sourceId":"master"}}'
yx_post() {
  yx_ensure_config
  local path="$1"
  shift
  $CURL -s -X POST -H "x-yunxiao-token: ${YX_TOKEN}" \
    -H "Content-Type: application/json" \
    "$(yx_base_url)${path}" "$@"
}

# ============================================================
# 平台路由（jenkins / yunxiao）
# ============================================================

# ── 获取服务的部署平台 ──
# 优先级: service-map.json 的 platform 字段 > DEPLOY_DEFAULT_PLATFORM 环境变量 > yunxiao
# 用法: get_platform <serviceNameJson>
get_platform() {
  local svcJson="$1"
  local platform
  platform=$(echo "$svcJson" | python3 -c "
import json, sys, os
s = json.load(sys.stdin)
p = s.get('platform', '')
if p:
    print(p)
else:
    print(os.environ.get('DEPLOY_DEFAULT_PLATFORM', 'yunxiao'))
" 2>/dev/null || echo "yunxiao")
  echo "$platform"
}

# ============================================================
# 服务映射（service-map.json）
# ============================================================

# ── 加载服务映射 ──
load_service_map() {
  local map="$SCRIPT_DIR/service-map.json"
  if [[ ! -f "$map" ]] && [[ -n "${CWORK_HOME:-}" ]]; then
    map="$CWORK_HOME/skills/deploy/scripts/service-map.json"
  fi
  if [[ ! -f "$map" ]]; then
    echo "错误: 服务映射文件不存在: $map" >&2
    exit 1
  fi
  SERVICE_MAP_PATH="$map"
}

# ── 从映射中查找服务 ──
lookup_service() {
  local appName="$1"
  load_service_map
  python3 -c "
import json, sys
with open('$SERVICE_MAP_PATH') as f:
    data = json.load(f)
for s in data.get('services', []):
    if s.get('appName') == '$appName':
        print(json.dumps(s, ensure_ascii=False))
        sys.exit(0)
print('NOT_FOUND', file=sys.stderr)
sys.exit(1)
" 2>/dev/null
}

# ── 获取 swimDeploy 值 ──
lookup_swim() {
  local env="$1"
  load_service_map
  python3 -c "
import json
with open('$SERVICE_MAP_PATH') as f:
    data = json.load(f)
swim = data.get('swimDeploy', {}).get('$env', '')
print(swim)
"
}

# ── 列出所有服务名（含平台标识） ──
list_service_names() {
  load_service_map
  python3 -c "
import json
with open('$SERVICE_MAP_PATH') as f:
    data = json.load(f)
for s in data.get('services', []):
    name = s.get('appName', '')
    ej = s.get('executeJob', {})
    yx = s.get('yxDeploy', {})
    bj = s.get('buildJob', {})
    bj_keys = list(bj.keys()) if isinstance(bj, dict) else []
    envs = ','.join(sorted(set(list(ej.keys()) + list(yx.keys()) + bj_keys)))
    if s.get('singleJob'):
        envs = (envs + ',' if envs else '') + 'single'
    platform = s.get('platform', '-')
    print(f'{name}  [{envs}]  platform={platform}')
"
}
