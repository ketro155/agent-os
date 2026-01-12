#!/bin/bash
# Agent OS v4.10.0 - SubagentStop Hook with Context Offloading
# Implements FewWord-inspired tiered output strategy
# - <512B: inline display
# - 512B-4KB: compact pointer (~35 tokens)
# - >4KB: pointer + failure preview
# Receives: AGENT_ID, AGENT_TRANSCRIPT_PATH, AGENT_RESULT from Claude Code

set -e

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
METRICS_DIR="$PROJECT_DIR/.agent-os/metrics"
TRANSCRIPTS_DIR="$METRICS_DIR/transcripts"
AGENTS_LOG="$METRICS_DIR/agents.jsonl"

# NEW: Scratch directory for offloaded outputs
SCRATCH_DIR="$PROJECT_DIR/.agent-os/scratch"
TOOL_OUTPUTS_DIR="$SCRATCH_DIR/tool_outputs"
OUTPUT_INDEX="$SCRATCH_DIR/index.jsonl"
SESSION_STATS="$SCRATCH_DIR/session_stats.json"

# Offloading thresholds (configurable via env)
INLINE_MAX=${AGENT_OS_INLINE_MAX:-512}        # <512B: inline
PREVIEW_MIN=${AGENT_OS_PREVIEW_MIN:-4096}     # >4KB: add preview for failures
PREVIEW_LINES=${AGENT_OS_PREVIEW_LINES:-5}    # Lines to show in preview

# Retention periods (in hours)
SUCCESS_RETENTION=${AGENT_OS_SUCCESS_RETENTION:-24}
FAILURE_RETENTION=${AGENT_OS_FAILURE_RETENTION:-48}

# Ensure directories exist
mkdir -p "$METRICS_DIR" "$TRANSCRIPTS_DIR" "$TOOL_OUTPUTS_DIR"

# Get agent info from environment (provided by Claude Code)
AGENT_ID="${AGENT_ID:-unknown}"
TRANSCRIPT_PATH="${AGENT_TRANSCRIPT_PATH:-}"
AGENT_RESULT="${AGENT_RESULT:-}"
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

# ═══════════════════════════════════════════════════════════════════════════════
# TIERED OUTPUT OFFLOADING
# ═══════════════════════════════════════════════════════════════════════════════

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

    # Set retention metadata
    if [ "$EXIT_CODE" -eq 0 ]; then
      RETENTION_HOURS=$SUCCESS_RETENTION
    else
      RETENTION_HOURS=$FAILURE_RETENTION
    fi
    EXPIRES_AT=$(date -u -v+${RETENTION_HOURS}H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "+${RETENTION_HOURS} hours" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "")

    # Log to index
    cat >> "$OUTPUT_INDEX" << EOF
{"id":"$OUTPUT_ID","agent_type":"$AGENT_TYPE","agent_id":"$AGENT_ID","size":$TRANSCRIPT_SIZE,"exit_code":$EXIT_CODE,"created_at":"$STOPPED_AT","expires_at":"$EXPIRES_AT","path":"$OUTPUT_FILE"}
EOF

    # Update LATEST symlinks
    ln -sf "$OUTPUT_FILE" "$TOOL_OUTPUTS_DIR/LATEST.txt" 2>/dev/null || true
    ln -sf "$OUTPUT_FILE" "$TOOL_OUTPUTS_DIR/LATEST_${AGENT_TYPE}.txt" 2>/dev/null || true

    # Build offload message based on tier
    HUMAN_SIZE=$(numfmt --to=iec-i --suffix=B "$TRANSCRIPT_SIZE" 2>/dev/null || echo "${TRANSCRIPT_SIZE}B")

    if [ "$TRANSCRIPT_SIZE" -le "$PREVIEW_MIN" ]; then
      # Tier 2: 512B-4KB - compact pointer only
      OFFLOAD_MSG="[Output offloaded: $HUMAN_SIZE → /context-read $OUTPUT_ID]"
    else
      # Tier 3: >4KB - pointer + preview for failures
      if [ "$EXIT_CODE" -ne 0 ]; then
        PREVIEW=$(tail -n "$PREVIEW_LINES" "$OUTPUT_FILE" | head -c 500)
        OFFLOAD_MSG="[Output offloaded: $HUMAN_SIZE → /context-read $OUTPUT_ID]\n---Preview (last $PREVIEW_LINES lines)---\n$PREVIEW\n---"
      else
        OFFLOAD_MSG="[Output offloaded: $HUMAN_SIZE → /context-read $OUTPUT_ID]"
      fi
    fi
  fi

  # Also copy to transcripts dir for debugging
  TRANSCRIPT_FILENAME="${AGENT_ID}-$(date +%Y%m%d-%H%M%S).txt"
  cp "$TRANSCRIPT_PATH" "$TRANSCRIPTS_DIR/$TRANSCRIPT_FILENAME" 2>/dev/null || true
