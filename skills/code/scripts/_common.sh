#!/usr/bin/env bash
# =============================================================================
# cwork-code 共用模块: GitLab API curl 封装 + codegraph 触发
# 仅供其他脚本 source:  source "$SCRIPT_DIR/_common.sh"
#
# 配置来源(优先级, 高 -> 低):
#   1. 环境变量(同名): GITLAB_URL, GITLAB_TOKEN, GITLAB_NAMESPACES,
#      CODE_WORKSPACE, CODEGRAPH_BIN, CODEGRAPH_PATH
#   2. 同目录 .config.local.sh(本工程内, 已 gitignore)
#      缺失则 fail 提示配置方法
#
# 绝对只读: gitlab_call 只封装 GET, 代码结构上不存在任何写路径。
# clone/pull 是本地操作，不通过 API 写远端。
# =============================================================================

_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$_COMMON_DIR/.config.local.sh" ] && source "$_COMMON_DIR/.config.local.sh"

fail() { echo "ERROR: $*" >&2; exit 1; }
require_cmd() { command -v "$1" >/dev/null 2>&1 || fail "缺少命令: $1 (请先安装)"; }

# ---- 配置校验 ----
GITLAB_URL="${GITLAB_URL:-}"
GITLAB_TOKEN="${GITLAB_TOKEN:-}"
[[ -n "$GITLAB_URL" ]] || fail "未配置 GITLAB_URL: 请 cp scripts/config.example.sh scripts/.config.local.sh 并填入 GitLab 地址"
[[ -n "$GITLAB_TOKEN" ]] || fail "未配置 GITLAB_TOKEN: 请在 scripts/.config.local.sh 填入 GitLab Private Token"
GITLAB_URL="${GITLAB_URL%/}"

CODE_WORKSPACE="${CODE_WORKSPACE:-/Users/caomunian/Work/code-projects}"
CODEGRAPH_PATH="${CODEGRAPH_PATH:-$CODE_WORKSPACE}"
CODEGRAPH_BIN="${CODEGRAPH_BIN:-}"

get_namespaces() { echo "${GITLAB_NAMESPACES:-omp,omp-device,zdl,center,omp-barrier,adp,mmp,omp-zdl,ctp}"; }

# ---- GitLab API GET 封装（绝对只读） ----
# 用法: gitlab_call <api_path> [query_key=value ...]
#   api_path: /api/v4/... 形式
#   自动带 PRIVATE-TOKEN header
gitlab_call() {
  require_cmd curl
  local api_path="$1"; shift
  local url="${GITLAB_URL}${api_path}"

  local query_args=()
  for kv in "$@"; do
    query_args+=("$kv")
  done

  if [[ ${#query_args[@]} -gt 0 ]]; then
    local query_str
    query_str=$(IFS='&'; echo "${query_args[*]}")
    url="${url}?${query_str}"
  fi

  curl -s --connect-timeout 10 --max-time 60 \
    -H "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
    -H "Accept: application/json" \
    "${url}"
}

# ---- 查找项目 ID（按 namespace 列表逐个尝试） ----
# 用法: find_project_id <project_name>
#   返回项目 ID，找不到返回空
find_project_id() {
  local project_name="$1"
  local namespaces
  namespaces=$(get_namespaces)

  IFS=',' read -ra NS_LIST <<< "$namespaces"
  for ns in "${NS_LIST[@]}"; do
    local result
    result=$(gitlab_call "/api/v4/projects/${ns}%2F${project_name}")
    local pid
    pid=$(echo "$result" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))" 2>/dev/null)
    if [[ -n "$pid" && "$pid" != "" ]]; then
      echo "$pid"
      return 0
    fi
  done

  return 1
}

# ---- 获取项目 clone URL ----
# 用法: get_clone_url <project_name> [namespace]
#   返回 http clone url
get_clone_url() {
  local project_name="$1"
  local namespace="${2:-}"

  if [[ -n "$namespace" ]]; then
    local result
    result=$(gitlab_call "/api/v4/projects/${namespace}%2F${project_name}")
    echo "$result" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('http_url_to_repo',''))" 2>/dev/null
  else
    local namespaces
    namespaces=$(get_namespaces)
    IFS=',' read -ra NS_LIST <<< "$namespaces"
    for ns in "${NS_LIST[@]}"; do
      local result
      result=$(gitlab_call "/api/v4/projects/${ns}%2F${project_name}")
      local url
      url=$(echo "$result" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('http_url_to_repo',''))" 2>/dev/null)
      if [[ -n "$url" && "$url" != "" ]]; then
        echo "$url"
        return 0
      fi
    done
  fi
}

# ---- CodeGraph 触发 ----
# 用法: trigger_codegraph_sync [path]
#   已安装则 sync，未安装/锁占用则跳过
trigger_codegraph_sync() {
  local sync_path="${1:-$CODEGRAPH_PATH}"
  local cg_bin="$CODEGRAPH_BIN"

  if [[ -z "$cg_bin" ]]; then
    cg_bin=$(command -v codegraph 2>/dev/null || true)
  fi

  if [[ -z "$cg_bin" ]]; then
    echo "[codegraph] 未安装 codegraph，跳过同步"
    return 0
  fi

  echo "[codegraph] 开始增量同步: $sync_path"
  if "$cg_bin" sync "$sync_path" -q 2>/dev/null; then
    echo "[codegraph] 同步完成"
  else
    echo "[codegraph] 同步失败或锁占用，跳过（不阻塞）"
  fi
}
