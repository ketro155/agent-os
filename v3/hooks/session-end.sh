#!/bin/bash
# Agent OS v3.0 - Session End Hook
# Logs session summary to progress log
# Creates checkpoint for recovery

set -e

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
STATE_DIR="$PROJECT_DIR/.agent-os/state"
PROGRESS_DIR="$PROJECT_DIR/.agent-os/progress"

# 1. Read session state
SESSION_START=""
if [ -f "$STATE_DIR/session.json" ]; then
  SESSION_START=$(jq -r '.started_at' "$STATE_DIR/session.json" 2>/dev/null || echo "")
fi

# 2. Calculate session duration
if [ -n "$SESSION_START" ]; then
  START_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$SESSION_START" "+%s" 2>/dev/null || echo "0")
  END_EPOCH=$(date "+%s")
  DURATION_MINUTES=$(( (END_EPOCH - START_EPOCH) / 60 ))
else
  DURATION_MINUTES=0
fi

# 3. Get task progress
TASKS_COMPLETED=0
TASKS_FILE=$(find "$PROJECT_DIR/.agent-os/tasks" -name "tasks.json" -type f 2>/dev/null | head -1)
if [ -n "$TASKS_FILE" ] && [ -f "$TASKS_FILE" ]; then
  # Count tasks completed in this session (completed_at after session start)
  if [ -n "$SESSION_START" ]; then
    TASKS_COMPLETED=$(jq --arg start "$SESSION_START" '[.tasks[] | select(.completed_at != null and .completed_at > $start)] | length' "$TASKS_FILE" 2>/dev/null || echo "0")
  fi
fi

# 4. Append to progress log
if [ -f "$PROGRESS_DIR/progress.json" ]; then
  ENTRY_ID="entry-$(date +%Y%m%d-%H%M%S)-end"
  TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  # Create new entry
  NEW_ENTRY=$(cat << EOF
{
  "id": "$ENTRY_ID",
  "timestamp": "$TIMESTAMP",
  "type": "session_ended",
  "data": {
    "duration_minutes": $DURATION_MINUTES,
    "tasks_completed": $TASKS_COMPLETED,
    "notes": "Session ended normally"
  }
}
EOF
)

  # Append to progress.json
  jq --argjson entry "$NEW_ENTRY" '.entries += [$entry] | .metadata.last_updated = $entry.timestamp | .metadata.total_entries = (.entries | length)' \
    "$PROGRESS_DIR/progress.json" > "$PROGRESS_DIR/progress.json.tmp" && \
    mv "$PROGRESS_DIR/progress.json.tmp" "$PROGRESS_DIR/progress.json"
fi

# 5. Create checkpoint
mkdir -p "$STATE_DIR/checkpoints"
CHECKPOINT_FILE="$STATE_DIR/checkpoints/$(date +%Y%m%d-%H%M%S).json"

GIT_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "none")

cat > "$CHECKPOINT_FILE" << EOF
{
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "git_commit": "$GIT_COMMIT",
  "session_duration_minutes": $DURATION_MINUTES,
  "tasks_completed": $TASKS_COMPLETED
}
EOF

# 6. Cleanup old checkpoints (keep last 10)
ls -t "$STATE_DIR/checkpoints/"*.json 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true

# 7. Clear session state
rm -f "$STATE_DIR/session.json"

# 8. Output
cat << EOF
{
  "continue": true,
  "systemMessage": "Session logged: ${DURATION_MINUTES}min, ${TASKS_COMPLETED} tasks completed"
}
EOF
