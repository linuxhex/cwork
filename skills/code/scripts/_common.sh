#!/usr/bin/env bash
# =============================================================================
# cwork-code 共用模块: CodeUp + GitLab 双平台 API 封装 + codegraph 触发
# 仅供其他脚本 source:  source "$SCRIPT_DIR/_common.sh"
#
# 平台策略:
#   - 大部分代码在 CodeUp（云效代码托管）
#   - 前端项目在 GitLab
#   - 查找顺序: CodeUp 优先，GitLab 作为 fallback
#   - 找代码优先使用 codegraph 索引
#
# 配置来源(优先级, 高 -> 低):
#   1. 环境变量(同名)
#   2. 同目录 .config.local.sh(本工程内, 已 gitignore)
#      缺失则 fail 提示配置方法
#
# 绝对只读: codeup_call/gitlab_call 只封装 GET, 代码结构上不存在任何写路径。
# clone/pull 是本地操作，不通过 API 写远端。
# =============================================================================

_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.config.local.sh
if [ -f "$_COMMON_DIR/.config.local.sh" ]; then
  source "$_COMMON_DIR/.config.local.sh"
elif [ -n "${CWORK_HOME:-}" ] && [ -f "$CWORK_HOME/skills/code/scripts/.config.local.sh" ]; then
  # IDE 安装场景: 同目录无凭证(bin/cwork.js 的 SENSITIVE_PATTERNS 过滤了 .config.local.sh),
  # 回 CWORK_HOME 源仓库读同一份, 避免每个 IDE 重复配置
  source "$CWORK_HOME/skills/code/scripts/.config.local.sh"
fi

fail() { echo "ERROR: $*" >&2; exit 1; }
require_cmd() { command -v "$1" >/dev/null 2>&1 || fail "缺少命令: $1 (请先安装)"; }

# ---- 配置校验 ----
CODEUP_ENABLED="${CODEUP_ENABLED:-true}"
GITLAB_ENABLED="${GITLAB_ENABLED:-true}"

# CodeUp 配置
CODEUP_DOMAIN="${CODEUP_DOMAIN:-openapi-rdc.aliyuncs.com}"
CODEUP_ORG="${CODEUP_ORG_ID:-}"
CODEUP_TOKEN="${CODEUP_TOKEN:-}"

# GitLab 配置
GITLAB_URL="${GITLAB_URL:-}"
GITLAB_TOKEN="${GITLAB_TOKEN:-}"

# 校验至少一个平台可用
if [[ "$CODEUP_ENABLED" == "true" ]]; then
  if [[ -z "$CODEUP_ORG" || -z "$CODEUP_TOKEN" ]]; then
    echo "[WARN] CodeUp 配置不完整，跳过 CodeUp 平台" >&2
    CODEUP_ENABLED="false"
  fi
fi

if [[ "$GITLAB_ENABLED" == "true" ]]; then
  if [[ -z "$GITLAB_URL" || -z "$GITLAB_TOKEN" ]]; then
    echo "[WARN] GitLab 配置不完整，跳过 GitLab 平台" >&2
    GITLAB_ENABLED="false"
  fi
  [[ -n "$GITLAB_URL" ]] && GITLAB_URL="${GITLAB_URL%/}"
fi

if [[ "$CODEUP_ENABLED" != "true" && "$GITLAB_ENABLED" != "true" ]]; then
  fail "至少需要配置一个平台（CodeUp 或 GitLab）: 请执行 cp scripts/config.example.sh scripts/.config.local.sh 并填入凭证"
fi

CODE_WORKSPACE="${CODE_WORKSPACE:-/Users/caomunian/Work/code-projects}"
CODEGRAPH_PATH="${CODEGRAPH_PATH:-$CODE_WORKSPACE}"
CODEGRAPH_BIN="${CODEGRAPH_BIN:-}"

get_namespaces() { echo "${GITLAB_NAMESPACES:-omp,omp-device,zdl,center,omp-barrier,adp,mmp,omp-zdl,ctp}"; }

