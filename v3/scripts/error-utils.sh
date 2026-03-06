#!/bin/bash
# Agent OS v5.5.0 - Centralized error handling utilities
# Source this file: source "${CLAUDE_PROJECT_DIR}/.claude/scripts/error-utils.sh"

# error_tier <code> - Returns tier name for an error code
error_tier() {
  case "${1:0:2}" in
    E0) echo "TRANSIENT" ;; E1) echo "RECOVERABLE" ;;
    E2) echo "FATAL" ;; E3) echo "RECOVERABLE" ;; *) echo "FATAL" ;;
  esac
}

# classify_error [message] - Returns error code (reads stdin if no arg)
classify_error() {
  local msg; msg="$(echo "${1:-$(cat)}" | tr '[:upper:]' '[:lower:]')"
  case "$msg" in
    *e2e*timeout*)                        echo "E301" ;;
    *e2e*network*)                        echo "E304" ;;
    *"element not found"*|*selector*)     echo "E302" ;;
    *browser*crash*|*browser*disconnect*) echo "E303" ;;
    *scenario*fail*)                      echo "E300" ;;
    *timeout*|*etimedout*)                echo "E001" ;;
    *"rate limit"*|*429*)                 echo "E002" ;;
    *ebusy*|*locked*)                     echo "E003" ;;
    *"protected branch"*)                 echo "E201" ;;
    *authentication*)                     echo "E200" ;;
    *eacces*|*permission*)                echo "E205" ;;
    *enoent*|*"not found"*)               echo "E100" ;;
    *conflict*)                           echo "E107" ;;
    *test*fail*)                          echo "E101" ;;
    *build*fail*)                         echo "E102" ;;
    *)                                    echo "E206" ;;
  esac
}

# log_error <code> <agent> <operation> [details] - Structured JSON error to stderr
log_error() {
  local code="$1" agent="$2" operation="$3" details="${4:-}" tier msg ts
  tier="$(error_tier "$code")"
  ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  declare -A _msgs=(
    [E001]="Network request timed out" [E002]="API rate limit exceeded"
    [E003]="File is locked by another process" [E004]="Git temporary conflict"
    [E005]="Subprocess execution timed out" [E100]="Required file not found"
    [E101]="Test execution failed" [E102]="Build process failed"
    [E103]="Input validation failed" [E104]="Required dependency not available"
    [E105]="Predecessor artifact not found" [E106]="Configuration invalid or missing"
    [E107]="Git merge conflict requires resolution" [E108]="PR requires review"
    [E109]="Task blocked by unresolved dependency" [E200]="Authentication failed"
    [E201]="Cannot modify protected branch" [E202]="Data schema incompatible"
    [E203]="Data corruption detected" [E204]="System resources exhausted"
    [E205]="Operation not permitted" [E206]="System in invalid state"
    [E300]="E2E test scenario failed" [E301]="E2E test scenario timed out"
    [E302]="Target element not found in E2E test" [E303]="Browser connection lost"
    [E304]="Network request failed in E2E test"
  )
  msg="${_msgs[$code]:-System in invalid state}"
  printf '{"code":"%s","tier":"%s","message":"%s","agent":"%s","operation":"%s","timestamp":"%s","details":"%s"}\n' \
    "$code" "$tier" "$msg" "$agent" "$operation" "$ts" "$details" >&2
}
