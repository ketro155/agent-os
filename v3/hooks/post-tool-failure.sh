#!/bin/bash
# Agent OS v5.5.0 - PostToolFailure Hook
# Fires when: A tool call fails
# Purpose: Track tool failures for debugging flaky operations
# Input: Hook context JSON on stdin (tool_name, error, etc.)
# Output: {"continue": true} (observational — never blocks)

set -e

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
METRICS_DIR="$PROJECT_DIR/.agent-os/metrics"
FAILURES_LOG="$METRICS_DIR/tool-failures.jsonl"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Ensure metrics directory exists
mkdir -p "$METRICS_DIR"

# Read hook input from stdin
HOOK_INPUT=$(cat)
TOOL_NAME=$(echo "$HOOK_INPUT" | jq -r '.tool_name // .name // "unknown"' 2>/dev/null)
ERROR_MSG=$(echo "$HOOK_INPUT" | jq -r '.error // .error_message // .message // ""' 2>/dev/null)
AGENT_TYPE=$(echo "$HOOK_INPUT" | jq -r '.agent_type // .type // ""' 2>/dev/null)

# Truncate error message to prevent unbounded log growth (max 500 chars)
if [ ${#ERROR_MSG} -gt 500 ]; then
  ERROR_MSG="${ERROR_MSG:0:500}...[truncated]"
fi

# Append structured JSON line to tool-failures.jsonl
jq -n -c \
  --arg ts "$TIMESTAMP" \
  --arg tool "$TOOL_NAME" \
  --arg err "$ERROR_MSG" \
  --arg agent "$AGENT_TYPE" \
  '{timestamp:$ts,tool_name:$tool,error_message:$err,agent_type:$agent}' \
  >> "$FAILURES_LOG"

# Output (observational — never block)
echo '{"continue":true}'
