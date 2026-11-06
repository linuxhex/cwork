#!/usr/bin/env bash
# 读取本地 Obsidian vault 待办（inbox.md）
set -euo pipefail

VAULT="${CWORK_NOTE_VAULT:-$HOME/Documents/Notes}"
INBOX="$VAULT/inbox.md"

if [[ ! -d "$VAULT/.obsidian" ]]; then
  echo "VAULT_STATUS=missing"
  echo "vault=$VAULT"
  exit 0
fi

echo "VAULT_STATUS=ok"
echo "vault=$VAULT"

if [[ ! -f "$INBOX" ]]; then
  echo "INBOX_STATUS=missing"
  exit 0
fi

echo "INBOX_STATUS=ok"
echo "---- inbox.md ----"
cat "$INBOX"
echo "---- open todos ----"
grep -E '^[[:space:]]*- \[ \]' "$INBOX" || true
