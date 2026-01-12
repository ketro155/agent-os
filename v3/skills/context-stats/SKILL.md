---
name: context-stats
description: Display context efficiency statistics - tokens saved, outputs offloaded, storage usage.
version: 1.0.0
---

# Context Stats Skill

Displays statistics about context offloading efficiency for the current session.

## Usage

```
/context-stats            # Show session statistics
```

## Instructions

1. **Read session statistics** from `.agent-os/scratch/session_stats.json`
2. **Calculate storage usage** from scratch directory
3. **List recent offloaded outputs** from index
4. **Display summary**

## Implementation

Execute this bash command to gather stats:

```bash
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
SCRATCH_DIR="$PROJECT_DIR/.agent-os/scratch"
STATS_FILE="$SCRATCH_DIR/session_stats.json"
INDEX_FILE="$SCRATCH_DIR/index.jsonl"
OUTPUTS_DIR="$SCRATCH_DIR/tool_outputs"

echo "═══════════════════════════════════════════════════════════════"
echo "                  CONTEXT EFFICIENCY REPORT                     "
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Session statistics
if [ -f "$STATS_FILE" ]; then
  BYTES=$(jq -r '.bytes_offloaded // 0' "$STATS_FILE")
  COUNT=$(jq -r '.offload_count // 0' "$STATS_FILE")
  TOKENS=$(jq -r '.estimated_tokens_saved // 0' "$STATS_FILE")
  STARTED=$(jq -r '.session_started // "unknown"' "$STATS_FILE")

  # Human-readable bytes
  if [ "$BYTES" -gt 1048576 ]; then
    HUMAN_BYTES="$(echo "scale=2; $BYTES / 1048576" | bc)MB"
  elif [ "$BYTES" -gt 1024 ]; then
    HUMAN_BYTES="$(echo "scale=2; $BYTES / 1024" | bc)KB"
  else
    HUMAN_BYTES="${BYTES}B"
  fi

  echo "📊 Session Statistics"
  echo "   Started:        $STARTED"
  echo "   Outputs:        $COUNT offloaded"
  echo "   Data Saved:     $HUMAN_BYTES"
  echo "   Tokens Saved:   ~$TOKENS (estimated)"
  echo ""
else
  echo "📊 No session statistics yet (no outputs offloaded)"
  echo ""
fi

# Storage usage
if [ -d "$OUTPUTS_DIR" ]; then
  STORAGE=$(du -sh "$SCRATCH_DIR" 2>/dev/null | cut -f1)
  FILE_COUNT=$(ls -1 "$OUTPUTS_DIR"/*.txt 2>/dev/null | wc -l | tr -d ' ')
  echo "💾 Storage"
  echo "   Scratch Size:   $STORAGE / 250MB limit"
  echo "   Output Files:   $FILE_COUNT"
  echo ""
fi

# Recent outputs
if [ -f "$INDEX_FILE" ]; then
  echo "📁 Recent Offloaded Outputs"
  echo "   ─────────────────────────────────────────────────────────"
  tail -5 "$INDEX_FILE" | while read line; do
    ID=$(echo "$line" | jq -r '.id')
    TYPE=$(echo "$line" | jq -r '.agent_type')
    SIZE=$(echo "$line" | jq -r '.size')
    EXIT=$(echo "$line" | jq -r '.exit_code')

    # Human readable size
    if [ "$SIZE" -gt 1024 ]; then
      HSIZE="$(echo "scale=1; $SIZE / 1024" | bc)KB"
    else
      HSIZE="${SIZE}B"
    fi

    # Status icon
    if [ "$EXIT" = "0" ]; then
      ICON="✓"
    else
      ICON="✗"
    fi

    printf "   %s %-50s %8s %s\n" "$ICON" "$ID" "$HSIZE" "$TYPE"
  done
  echo ""
fi

echo "═══════════════════════════════════════════════════════════════"
echo "Commands: /context-read <id> | /context-search <term>"
echo "═══════════════════════════════════════════════════════════════"
```

## Response Format

Display the statistics in a clear, formatted way:

```
═══════════════════════════════════════════════════════════════
                  CONTEXT EFFICIENCY REPORT
═══════════════════════════════════════════════════════════════

📊 Session Statistics
   Started:        2026-01-12T14:30:00Z
   Outputs:        8 offloaded
   Data Saved:     145KB
   Tokens Saved:   ~36,250 (estimated)

💾 Storage
   Scratch Size:   2.1M / 250MB limit
   Output Files:   8

📁 Recent Offloaded Outputs
   ─────────────────────────────────────────────────────────
   ✓ phase2_20260112_143022_exit0                    12.5KB phase2-implementation
   ✗ phase2_20260112_143522_exit1                    45.2KB phase2-implementation
   ✓ wave-orchestrator_20260112_144001_exit0          8.3KB wave-orchestrator

═══════════════════════════════════════════════════════════════
Commands: /context-read <id> | /context-search <term>
═══════════════════════════════════════════════════════════════
```
