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

# ── 带鉴权的 Jenkins POST 请求 ──
# 用法: jenkins_post "/job/xxx/buildWithParameters" -d "key=value"
jenkins_post() {
  jenkins_ensure_config
  local path="$1"
  shift
  local url="${JENKINS_URL:-http://172.16.98.169:18001}"
  url="${url%/}"

  $CURL -s -u "${JENKINS_USER}:${JENKINS_PASS}" -X POST "${url}${path}" "$@"
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
# 优先级: service-map.json 的 platform 字段 > DEPLOY_DEFAULT_PLATFORM 环境变量 > jenkins
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
    print(os.environ.get('DEPLOY_DEFAULT_PLATFORM', 'jenkins'))
" 2>/dev/null || echo "jenkins")
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
    envs = ','.join(sorted(ej.keys()))
    platform = s.get('platform', '-')
    print(f'{name}  [{envs}]  platform={platform}')
"
}
