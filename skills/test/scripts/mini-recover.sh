#!/bin/bash
# cwork-test 小程序自动化「挂起」恢复脚本
#
# 适用症状（三联，占其一即可判定挂起）：
#   1. MCP 工具调用（click/navigate_to/wait_for 等）长时间无返回
#   2. 小程序一直显示"加载中"不渲染
#   3. 模拟器手动点击无反应（命令队列堵死的伴随现象，不是死机）
#
# 根因：miniprogram-automator 的 Connection.send 无请求超时，开发者工具回包丢失时
#       Promise 永久挂起；MCP 层除 connect_devtools(45s) 外也无超时，命令队列堵死后
#       只能重启开发者工具清掉堵塞的 WebSocket。
#
# 用法：bash mini-recover.sh <小程序项目路径（含 project.config.json 的目录）> [自动化端口]
#       端口默认 9420

set -u
CLI_PATH="/Applications/wechatwebdevtools.app/Contents/MacOS/cli"
PORT="${2:-9420}"
PROJECT_PATH="${1:-}"

echo "═══════════════════════════════════════════════════════════"
echo "【小程序自动化挂起恢复】端口 $PORT"
echo "═══════════════════════════════════════════════════════════"

# 1. 前置校验
if [ ! -f "$CLI_PATH" ]; then
  echo "❌ 未找到微信开发者工具 CLI：$CLI_PATH"
  exit 1
fi
if [ -z "$PROJECT_PATH" ] || [ ! -f "$PROJECT_PATH/project.config.json" ]; then
  echo "用法：bash mini-recover.sh <小程序项目路径（含 project.config.json 的目录）> [端口]"
  exit 1
fi

# 2. 退出开发者工具（优雅退出，失败强杀兜底）
echo "→ 退出微信开发者工具..."
"$CLI_PATH" quit >/dev/null 2>&1
sleep 3
if pgrep -f "wechatwebdevtools" >/dev/null 2>&1; then
  echo "→ 优雅退出未完成，强制结束进程..."
  pkill -f "wechatwebdevtools" >/dev/null 2>&1
  sleep 2
fi
if pgrep -f "wechatwebdevtools" >/dev/null 2>&1; then
  echo "❌ 开发者工具进程仍存活，请手动退出后重跑本脚本"
  exit 1
fi

# 3. 重新打开项目并开启自动化端口
#    ⚠️ --auto-port 才是自动化端口（automator 官方 Launcher 同款参数）；
#    --port 是 IDE HTTP 服务端口，用错会导致 automator 连不上。
echo "→ 重新打开项目：$PROJECT_PATH"
"$CLI_PATH" open --project "$PROJECT_PATH" >/dev/null 2>&1
sleep 5

echo "→ 开启自动化端口：$PORT"
# cli auto 触发完会自行退出，放后台防止个别环境下进程滞留阻塞脚本
"$CLI_PATH" auto --project "$PROJECT_PATH" --auto-port "$PORT" >/dev/null 2>&1 &

# 4. 轮询等待自动化端口就绪（最多约 30 秒）
echo "→ 等待自动化端口就绪..."
for _ in $(seq 1 15); do
  if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "✓ 恢复完成：自动化端口 $PORT 已就绪"
    echo ""
    echo "下一步（AI 执行）："
    echo "  1. connect_devtools({ projectPath: \"$PROJECT_PATH\", strategy: \"connect\" }) 重连"
    echo "  2. 从当前测试场景的第一个步骤重跑（无需从头跑全部场景）"
    echo "  3. 若再次在同一位置挂起 → 记为该场景失败，跳过继续下一场景（二次挂起不恢复）"
    exit 0
  fi
  sleep 2
done

echo "❌ 自动化端口 $PORT 在 30 秒内未就绪，排查建议："
echo "   - 手动打开开发者工具，确认项目能正常编译（编译报错会卡加载）"
echo "   - 确认 设置 → 安全 → 服务端口 已开启"
echo "   - 确认小程序已登录（未登录扫码登录后重跑）"
exit 1
