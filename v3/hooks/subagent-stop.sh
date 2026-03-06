#!/bin/bash
# Agent OS v5.5.0 - SubagentStop Hook
# Simplified offloading (PreCompact hook handles context preservation)
# - >512B: offload to scratch with compact pointer
# - Expired cleanup via find (cross-platform)
# Input: Hook context JSON on stdin

set -e

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
METRICS_DIR="$PROJECT_DIR/.agent-os/metrics"
TRANSCRIPTS_DIR="$METRICS_DIR/transcripts"
AGENTS_LOG="$METRICS_DIR/agents.jsonl"

# Scratch directory for offloaded outputs
SCRATCH_DIR="$PROJECT_DIR/.agent-os/scratch"
TOOL_OUTPUTS_DIR="$SCRATCH_DIR/tool_outputs"
OUTPUT_INDEX="$SCRATCH_DIR/index.jsonl"
SESSION_STATS="$SCRATCH_DIR/session_stats.json"

# Offloading threshold (configurable via env)
INLINE_MAX=${AGENT_OS_INLINE_MAX:-512}

# Retention period (in hours) — applies to all offloaded files
FAILURE_RETENTION=${AGENT_OS_FAILURE_RETENTION:-48}

# Ensure directories exist
mkdir -p "$METRICS_DIR" "$TRANSCRIPTS_DIR" "$TOOL_OUTPUTS_DIR"

# Read hook input from stdin (Claude Code passes context as JSON)
HOOK_INPUT=$(cat)
AGENT_ID=$(echo "$HOOK_INPUT" | jq -r '.agent_id // .id // "unknown"' 2>/dev/null)
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path // .agent_transcript_path // ""' 2>/dev/null)
AGENT_RESULT=$(echo "$HOOK_INPUT" | jq -r '.result // .agent_result // ""' 2>/dev/null)
STOPPED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Determine exit status from result (success if contains "completed" or no error)
EXIT_CODE=0
if echo "$AGENT_RESULT" | grep -qiE 'error|failed|blocked|exception'; then
  EXIT_CODE=1
fi

# Calculate duration if we can find the start time
DURATION=""
AGENT_TYPE="unknown"
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
  AGENT_TYPE=$(grep "\"agent_id\":\"$AGENT_ID\"" "$AGENTS_LOG" | grep '"event":"start"' | tail -1 | jq -r '.agent_type' 2>/dev/null || echo "unknown")
fi

# ===============================================================================
# OUTPUT OFFLOADING (single tier: offload everything > INLINE_MAX)
# ===============================================================================

OFFLOAD_MSG=""
BYTES_OFFLOADED=0
OUTPUT_ID=""

# Process transcript if available
if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
  TRANSCRIPT_SIZE=$(stat -f%z "$TRANSCRIPT_PATH" 2>/dev/null || stat -c%s "$TRANSCRIPT_PATH" 2>/dev/null || echo "0")

  if [ "$TRANSCRIPT_SIZE" -gt "$INLINE_MAX" ]; then
    # Generate output ID
    OUTPUT_ID="${AGENT_TYPE}_$(date +%Y%m%d_%H%M%S)_${AGENT_ID}_exit${EXIT_CODE}"
    OUTPUT_FILE="$TOOL_OUTPUTS_DIR/${OUTPUT_ID}.txt"

    # Redact secrets if script exists
    REDACT_SCRIPT="$PROJECT_DIR/.claude/scripts/redact-secrets.sh"
    if [ -x "$REDACT_SCRIPT" ]; then
      cat "$TRANSCRIPT_PATH" | "$REDACT_SCRIPT" > "$OUTPUT_FILE"
    else
      cp "$TRANSCRIPT_PATH" "$OUTPUT_FILE"
    fi

    BYTES_OFFLOADED=$TRANSCRIPT_SIZE

    # Log to index
    cat >> "$OUTPUT_INDEX" << EOF
{"id":"$OUTPUT_ID","agent_type":"$AGENT_TYPE","agent_id":"$AGENT_ID","size":$TRANSCRIPT_SIZE,"exit_code":$EXIT_CODE,"created_at":"$STOPPED_AT","path":"$OUTPUT_FILE"}
EOF

    # Update LATEST symlinks
    ln -sf "$OUTPUT_FILE" "$TOOL_OUTPUTS_DIR/LATEST.txt" 2>/dev/null || true
    ln -sf "$OUTPUT_FILE" "$TOOL_OUTPUTS_DIR/LATEST_${AGENT_TYPE}.txt" 2>/dev/null || true

    # Build offload message
    HUMAN_SIZE=$(numfmt --to=iec-i --suffix=B "$TRANSCRIPT_SIZE" 2>/dev/null || echo "${TRANSCRIPT_SIZE}B")
    OFFLOAD_MSG="[Output offloaded: $HUMAN_SIZE → /context-read $OUTPUT_ID]"
  fi

  # Also copy to transcripts dir for debugging
  TRANSCRIPT_FILENAME="${AGENT_ID}-$(date +%Y%m%d-%H%M%S).txt"
  cp "$TRANSCRIPT_PATH" "$TRANSCRIPTS_DIR/$TRANSCRIPT_FILENAME" 2>/dev/null || true
