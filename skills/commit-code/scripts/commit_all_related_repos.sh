#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

trim() {
  local v="$1"
  v="${v#"${v%%[![:space:]]*}"}"
  v="${v%"${v##*[![:space:]]}"}"
  printf '%s' "$v"
}

stage_by_allowlist() {
  local repo="$1"
  local allowlist_file="$2"

  while IFS= read -r pathspec; do
    pathspec="$(trim "$pathspec")"
    [[ -z "$pathspec" ]] && continue
    [[ "$pathspec" == \#* ]] && continue
    git -C "$repo" add -A -- "$pathspec"
  done < "$allowlist_file"
}

REPOS_RAW=""
REQ_SHORT=""
REQUIREMENT_KEY=""
COMMIT_TYPE=""
COMMIT_DETAIL=""
ALLOWLIST_FILE=""
ALLOW_ALL_CHANGES="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repos) REPOS_RAW="$2"; shift 2 ;;
    --requirement-short) REQ_SHORT="$2"; shift 2 ;;
    --requirement-key) REQUIREMENT_KEY="$2"; shift 2 ;;
    --commit-type) COMMIT_TYPE="$2"; shift 2 ;;
    --commit-detail) COMMIT_DETAIL="$2"; shift 2 ;;
    --allowlist-file) ALLOWLIST_FILE="$2"; shift 2 ;;
    --allow-all-changes) ALLOW_ALL_CHANGES="true"; shift 1 ;;
    *) fail "unknown argument: $1" ;;
  esac
done

[[ -n "$REPOS_RAW" ]] || fail "--repos is required"
[[ -n "$REQ_SHORT" ]] || fail "--requirement-short is required"
[[ -n "$REQUIREMENT_KEY" ]] || fail "--requirement-key is required"
[[ -n "$COMMIT_TYPE" ]] || fail "--commit-type is required"
[[ -n "$COMMIT_DETAIL" ]] || fail "--commit-detail is required"

case "$COMMIT_TYPE" in
  add|del|modify|fix|refactor|docs) ;;
  *) fail "commit type not allowed: $COMMIT_TYPE" ;;
esac

if [[ -n "$ALLOWLIST_FILE" && ! -f "$ALLOWLIST_FILE" ]]; then
  fail "allowlist file not found: $ALLOWLIST_FILE"
fi

COMMIT_MSG="$(printf '【%s】<%s> %s' "$REQ_SHORT" "$COMMIT_TYPE" "$COMMIT_DETAIL")"

REPO_LINES=""
while IFS= read -r line; do
  t="$(trim "$line")"
  [[ -n "$t" ]] && REPO_LINES="${REPO_LINES}${t}"$'\n'
done < <(tr ',' '\n' <<<"$REPOS_RAW")

[[ -n "$REPO_LINES" ]] || fail "no valid repos found"
REPO_LINES="$(printf '%s\n' "$REPO_LINES" | sed '/^$/d' | sort -u)"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STATE_SCRIPT="$SCRIPT_DIR/../../init/scripts/workflow_state.sh"
CLAIMS_SCRIPT="$SCRIPT_DIR/../../init/scripts/agent_claims.sh"

BASE_BRANCH=""
PREP_LINES=""
COMMITTED_LINES=""

