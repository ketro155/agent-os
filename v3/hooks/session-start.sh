#!/bin/bash
# Agent OS v3.0 - Session Start Hook
# Replaces: session-startup skill
# Runs automatically when a Claude Code session starts

set -e

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
STATE_DIR="$PROJECT_DIR/.agent-os/state"
PROGRESS_DIR="$PROJECT_DIR/.agent-os/progress"

# CRITICAL: Persist CLAUDE_PROJECT_DIR for all subsequent Bash commands
# CLAUDE_ENV_FILE is sourced before every Bash tool call, making this variable
# available in commands like /execute-tasks that reference it
if [ -n "$CLAUDE_ENV_FILE" ] && [ -n "$CLAUDE_PROJECT_DIR" ]; then
  echo "export CLAUDE_PROJECT_DIR=\"$CLAUDE_PROJECT_DIR\"" >> "$CLAUDE_ENV_FILE"
fi

# Initialize output
OUTPUT='{}'

# 1. Verify Agent OS installation
if [ ! -d "$PROJECT_DIR/.agent-os" ]; then
  OUTPUT=$(echo "$OUTPUT" | jq '. + {"agent_os_installed": false, "systemMessage": "Agent OS not installed in this project. Run setup/project.sh to install."}')
  echo "$OUTPUT"
  exit 0
fi

# 2. Load recent progress (cross-session memory)
RECENT_PROGRESS=""
if [ -f "$PROGRESS_DIR/progress.json" ]; then
  RECENT_PROGRESS=$(jq -r '.entries[-3:] | map("\(.type): \(.data.description // .data.notes // "")") | join("; ")' "$PROGRESS_DIR/progress.json" 2>/dev/null || echo "")
fi

# 3. Check for active tasks
ACTIVE_TASK=""
TASK_CONTEXT=""
# Find most recently modified tasks.json (handles multiple specs)
TASKS_FILE=$(find "$PROJECT_DIR/.agent-os/specs" -name "tasks.json" -type f 2>/dev/null | xargs ls -t 2>/dev/null | head -1)

if [ -n "$TASKS_FILE" ] && [ -f "$TASKS_FILE" ]; then
  # Find in-progress or next pending task
  ACTIVE_TASK=$(jq -r '.tasks[] | select(.status == "in_progress") | "\(.id): \(.description)"' "$TASKS_FILE" 2>/dev/null | head -1)

  if [ -z "$ACTIVE_TASK" ]; then
    ACTIVE_TASK=$(jq -r '.tasks[] | select(.status == "pending" and .type == "subtask") | "\(.id): \(.description)"' "$TASKS_FILE" 2>/dev/null | head -1)
  fi

  # Get summary
  TASK_CONTEXT=$(jq -r '"Spec: \(.spec) | Progress: \(.summary.overall_percent)% (\(.summary.completed)/\(.summary.total_tasks) tasks)"' "$TASKS_FILE" 2>/dev/null || echo "")
fi

# 4. Check git state
GIT_BRANCH=$(git branch --show-current 2>/dev/null || echo "not a git repo")
GIT_STATUS=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
GIT_UNCOMMITTED="$GIT_STATUS uncommitted changes"

# 5. Build system message for Claude
SYSTEM_MSG=""

if [ -n "$RECENT_PROGRESS" ]; then
  SYSTEM_MSG="**Recent Progress**: $RECENT_PROGRESS\n"
fi

if [ -n "$TASK_CONTEXT" ]; then
  SYSTEM_MSG="${SYSTEM_MSG}**Task Context**: $TASK_CONTEXT\n"
fi

if [ -n "$ACTIVE_TASK" ]; then
  SYSTEM_MSG="${SYSTEM_MSG}**Active/Next Task**: $ACTIVE_TASK\n"
fi

SYSTEM_MSG="${SYSTEM_MSG}**Git**: $GIT_BRANCH ($GIT_UNCOMMITTED)"

# 6. Write session state
mkdir -p "$STATE_DIR"
cat > "$STATE_DIR/session.json" << EOF
{
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "git_branch": "$GIT_BRANCH",
  "active_task": "$ACTIVE_TASK",
  "progress_loaded": true
}
EOF

# 7. Output for Claude Code
cat << EOF
{
  "continue": true,
  "systemMessage": "$SYSTEM_MSG"
}
EOF
