#!/usr/bin/env bash
set -euo pipefail

fail(){ echo "ERROR: $*" >&2; exit 1; }
trim(){ local v="$1"; v="${v#"${v%%[![:space:]]*}"}"; v="${v%"${v##*[![:space:]]}"}"; printf '%s' "$v"; }

MAIN_DIR=""
DEPS_RAW=""
EXPECT_MULTI="true"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --main-dir) MAIN_DIR="$2"; shift 2 ;;
    --deps) DEPS_RAW="$2"; shift 2 ;;
    --expect-multi) EXPECT_MULTI="$2"; shift 2 ;;
    *) fail "unknown argument: $1" ;;
  esac
done

[[ -n "$MAIN_DIR" ]] || fail "--main-dir is required"
[[ "$MAIN_DIR" = /* ]] || fail "--main-dir must be absolute"
[[ -d "$MAIN_DIR" ]] || fail "main dir not found: $MAIN_DIR"

count=0
uniq_file="$(mktemp)"
trap 'rm -f "$uniq_file"' EXIT

printf '%s\n' "$MAIN_DIR" | sed '/^$/d' >> "$uniq_file"
count=1
if [[ -n "$DEPS_RAW" ]]; then
  while IFS= read -r dep; do
    dep="$(trim "$dep")"
    [[ -z "$dep" ]] && continue
    [[ "$dep" = /* ]] || fail "dep must be absolute: $dep"
    [[ -d "$dep" ]] || fail "dep dir not found: $dep"
    printf '%s\n' "$dep" >> "$uniq_file"
    count=$((count+1))
  done < <(tr ',' '\n' <<<"$DEPS_RAW")
fi

uniq_count="$(sort -u "$uniq_file" | wc -l | tr -d ' ')"
[[ "$uniq_count" == "$count" ]] || fail "duplicate repos found in main/deps"

if [[ "$EXPECT_MULTI" == "true" ]]; then
  dep_count=$((count-1))
  [[ "$dep_count" -ge 1 ]] || fail "microservice workflow expects at least 1 dependency repo"
fi

echo "MICROSERVICE_SCOPE_OK"
echo "TOTAL_REPOS=$count"
