#!/usr/bin/env bash
# =============================================================================
# cwork 跨平台兼容层（POSIX shim）
#
# 由各技能的 _common.sh 在算出自身目录后 source。只定义变量和函数，
# 不 set -e/-u，不改变调用方语义。
#
# 解决两类 Windows 问题：
#
# 1) python3 不可用
#    Windows 上 python.org 安装只提供 python.exe；
#    %LOCALAPPDATA%\Microsoft\WindowsApps\python3.exe 是 0 字节的 Store
#    应用执行别名(reparse point)，执行会弹商店或直接失败。
#    而各技能脚本正文里签名/JSON 解析大量使用 `python3 - <<PY` 与 `python3 -c`。
#    本文件探测到 python3 不可用时，用一个同名 shell 函数接管——脚本正文零改动。
#
# 2) 路径假设
#    /tmp、/usr/local/bin、macOS 专属路径在 Windows 不存在；反过来给 cmd/docker
#    等 Windows 程序传 POSIX 路径也会失败。这里提供 tmpdir / 路径双向转换，
#    并把「工程外资源」（服务地图、npm 全局包）的定位统一收口。
#
# 手工验证：
#   bash -c '. skills/common/win-compat.sh; cwork_diag'
# =============================================================================

# ---- 平台判定 ----------------------------------------------------------------

# 输出 windows / macos / linux / unknown
cwork_os() {
  case "${OSTYPE:-$(uname -s 2>/dev/null || echo unknown)}" in
    msys*|cygwin*|mingw*) echo windows ;;
    darwin*)              echo macos ;;
    linux*)               echo linux ;;
    *)                    echo unknown ;;
  esac
}

cwork_is_windows() { [[ "$(cwork_os)" == "windows" ]]; }

# ---- CWORK_HOME（cwork 源仓库根） --------------------------------------------
# 优先级: 环境变量 > 由本文件位置推断（本文件固定位于 <root>/skills/common/）
cwork_home() {
  if [[ -n "${CWORK_HOME:-}" ]]; then
    printf '%s\n' "$CWORK_HOME"
    return 0
  fi
  local self_dir root
  self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || return 1
  root="$(cd "$self_dir/../.." 2>/dev/null && pwd)" || return 1
  printf '%s\n' "$root"
}

# ---- Python 解释器 -----------------------------------------------------------

# 判断某个命令名是否为可用的 Python 3。
# 排除 WindowsApps 下的 Store 别名占位（0 字节 reparse point，执行会弹商店）。
cwork_python_probe() {
  local cmd="$1" resolved
  resolved="$(command -v "$cmd" 2>/dev/null)" || return 1
  [[ -n "$resolved" ]] || return 1
  case "$resolved" in
    *[Ww]indows[Aa]pps*) return 1 ;;
  esac
  [[ -x "$resolved" ]] || return 1
  "$cmd" -c 'import sys; sys.exit(0 if sys.version_info[0] == 3 else 1)' >/dev/null 2>&1
}

# 输出可用的 Python 3 命令名（不是路径，方便直接调用）
# 优先级: CWORK_PYTHON > python3 > python > py
cwork_python() {
  if [[ -n "${CWORK_PYTHON:-}" ]]; then
    printf '%s\n' "$CWORK_PYTHON"
    return 0
  fi
  if [[ -n "${_CWORK_PY:-}" ]]; then
    printf '%s\n' "$_CWORK_PY"
    return 0
  fi
  local c
  for c in python3 python py; do
    if cwork_python_probe "$c"; then
      _CWORK_PY="$c"
      printf '%s\n' "$c"
      return 0
    fi
  done
  return 1
}

# python3 接管：脚本正文已经写了大量 `python3 ...`，不逐个改写，
# 直接用同名函数覆盖为探测到的真实解释器。
cwork_install_python3_shim() {
  # 已可用则什么都不做（macOS/Linux 常态）
  if cwork_python_probe python3; then
    return 0
  fi
  if ! _CWORK_PY_REAL="$(cwork_python)"; then
    echo "WARN: 未找到可用的 Python 3（python3/python/py 均不可用），依赖签名的技能将失败。" >&2
    echo "      安装: https://www.python.org/downloads/ 或设置 CWORK_PYTHON=<解释器绝对路径>" >&2
    return 1
  fi
  # shellcheck disable=SC2317
  python3() { "$_CWORK_PY_REAL" "$@"; }
  echo "INFO: python3 不可用，已回退到 '$_CWORK_PY_REAL'（skills/common/win-compat.sh）" >&2
  return 0
}

# ---- 临时目录 ----------------------------------------------------------------

# Git Bash 的 /tmp 已映射到 %TEMP%，但显式 TMPDIR / CWORK_TMPDIR 优先
cwork_tmpdir() {
  local d="${CWORK_TMPDIR:-${TMPDIR:-/tmp}}"
  mkdir -p "$d" 2>/dev/null || true
  printf '%s\n' "$d"
}

