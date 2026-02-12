#!/bin/bash
# Agent OS v5.3.0 - TeammateIdle Hook
# Fires when: A teammate goes idle (between turns)
# Input: Hook context JSON on stdin
# Purpose: Track teammate lifecycle metrics for debugging slow waves
set -e

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
METRICS_DIR="$PROJECT_DIR/.agent-os/metrics"
AGENTS_LOG="$METRICS_DIR/agents.jsonl"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Ensure metrics directory exists
mkdir -p "$METRICS_DIR"

# Read hook input from stdin
HOOK_INPUT=$(cat)
AGENT_NAME=$(echo "$HOOK_INPUT" | jq -r '.agent_name // .name // "unknown"' 2>/dev/null)
TEAM_NAME=$(echo "$HOOK_INPUT" | jq -r '.team_name // ""' 2>/dev/null)

# Log idle event to agents.jsonl
jq -n --arg ts "$TIMESTAMP" --arg name "$AGENT_NAME" --arg team "$TEAM_NAME" \
  '{event:"teammate_idle",timestamp:$ts,agent:$name,team:$team}' >> "$AGENTS_LOG"

# Output (compact, non-blocking)
echo "{\"continue\":true}"
