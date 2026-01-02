#!/bin/bash
# Agent OS v4.5.5 - Execute Spec Operations Script
# Manages state machine for /execute-spec command
# Handles spec execution cycle: execute → review → merge → next wave

set -e

COMMAND="${1:-help}"
shift || true

# Robust project directory detection (same pattern as other scripts)
detect_project_dir() {
  if [ -n "$CLAUDE_PROJECT_DIR" ] && [ -d "$CLAUDE_PROJECT_DIR/.agent-os" ]; then
    echo "$CLAUDE_PROJECT_DIR"
    return
  fi

  if [ -d "./.agent-os" ]; then
    pwd
    return
  fi

  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local project_dir="${script_dir%/.claude/scripts}"
  if [ -d "$project_dir/.agent-os" ]; then
    echo "$project_dir"
    return
  fi

  local current="$(pwd)"
  while [ "$current" != "/" ]; do
    if [ -d "$current/.agent-os" ]; then
      echo "$current"
      return
    fi
    current="$(dirname "$current")"
  done

  pwd
}

PROJECT_DIR="$(detect_project_dir)"
STATE_DIR="$PROJECT_DIR/.agent-os/state"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Get state file path for a spec
get_state_file() {
  local spec_name="$1"
  echo "$STATE_DIR/execute-spec-${spec_name}.json"
}

# Find tasks.json for a spec
find_tasks_json() {
  local spec_name="$1"
  local base_path="$PROJECT_DIR/.agent-os/specs"

  if [ -n "$spec_name" ]; then
    # Try exact match first
    if [ -f "$base_path/$spec_name/tasks.json" ]; then
      echo "$base_path/$spec_name/tasks.json"
      return
    fi
    # Try with date prefix pattern
    local match=$(find "$base_path" -maxdepth 1 -type d -name "*-$spec_name" 2>/dev/null | head -1)
    if [ -n "$match" ] && [ -f "$match/tasks.json" ]; then
      echo "$match/tasks.json"
      return
    fi
  fi

  # Find first tasks.json
  find "$base_path" -name "tasks.json" -type f 2>/dev/null | head -1
}

# Get total waves from tasks.json
get_total_waves() {
  local tasks_file="$1"
  if [ ! -f "$tasks_file" ]; then
    echo "1"
    return
  fi
  local total
  total=$(jq -r '.execution_strategy.waves | length // 1' "$tasks_file" 2>/dev/null)
  echo "${total:-1}"
}