# ---- 路径转换 ----------------------------------------------------------------

# POSIX -> Windows（给 cmd/docker/kubectl 等原生程序传参用）
# /c/Users/x -> C:\Users\x
cwork_win_path() {
  local p="$1"
  if cwork_is_windows && command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$p"
    return
  fi
  # 回退：手写转换（无 cygpath 的 MSYS 精简环境）
  p="${p//\//\\}"
  if [[ "$p" =~ ^\\([A-Za-z])\\ ]]; then
    local drive="${BASH_REMATCH[1]}"
    p="${drive}:\\${p:3}"
  fi
  printf '%s\n' "$p"
}

# Windows -> POSIX（给 bash/git 等 POSIX 程序传参用）
# C:\Users\x -> /c/Users/x
cwork_posix_path() {
  local p="$1"
  if cwork_is_windows && command -v cygpath >/dev/null 2>&1; then
    cygpath -u "$p"
    return
  fi
  p="${p//\\//}"
  if [[ "$p" =~ ^([A-Za-z]): ]]; then
    local drive
    drive="$(printf '%s' "${BASH_REMATCH[1]}" | tr '[:upper:]' '[:lower:]')"
    p="/${drive}${p:2}"
  fi
  printf '%s\n' "$p"
}

# ---- 工程外资源定位 ----------------------------------------------------------

# 服务地图 .services-map.md（cwork 唯一权威服务地图）
# 优先级: CWORK_SERVICES_MAP > $CWORK_HOME/.services-map.md > ~/.services-map.md
# 找不到返回非 0（调用方应降级为「按服务名向用户确认」而不是报错退出）
cwork_services_map() {
  local home c
  home="$(cwork_home 2>/dev/null || true)"
  for c in "${CWORK_SERVICES_MAP:-}" "${home:+$home/.services-map.md}" "$HOME/.services-map.md"; do
    [[ -n "$c" && -f "$c" ]] || continue
    printf '%s\n' "$c"
    return 0
  done
  return 1
}

# npm 全局 node_modules 候选目录（ego-browser / miniprogram-automator 等定位用）
# 每行一个，按平台给出
cwork_npm_global_dirs() {
  local _cna _cnl
  [[ -n "${NODE_PATH:-}" ]] && printf '%s\n' "$NODE_PATH"
  case "$(cwork_os)" in
    windows)
      # APPDATA/LOCALAPPDATA 是反斜杠原生路径，统一成正斜杠，避免诊断输出出现混合分隔符
      _cna="${APPDATA:-$HOME/AppData/Roaming}"
      _cnl="${LOCALAPPDATA:-$HOME/AppData/Local}"
      printf '%s\n' "${_cna//\\//}/npm/node_modules"
      printf '%s\n' "${_cnl//\\//}/pnpm/global/5/node_modules"
      ;;
    macos)
      printf '%s\n' "/opt/homebrew/lib/node_modules"
      printf '%s\n' "/usr/local/lib/node_modules"
      printf '%s\n' "$HOME/.npm-global/lib/node_modules"
      ;;
    *)
      printf '%s\n' "/usr/local/lib/node_modules"
      printf '%s\n' "/usr/lib/node_modules"
      printf '%s\n' "$HOME/.npm-global/lib/node_modules"
      ;;
  esac
}

# ---- 诊断 -------------------------------------------------------------------

cwork_diag() {
  echo "cwork 兼容层诊断"
  echo "  os            : $(cwork_os)  (OSTYPE=${OSTYPE:-未设置} MSYSTEM=${MSYSTEM:-未设置})"
  echo "  bash          : ${BASH_VERSION}"
  echo "  CWORK_HOME    : $(cwork_home 2>/dev/null || echo '<未解析>')"
  echo "  python3 直连   : $(cwork_python_probe python3 && echo 可用 || echo 不可用)"
  echo "  python 选用    : $(cwork_python 2>/dev/null || echo '<无可用 Python 3>')"
  echo "  tmpdir        : $(cwork_tmpdir)"
  echo "  服务地图       : $(cwork_services_map 2>/dev/null || echo '<未找到>')"
  echo "  cygpath       : $(command -v cygpath 2>/dev/null || echo '<无>')"
  local d
  while IFS= read -r d; do
    [[ -n "$d" ]] && echo "  npm 全局目录   : $d"
  done <<< "$(cwork_npm_global_dirs)"
}

# 建立 python3 接管（source 即生效；CWORK_SKIP_PY_SHIM=1 可关闭）
if [[ "${CWORK_SKIP_PY_SHIM:-0}" != "1" ]]; then
  cwork_install_python3_shim || true
fi

# 直接执行本文件（而非 source）时打印诊断：bash skills/common/win-compat.sh
# 供 bin/cwork.ps1 doctor 调用——避开 PowerShell 向 bash -c 传字符串时丢双引号的问题
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  cwork_diag
fi
