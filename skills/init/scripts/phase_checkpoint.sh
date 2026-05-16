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

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SYNC_SCRIPT="$SCRIPT_DIR/sync_requirement_docs.sh"
STATE_SCRIPT="$SCRIPT_DIR/workflow_state.sh"
LOCK_SCRIPT="$SCRIPT_DIR/workflow_lock.sh"
CLAIMS_SCRIPT="$SCRIPT_DIR/agent_claims.sh"

MAIN_DIR=""
REQUIREMENT_KEY=""
PHASE=""
DEPS_RAW=""
OWNER=""
LOCK_TTL_SECONDS="14400"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --main-dir) MAIN_DIR="$2"; shift 2 ;;
    --requirement-key) REQUIREMENT_KEY="$2"; shift 2 ;;
    --phase) PHASE="$2"; shift 2 ;;
    --deps) DEPS_RAW="$2"; shift 2 ;;
    --owner) OWNER="$2"; shift 2 ;;
    --lock-ttl-seconds) LOCK_TTL_SECONDS="$2"; shift 2 ;;
    *) fail "unknown argument: $1" ;;
  esac
done

[[ -n "$MAIN_DIR" ]] || fail "--main-dir is required"
[[ -n "$REQUIREMENT_KEY" ]] || fail "--requirement-key is required"
[[ -n "$PHASE" ]] || fail "--phase is required"
[[ "$MAIN_DIR" = /* ]] || fail "--main-dir must be absolute"
[[ -d "$MAIN_DIR" ]] || fail "main dir not found: $MAIN_DIR"
[[ -n "$OWNER" ]] || OWNER="$(whoami)-$$"
[[ "$LOCK_TTL_SECONDS" =~ ^[0-9]+$ ]] || fail "--lock-ttl-seconds must be non-negative integer"

DEP_LINES=""
if [[ -n "$DEPS_RAW" ]]; then
  while IFS= read -r line; do
    t="$(trim "$line")"
    [[ -n "$t" ]] && DEP_LINES="${DEP_LINES}${t}"$'\n'
  done < <(tr ',' '\n' <<<"$DEPS_RAW")
fi

ALL_REPO_LINES="$MAIN_DIR"$'\n'"$DEP_LINES"
SORTED_REPOS="$(printf '%s\n' "$ALL_REPO_LINES" | sed '/^$/d' | sort -u)"
LOCKED_LINES=""
ADVANCED_LINES=""

release_all() {
  if [[ -n "$LOCKED_LINES" ]]; then
    while IFS= read -r repo; do
      [[ -z "$repo" ]] && continue
      bash "$LOCK_SCRIPT" --repo "$repo" --requirement-key "$REQUIREMENT_KEY" --action release --owner "$OWNER" --ttl-seconds "$LOCK_TTL_SECONDS" >/dev/null 2>&1 || true
    done <<<"$LOCKED_LINES"
  fi
}

rollback_advanced() {
  if [[ -z "$ADVANCED_LINES" ]]; then
    return 0
  fi

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    repo="${line%%|*}"
    rest="${line#*|}"
    prev_phase="${rest%%|*}"
    post_version="${rest##*|}"

    bash "$STATE_SCRIPT" --repo "$repo" --requirement-key "$REQUIREMENT_KEY" --action force-set --phase "$prev_phase" --expect-version "$post_version" >/dev/null 2>&1 || true
  done <<<"$ADVANCED_LINES"
}

trap release_all EXIT

# 1) acquire locks in deterministic order
while IFS= read -r repo; do
  [[ -z "$repo" ]] && continue
  bash "$LOCK_SCRIPT" --repo "$repo" --requirement-key "$REQUIREMENT_KEY" --action acquire --owner "$OWNER" --ttl-seconds "$LOCK_TTL_SECONDS" >/dev/null
  LOCKED_LINES="${LOCKED_LINES}${repo}"$'\n'
done <<<"$SORTED_REPOS"

# 2) preflight transition checks and capture versions
CHECK_LINES=""
while IFS= read -r repo; do
  [[ -z "$repo" ]] && continue
  bash "$STATE_SCRIPT" --repo "$repo" --requirement-key "$REQUIREMENT_KEY" --action can-advance --phase "$PHASE" >/dev/null
  prev_phase="$(bash "$STATE_SCRIPT" --repo "$repo" --requirement-key "$REQUIREMENT_KEY" --action get)"
  prev_version="$(bash "$STATE_SCRIPT" --repo "$repo" --requirement-key "$REQUIREMENT_KEY" --action get-version)"
  CHECK_LINES="${CHECK_LINES}${repo}|${prev_phase}|${prev_version}"$'\n'
done <<<"$SORTED_REPOS"

# 3) sync first, then advance state
case "$PHASE" in
  brainstorming|writing-plans|executing-plans|loop-refined|commit-code)
    bash "$SYNC_SCRIPT" --main-dir "$MAIN_DIR" --requirement-key "$REQUIREMENT_KEY" --deps "$DEPS_RAW"
    ;;
  *) ;;
esac

# heartbeat once before state write
while IFS= read -r repo; do
  [[ -z "$repo" ]] && continue
  bash "$LOCK_SCRIPT" --repo "$repo" --requirement-key "$REQUIREMENT_KEY" --action renew --owner "$OWNER" --ttl-seconds "$LOCK_TTL_SECONDS" >/dev/null || true
done <<<"$SORTED_REPOS"

# 4) advance with CAS
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  repo="${line%%|*}"
  rest="${line#*|}"
  prev_phase="${rest%%|*}"
  prev_version="${rest##*|}"

  result="$(bash "$STATE_SCRIPT" --repo "$repo" --requirement-key "$REQUIREMENT_KEY" --action advance --phase "$PHASE" --expect-version "$prev_version")" || {
    rollback_advanced
    fail "phase advance failed for repo: $repo"
  }

  post_version="${result##*:}"
  if [[ "$post_version" == "$result" ]]; then
    post_version="$(bash "$STATE_SCRIPT" --repo "$repo" --requirement-key "$REQUIREMENT_KEY" --action get-version)"
  fi

  bash "$CLAIMS_SCRIPT" --repo "$repo" --requirement-key "$REQUIREMENT_KEY" --action archive-completed >/dev/null || true
  ADVANCED_LINES="${repo}|${prev_phase}|${post_version}"$'\n'"$ADVANCED_LINES"
done <<<"$CHECK_LINES"

echo "CHECKPOINT_DONE"
