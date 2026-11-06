#!/usr/bin/env bash
# Cute 启动时自动播放今日简报：以打印模式跑 cwork-note，只输出简报结果。
# - 单独成脚本：Cute 若直接把整段 prompt 作为 `claude '...'` 注入终端，会回显一长串命令。
# - 用 `claude -p`：只打印最终结果，不显示启动 banner / 工具调用过程（用户要求「给结果就行」）。
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export CWORK_NOTE_SKILL_DIR="$SKILL_DIR"

IFS= read -r -d '' PROMPT <<'EOF' || true
执行技能 cwork-note。
先运行该技能的 scripts/brief.sh 拿到今日简报骨架（忽略 # meta 段），把简报原样输出。
只输出简报结果，不要解释执行过程。
EOF

exec "${CWORK_CLAUDE_BIN:-claude}" -p "$PROMPT"
