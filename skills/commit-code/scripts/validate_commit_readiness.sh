#!/usr/bin/env bash
set -euo pipefail

fail() { echo "ERROR: $*" >&2; exit 1; }
trim() {
  local v="$1"
  v="${v#"${v%%[![:space:]]*}"}"
  v="${v%"${v##*[![:space:]]}"}"
  printf '%s' "$v"
}

REPOS_RAW=""
REQUIREMENT_KEY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repos) REPOS_RAW="$2"; shift 2 ;;
    --requirement-key) REQUIREMENT_KEY="$2"; shift 2 ;;
    *) fail "unknown argument: $1" ;;
  esac
done

[[ -n "$REPOS_RAW" ]] || fail "--repos is required"
[[ -n "$REQUIREMENT_KEY" ]] || fail "--requirement-key is required"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STATE_SCRIPT="$SCRIPT_DIR/../../init/scripts/workflow_state.sh"

BASE_BRANCH=""
while IFS= read -r repo; do
  repo="$(trim "$repo")"
  [[ -z "$repo" ]] && continue
  [[ -d "$repo" ]] || fail "repo not found: $repo"
  [[ "$repo" = /* ]] || fail "repo must be absolute: $repo"
  git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "not git repo: $repo"

  branch="$(git -C "$repo" branch --show-current)"
  [[ -n "$branch" ]] || fail "detached HEAD not allowed: $repo"
  if [[ -z "$BASE_BRANCH" ]]; then
    BASE_BRANCH="$branch"
  elif [[ "$branch" != "$BASE_BRANCH" ]]; then
    fail "branch mismatch: $repo => $branch, expected $BASE_BRANCH"
  fi

  bash "$STATE_SCRIPT" --repo "$repo" --requirement-key "$REQUIREMENT_KEY" --action assert --phase commit-code >/dev/null || fail "workflow phase not commit-code: $repo"

  changes_file="$repo/docs/requirements/$REQUIREMENT_KEY/03-changes.md"
  if [[ -f "$changes_file" ]] && rg -n "status:\s*open|状态[:：]\s*open|\[ \]" "$changes_file" >/dev/null 2>&1; then
    fail "open issue markers found in $changes_file"
  fi

done < <(tr ',' '\n' <<<"$REPOS_RAW")

echo "COMMIT_READINESS_OK"
echo "BRANCH=$BASE_BRANCH"