fi

# ===============================================================================
# UPDATE SESSION STATISTICS
# ===============================================================================

# Initialize or update session stats
if [ -f "$SESSION_STATS" ]; then
  CURRENT_OFFLOADED=$(jq -r '.bytes_offloaded // 0' "$SESSION_STATS")
  CURRENT_COUNT=$(jq -r '.offload_count // 0' "$SESSION_STATS")
  NEW_OFFLOADED=$((CURRENT_OFFLOADED + BYTES_OFFLOADED))
  NEW_COUNT=$((CURRENT_COUNT + (BYTES_OFFLOADED > 0 ? 1 : 0)))

  # Estimate tokens saved (~4 chars per token)
  TOKENS_SAVED=$((NEW_OFFLOADED / 4))

  jq --arg bytes "$NEW_OFFLOADED" --arg count "$NEW_COUNT" --arg tokens "$TOKENS_SAVED" \
    '.bytes_offloaded = ($bytes | tonumber) | .offload_count = ($count | tonumber) | .estimated_tokens_saved = ($tokens | tonumber)' \
    "$SESSION_STATS" > "${SESSION_STATS}.tmp" && mv "${SESSION_STATS}.tmp" "$SESSION_STATS"
else
  TOKENS_SAVED=$((BYTES_OFFLOADED / 4))
  cat > "$SESSION_STATS" << EOF
{
  "session_started": "$STOPPED_AT",
  "bytes_offloaded": $BYTES_OFFLOADED,
  "offload_count": $((BYTES_OFFLOADED > 0 ? 1 : 0)),
  "estimated_tokens_saved": $TOKENS_SAVED
}
EOF
fi

# ===============================================================================
# LOG AGENT STOP EVENT
# ===============================================================================

cat >> "$AGENTS_LOG" << EOF
{"event":"stop","agent_id":"$AGENT_ID","agent_type":"$AGENT_TYPE","stopped_at":"$STOPPED_AT","duration_seconds":${DURATION:-null},"exit_code":$EXIT_CODE,"bytes_offloaded":$BYTES_OFFLOADED,"output_id":"$OUTPUT_ID"}
EOF

# ===============================================================================
# CLEANUP: time-based expiry
# ===============================================================================

# Clean up old transcripts (keep last 20)
TRANSCRIPT_COUNT=$(ls -1 "$TRANSCRIPTS_DIR" 2>/dev/null | wc -l | tr -d ' ')
if [ "$TRANSCRIPT_COUNT" -gt 20 ]; then
  ls -1t "$TRANSCRIPTS_DIR" | tail -n +21 | xargs -I{} rm "$TRANSCRIPTS_DIR/{}" 2>/dev/null || true
fi

# Clean up offloaded outputs older than FAILURE_RETENTION hours (cross-platform)
RETENTION_MINUTES=$((FAILURE_RETENTION * 60))
find "$TOOL_OUTPUTS_DIR" -name "*.txt" -not -name "LATEST*.txt" -mmin +$RETENTION_MINUTES -delete 2>/dev/null || true

# ===============================================================================
# BUILD RESPONSE
# ===============================================================================

TOTAL_AGENTS=$(grep -c '"event":"start"' "$AGENTS_LOG" 2>/dev/null || echo "0")
COMPLETED_AGENTS=$(grep -c '"event":"stop"' "$AGENTS_LOG" 2>/dev/null || echo "0")

if [ -n "$DURATION" ]; then
  DURATION_MSG="${DURATION}s"
else
  DURATION_MSG="unknown"
fi

# Build system message
SYS_MSG="[Agent Complete] $AGENT_ID ($AGENT_TYPE) - Duration: $DURATION_MSG | Session: $COMPLETED_AGENTS agents"

if [ -n "$OFFLOAD_MSG" ]; then
  SYS_MSG="$SYS_MSG\n$OFFLOAD_MSG"
fi

# Add token savings summary if significant
if [ -f "$SESSION_STATS" ]; then
  TOTAL_SAVED=$(jq -r '.estimated_tokens_saved // 0' "$SESSION_STATS")
  if [ "$TOTAL_SAVED" -gt 1000 ]; then
    SYS_MSG="$SYS_MSG\n[Context Efficiency] ~${TOTAL_SAVED} tokens saved via offloading"
  fi
fi

# Return success
cat << EOF
{
  "continue": true,
  "systemMessage": "$SYS_MSG"
}
EOF
