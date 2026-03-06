#!/bin/bash
# Agent OS v5.5.0 - Pre-Compact Hook
# Fires when: Context window compaction is about to occur
# Purpose: Inject critical context so compaction preserves essential state
# Input: Hook context JSON on stdin
# Output: {"additionalContext": "..."} with task state, wave progress, decisions

set -e

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
PROGRESS_FILE="$PROJECT_DIR/.agent-os/progress/progress.json"
EXECUTION_STATE="$PROJECT_DIR/.agent-os/state/execution-state.json"
DECISIONS_LOG="$PROJECT_DIR/.agent-os/logs/decisions-log.md"

# Read hook input from stdin
HOOK_INPUT=$(cat)

# ═══════════════════════════════════════════════════════════════════════════════
# 1. CURRENT TASK STATE
# ═══════════════════════════════════════════════════════════════════════════════

TASK_INFO=""
if [ -f "$PROGRESS_FILE" ]; then
  # Get the most recent task-related entry
  LATEST_TASK=$(jq -r '
    [.entries[] | select(.type == "task_completed" or .type == "task_started" or .type == "interrupted")]
    | last
    | if . then "\(.type): \(.data.task_id // "unknown") - \(.data.description // "")" else "" end
  ' "$PROGRESS_FILE" 2>/dev/null || echo "")

  if [ -n "$LATEST_TASK" ] && [ "$LATEST_TASK" != "" ] && [ "$LATEST_TASK" != "null" ]; then
    TASK_INFO="$LATEST_TASK"
  fi
fi

# Also check tasks.json for in-progress tasks (more reliable than progress.json)
TASKS_FILE=$(find "$PROJECT_DIR/.agent-os/specs" -name "tasks.json" -type f 2>/dev/null | xargs ls -t 2>/dev/null | head -1)
ACTIVE_TASK=""
WAVE_PROGRESS=""

if [ -n "$TASKS_FILE" ] && [ -f "$TASKS_FILE" ]; then
  ACTIVE_TASK=$(jq -r '
    [.tasks[] | select(.status == "in_progress")]
    | first
    | if . then "Task \(.id): \(.description)" else "" end
  ' "$TASKS_FILE" 2>/dev/null || echo "")

  # Compute wave progress from summary and execution_strategy
  WAVE_PROGRESS=$(jq -r '
    if .execution_strategy.waves then
      (.execution_strategy.waves | length) as $total_waves |
      ([.tasks[] | select(.status == "pass" or .status == "completed")] | length) as $done |
      (.summary.total_tasks // (.tasks | length)) as $total |
      "Wave progress: \($done)/\($total) tasks across \($total_waves) waves (\(.summary.overall_percent // 0)%)"
    else
      "\(.summary.overall_percent // 0)% complete (\(.summary.completed // 0)/\(.summary.total_tasks // 0) tasks)"
    end
  ' "$TASKS_FILE" 2>/dev/null || echo "")
fi

# ═══════════════════════════════════════════════════════════════════════════════
# 2. ACTIVE SPEC
# ═══════════════════════════════════════════════════════════════════════════════

SPEC_NAME=""
if [ -f "$EXECUTION_STATE" ]; then
  SPEC_NAME=$(jq -r '.spec_name // .active_spec // ""' "$EXECUTION_STATE" 2>/dev/null || echo "")
fi

# Fallback: derive from tasks.json path
if [ -z "$SPEC_NAME" ] && [ -n "$TASKS_FILE" ]; then
  SPEC_NAME=$(basename "$(dirname "$TASKS_FILE")" 2>/dev/null || echo "")
fi

# ═══════════════════════════════════════════════════════════════════════════════
# 3. RECENT DECISIONS (last 3 entries from decisions-log.md)
# ═══════════════════════════════════════════════════════════════════════════════

DECISIONS=""
if [ -f "$DECISIONS_LOG" ]; then
  # Extract last 3 decision entries (lines starting with "## " are decision headers)
  DECISIONS=$(grep -E "^## " "$DECISIONS_LOG" 2>/dev/null | tail -3 | sed 's/^## //' | tr '\n' '; ' | sed 's/; $//')
fi

# ═══════════════════════════════════════════════════════════════════════════════
# 4. BUILD additionalContext
# ═══════════════════════════════════════════════════════════════════════════════

CONTEXT_PARTS=()

if [ -n "$SPEC_NAME" ] && [ "$SPEC_NAME" != "" ] && [ "$SPEC_NAME" != "null" ]; then
  CONTEXT_PARTS+=("Spec: $SPEC_NAME")
fi

if [ -n "$ACTIVE_TASK" ] && [ "$ACTIVE_TASK" != "" ] && [ "$ACTIVE_TASK" != "null" ]; then
  CONTEXT_PARTS+=("Active: $ACTIVE_TASK")
elif [ -n "$TASK_INFO" ] && [ "$TASK_INFO" != "" ]; then
  CONTEXT_PARTS+=("Last: $TASK_INFO")
fi

if [ -n "$WAVE_PROGRESS" ] && [ "$WAVE_PROGRESS" != "" ] && [ "$WAVE_PROGRESS" != "null" ]; then
  CONTEXT_PARTS+=("$WAVE_PROGRESS")
fi

if [ -n "$DECISIONS" ]; then
  CONTEXT_PARTS+=("Key decisions: $DECISIONS")
fi

# Join parts with " | "
ADDITIONAL_CONTEXT=""
for i in "${!CONTEXT_PARTS[@]}"; do
  if [ "$i" -eq 0 ]; then
    ADDITIONAL_CONTEXT="${CONTEXT_PARTS[$i]}"
  else
    ADDITIONAL_CONTEXT="$ADDITIONAL_CONTEXT | ${CONTEXT_PARTS[$i]}"
  fi
done

# ═══════════════════════════════════════════════════════════════════════════════
# 5. OUTPUT
# ═══════════════════════════════════════════════════════════════════════════════

if [ -n "$ADDITIONAL_CONTEXT" ]; then
  # Escape for JSON
  ADDITIONAL_CONTEXT=$(echo "$ADDITIONAL_CONTEXT" | jq -Rs '.' | sed 's/^"//;s/"$//')
  cat << EOF
{"additionalContext": "[Agent OS Pre-Compact] $ADDITIONAL_CONTEXT"}
EOF
else
  echo "{}"
fi