# Get current wave (first wave with pending tasks)
get_current_wave() {
  local tasks_file="$1"
  if [ ! -f "$tasks_file" ]; then
    echo "1"
    return
  fi

  local wave
  wave=$(jq -r '
    .execution_strategy.waves as $waves |
    .tasks as $tasks |
    ($waves // []) |
    map(select(
      .tasks as $wave_tasks |
      ($tasks | map(select(.id as $id | $wave_tasks | index($id))) | map(select(.status == "pending" or .status == "in_progress")) | length) > 0
    )) |
    .[0].wave_id // 1
  ' "$tasks_file" 2>/dev/null)

  echo "${wave:-1}"
}

case "$COMMAND" in

  # Initialize execution state for a spec
  # Usage: execute-spec-operations.sh init <spec_name> [--manual]
  init)
    SPEC_NAME="$1"
    MANUAL_MODE="false"

    # Parse flags
    for arg in "$@"; do
      case "$arg" in
        --manual) MANUAL_MODE="true" ;;
      esac
    done

    if [ -z "$SPEC_NAME" ]; then
      echo '{"error": "Usage: execute-spec-operations.sh init <spec_name> [--manual]"}'
      exit 1
    fi

    # Ensure state directory exists
    mkdir -p "$STATE_DIR"

    STATE_FILE=$(get_state_file "$SPEC_NAME")
    TASKS_FILE=$(find_tasks_json "$SPEC_NAME")

    if [ ! -f "$TASKS_FILE" ]; then
      echo '{"error": "tasks.json not found for spec: '"$SPEC_NAME"'"}'
      exit 1
    fi

    TOTAL_WAVES=$(get_total_waves "$TASKS_FILE")
    CURRENT_WAVE=$(get_current_wave "$TASKS_FILE")
    SPEC_PATH=$(dirname "$TASKS_FILE")
    TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # Normalize spec name (remove date prefix if present)
    NORMALIZED_SPEC=$(echo "$SPEC_NAME" | sed -E 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}-//')

    # Create initial state
    cat > "$STATE_FILE" << EOF
{
  "version": "1.0",
  "spec_name": "$SPEC_NAME",
  "spec_path": "$SPEC_PATH",
  "current_wave": $CURRENT_WAVE,
  "total_waves": $TOTAL_WAVES,
  "phase": "INIT",
  "pr_number": null,
  "pr_url": null,
  "wave_branch": "feature/$NORMALIZED_SPEC-wave-$CURRENT_WAVE",
  "base_branch": "feature/$NORMALIZED_SPEC",
  "is_final_wave": $([ "$CURRENT_WAVE" -eq "$TOTAL_WAVES" ] && echo "true" || echo "false"),
  "review_status": {
    "bot_reviewed": false,
    "last_check": null,
    "poll_count": 0,
    "review_decision": null,
    "blocking_count": 0,
    "future_items_count": 0,
    "future_items_captured": false
  },
  "execution_status": {
    "tasks_total": 0,
    "tasks_completed": 0,
    "tasks_failed": 0,
    "last_error": null
  },
  "history": [],
  "flags": {
    "manual_mode": $MANUAL_MODE,
    "poll_interval_ms": 120000,
    "max_poll_duration_ms": 1800000
  },
  "created_at": "$TIMESTAMP",
  "updated_at": "$TIMESTAMP",
  "session_id": null
}
EOF

    echo '{
      "success": true,
      "state_file": "'"$STATE_FILE"'",
      "spec_name": "'"$SPEC_NAME"'",
      "current_wave": '"$CURRENT_WAVE"',
      "total_waves": '"$TOTAL_WAVES"',
      "phase": "INIT",
      "manual_mode": '"$MANUAL_MODE"'
    }'
    ;;

  # Get current state
  # Usage: execute-spec-operations.sh status <spec_name>
  status)
    SPEC_NAME="$1"

    if [ -z "$SPEC_NAME" ]; then
      echo '{"error": "Usage: execute-spec-operations.sh status <spec_name>"}'
      exit 1
    fi

    STATE_FILE=$(get_state_file "$SPEC_NAME")

    if [ ! -f "$STATE_FILE" ]; then
      echo '{
        "exists": false,
        "spec_name": "'"$SPEC_NAME"'",
        "message": "No execution state found. Run init first."
      }'
      exit 0
    fi

    # Ensure flags object exists with defaults (defensive fix for malformed state files)
    # This handles state files that were manually modified or created by older versions
    jq '. + {exists: true} |
      .flags = (.flags // {}) |
      .flags.manual_mode = (.flags.manual_mode // false) |
      .flags.poll_interval_ms = (.flags.poll_interval_ms // 120000) |
      .flags.max_poll_duration_ms = (.flags.max_poll_duration_ms // 1800000)
    ' "$STATE_FILE"
    ;;

  # Transition to a new phase
  # Usage: execute-spec-operations.sh transition <spec_name> <new_phase> [data_json]
  transition)
    SPEC_NAME="$1"
    NEW_PHASE="$2"
    DATA_JSON="${3:-{}}"

    if [ -z "$SPEC_NAME" ] || [ -z "$NEW_PHASE" ]; then
      echo '{"error": "Usage: execute-spec-operations.sh transition <spec_name> <new_phase> [data_json]"}'
      exit 1
    fi

    STATE_FILE=$(get_state_file "$SPEC_NAME")

    if [ ! -f "$STATE_FILE" ]; then
      echo '{"error": "No state file found for spec: '"$SPEC_NAME"'. Run init first."}'
      exit 1
    fi

    # Validate phase
    case "$NEW_PHASE" in
      INIT|EXECUTE|AWAITING_REVIEW|REVIEW_PROCESSING|READY_TO_MERGE|COMPLETED|FAILED)
        ;;
      *)
        echo '{"error": "Invalid phase: '"$NEW_PHASE"'. Valid: INIT, EXECUTE, AWAITING_REVIEW, REVIEW_PROCESSING, READY_TO_MERGE, COMPLETED, FAILED"}'
        exit 1
        ;;
    esac

    TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    OLD_PHASE=$(jq -r '.phase' "$STATE_FILE")

    # Update state with new phase and any additional data
    jq --arg phase "$NEW_PHASE" --arg ts "$TIMESTAMP" --argjson data "$DATA_JSON" '
      .phase = $phase |
      .updated_at = $ts |
      . + $data
    ' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"

    echo '{
      "success": true,
      "old_phase": "'"$OLD_PHASE"'",
      "new_phase": "'"$NEW_PHASE"'",
      "spec_name": "'"$SPEC_NAME"'"
    }'
    ;;

  # Update review status
  # Usage: execute-spec-operations.sh update-review <spec_name> <review_data_json>
  update-review)
    SPEC_NAME="$1"
    REVIEW_DATA="$2"

    if [ -z "$SPEC_NAME" ] || [ -z "$REVIEW_DATA" ]; then
      echo '{"error": "Usage: execute-spec-operations.sh update-review <spec_name> <review_data_json>"}'
      exit 1
    fi

    STATE_FILE=$(get_state_file "$SPEC_NAME")

    if [ ! -f "$STATE_FILE" ]; then
      echo '{"error": "No state file found"}'
      exit 1
    fi

    TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    jq --arg ts "$TIMESTAMP" --argjson review "$REVIEW_DATA" '
      .review_status = (.review_status + $review + {last_check: $ts}) |
      .review_status.poll_count = ((.review_status.poll_count // 0) + 1) |
      .updated_at = $ts
    ' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"

    echo '{"success": true}'
    ;;

  # Set PR info after PR creation
  # Usage: execute-spec-operations.sh set-pr <spec_name> <pr_number> <pr_url>
  set-pr)
    SPEC_NAME="$1"
    PR_NUMBER="$2"
    PR_URL="$3"

    if [ -z "$SPEC_NAME" ] || [ -z "$PR_NUMBER" ]; then
      echo '{"error": "Usage: execute-spec-operations.sh set-pr <spec_name> <pr_number> [pr_url]"}'
      exit 1
    fi

    STATE_FILE=$(get_state_file "$SPEC_NAME")

    if [ ! -f "$STATE_FILE" ]; then
      echo '{"error": "No state file found"}'
      exit 1
    fi

    TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    jq --arg pr "$PR_NUMBER" --arg url "${PR_URL:-}" --arg ts "$TIMESTAMP" '
      .pr_number = ($pr | tonumber) |
      .pr_url = (if $url == "" then null else $url end) |
      .updated_at = $ts
    ' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"

    echo '{"success": true, "pr_number": '"$PR_NUMBER"'}'
    ;;

  # Advance to next wave after successful merge
  # Usage: execute-spec-operations.sh advance-wave <spec_name>
  advance-wave)
    SPEC_NAME="$1"

    if [ -z "$SPEC_NAME" ]; then
      echo '{"error": "Usage: execute-spec-operations.sh advance-wave <spec_name>"}'
      exit 1
    fi

    STATE_FILE=$(get_state_file "$SPEC_NAME")

    if [ ! -f "$STATE_FILE" ]; then
      echo '{"error": "No state file found"}'
      exit 1
    fi

    TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # Get current state
    CURRENT_WAVE=$(jq -r '.current_wave' "$STATE_FILE")
    TOTAL_WAVES=$(jq -r '.total_waves' "$STATE_FILE")
    PR_NUMBER=$(jq -r '.pr_number // "null"' "$STATE_FILE")
    PR_URL=$(jq -r '.pr_url // "null"' "$STATE_FILE")

    # Create history entry for completed wave
    HISTORY_ENTRY=$(jq -n \
      --arg wave "$CURRENT_WAVE" \
      --arg pr "$PR_NUMBER" \
      --arg url "$PR_URL" \
      --arg ts "$TIMESTAMP" \
      '{
        wave: ($wave | tonumber),
        pr_number: (if $pr == "null" then null else ($pr | tonumber) end),
        pr_url: (if $url == "null" then null else $url end),
        status: "merged",
        merged_at: $ts,
        branch_cleaned: false,
        review_cycles: 1
      }')

    NEXT_WAVE=$((CURRENT_WAVE + 1))

    # Check if spec is complete
    if [ "$NEXT_WAVE" -gt "$TOTAL_WAVES" ]; then
      # Spec completed!
      jq --arg ts "$TIMESTAMP" --argjson hist "$HISTORY_ENTRY" '
        .history += [$hist] |
        .phase = "COMPLETED" |
        .updated_at = $ts
      ' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"

      echo '{
        "success": true,
        "completed": true,
        "message": "Spec execution completed! All waves merged.",
        "total_waves": '"$TOTAL_WAVES"'
      }'
    else
      # Normalize spec name for branch naming
      NORMALIZED_SPEC=$(echo "$SPEC_NAME" | sed -E 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}-//')

      # Advance to next wave
      jq --arg ts "$TIMESTAMP" \
         --argjson hist "$HISTORY_ENTRY" \
         --argjson next "$NEXT_WAVE" \
         --argjson total "$TOTAL_WAVES" \
         --arg wb "feature/$NORMALIZED_SPEC-wave-$NEXT_WAVE" '
        .history += [$hist] |
        .current_wave = $next |
        .wave_branch = $wb |
        .is_final_wave = ($next == $total) |
        .phase = "EXECUTE" |
        .pr_number = null |
        .pr_url = null |
        .review_status = {
          bot_reviewed: false,
          last_check: null,
          poll_count: 0,
          review_decision: null,
          blocking_count: 0,
          future_items_count: 0,
          future_items_captured: false
        } |
        .execution_status = {
          tasks_total: 0,
          tasks_completed: 0,
          tasks_failed: 0,
          last_error: null
        } |
        .updated_at = $ts
      ' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"

      echo '{
        "success": true,
        "completed": false,
        "previous_wave": '"$CURRENT_WAVE"',
        "current_wave": '"$NEXT_WAVE"',
        "total_waves": '"$TOTAL_WAVES"',
        "is_final_wave": '$([ "$NEXT_WAVE" -eq "$TOTAL_WAVES" ] && echo "true" || echo "false")'
      }'
    fi
    ;;

  # Mark wave branch as cleaned
  # Usage: execute-spec-operations.sh mark-cleaned <spec_name> <wave_number>
  mark-cleaned)
    SPEC_NAME="$1"
    WAVE_NUMBER="$2"

    if [ -z "$SPEC_NAME" ] || [ -z "$WAVE_NUMBER" ]; then
      echo '{"error": "Usage: execute-spec-operations.sh mark-cleaned <spec_name> <wave_number>"}'
      exit 1
    fi

    STATE_FILE=$(get_state_file "$SPEC_NAME")

    if [ ! -f "$STATE_FILE" ]; then
      echo '{"error": "No state file found"}'
      exit 1
    fi

    TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    jq --arg wave "$WAVE_NUMBER" --arg ts "$TIMESTAMP" '
      .history = [.history[] | if .wave == ($wave | tonumber) then .branch_cleaned = true else . end] |
      .updated_at = $ts
    ' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"

    echo '{"success": true, "wave": '"$WAVE_NUMBER"', "branch_cleaned": true}'
    ;;

  # Record a failure
  # Usage: execute-spec-operations.sh fail <spec_name> <error_message>
  fail)
    SPEC_NAME="$1"
    ERROR_MSG="$2"

    if [ -z "$SPEC_NAME" ] || [ -z "$ERROR_MSG" ]; then
      echo '{"error": "Usage: execute-spec-operations.sh fail <spec_name> <error_message>"}'
      exit 1
    fi

    STATE_FILE=$(get_state_file "$SPEC_NAME")

    if [ ! -f "$STATE_FILE" ]; then
      echo '{"error": "No state file found"}'
      exit 1
    fi

    TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    jq --arg err "$ERROR_MSG" --arg ts "$TIMESTAMP" '
      .phase = "FAILED" |
      .execution_status.last_error = $err |
      .updated_at = $ts
    ' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"

    echo '{"success": true, "phase": "FAILED", "error": "'"$ERROR_MSG"'"}'
    ;;

  # Reset state for retry
  # Usage: execute-spec-operations.sh reset <spec_name>
  reset)
    SPEC_NAME="$1"

    if [ -z "$SPEC_NAME" ]; then
      echo '{"error": "Usage: execute-spec-operations.sh reset <spec_name>"}'
      exit 1
    fi

    STATE_FILE=$(get_state_file "$SPEC_NAME")

    if [ ! -f "$STATE_FILE" ]; then
      echo '{"error": "No state file found"}'
      exit 1
    fi

    TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # Reset to EXECUTE phase, keeping history
    jq --arg ts "$TIMESTAMP" '
      .phase = "EXECUTE" |
      .execution_status = {
        tasks_total: 0,
        tasks_completed: 0,
        tasks_failed: 0,
        last_error: null
      } |
      .review_status = {
        bot_reviewed: false,
        last_check: null,
        poll_count: 0,
        review_decision: null,
        blocking_count: 0,
        future_items_count: 0,
        future_items_captured: false
      } |
      .updated_at = $ts
    ' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"

    echo '{
      "success": true,
      "phase": "EXECUTE",
      "message": "State reset. Ready to retry current wave."
    }'
    ;;

  # Check if polling should continue
  # Usage: execute-spec-operations.sh check-poll-timeout <spec_name>
  check-poll-timeout)
    SPEC_NAME="$1"

    if [ -z "$SPEC_NAME" ]; then
      echo '{"error": "Usage: execute-spec-operations.sh check-poll-timeout <spec_name>"}'
      exit 1
    fi

    STATE_FILE=$(get_state_file "$SPEC_NAME")

    if [ ! -f "$STATE_FILE" ]; then
      echo '{"error": "No state file found"}'
      exit 1
    fi

    # Calculate elapsed time and remaining
    POLL_COUNT=$(jq -r '.review_status.poll_count // 0' "$STATE_FILE")
    POLL_INTERVAL=$(jq -r '.flags.poll_interval_ms // 120000' "$STATE_FILE")
    MAX_DURATION=$(jq -r '.flags.max_poll_duration_ms // 1800000' "$STATE_FILE")

    ELAPSED_MS=$((POLL_COUNT * POLL_INTERVAL))
    REMAINING_MS=$((MAX_DURATION - ELAPSED_MS))

    if [ "$REMAINING_MS" -le 0 ]; then
      echo '{
        "continue_polling": false,
        "reason": "timeout",
        "poll_count": '"$POLL_COUNT"',
        "elapsed_minutes": '"$((ELAPSED_MS / 60000))"',
        "message": "Polling timeout reached (30 minutes). Please check PR manually."
      }'
    else
      echo '{
        "continue_polling": true,
        "poll_count": '"$POLL_COUNT"',
        "elapsed_minutes": '"$((ELAPSED_MS / 60000))"',
        "remaining_minutes": '"$((REMAINING_MS / 60000))"'
      }'
    fi
    ;;

  # List all active spec executions
  # Usage: execute-spec-operations.sh list
  list)
    mkdir -p "$STATE_DIR"

    STATES=$(find "$STATE_DIR" -name "execute-spec-*.json" -type f 2>/dev/null)

    if [ -z "$STATES" ]; then
      echo '{"specs": [], "count": 0}'
      exit 0
    fi

    echo "$STATES" | while read -r state_file; do
      if [ -f "$state_file" ]; then
        jq '{
          spec_name,
          current_wave,
          total_waves,
          phase,
          pr_number,
          updated_at
        }' "$state_file"
      fi
    done | jq -s '{specs: ., count: length}'
    ;;

  # Delete state file (cleanup)
  # Usage: execute-spec-operations.sh delete <spec_name>
  delete)
    SPEC_NAME="$1"

    if [ -z "$SPEC_NAME" ]; then
      echo '{"error": "Usage: execute-spec-operations.sh delete <spec_name>"}'
      exit 1
    fi

    STATE_FILE=$(get_state_file "$SPEC_NAME")

    if [ -f "$STATE_FILE" ]; then
      rm -f "$STATE_FILE"
      echo '{"success": true, "deleted": "'"$STATE_FILE"'"}'
    else
      echo '{"success": true, "message": "No state file found to delete"}'
    fi
    ;;

  help|*)
    cat << 'EOF'
