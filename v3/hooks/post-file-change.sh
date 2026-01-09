#!/bin/bash
# Agent OS v4.6 - Post File Change Hook
# Replaces: task-sync skill
# Automatically regenerates markdown from JSON source-of-truth files
# v4.5: Auto-graduates future_tasks to prevent orphans
# v4.6: Added test-plan.json and test-report.json handlers

set -e

# Get the file path from environment (set by Claude Code)
FILE_PATH="${TOOL_INPUT_FILE_PATH:-$1}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# Only process tasks.json files
if [[ "$FILE_PATH" == *"tasks.json" ]]; then
  # Check if it's a v3+ format file
  VERSION=$(jq -r '.version // "unknown"' "$FILE_PATH" 2>/dev/null || echo "unknown")

  if [[ "$VERSION" == "3"* || "$VERSION" == "4"* ]]; then
    SCRIPT_DIR="$(dirname "$0")/../scripts"
    MESSAGES=()

    # 1. Regenerate markdown
    if [ -f "$SCRIPT_DIR/json-to-markdown.js" ]; then
      node "$SCRIPT_DIR/json-to-markdown.js" "$FILE_PATH"
      MESSAGES+=("tasks.md auto-regenerated")
    fi

    # 2. Auto-graduate future_tasks (v4.5 - prevents orphans)
    FUTURE_COUNT=$(jq '(.future_tasks // []) | length' "$FILE_PATH" 2>/dev/null || echo "0")

    if [ "$FUTURE_COUNT" -gt 0 ]; then
      # Extract spec name from path
      SPEC_NAME=$(basename "$(dirname "$FILE_PATH")")

      # Count by type
      ROADMAP_COUNT=$(jq '[.future_tasks // [] | .[] | select(.future_type == "ROADMAP_ITEM")] | length' "$FILE_PATH" 2>/dev/null || echo "0")
      WAVE_COUNT=$(jq '[.future_tasks // [] | .[] | select(.future_type == "WAVE_TASK" or .future_type == null)] | length' "$FILE_PATH" 2>/dev/null || echo "0")

      # Auto-graduate ROADMAP_ITEM to roadmap.md
      if [ "$ROADMAP_COUNT" -gt 0 ]; then
        ROADMAP_IDS=$(jq -r '.future_tasks // [] | map(select(.future_type == "ROADMAP_ITEM")) | .[].id' "$FILE_PATH" 2>/dev/null)
        GRADUATED=0

        for FID in $ROADMAP_IDS; do
          if [ -n "$FID" ]; then
            RESULT=$("$SCRIPT_DIR/task-operations.sh" graduate "$FID" "roadmap" "" "$SPEC_NAME" 2>/dev/null || echo '{"success":false}')
            if echo "$RESULT" | jq -e '.success' > /dev/null 2>&1; then
              GRADUATED=$((GRADUATED + 1))
            fi
          fi
        done

        if [ "$GRADUATED" -gt 0 ]; then
          MESSAGES+=("$GRADUATED ROADMAP_ITEM(s) → roadmap.md")
        fi
      fi

      # Auto-promote WAVE_TASK to next wave (simple promotion, no subtask expansion)
      if [ "$WAVE_COUNT" -gt 0 ]; then
        # Get next wave number
        NEXT_WAVE_RESULT=$("$SCRIPT_DIR/task-operations.sh" determine-next-wave "$SPEC_NAME" 2>/dev/null || echo '{"next_wave":1}')
        NEXT_WAVE=$(echo "$NEXT_WAVE_RESULT" | jq -r '.next_wave // 1')

        WAVE_IDS=$(jq -r '.future_tasks // [] | map(select(.future_type == "WAVE_TASK" or .future_type == null)) | .[].id' "$FILE_PATH" 2>/dev/null)
        PROMOTED=0

        for FID in $WAVE_IDS; do
          if [ -n "$FID" ]; then
            # Get the future task details
            ITEM=$(jq --arg fid "$FID" '.future_tasks // [] | map(select(.id == $fid)) | first' "$FILE_PATH" 2>/dev/null)

            if [ "$ITEM" != "null" ] && [ -n "$ITEM" ]; then
              DESCRIPTION=$(echo "$ITEM" | jq -r '.description // "Imported task"')
              FILE_CTX=$(echo "$ITEM" | jq -r '.file_context // ""')
              PR_NUM=$(echo "$ITEM" | jq -r '.pr_number // ""')

              # Create simple parent task (no subtasks - phase1-discovery will expand)
              TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
              NEXT_ID="$NEXT_WAVE"

              # Find next available ID in this wave
              EXISTING_IN_WAVE=$(jq --arg wave "$NEXT_WAVE" '[.tasks // [] | .[] | select(.wave == ($wave | tonumber) or (.id | startswith($wave + ".")))] | length' "$FILE_PATH" 2>/dev/null || echo "0")
              if [ "$EXISTING_IN_WAVE" -gt 0 ]; then
                # Wave already has tasks, use wave.N format
                NEXT_NUM=$((EXISTING_IN_WAVE + 1))
                NEXT_ID="${NEXT_WAVE}.${NEXT_NUM}"
              fi

              # Add as simple task (needs_subtask_expansion flag for phase1)
              jq --arg fid "$FID" \
                 --arg id "$NEXT_ID" \
                 --arg desc "$DESCRIPTION" \
                 --arg ctx "$FILE_CTX" \
                 --arg pr "$PR_NUM" \
                 --arg ts "$TIMESTAMP" \
                 --argjson wave "$NEXT_WAVE" '
                # Add simple task
                .tasks += [{
                  id: $id,
                  type: "parent",
                  description: $desc,
                  status: "pending",
                  wave: $wave,
                  needs_subtask_expansion: true,
                  promoted_from: $fid,
                  file_context: (if $ctx == "" then null else $ctx end),
                  source: (if $pr == "" then "future_task" else ("PR #" + $pr) end),
                  created_at: $ts
                }] |
                # Remove from future_tasks
                .future_tasks = (.future_tasks // [] | map(select(.id != $fid))) |
                # Update execution_strategy.waves if exists
                (if .execution_strategy.waves then
                  .execution_strategy.waves = (
                    if (.execution_strategy.waves | map(select(.wave_id == $wave)) | length) > 0 then
                      .execution_strategy.waves | map(
                        if .wave_id == $wave then .tasks = (.tasks + [$id] | unique) else . end
                      )
                    else
                      .execution_strategy.waves + [{wave_id: $wave, tasks: [$id], rationale: "Auto-promoted from future_tasks"}]
                    end
                  )
                else . end) |
                .updated = $ts
              ' "$FILE_PATH" > "${FILE_PATH}.tmp" && mv "${FILE_PATH}.tmp" "$FILE_PATH"

              PROMOTED=$((PROMOTED + 1))
            fi
          fi
        done

        if [ "$PROMOTED" -gt 0 ]; then
          MESSAGES+=("$PROMOTED WAVE_TASK(s) → wave $NEXT_WAVE (pending expansion)")
        fi
      fi
    fi

    # Build system message
    if [ ${#MESSAGES[@]} -gt 0 ]; then
      MSG=$(printf '%s; ' "${MESSAGES[@]}")
      MSG=${MSG%; }  # Remove trailing semicolon
      cat << EOF
{
  "continue": true,
  "systemMessage": "$MSG"
}
EOF
      exit 0
    fi

    cat << EOF
{
  "continue": true,
  "systemMessage": "tasks.md auto-regenerated from tasks.json"
}
EOF
    exit 0
  fi
fi

# Handle test-plan.json files
if [[ "$FILE_PATH" == *"test-plan.json" ]]; then
  VERSION=$(jq -r '.version // "unknown"' "$FILE_PATH" 2>/dev/null || echo "unknown")

  if [[ "$VERSION" == "1"* ]]; then
    SCRIPT_DIR="$(dirname "$0")/../scripts"

    # Regenerate markdown
    if [ -f "$SCRIPT_DIR/test-plan-to-markdown.js" ]; then
      node "$SCRIPT_DIR/test-plan-to-markdown.js" "$FILE_PATH" 2>/dev/null || true
      cat << EOF
{
  "continue": true,
  "systemMessage": "test-plan.md auto-regenerated from test-plan.json"
}
EOF
      exit 0
    fi
  fi
fi

# Handle test-report.json files
if [[ "$FILE_PATH" == *"test-report.json" ]]; then
  VERSION=$(jq -r '.version // "unknown"' "$FILE_PATH" 2>/dev/null || echo "unknown")

  if [[ "$VERSION" == "1"* ]]; then
    SCRIPT_DIR="$(dirname "$0")/../scripts"

    # Regenerate markdown
    if [ -f "$SCRIPT_DIR/test-report-to-markdown.js" ]; then
      node "$SCRIPT_DIR/test-report-to-markdown.js" "$FILE_PATH" 2>/dev/null || true
      cat << EOF
{
  "continue": true,
  "systemMessage": "test-report.md auto-regenerated from test-report.json"
}
EOF
      exit 0
    fi
  fi
fi

# For all other files, just continue
cat << EOF
{
  "continue": true
}
EOF
