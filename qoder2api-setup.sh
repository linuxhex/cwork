#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$HOME/.local/share/qoder2api"
BRIDGE_HOST="${QODER_HOST:-127.0.0.1}"
BRIDGE_PORT="${QODER_PORT:-8963}"
BRIDGE_URL="http://${BRIDGE_HOST}:${BRIDGE_PORT}"

SHELL_RC=""
if [ -f "$HOME/.zshrc" ]; then
    SHELL_RC="$HOME/.zshrc"
elif [ -f "$HOME/.bashrc" ]; then
    SHELL_RC="$HOME/.bashrc"
fi

MARKER_BEGIN="# >>> qoder2api bridge >>>"
MARKER_END="# <<< qoder2api bridge <<<"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*"; }

check_go() {
    if ! command -v go &>/dev/null; then
        error "未检测到 Go，请先安装: https://go.dev/dl/"
        exit 1
    fi
    info "Go 已安装: $(go version)"
}

clone_or_update_repo() {
    if [ -d "$REPO_DIR/.git" ]; then
        info "仓库已存在，拉取最新代码..."
        git -C "$REPO_DIR" pull --ff-only 2>/dev/null || warn "拉取失败，使用现有代码"
    else
        info "克隆 qoder2api 仓库..."
        mkdir -p "$(dirname "$REPO_DIR")"
        git clone https://github.com/jyao0708/qoder2api.git "$REPO_DIR"
    fi
}

build() {
    info "编译 qoder2api..."
    cd "$REPO_DIR"
    go build -o "$REPO_DIR/bin/qoder2api" ./cmd/qoder2api
    go build -o "$REPO_DIR/bin/qoder2api-login" ./cmd/qoder2api-login
    info "编译完成"
}

do_login() {
    local auth_path="$HOME/.config/qoder2api/auth.json"
    if [ -f "$auth_path" ]; then
        warn "auth.json 已存在: $auth_path"
        read -rp "是否重新登录? (y/N) " ans
        if [[ ! "$ans" =~ ^[Yy]$ ]]; then
            info "跳过登录"
            return 0
        fi
    fi
    info "启动浏览器登录..."
    info "如果浏览器没有自动打开，请手动复制上面的链接"
    "$REPO_DIR/bin/qoder2api-login"
    info "登录成功"
}

start_bridge() {
    local pid_file="$REPO_DIR/bridge.pid"
    local log_file="$REPO_DIR/bridge.log"

    if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
        warn "桥接服务已在运行 (PID: $(cat "$pid_file"))"
        read -rp "是否重启? (y/N) " ans
        if [[ "$ans" =~ ^[Yy]$ ]]; then
            kill "$(cat "$pid_file")" 2>/dev/null || true
            sleep 1
        else
            return 0
        fi
    fi

    info "启动桥接服务 ${BRIDGE_URL}..."
    nohup "$REPO_DIR/bin/qoder2api" > "$log_file" 2>&1 &
    echo $! > "$pid_file"
    sleep 2

    if kill -0 "$(cat "$pid_file")" 2>/dev/null; then
        info "桥接服务已启动 (PID: $(cat "$pid_file"))"
    else
        error "桥接服务启动失败，查看日志: $log_file"
        exit 1
    fi
}

stop_bridge() {
    local pid_file="$REPO_DIR/bridge.pid"
    if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
        kill "$(cat "$pid_file")"
        rm -f "$pid_file"
        info "桥接服务已停止"
    else
        warn "桥接服务未在运行"
    fi
}

switch_claude() {
    if [ -z "$SHELL_RC" ]; then
        error "未找到 ~/.zshrc 或 ~/.bashrc"
        exit 1
    fi

    if grep -q "$MARKER_BEGIN" "$SHELL_RC" 2>/dev/null; then
        warn "Claude Code 已切换到 qoder2api"
        info "当前配置: $BRIDGE_URL"
        return 0
    fi

    cat >> "$SHELL_RC" <<EOF

${MARKER_BEGIN}
export ANTHROPIC_BASE_URL="${BRIDGE_URL}"
export ANTHROPIC_API_KEY="test-key"
${MARKER_END}
EOF

    info "Claude Code 已切换到 qoder2api"
    info "写入配置: $SHELL_RC"
    echo ""
    echo "  export ANTHROPIC_BASE_URL=${BRIDGE_URL}"
    echo "  export ANTHROPIC_API_KEY=test-key"
    echo ""
    warn "请执行 source $SHELL_RC 或重新打开终端生效"
    warn "之后直接用 claude 命令即可，会走 Qoder 的 token"
}

unswitch_claude() {
    if [ -z "$SHELL_RC" ]; then
        error "未找到 ~/.zshrc 或 ~/.bashrc"
        exit 1
    fi

    if ! grep -q "$MARKER_BEGIN" "$SHELL_RC" 2>/dev/null; then
        warn "Claude Code 未使用 qoder2api，无需恢复"
        return 0
    fi

    sed -i '' "/${MARKER_BEGIN}/,/${MARKER_END}/d" "$SHELL_RC"
    info "Claude Code 已恢复默认配置"
    warn "请执行 source $SHELL_RC 或重新打开终端生效"
}

show_status() {
    local pid_file="$REPO_DIR/bridge.pid"
    echo ""
    echo "=== qoder2api 状态 ==="
    echo ""

    if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
        info "桥接服务: 运行中 (PID: $(cat "$pid_file"))"
        info "监听地址: ${BRIDGE_URL}"
    else
        warn "桥接服务: 未运行"
    fi

    if [ -f "$HOME/.config/qoder2api/auth.json" ]; then
        info "认证文件: 存在"
    else
        warn "认证文件: 不存在"
    fi

    if [ -n "$SHELL_RC" ] && grep -q "$MARKER_BEGIN" "$SHELL_RC" 2>/dev/null; then
        info "Claude Code: 已切换到 qoder2api"
    else
        warn "Claude Code: 使用默认配置"
    fi
    echo ""
}

case "${1:-setup}" in
    setup)
        check_go
        clone_or_update_repo
        build
        do_login
        start_bridge
        switch_claude
        echo ""
        info "设置完成！重新打开终端后，直接用 claude 即可"
        ;;
    start)
        start_bridge
        ;;
    stop)
        stop_bridge
        ;;
    restart)
        stop_bridge
        sleep 1
        start_bridge
        ;;
    status)
        show_status
        ;;
    switch)
        switch_claude
        ;;
    unswitch)
        unswitch_claude
        ;;
    login)
        "$REPO_DIR/bin/qoder2api-login"
        ;;
    *)
        echo "用法: $0 {setup|start|stop|restart|status|switch|unswitch|login}"
        echo ""
        echo "  setup    - 完整设置 (克隆+编译+登录+启动+切换Claude)"
        echo "  start    - 启动桥接服务"
        echo "  stop     - 停止桥接服务"
        echo "  restart  - 重启桥接服务"
        echo "  status   - 查看状态"
        echo "  switch   - 切换 Claude Code 到 qoder2api"
        echo "  unswitch - 恢复 Claude Code 默认配置"
        echo "  login    - 重新登录"
        exit 1
        ;;
esac
