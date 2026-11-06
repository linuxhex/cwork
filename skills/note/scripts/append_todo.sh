#!/usr/bin/env bash
# 追加一条未完成待办到 inbox.md
set -euo pipefail

VAULT="${CWORK_NOTE_VAULT:-$HOME/Documents/Notes}"
INBOX="$VAULT/inbox.md"
TEXT="${*:-}"

if [[ -z "$TEXT" ]]; then
  echo "usage: append_todo.sh <todo text>" >&2
  exit 2
fi

mkdir -p "$VAULT"
if [[ ! -f "$INBOX" ]]; then
  printf '# Inbox\n\n## 待办\n\n## 认知\n\n' > "$INBOX"
fi

if ! grep -q '^## 待办' "$INBOX"; then
  printf '\n## 待办\n\n' >> "$INBOX"
fi

# 插到 ## 待办 段落后面
python3 - "$INBOX" "$TEXT" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
text = sys.argv[2].strip()
content = path.read_text()
line = f"- [ ] {text}\n"
marker = "## 待办"
if marker in content:
    parts = content.split(marker, 1)
    head, rest = parts[0], parts[1]
    # keep heading, insert todo after following blank lines/content start
    if rest.startswith("\n"):
        rest = rest[1:]
    new = head + marker + "\n\n" + line + rest.lstrip("\n")
else:
    new = content.rstrip() + "\n\n## 待办\n\n" + line
path.write_text(new)
print(f"appended: {line.strip()}")
print(f"path: {path}")
PY
