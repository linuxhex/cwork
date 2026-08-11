#!/bin/bash
# cwork 技能同步脚本
# 用法:
#   ./sync.sh          # 同步到所有 IDE
#   ./sync.sh cursor   # 只同步到 Cursor
#   ./sync.sh trae     # 只同步到 Trae
#   ./sync.sh qoder    # 只同步到 Qoder
#   ./sync.sh claude   # 只同步到 Claude

set -e
cd "$(dirname "$0")"

TOOL="${1:-auto}"

echo "🔄 同步 cwork 技能到: $TOOL"
echo ""

node bin/cwork.js --tool "$TOOL"
