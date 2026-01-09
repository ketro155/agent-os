#!/bin/bash
# Agent OS v4.8.0 - SubagentStart Hook
# Tracks subagent lifecycle for debugging and metrics
# Receives: AGENT_TYPE, AGENT_ID from Claude Code

set -e

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
METRICS_DIR="$PROJECT_DIR/.agent-os/metrics"
AGENTS_LOG="$METRICS_DIR/agents.jsonl"

# Ensure metrics directory exists
mkdir -p "$METRICS_DIR"

# Get agent info from environment (provided by Claude Code)
AGENT_TYPE="${AGENT_TYPE:-unknown}"
AGENT_ID="${AGENT_ID:-$(date +%s)}"
STARTED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Log agent start event (append to JSONL for analysis)
cat >> "$AGENTS_LOG" << EOF
{"event":"start","agent_type":"$AGENT_TYPE","agent_id":"$AGENT_ID","started_at":"$STARTED_AT"}
EOF

# Track active agents count
ACTIVE_COUNT=$(grep -c '"event":"start"' "$AGENTS_LOG" 2>/dev/null || echo "0")
STOPPED_COUNT=$(grep -c '"event":"stop"' "$AGENTS_LOG" 2>/dev/null || echo "0")
RUNNING_COUNT=$((ACTIVE_COUNT - STOPPED_COUNT))

# Build system message for subagent context
SYSTEM_MSG=""

# If this is a classification agent (haiku), note it's read-only
case "$AGENT_TYPE" in
  comment-classifier|future-classifier|roadmap-integrator)
    SYSTEM_MSG="[Classifier Agent] Read-only mode - analysis only, no file modifications."
    ;;
  phase2-implementation|subtask-group-worker)
    SYSTEM_MSG="[Implementation Agent] TDD workflow active - RED > GREEN > REFACTOR."
    ;;
  wave-lifecycle-agent|execute-spec-orchestrator)
    SYSTEM_MSG="[Orchestrator Agent] Multi-wave execution - track state carefully."
    ;;
  test-executor)
    SYSTEM_MSG="[Test Agent] Browser automation active - Chrome MCP tools available."
    ;;
  git-workflow)
    SYSTEM_MSG="[Git Agent] Branch/commit/PR operations - verify branch before actions."
    ;;
  *)
    SYSTEM_MSG="[Agent: $AGENT_TYPE] Started at $STARTED_AT"
    ;;
esac

# Return success with context
cat << EOF
{
  "continue": true,
  "systemMessage": "$SYSTEM_MSG | Running agents: $RUNNING_COUNT"
}
EOF