fi

# ═══════════════════════════════════════════════════════════════════════════════
# UPDATE SESSION STATISTICS
# ═══════════════════════════════════════════════════════════════════════════════

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

# ═══════════════════════════════════════════════════════════════════════════════
# LOG AGENT STOP EVENT
# ═══════════════════════════════════════════════════════════════════════════════

cat >> "$AGENTS_LOG" << EOF
{"event":"stop","agent_id":"$AGENT_ID","agent_type":"$AGENT_TYPE","stopped_at":"$STOPPED_AT","duration_seconds":${DURATION:-null},"exit_code":$EXIT_CODE,"bytes_offloaded":$BYTES_OFFLOADED,"output_id":"$OUTPUT_ID"}
EOF

# ═══════════════════════════════════════════════════════════════════════════════
# CLEANUP: LRU eviction and expired files
# ═══════════════════════════════════════════════════════════════════════════════

# Clean up old transcripts (keep last 20)
TRANSCRIPT_COUNT=$(ls -1 "$TRANSCRIPTS_DIR" 2>/dev/null | wc -l | tr -d ' ')
if [ "$TRANSCRIPT_COUNT" -gt 20 ]; then
  ls -1t "$TRANSCRIPTS_DIR" | tail -n +21 | xargs -I{} rm "$TRANSCRIPTS_DIR/{}" 2>/dev/null || true
fi

# Clean up expired offloaded outputs
CURRENT_TIME=$(date +%s)
if [ -f "$OUTPUT_INDEX" ]; then
  while IFS= read -r line; do
    EXPIRES=$(echo "$line" | jq -r '.expires_at' 2>/dev/null)
    if [ -n "$EXPIRES" ] && [ "$EXPIRES" != "null" ]; then
      EXPIRE_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$EXPIRES" +%s 2>/dev/null || echo "0")
      if [ "$EXPIRE_EPOCH" -lt "$CURRENT_TIME" ]; then
        FILE_PATH=$(echo "$line" | jq -r '.path')
        rm -f "$FILE_PATH" 2>/dev/null || true
      fi
    fi
  done < "$OUTPUT_INDEX"
fi

# LRU eviction if scratch exceeds 250MB
SCRATCH_SIZE=$(du -sm "$SCRATCH_DIR" 2>/dev/null | cut -f1 || echo "0")
SCRATCH_MAX=${AGENT_OS_SCRATCH_MAX_MB:-250}
if [ "$SCRATCH_SIZE" -gt "$SCRATCH_MAX" ]; then
  # Delete oldest files until under limit
  while [ "$SCRATCH_SIZE" -gt "$SCRATCH_MAX" ]; do
    OLDEST=$(ls -1t "$TOOL_OUTPUTS_DIR"/*.txt 2>/dev/null | tail -1)
    if [ -n "$OLDEST" ] && [ -f "$OLDEST" ]; then
      rm -f "$OLDEST"
    else
      break
    fi
    SCRATCH_SIZE=$(du -sm "$SCRATCH_DIR" 2>/dev/null | cut -f1 || echo "0")
  done
fi

# ═══════════════════════════════════════════════════════════════════════════════
# BUILD RESPONSE
# ═══════════════════════════════════════════════════════════════════════════════

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
