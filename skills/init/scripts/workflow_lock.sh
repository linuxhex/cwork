#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

REPO=""
REQUIREMENT_KEY=""
ACTION=""
OWNER=""
FORCE="false"
TTL_SECONDS="14400"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --requirement-key) REQUIREMENT_KEY="$2"; shift 2 ;;
    --action) ACTION="$2"; shift 2 ;;
    --owner) OWNER="$2"; shift 2 ;;
    --ttl-seconds) TTL_SECONDS="$2"; shift 2 ;;
    --force) FORCE="true"; shift 1 ;;
    *) fail "unknown argument: $1" ;;
  esac
done

[[ -n "$REPO" ]] || fail "--repo is required"
[[ -n "$REQUIREMENT_KEY" ]] || fail "--requirement-key is required"
[[ -n "$ACTION" ]] || fail "--action is required"
[[ "$REPO" = /* ]] || fail "--repo must be absolute"

[[ -n "$OWNER" ]] || OWNER="$(whoami)-$$"
[[ "$TTL_SECONDS" =~ ^[0-9]+$ ]] || fail "--ttl-seconds must be a non-negative integer"

REQ_DIR="$REPO/docs/requirements/$REQUIREMENT_KEY"
LOCK_DIR="$REQ_DIR/.workflow.lock"
LOCK_META="$LOCK_DIR/lock.json"
mkdir -p "$REQ_DIR"

now_iso() {
  date '+%Y-%m-%dT%H:%M:%S%z'
}

now_epoch() {
  date '+%s'
}

try_cleanup_expired_lock() {
  [[ -d "$LOCK_DIR" && -f "$LOCK_META" ]] || return 0
  lock_epoch="$(sed -n 's/^[[:space:]]*"acquired_epoch": "\([0-9]*\)".*/\1/p' "$LOCK_META" | head -n1)"
  lock_ttl="$(sed -n 's/^[[:space:]]*"ttl_seconds": "\([0-9]*\)".*/\1/p' "$LOCK_META" | head -n1)"

  [[ -n "$lock_epoch" ]] || return 0
  [[ -n "$lock_ttl" ]] || lock_ttl="$TTL_SECONDS"
  [[ "$lock_ttl" =~ ^[0-9]+$ ]] || lock_ttl="$TTL_SECONDS"
  [[ "$lock_ttl" -gt 0 ]] || return 0

  current_epoch="$(now_epoch)"
  age=$(( current_epoch - lock_epoch ))
  if [[ "$age" -ge "$lock_ttl" ]]; then
    rm -rf "$LOCK_DIR"
  fi
}

if [[ "$ACTION" == "acquire" ]]; then
  try_cleanup_expired_lock

  if mkdir "$LOCK_DIR" 2>/dev/null; then
    cat > "$LOCK_META" <<META
{
  "owner": "$OWNER",
  "pid": "$$",
  "acquired_at": "$(now_iso)",
  "acquired_epoch": "$(now_epoch)",
  "ttl_seconds": "$TTL_SECONDS"
}
META
    echo "LOCK_ACQUIRED"
    exit 0
  fi
  fail "lock already held: $LOCK_META"
fi

if [[ "$ACTION" == "status" ]]; then
  try_cleanup_expired_lock
  if [[ -d "$LOCK_DIR" ]]; then
    echo "LOCK_HELD"
    [[ -f "$LOCK_META" ]] && cat "$LOCK_META"
  else
    echo "LOCK_FREE"
  fi
  exit 0
fi

if [[ "$ACTION" == "renew" ]]; then
  try_cleanup_expired_lock
  [[ -d "$LOCK_DIR" ]] || fail "lock not held"
  [[ -f "$LOCK_META" ]] || fail "lock meta not found"

  current_owner="$(sed -n 's/^[[:space:]]*"owner": "\([^"]*\)".*/\1/p' "$LOCK_META" | head -n1)"
  [[ "$current_owner" == "$OWNER" ]] || fail "lock owner mismatch: held by $current_owner, current $OWNER"

  cat > "$LOCK_META" <<META
{
  "owner": "$OWNER",
  "pid": "$$",
  "acquired_at": "$(now_iso)",
  "acquired_epoch": "$(now_epoch)",
  "ttl_seconds": "$TTL_SECONDS"
}
META
  echo "LOCK_RENEWED"
  exit 0
fi

if [[ "$ACTION" == "release" ]]; then
  try_cleanup_expired_lock

  if [[ ! -d "$LOCK_DIR" ]]; then
    echo "LOCK_ALREADY_FREE"
    exit 0
  fi

  if [[ "$FORCE" == "true" ]]; then
    rm -rf "$LOCK_DIR"
    echo "LOCK_RELEASED_FORCE"
    exit 0
  fi

  if [[ ! -f "$LOCK_META" ]]; then
    rm -rf "$LOCK_DIR"
    echo "LOCK_RELEASED_NO_META"
    exit 0
  fi

  current_owner="$(sed -n 's/^[[:space:]]*"owner": "\([^"]*\)".*/\1/p' "$LOCK_META" | head -n1)"
  if [[ "$current_owner" != "$OWNER" ]]; then
    fail "lock owner mismatch: held by $current_owner, current $OWNER"
  fi

  rm -rf "$LOCK_DIR"
  echo "LOCK_RELEASED"
  exit 0
fi

fail "unknown action: $ACTION"