# ---- CodeUp API GET 封装（绝对只读） ----
# 用法: codeup_call <api_path> [query_key=value ...]
#   api_path: API 路径, 如 /repositories
#   自动带 x-yunxiao-token header
#   只封装 GET, 绝对只读
codeup_call() {
  require_cmd curl
  local api_path="$1"; shift
  local base_url="https://${CODEUP_DOMAIN}/oapi/v1/codeup/organizations/${CODEUP_ORG}"
  local url="${base_url}${api_path}"

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
    -H "x-yunxiao-token: ${CODEUP_TOKEN}" \
    -H "Accept: application/json" \
    "${url}"
}

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

# ---- 双平台查找项目 ----
# 用法: find_project <project_name>
#   返回: platform:id:url (如 "codeup:12345:https://..." 或 "gitlab:678:https://...")
#   找不到返回空
find_project() {
  local project_name="$1"
  local result

  # 1. 优先查 CodeUp
  if [[ "$CODEUP_ENABLED" == "true" ]]; then
    echo "[查找] CodeUp 平台: $project_name" >&2
    local codeup_result
    codeup_result=$(codeup_call "/repositories" "perPage=100")

    # 解析 JSON，搜索匹配的项目
    local repo_info
    repo_info=$(echo "$codeup_result" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if isinstance(data, list):
        for repo in data:
            if repo.get('name') == sys.argv[1] or repo.get('path') == sys.argv[1]:
                print(f\"{repo['id']}|{repo.get('webUrl', '')}|{repo.get('pathWithNamespace', '')}\")
                break
except:
    pass
" "$project_name" 2>/dev/null)

    if [[ -n "$repo_info" ]]; then
      local repo_id repo_url repo_path
      IFS='|' read -r repo_id repo_url repo_path <<< "$repo_info"
      echo "codeup:${repo_id}:${repo_url}"
      return 0
    fi
  fi

  # 2. CodeUp 未找到，fallback 到 GitLab
  if [[ "$GITLAB_ENABLED" == "true" ]]; then
    echo "[查找] GitLab 平台: $project_name" >&2
    local namespaces
    namespaces=$(get_namespaces)
    IFS=',' read -ra NS_LIST <<< "$namespaces"
    for ns in "${NS_LIST[@]}"; do
      local gitlab_result
      gitlab_result=$(gitlab_call "/api/v4/projects/${ns}%2F${project_name}")
      local pid url
      pid=$(echo "$gitlab_result" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))" 2>/dev/null)
      url=$(echo "$gitlab_result" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('http_url_to_repo',''))" 2>/dev/null)
      if [[ -n "$pid" && -n "$url" ]]; then
        echo "gitlab:${pid}:${url}"
        return 0
      fi
    done
  fi

  return 1
}

# ---- 获取项目 clone URL（双平台） ----
# 用法: get_clone_url <project_name>
#   返回 http clone url
get_clone_url() {
  local project_name="$1"
  local result
  result=$(find_project "$project_name") || return 1

  # 解析 platform:id:url
  local platform pid url
  IFS=':' read -r platform pid url <<< "$result"
  echo "$url"
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

# ---- CodeGraph 索引查询（优先推荐） ----
# 用法: search_codegraph <keyword>
#   返回: 文件路径列表（JSON）
search_codegraph() {
  local keyword="$1"
  local cg_bin="$CODEGRAPH_BIN"

  if [[ -z "$cg_bin" ]]; then
    cg_bin=$(command -v codegraph 2>/dev/null || true)
  fi

  if [[ -z "$cg_bin" ]]; then
    echo "[codegraph] 未安装 codegraph，无法使用索引查询" >&2
    return 1
  fi

  echo "[codegraph] 索引查询: $keyword" >&2
  # TODO: 调用 codegraph search API
  # "$cg_bin" search "$keyword" --format json
}