Agent OS v4.4.1 Execute Spec Operations

Manages the state machine for automated spec execution (/execute-spec command).

Usage: execute-spec-operations.sh <command> [args]

State Management:
  init <spec_name> [--manual]            Initialize execution state (default: background polling)
  status <spec_name>                     Get current execution state
  transition <spec> <phase> [data]       Transition to new phase
  reset <spec_name>                      Reset state for retry
  delete <spec_name>                     Delete state file

Phase Transitions:
  Phases: INIT → EXECUTE → AWAITING_REVIEW → REVIEW_PROCESSING → READY_TO_MERGE → (next wave or COMPLETED)
  Also: FAILED (from any phase)

PR & Review:
  set-pr <spec_name> <pr_num> [url]      Set PR info after creation
  update-review <spec> <review_json>     Update review status
  check-poll-timeout <spec_name>         Check if polling should continue

Wave Management:
  advance-wave <spec_name>               Advance to next wave after merge
  mark-cleaned <spec> <wave>             Mark wave branch as cleaned

Utilities:
  list                                   List all active spec executions

Examples:
  execute-spec-operations.sh init frontend-ui           # Background polling (default)
  execute-spec-operations.sh init frontend-ui --manual  # Manual polling mode
  execute-spec-operations.sh status frontend-ui
  execute-spec-operations.sh transition frontend-ui EXECUTE
  execute-spec-operations.sh set-pr frontend-ui 123 "https://github.com/.../pull/123"
  execute-spec-operations.sh update-review frontend-ui '{"bot_reviewed": true}'
  execute-spec-operations.sh advance-wave frontend-ui
  execute-spec-operations.sh reset frontend-ui
EOF
    ;;

esac
