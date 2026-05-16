#!/usr/bin/env bash
set -euo pipefail

fail() { echo "ERROR: $*" >&2; exit 1; }
trim() {
  local v="$1"
  v="${v#"${v%%[![:space:]]*}"}"
  v="${v%"${v##*[![:space:]]}"}"
  printf '%s' "$v"
}

MAIN_DIR=""
REQUIREMENT_KEY=""
DEPS_RAW=""
FEATURE_BRANCH=""
OUT_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --main-dir) MAIN_DIR="$2"; shift 2 ;;
    --requirement-key) REQUIREMENT_KEY="$2"; shift 2 ;;
    --deps) DEPS_RAW="$2"; shift 2 ;;
    --feature-branch) FEATURE_BRANCH="$2"; shift 2 ;;
    --out-file) OUT_FILE="$2"; shift 2 ;;
    *) fail "unknown argument: $1" ;;
  esac
done

[[ -n "$MAIN_DIR" ]] || fail "--main-dir is required"
[[ -n "$REQUIREMENT_KEY" ]] || fail "--requirement-key is required"
[[ -n "$OUT_FILE" ]] || fail "--out-file is required"

python3 - "$MAIN_DIR" "$REQUIREMENT_KEY" "$DEPS_RAW" "$FEATURE_BRANCH" "$OUT_FILE" <<'PY'
import json
import re
import sys
from pathlib import Path

main_dir = Path(sys.argv[1])
requirement_key = sys.argv[2]
deps_raw = sys.argv[3]
feature_branch = sys.argv[4]
out_file = Path(sys.argv[5])

repos = [main_dir]
for item in deps_raw.split(','):
    item = item.strip()
    if item:
        repos.append(Path(item))

def read_phase(repo: Path):
    p = repo / "docs" / "requirements" / requirement_key / "workflow-state.json"
    if not p.exists():
        return "unknown"
    try:
        return json.loads(p.read_text(encoding="utf-8")).get("current_phase", "unknown")
    except Exception:
        return "unknown"

repo_rows = []
for repo in repos:
    branch = "-"
    head = repo / ".git"
    if head.exists():
        import subprocess
        try:
            branch = subprocess.check_output(["git", "-C", str(repo), "branch", "--show-current"], text=True).strip() or "-"
        except Exception:
            branch = "-"
    repo_rows.append({"name": repo.name, "branch": branch, "phase": read_phase(repo)})

rounds = []
changes = main_dir / "docs" / "requirements" / requirement_key / "03-changes.md"
if changes.exists():
    text = changes.read_text(encoding="utf-8", errors="ignore")
    for m in re.finditer(r"^## Round\s+(\d+)\n([\s\S]*?)(?=^## Round\s+\d+|\Z)", text, re.M):
        body = m.group(2)
        open_m = re.search(r"open[_ ]issues:\s*(\d+)", body)
        closed_m = re.search(r"closed[_ ]issues:\s*(\d+)", body)
        rounds.append({
            "round": int(m.group(1)),
            "open": int(open_m.group(1)) if open_m else 0,
            "closed": int(closed_m.group(1)) if closed_m else 0,
        })

current_phase = "unknown"
if repo_rows:
    current_phase = repo_rows[0].get("phase", "unknown")

payload = {
    "requirement_key": requirement_key,
    "feature_branch": feature_branch,
    "current_phase": current_phase,
    "repos": repo_rows,
    "rounds": rounds,
}

out_file.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print("VISUAL_STATE_WRITTEN")
PY
