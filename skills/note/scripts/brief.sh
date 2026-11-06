#!/usr/bin/env bash
# cwork-note: 生成本地今日简报骨架（确定性，不依赖 MCP/模型临场发挥）
# 用法: brief.sh
# 输出: 终端 dashboard 文本到 stdout
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT="${CWORK_NOTE_VAULT:-$HOME/Documents/Notes}"
INBOX="$VAULT/inbox.md"
NOW="$(date '+%Y-%m-%d %H:%M')"
TODAY="$(date '+%Y-%m-%d')"

echo "今日简报 · ${NOW}"
echo "────────────────────────────────"

# ---- 待办（有才展示）----
todos=()
if [[ -f "$INBOX" ]]; then
  while IFS= read -r line; do
    # 兼容 `- [ ]` / `- [ ]` 前导空白
    item="$(printf '%s\n' "$line" | sed -E 's/^[[:space:]]*- \[ \][[:space:]]*//')"
    [[ -n "$item" ]] && todos+=("$item")
  done < <(grep -E '^[[:space:]]*- \[ \]' "$INBOX" || true)
fi
# 也扫 待办/ 目录下未完成项（最多补到 12）
if [[ -d "$VAULT/待办" ]]; then
  while IFS= read -r line; do
    (( ${#todos[@]} >= 12 )) && break
    item="$(printf '%s\n' "$line" | sed -E 's/^[[:space:]]*- \[ \][[:space:]]*//')"
    [[ -n "$item" ]] && todos+=("$item")
  done < <(grep -REh '^[[:space:]]*- \[ \]' "$VAULT/待办" 2>/dev/null || true)
fi

if (( ${#todos[@]} > 0 )); then
  # 去重保序
  uniq_todos=()
  seen=$'\n'
  for t in "${todos[@]}"; do
    case "$seen" in
      *$'\n'"$t"$'\n'*) continue ;;
    esac
    seen+="$t"$'\n'
    uniq_todos+=("$t")
    (( ${#uniq_todos[@]} >= 12 )) && break
  done
  echo "待办  ${#uniq_todos[@]}"
  for t in "${uniq_todos[@]}"; do
    echo "  ☐ $t"
  done
  echo "────────────────────────────────"
fi

# ---- 提醒行（始终展示，下班检查有锚）----
echo "提醒  17:30  云效填写 · 工时 8h"
echo "────────────────────────────────"

if (( ${#todos[@]} == 0 )); then
  echo "还没有待办。直接告诉我今天要做什么。"
else
  echo "直接说待办 / 认知，我会写入知识库"
fi

# ---- 机器可读附注（给 agent 做下班检查，不进主看板时可忽略）----
echo
echo "# meta"
echo "date=$TODAY"
echo "vault=$VAULT"
echo "inbox=$INBOX"
echo "todo_count=${#todos[@]}"
echo "worktime_script=$SCRIPT_DIR/yunxiao_worktime.sh"
echo "offwork_check=yunxiao_query.sh list + yunxiao_worktime.sh"
