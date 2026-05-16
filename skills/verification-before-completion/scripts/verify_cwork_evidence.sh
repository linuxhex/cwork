#!/usr/bin/env bash
set -euo pipefail

fail(){ echo "ERROR: $*" >&2; exit 1; }
trim(){ local v="$1"; v="${v#"${v%%[![:space:]]*}"}"; v="${v%"${v##*[![:space:]]}"}"; printf '%s' "$v"; }

MAIN_DIR=""
DEPS_RAW=""
REQUIREMENT_KEY=""
EXPECT_PHASE="commit-code"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --main-dir) MAIN_DIR="$2"; shift 2 ;;
    --deps) DEPS_RAW="$2"; shift 2 ;;
    --requirement-key) REQUIREMENT_KEY="$2"; shift 2 ;;
    --expect-phase) EXPECT_PHASE="$2"; shift 2 ;;
    *) fail "unknown argument: $1" ;;
  esac
done

[[ -n "$MAIN_DIR" ]] || fail "--main-dir is required"
[[ -n "$REQUIREMENT_KEY" ]] || fail "--requirement-key is required"
[[ "$MAIN_DIR" = /* ]] || fail "--main-dir must be absolute"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STATE_SCRIPT="$SCRIPT_DIR/../../init/scripts/workflow_state.sh"
COMMIT_READINESS="$SCRIPT_DIR/../../commit-code/scripts/validate_commit_readiness.sh"

check_repo_docs(){
  local repo="$1"
  local req_dir="$repo/docs/requirements/$REQUIREMENT_KEY"
  [[ -d "$req_dir" ]] || fail "missing requirement dir: $req_dir"
  for f in 00-context.md 01-analysis.md 02-plan.md 03-changes.md; do
    [[ -f "$req_dir/$f" ]] || fail "missing file: $req_dir/$f"
  done
  [[ -f "$req_dir/workflow-state.json" ]] || fail "missing workflow state: $req_dir/workflow-state.json"
  [[ -f "$req_dir/agent-claims.json" ]] || fail "missing claims: $req_dir/agent-claims.json"
}

repos="$MAIN_DIR"
check_repo_docs "$MAIN_DIR"

if [[ -n "$DEPS_RAW" ]]; then
  while IFS= read -r dep; do
    dep="$(trim "$dep")"
    [[ -z "$dep" ]] && continue
    repos="$repos,$dep"

    dep_req_dir="$dep/docs/requirements/$REQUIREMENT_KEY"
    [[ -d "$dep_req_dir" ]] || fail "missing dependency requirement dir: $dep_req_dir"
    for f in 00-repo-context.md 01-repo-analysis.md 02-repo-plan.md 03-repo-changes.md; do
      [[ -f "$dep_req_dir/$f" ]] || fail "missing file: $dep_req_dir/$f"
    done
    [[ -f "$dep_req_dir/workflow-state.json" ]] || fail "missing workflow state: $dep_req_dir/workflow-state.json"
  done < <(tr ',' '\n' <<<"$DEPS_RAW")
fi

# phase assertions
while IFS= read -r repo; do
  repo="$(trim "$repo")"
  [[ -z "$repo" ]] && continue
  bash "$STATE_SCRIPT" --repo "$repo" --requirement-key "$REQUIREMENT_KEY" --action assert --phase "$EXPECT_PHASE" >/dev/null || fail "phase assert failed for $repo expect=$EXPECT_PHASE"
done < <(tr ',' '\n' <<<"$repos")

# minimal loop evidence in main repo
round_count="$(find "$MAIN_DIR/docs/requirements/$REQUIREMENT_KEY/process" -maxdepth 1 -type f -name 'round-*.md' 2>/dev/null | wc -l | tr -d ' ')"
if [[ "$round_count" -eq 0 ]]; then
  fail "no loop-refined round evidence under process/round-*.md"
fi

if [[ "$EXPECT_PHASE" == "commit-code" ]]; then
  bash "$COMMIT_READINESS" --repos "$repos" --requirement-key "$REQUIREMENT_KEY" >/dev/null
fi

echo "VERIFICATION_EVIDENCE_OK"
echo "REPOS=$repos"
echo "ROUND_FILES=$round_count"
