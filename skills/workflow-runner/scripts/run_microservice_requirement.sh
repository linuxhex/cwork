#!/usr/bin/env bash
set -euo pipefail

fail(){ echo "ERROR: $*" >&2; exit 1; }

MAIN_DIR=""
DEPS_RAW=""
REQUIREMENT_KEY=""
FEATURE_BRANCH=""
OWNER=""
AUTO_PHASE="true"
AUTO_COMMIT="false"
REQ_SHORT=""
COMMIT_TYPE=""
COMMIT_DETAIL=""
ALLOW_ALL_CHANGES="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --main-dir) MAIN_DIR="$2"; shift 2 ;;
    --deps) DEPS_RAW="$2"; shift 2 ;;
    --requirement-key) REQUIREMENT_KEY="$2"; shift 2 ;;
    --feature-branch) FEATURE_BRANCH="$2"; shift 2 ;;
    --owner) OWNER="$2"; shift 2 ;;
    --auto-phase) AUTO_PHASE="$2"; shift 2 ;;
    --auto-commit) AUTO_COMMIT="$2"; shift 2 ;;
    --requirement-short) REQ_SHORT="$2"; shift 2 ;;
    --commit-type) COMMIT_TYPE="$2"; shift 2 ;;
    --commit-detail) COMMIT_DETAIL="$2"; shift 2 ;;
    --allow-all-changes) ALLOW_ALL_CHANGES="true"; shift 1 ;;
    *) fail "unknown argument: $1" ;;
  esac
done

[[ -n "$MAIN_DIR" ]] || fail "--main-dir is required"
[[ -n "$REQUIREMENT_KEY" ]] || fail "--requirement-key is required"
[[ "$MAIN_DIR" = /* ]] || fail "--main-dir must be absolute"

[[ -n "$OWNER" ]] || OWNER="$(whoami)-workflow-$$"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INIT_SCRIPTS="$SCRIPT_DIR/../../init/scripts"
COMMIT_SCRIPTS="$SCRIPT_DIR/../../commit-code/scripts"

bash "$INIT_SCRIPTS/validate_microservice_scope.sh" --main-dir "$MAIN_DIR" --deps "$DEPS_RAW" --expect-multi true
bash "$INIT_SCRIPTS/generate_service_manifest.sh" --main-dir "$MAIN_DIR" --requirement-key "$REQUIREMENT_KEY" --deps "$DEPS_RAW" --feature-branch "$FEATURE_BRANCH"

if [[ "$AUTO_PHASE" == "true" ]]; then
  bash "$INIT_SCRIPTS/run_cwork_pipeline.sh" \
    --main-dir "$MAIN_DIR" \
    --deps "$DEPS_RAW" \
    --requirement-key "$REQUIREMENT_KEY" \
    --owner "$OWNER" \
    --from-phase brainstorming \
    --to-phase commit-code
fi

if [[ "$AUTO_COMMIT" == "true" ]]; then
  [[ -n "$REQ_SHORT" ]] || fail "--requirement-short is required when --auto-commit true"
  [[ -n "$COMMIT_TYPE" ]] || fail "--commit-type is required when --auto-commit true"
  [[ -n "$COMMIT_DETAIL" ]] || fail "--commit-detail is required when --auto-commit true"

  repos="$MAIN_DIR"
  if [[ -n "$DEPS_RAW" ]]; then
    repos="$repos,$DEPS_RAW"
  fi

  bash "$COMMIT_SCRIPTS/validate_commit_readiness.sh" --repos "$repos" --requirement-key "$REQUIREMENT_KEY"

  cmd=(bash "$COMMIT_SCRIPTS/commit_all_related_repos.sh"
    --repos "$repos"
    --requirement-short "$REQ_SHORT"
    --requirement-key "$REQUIREMENT_KEY"
    --commit-type "$COMMIT_TYPE"
    --commit-detail "$COMMIT_DETAIL")

  if [[ "$ALLOW_ALL_CHANGES" == "true" ]]; then
    cmd+=(--allow-all-changes)
  fi

  "${cmd[@]}"
fi

echo "WORKFLOW_RUNNER_DONE"
