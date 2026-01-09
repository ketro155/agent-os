#!/bin/bash
# Agent OS v4.8.0 - SubagentStop Hook
# Captures subagent completion for debugging and metrics
# Receives: AGENT_ID, AGENT_TRANSCRIPT_PATH from Claude Code

set -e

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
METRICS_DIR="$PROJECT_DIR/.agent-os/metrics"
TRANSCRIPTS_DIR="$METRICS_DIR/transcripts"
AGENTS_LOG="$METRICS_DIR/agents.jsonl"

# Ensure directories exist
mkdir -p "$METRICS_DIR" "$TRANSCRIPTS_DIR"

# Get agent info from environment (provided by Claude Code)
AGENT_ID="${AGENT_ID:-unknown}"
TRANSCRIPT_PATH="${AGENT_TRANSCRIPT_PATH:-}"
STOPPED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Calculate duration if we can find the start time
DURATION=""
if [ -f "$AGENTS_LOG" ]; then
  START_TIME=$(grep "\"agent_id\":\"$AGENT_ID\"" "$AGENTS_LOG" | grep '"event":"start"' | tail -1 | jq -r '.started_at' 2>/dev/null || echo "")
  if [ -n "$START_TIME" ]; then
    # Convert to epoch for duration calculation (macOS compatible)
    START_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$START_TIME" +%s 2>/dev/null || echo "")
    END_EPOCH=$(date +%s)
    if [ -n "$START_EPOCH" ]; then
      DURATION=$((END_EPOCH - START_EPOCH))
    fi
  fi

  # Get agent type from start record
  AGENT_TYPE=$(grep "\"agent_id\":\"$AGENT_ID\"" "$AGENTS_LOG" | grep '"event":"start"' | tail -1 | jq -r '.agent_type' 2>/dev/null || echo "unknown")
fi

# Log agent stop event
cat >> "$AGENTS_LOG" << EOF
{"event":"stop","agent_id":"$AGENT_ID","agent_type":"${AGENT_TYPE:-unknown}","stopped_at":"$STOPPED_AT","duration_seconds":${DURATION:-null},"transcript_path":"$TRANSCRIPT_PATH"}
EOF

# Copy transcript for debugging if path provided and file exists
if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
  TRANSCRIPT_FILENAME="${AGENT_ID}-$(date +%Y%m%d-%H%M%S).txt"
  cp "$TRANSCRIPT_PATH" "$TRANSCRIPTS_DIR/$TRANSCRIPT_FILENAME" 2>/dev/null || true
fi

# Update metrics summary
TOTAL_AGENTS=$(grep -c '"event":"start"' "$AGENTS_LOG" 2>/dev/null || echo "0")
COMPLETED_AGENTS=$(grep -c '"event":"stop"' "$AGENTS_LOG" 2>/dev/null || echo "0")

# Clean up old transcripts (keep last 20)
TRANSCRIPT_COUNT=$(ls -1 "$TRANSCRIPTS_DIR" 2>/dev/null | wc -l | tr -d ' ')
if [ "$TRANSCRIPT_COUNT" -gt 20 ]; then
  ls -1t "$TRANSCRIPTS_DIR" | tail -n +21 | xargs -I{} rm "$TRANSCRIPTS_DIR/{}" 2>/dev/null || true
fi

# Build completion message
if [ -n "$DURATION" ]; then
  DURATION_MSG="${DURATION}s"
else
  DURATION_MSG="unknown"
fi

# Return success
cat << EOF
{
  "continue": true,
  "systemMessage": "[Agent Complete] $AGENT_ID (${AGENT_TYPE:-unknown}) - Duration: $DURATION_MSG | Session total: $COMPLETED_AGENTS agents"
}
EOF