# 1) preflight checks
while IFS= read -r repo; do
  [[ -z "$repo" ]] && continue
  [[ "$repo" = /* ]] || fail "repo path must be absolute: $repo"
  [[ -d "$repo" ]] || fail "repo not found: $repo"
  git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "not a git repo: $repo"

  branch="$(git -C "$repo" branch --show-current)"
  [[ -n "$branch" ]] || fail "detached HEAD not allowed: $repo"

  if [[ -z "$BASE_BRANCH" ]]; then
    BASE_BRANCH="$branch"
  else
    [[ "$branch" == "$BASE_BRANCH" ]] || fail "branch mismatch: $repo uses $branch, expected $BASE_BRANCH"
  fi

  bash "$STATE_SCRIPT" --repo "$repo" --requirement-key "$REQUIREMENT_KEY" --action assert --phase commit-code >/dev/null || fail "workflow phase is not commit-code for repo: $repo"
done <<<"$REPO_LINES"

# 2) stage all repos first (so we fail early before any commit)
while IFS= read -r repo; do
  [[ -z "$repo" ]] && continue

  branch="$(git -C "$repo" branch --show-current)"
  pre_head="$(git -C "$repo" rev-parse HEAD)"
  req_doc_path="docs/requirements/$REQUIREMENT_KEY"

  git -C "$repo" reset >/dev/null 2>&1 || true

  if [[ -d "$repo/$req_doc_path" ]]; then
    git -C "$repo" add -A "$req_doc_path"
  fi

  repo_allowlist="$repo/docs/requirements/$REQUIREMENT_KEY/commit-allowlist.txt"
  if [[ -n "$ALLOWLIST_FILE" ]]; then
    stage_by_allowlist "$repo" "$ALLOWLIST_FILE"
  elif [[ -f "$repo_allowlist" ]]; then
    stage_by_allowlist "$repo" "$repo_allowlist"
  elif [[ "$ALLOW_ALL_CHANGES" == "true" ]]; then
    git -C "$repo" add -A
  else
    fail "no allowlist for repo: $repo (expected $repo_allowlist), or pass --allow-all-changes"
  fi

  git -C "$repo" reset -- .DS_Store '*.swp' '*.tmp' '*.log' >/dev/null 2>&1 || true

  if git -C "$repo" diff --cached --quiet; then
    mode="skip"
  else
    mode="commit"
  fi

  PREP_LINES="${PREP_LINES}${repo}|${branch}|${mode}|${pre_head}"$'\n'
done <<<"$REPO_LINES"

rollback_committed() {
  [[ -z "$COMMITTED_LINES" ]] && return 0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    repo="${line%%|*}"
    prev_head="${line#*|}"
    git -C "$repo" reset --hard "$prev_head" >/dev/null 2>&1 || true
    git -C "$repo" reset >/dev/null 2>&1 || true
  done <<<"$COMMITTED_LINES"
}

# 3) commit repos marked commit
OUTPUT_LINES=""
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  repo="${line%%|*}"
  rest="${line#*|}"
  branch="${rest%%|*}"
  rest="${rest#*|}"
  mode="${rest%%|*}"
  pre_head="${rest##*|}"

  if [[ "$mode" == "skip" ]]; then
    continue
  fi

  if ! git -C "$repo" commit -m "$COMMIT_MSG" >/dev/null 2>&1; then
    rollback_committed
    fail "commit failed and rolled back committed repos: $repo"
  fi

  COMMITTED_LINES="${COMMITTED_LINES}${repo}|${pre_head}"$'\n'
  hash="$(git -C "$repo" rev-parse HEAD)"
  OUTPUT_LINES="${OUTPUT_LINES}${repo}|${branch}|${hash}|${COMMIT_MSG}"$'\n'
done <<<"$PREP_LINES"

# 4) mark done for all repos (including skip)
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  repo="${line%%|*}"
  rest="${line#*|}"
  branch="${rest%%|*}"
  rest="${rest#*|}"
  mode="${rest%%|*}"

  bash "$STATE_SCRIPT" --repo "$repo" --requirement-key "$REQUIREMENT_KEY" --action advance --phase done >/dev/null || fail "failed to advance workflow state to done: $repo"
  bash "$CLAIMS_SCRIPT" --repo "$repo" --requirement-key "$REQUIREMENT_KEY" --action archive-completed >/dev/null || true

  if [[ "$mode" == "skip" ]]; then
    OUTPUT_LINES="${OUTPUT_LINES}${repo}|${branch}|SKIPPED_NO_CHANGES|-"$'\n'
  fi

done <<<"$PREP_LINES"

echo "COMMIT_DONE"
printf '%s' "$OUTPUT_LINES" | sed '/^$/d'
