#!/bin/bash
# Agent OS v5.5.0 - Stop Hook
# Fires when: Agent is about to stop (premature or normal)
# Purpose: Detect premature stops and log recovery info for interrupted work
# Input: Hook context JSON on stdin
# Output: {"continue": true} (observational — never blocks)

set -e

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
PROGRESS_FILE="$PROJECT_DIR/.agent-os/progress/progress.json"
SCRATCH_DIR="$PROJECT_DIR/.agent-os/scratch"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Read hook input from stdin
HOOK_INPUT=$(cat)
AGENT_TYPE=$(echo "$HOOK_INPUT" | jq -r '.agent_type // .type // "unknown"' 2>/dev/null)
AGENT_ID=$(echo "$HOOK_INPUT" | jq -r '.agent_id // .id // "unknown"' 2>/dev/null)
REASON=$(echo "$HOOK_INPUT" | jq -r '.reason // .stop_reason // "unknown"' 2>/dev/null)

# ═══════════════════════════════════════════════════════════════════════════════
# 1. CHECK FOR IN-PROGRESS TASKS
# ═══════════════════════════════════════════════════════════════════════════════

ACTIVE_TASK_ID=""
ACTIVE_TASK_DESC=""
SPEC_NAME=""

TASKS_FILE=$(find "$PROJECT_DIR/.agent-os/specs" -name "tasks.json" -type f 2>/dev/null | xargs ls -t 2>/dev/null | head -1)

if [ -n "$TASKS_FILE" ] && [ -f "$TASKS_FILE" ]; then
  ACTIVE_TASK_ID=$(jq -r '[.tasks[] | select(.status == "in_progress")] | first | .id // ""' "$TASKS_FILE" 2>/dev/null || echo "")
  ACTIVE_TASK_DESC=$(jq -r '[.tasks[] | select(.status == "in_progress")] | first | .description // ""' "$TASKS_FILE" 2>/dev/null || echo "")
  SPEC_NAME=$(jq -r '.spec // ""' "$TASKS_FILE" 2>/dev/null || echo "")
fi

# ═══════════════════════════════════════════════════════════════════════════════
# 2. LOG INTERRUPTION IF TASK WAS IN PROGRESS
# ═══════════════════════════════════════════════════════════════════════════════

if [ -n "$ACTIVE_TASK_ID" ] && [ "$ACTIVE_TASK_ID" != "" ] && [ "$ACTIVE_TASK_ID" != "null" ]; then
  # Append interrupted entry to progress.json
  if [ -f "$PROGRESS_FILE" ]; then
    ENTRY=$(jq -n \
      --arg ts "$TIMESTAMP" \
      --arg tid "$ACTIVE_TASK_ID" \
      --arg desc "$ACTIVE_TASK_DESC" \
      --arg agent "$AGENT_TYPE" \
      --arg reason "$REASON" \
      '{
        id: ("interrupted-" + $ts),
        timestamp: $ts,
        type: "interrupted",
        data: {
          task_id: $tid,
          description: $desc,
          agent: $agent,
          reason: $reason
        }
      }')

    jq --argjson e "$ENTRY" \
      '.entries += [$e] | .metadata.last_updated = $e.timestamp | .metadata.total_entries = (.entries | length)' \
      "$PROGRESS_FILE" > "${PROGRESS_FILE}.tmp" && mv "${PROGRESS_FILE}.tmp" "$PROGRESS_FILE"
  fi

  # Write recovery checkpoint for next session
  mkdir -p "$SCRATCH_DIR"
  GIT_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
  GIT_DIRTY=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')

  cat > "$SCRATCH_DIR/recovery-checkpoint.json" << EOF
{
  "created_at": "$TIMESTAMP",
  "interrupted_task": {
    "id": "$ACTIVE_TASK_ID",
    "description": "$ACTIVE_TASK_DESC",
    "spec": "$SPEC_NAME"
  },
  "agent": {
    "type": "$AGENT_TYPE",
    "id": "$AGENT_ID",
    "stop_reason": "$REASON"
  },
  "git_state": {
    "branch": "$GIT_BRANCH",
    "uncommitted_files": $GIT_DIRTY
  }
}
EOF
fi

# ═══════════════════════════════════════════════════════════════════════════════
# 3. OUTPUT (observational — never block)
# ═══════════════════════════════════════════════════════════════════════════════

echo '{"continue":true}'
