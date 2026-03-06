#!/bin/bash
# Agent OS v5.5.0 - UserPromptSubmit Hook
# Fires when: User submits a prompt
# Purpose: Inject brief active task context into every user prompt
# Input: Hook context JSON on stdin
# Output: {"additionalContext": "..."} or {} if no active task
# IMPORTANT: Keep injection SHORT (< 200 chars) to avoid prompt bloat

set -e

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# Read hook input from stdin
HOOK_INPUT=$(cat)

# ═══════════════════════════════════════════════════════════════════════════════
# FIND ACTIVE TASK
# ═══════════════════════════════════════════════════════════════════════════════

TASKS_FILE=$(find "$PROJECT_DIR/.agent-os/specs" -name "tasks.json" -type f 2>/dev/null | xargs ls -t 2>/dev/null | head -1)

if [ -z "$TASKS_FILE" ] || [ ! -f "$TASKS_FILE" ]; then
  echo "{}"
  exit 0
fi

# Get the first in-progress task
ACTIVE=$(jq -r '
  [.tasks[] | select(.status == "in_progress")] | first |
  if . then "\(.id)|\(.description)" else "" end
' "$TASKS_FILE" 2>/dev/null || echo "")

if [ -z "$ACTIVE" ] || [ "$ACTIVE" = "" ] || [ "$ACTIVE" = "null" ]; then
  echo "{}"
  exit 0
fi

TASK_ID=$(echo "$ACTIVE" | cut -d'|' -f1)
TASK_DESC=$(echo "$ACTIVE" | cut -d'|' -f2-)

# Truncate description to keep total under 200 chars
MAX_DESC_LEN=120
if [ ${#TASK_DESC} -gt $MAX_DESC_LEN ]; then
  TASK_DESC="${TASK_DESC:0:$MAX_DESC_LEN}..."
fi

# Get wave info (compact)
WAVE_INFO=$(jq -r '
  if .execution_strategy.waves then
    (.execution_strategy.waves | length) as $total |
    ([.execution_strategy.waves[] | select(.tasks[] as $t | .tasks[] as $t2 | false) ] | length) as $dummy |
    "(\($total) waves)"
  else "" end
' "$TASKS_FILE" 2>/dev/null || echo "")

# Build compact context string
CONTEXT="[Agent OS] Active: Task $TASK_ID -- $TASK_DESC"
if [ -n "$WAVE_INFO" ] && [ "$WAVE_INFO" != "" ] && [ "$WAVE_INFO" != "null" ]; then
  CONTEXT="$CONTEXT $WAVE_INFO"
fi

# Escape for JSON output
CONTEXT=$(echo "$CONTEXT" | jq -Rs '.' | sed 's/^"//;s/"$//')

cat << EOF
{"additionalContext": "$CONTEXT"}
EOF
