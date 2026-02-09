#!/bin/bash
# Agent OS v4.12.0 - TaskCompleted Hook
# Fires when: TaskUpdate sets status to "completed"
# Input: Hook context JSON on stdin
set -e

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
PROGRESS_FILE="$PROJECT_DIR/.agent-os/progress/progress.json"
STATS_FILE="$PROJECT_DIR/.agent-os/scratch/session_stats.json"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Read hook input from stdin (Claude Code passes context as JSON)
HOOK_INPUT=$(cat)
TASK_ID=$(echo "$HOOK_INPUT" | jq -r '.task_id // .taskId // "unknown"' 2>/dev/null)
TASK_SUBJECT=$(echo "$HOOK_INPUT" | jq -r '.task_subject // .subject // ""' 2>/dev/null)

# 1. Append to progress.json (if exists)
if [ -f "$PROGRESS_FILE" ]; then
  ENTRY=$(jq -n --arg ts "$TIMESTAMP" --arg tid "$TASK_ID" --arg desc "$TASK_SUBJECT" \
    '{id:("task-complete-"+$ts),timestamp:$ts,type:"task_completed",data:{task_id:$tid,description:$desc}}')
  jq --argjson e "$ENTRY" '.entries+=[$e]|.metadata.last_updated=$e.timestamp|.metadata.total_entries=(.entries|length)' \
    "$PROGRESS_FILE" > "${PROGRESS_FILE}.tmp" && mv "${PROGRESS_FILE}.tmp" "$PROGRESS_FILE"
fi

# 2. Increment session stats
if [ -f "$STATS_FILE" ]; then
  jq '.tasks_completed=((.tasks_completed//0)+1)' "$STATS_FILE" > "${STATS_FILE}.tmp" && mv "${STATS_FILE}.tmp" "$STATS_FILE"
fi

# 3. Output (compact)
echo "{\"continue\":true}"
