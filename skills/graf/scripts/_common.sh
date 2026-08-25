#!/usr/bin/env bash
# _common.sh — Grafana 登录 + cookie 管理（cwork-graf 共享）

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# 使用 curl 完整路径，避免 source 时 PATH 问题
CURL="${CURL:-$(which curl 2>/dev/null || echo /usr/bin/curl)}"

# ── 加载凭证 ─
load_config() {
  local cfg="$SCRIPT_DIR/.config.local.sh"
  if [[ -f "$cfg" ]]; then
    # shellcheck source=/dev/null
    source "$cfg"
  fi

  # CWORK_HOME 回源仓库读凭证（IDE 安装场景）
  if [[ -z "${GRAFANA_USER:-}" || -z "${GRAFANA_PASS:-}" ]] && [[ -n "${CWORK_HOME:-}" ]]; then
    local src_cfg="$CWORK_HOME/skills/graf/scripts/.config.local.sh"
    if [[ -f "$src_cfg" ]]; then
      # shellcheck source=/dev/null
      source "$src_cfg"
    fi
  fi

  if [[ -z "${GRAFANA_USER:-}" || -z "${GRAFANA_PASS:-}" ]]; then
    echo "错误: Grafana 凭证未配置" >&2
    echo "  cp $SCRIPT_DIR/config.example.sh $SCRIPT_DIR/.config.local.sh" >&2
    echo "  然后编辑 .config.local.sh 填入 GRAFANA_USER / GRAFANA_PASS" >&2
    exit 1
  fi
}

# ── 登录获取 cookie ──
COOKIE_JAR="/tmp/cwork_graf_cookies.txt"

grafana_login() {
  load_config
  local url="${GRAFANA_URL:-https://graf.ykccn.net}"

  # 先拿初始 cookie
  $CURL -s -c "$COOKIE_JAR" -b "$COOKIE_JAR" "$url/login" -o /dev/null

  # 登录
  local resp
  resp=$($CURL -s -c "$COOKIE_JAR" -b "$COOKIE_JAR" \
    -X POST "$url/login" \
    -H 'Content-Type: application/json' \
    -d "{\"user\":\"$GRAFANA_USER\",\"password\":\"$GRAFANA_PASS\"}")

  if echo "$resp" | python3 -c "import sys,json; d=json.load(sys.stdin); exit(0 if d.get('message')=='Logged in' else 1)" 2>/dev/null; then
    return 0
  else
    echo "错误: Grafana 登录失败 — $resp" >&2
    exit 1
  fi
}

# ── 带鉴权的 GET 请求 ──
grafana_get() {
  local path="$1"
  shift
  local url="${GRAFANA_URL:-https://graf.ykccn.net}"

  # 确保已登录
  if [[ ! -f "$COOKIE_JAR" ]] || ! grep -q 'grafana_session' "$COOKIE_JAR" 2>/dev/null; then
    grafana_login
  fi

  $CURL -s -b "$COOKIE_JAR" "$url$path" "$@"
}

# ── 带鉴权的 POST 请求（用于 ds/query） ──
grafana_post() {
  local path="$1"
  shift
  local url="${GRAFANA_URL:-https://graf.ykccn.net}"

  if [[ ! -f "$COOKIE_JAR" ]] || ! grep -q 'grafana_session' "$COOKIE_JAR" 2>/dev/null; then
    grafana_login
  fi

  $CURL -s -b "$COOKIE_JAR" -X POST "$url$path" \
    -H 'Content-Type: application/json' "$@"
}
