#!/bin/bash
# Agent OS v3.0 - Task Operations Script
# Replaces MCP server with simple shell commands
# Called by hooks and agents for task management

set -e

COMMAND="${1:-help}"
shift || true

# Robust project directory detection
# Priority: CLAUDE_PROJECT_DIR > pwd (if .agent-os exists) > script location
detect_project_dir() {
  # 1. Try CLAUDE_PROJECT_DIR if set and valid
  if [ -n "$CLAUDE_PROJECT_DIR" ] && [ -d "$CLAUDE_PROJECT_DIR/.agent-os" ]; then
    echo "$CLAUDE_PROJECT_DIR"
    return
  fi

  # 2. Try current working directory
  if [ -d "./.agent-os" ]; then
    pwd
    return
  fi

  # 3. Try to find from script location (go up from .claude/scripts/)
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local project_dir="${script_dir%/.claude/scripts}"
  if [ -d "$project_dir/.agent-os" ]; then
    echo "$project_dir"
    return
  fi

  # 4. Search upward from pwd
  local current="$(pwd)"
  while [ "$current" != "/" ]; do
    if [ -d "$current/.agent-os" ]; then
      echo "$current"
      return
    fi
    current="$(dirname "$current")"
  done

  # Fallback to current directory
  pwd
}

PROJECT_DIR="$(detect_project_dir)"

# Find tasks.json
find_tasks_json() {
  local spec_name="$1"
  local base_path="$PROJECT_DIR/.agent-os/specs"

  if [ -n "$spec_name" ]; then
    echo "$base_path/$spec_name/tasks.json"
  else
    # Find first tasks.json
    find "$base_path" -name "tasks.json" -type f 2>/dev/null | head -1
  fi
}

case "$COMMAND" in

  # Get task status and summary
  status)
    SPEC_NAME="$1"
    TASKS_FILE=$(find_tasks_json "$SPEC_NAME")

    if [ ! -f "$TASKS_FILE" ]; then
      echo '{"error": "tasks.json not found"}'
      exit 1
    fi

    jq '{
      spec: .spec,
      summary: .summary,
      execution_strategy: .execution_strategy,
      next_task: (.tasks | map(select(.type == "subtask" and .status == "pending")) | first),
      in_progress: (.tasks | map(select(.status == "in_progress")) | first),
      recent_completed: (.tasks | map(select(.status == "pass")) | .[-3:])
    }' "$TASKS_FILE"
    ;;

  # Update task status
  update)
    TASK_ID="$1"
    STATUS="$2"
    SPEC_NAME="$3"

    if [ -z "$TASK_ID" ] || [ -z "$STATUS" ]; then
      echo '{"error": "Usage: task-operations.sh update <task_id> <status> [spec_name]"}'
      exit 1
    fi

    TASKS_FILE=$(find_tasks_json "$SPEC_NAME")

    if [ ! -f "$TASKS_FILE" ]; then
      echo '{"error": "tasks.json not found"}'
      exit 1
    fi

    TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # Update task status
    jq --arg id "$TASK_ID" --arg status "$STATUS" --arg ts "$TIMESTAMP" '
      .tasks |= map(
        if .id == $id then
          .status = $status |
          if $status == "in_progress" and .started_at == null then
            .started_at = $ts |
            .attempts = ((.attempts // 0) + 1)
          elif $status == "pass" and .completed_at == null then
            .completed_at = $ts
          else .
          end
        else .
        end
      ) |
      # Recalculate parent progress
      .tasks |= (
        group_by(.parent // .id) |
        map(
          if .[0].type == "subtask" then
            . as $subtasks |
            ($subtasks | map(select(.status == "pass")) | length) as $completed |
            ($subtasks | length) as $total |
            $subtasks | map(. + {parent_progress: (($completed / $total) * 100 | floor)})
          else .
          end
        ) | flatten
      ) |
      # Update summary
      .summary = {
        total_tasks: (.tasks | length),
        parent_tasks: (.tasks | map(select(.type == "parent")) | length),
        subtasks: (.tasks | map(select(.type == "subtask")) | length),
        completed: (.tasks | map(select(.status == "pass")) | length),
        in_progress: (.tasks | map(select(.status == "in_progress")) | length),
        blocked: (.tasks | map(select(.status == "blocked")) | length),
        pending: (.tasks | map(select(.status == "pending")) | length),
        overall_percent: (((.tasks | map(select(.status == "pass")) | length) / (.tasks | length)) * 100 | floor)
      } |
      .updated = $ts
    ' "$TASKS_FILE" > "${TASKS_FILE}.tmp" && mv "${TASKS_FILE}.tmp" "$TASKS_FILE"

    echo '{"success": true, "task_id": "'"$TASK_ID"'", "status": "'"$STATUS"'"}'
    ;;

  # Add artifacts to completed task
  artifacts)
    TASK_ID="$1"
    ARTIFACTS_JSON="$2"
    SPEC_NAME="$3"

    if [ -z "$TASK_ID" ] || [ -z "$ARTIFACTS_JSON" ]; then
      echo '{"error": "Usage: task-operations.sh artifacts <task_id> <artifacts_json> [spec_name]"}'
      exit 1
    fi

    TASKS_FILE=$(find_tasks_json "$SPEC_NAME")

    if [ ! -f "$TASKS_FILE" ]; then
      echo '{"error": "tasks.json not found"}'
      exit 1
    fi

    jq --arg id "$TASK_ID" --argjson artifacts "$ARTIFACTS_JSON" '
      .tasks |= map(
        if .id == $id then
          .artifacts = $artifacts
        else .
        end
      )
    ' "$TASKS_FILE" > "${TASKS_FILE}.tmp" && mv "${TASKS_FILE}.tmp" "$TASKS_FILE"

    echo '{"success": true, "task_id": "'"$TASK_ID"'"}'
    ;;

  # Collect artifacts from git diff
  collect-artifacts)
    SINCE_COMMIT="${1:-HEAD~1}"

    # Get file changes
    FILES_CREATED=$(git diff --name-status "$SINCE_COMMIT" HEAD 2>/dev/null | grep "^A" | cut -f2 | jq -R -s -c 'split("\n") | map(select(length > 0))')
    FILES_MODIFIED=$(git diff --name-status "$SINCE_COMMIT" HEAD 2>/dev/null | grep "^M" | cut -f2 | jq -R -s -c 'split("\n") | map(select(length > 0))')

    # Get test files
    TEST_FILES=$(git diff --name-status "$SINCE_COMMIT" HEAD 2>/dev/null | grep -E "\.(test|spec)\." | cut -f2 | jq -R -s -c 'split("\n") | map(select(length > 0))')

    # Extract exports from new files (handle paths with spaces)
    EXPORTS="[]"
    git diff --name-status "$SINCE_COMMIT" HEAD 2>/dev/null | grep "^A" | cut -f2 | grep -E "\.(ts|js)$" | while IFS= read -r file; do
      if [ -f "$file" ]; then
        FILE_EXPORTS=$(grep -oE "export\s+(const|function|class|type|interface|enum)\s+\w+" "$file" 2>/dev/null | sed 's/export\s*\(const\|function\|class\|type\|interface\|enum\)\s*//' | jq -R -s -c 'split("\n") | map(select(length > 0))')
        EXPORTS=$(echo "$EXPORTS $FILE_EXPORTS" | jq -s 'add | unique')
      fi
    done

    # Build result
    jq -n \
      --argjson files_created "$FILES_CREATED" \
      --argjson files_modified "$FILES_MODIFIED" \
      --argjson test_files "$TEST_FILES" \
      --argjson exports "$EXPORTS" \
      '{
        files_created: $files_created,
        files_modified: $files_modified,
        test_files: $test_files,
        exports_added: $exports,
        functions_created: ($exports | map(select(test("Type|Interface") | not)))
      }'
    ;;

  # Validate names exist in codebase
  validate-names)
    NAMES_JSON="$1"

    if [ -z "$NAMES_JSON" ]; then
      echo '{"error": "Usage: task-operations.sh validate-names <names_json_array>"}'
      exit 1
    fi

    RESULTS='{}'
    MISSING='[]'

    for name in $(echo "$NAMES_JSON" | jq -r '.[]'); do
      # Search in codebase (check common source directories)
      FOUND=""
      for src_dir in "$PROJECT_DIR/src" "$PROJECT_DIR/lib" "$PROJECT_DIR/app" "$PROJECT_DIR"; do
        if [ -d "$src_dir" ]; then
          FOUND=$(grep -r "export.*$name" --include="*.ts" --include="*.js" "$src_dir" 2>/dev/null | head -1)
          [ -n "$FOUND" ] && break
        fi
      done

      if [ -n "$FOUND" ]; then
        RESULTS=$(echo "$RESULTS" | jq --arg n "$name" '. + {($n): {"found": true, "source": "codebase"}}')
      else
        # Check task artifacts
        TASKS_FILE=$(find_tasks_json)
        if [ -f "$TASKS_FILE" ]; then
          ARTIFACT_TASK=$(jq -r --arg n "$name" '.tasks[] | select(.artifacts.exports_added // [] | index($n)) | .id' "$TASKS_FILE" | head -1)
          if [ -n "$ARTIFACT_TASK" ]; then
            RESULTS=$(echo "$RESULTS" | jq --arg n "$name" --arg t "$ARTIFACT_TASK" '. + {($n): {"found": true, "source": ("task:" + $t)}}')
          else
            RESULTS=$(echo "$RESULTS" | jq --arg n "$name" '. + {($n): {"found": false, "source": null}}')
            MISSING=$(echo "$MISSING" | jq --arg n "$name" '. + [$n]')
          fi
        else
          RESULTS=$(echo "$RESULTS" | jq --arg n "$name" '. + {($n): {"found": false, "source": null}}')
          MISSING=$(echo "$MISSING" | jq --arg n "$name" '. + [$n]')
        fi
      fi
    done

    ALL_VALID=$(echo "$MISSING" | jq 'length == 0')

    jq -n \
      --argjson results "$RESULTS" \
      --argjson missing "$MISSING" \
      --argjson valid "$ALL_VALID" \
      '{valid: $valid, results: $results, missing: $missing}'
    ;;

  # Get progress log entries
  progress)
    COUNT="${1:-5}"
    TYPE="$2"

    PROGRESS_FILE="$PROJECT_DIR/.agent-os/progress/progress.json"

    if [ ! -f "$PROGRESS_FILE" ]; then
      echo '{"error": "progress.json not found"}'
      exit 1
    fi

    if [ -n "$TYPE" ]; then
      jq --arg type "$TYPE" --argjson count "$COUNT" '{
        project: .project,
        total_entries: .metadata.total_entries,
        recent: [.entries[] | select(.type == $type)] | .[-$count:]
      }' "$PROGRESS_FILE"
    else
      jq --argjson count "$COUNT" '{
        project: .project,
        total_entries: .metadata.total_entries,
        recent: .entries[-$count:]
      }' "$PROGRESS_FILE"
    fi
    ;;

  # Log progress entry
  log-progress)
    TYPE="$1"
    DESCRIPTION="$2"
    SPEC="$3"
    TASK_ID="$4"
    NOTES="$5"

    if [ -z "$TYPE" ] || [ -z "$DESCRIPTION" ]; then
      echo '{"error": "Usage: task-operations.sh log-progress <type> <description> [spec] [task_id] [notes]"}'
      exit 1
    fi

    PROGRESS_FILE="$PROJECT_DIR/.agent-os/progress/progress.json"

    if [ ! -f "$PROGRESS_FILE" ]; then
      echo '{"error": "progress.json not found"}'
      exit 1
    fi

    ENTRY_ID="entry-$(date +%Y%m%d-%H%M%S)-$(head /dev/urandom | tr -dc 'a-z0-9' | head -c 6)"
    TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    jq --arg id "$ENTRY_ID" \
       --arg ts "$TIMESTAMP" \
       --arg type "$TYPE" \
       --arg desc "$DESCRIPTION" \
       --arg spec "$SPEC" \
       --arg task "$TASK_ID" \
       --arg notes "$NOTES" '
      .entries += [{
        id: $id,
        timestamp: $ts,
        type: $type,
        spec: (if $spec == "" then null else $spec end),
        task_id: (if $task == "" then null else $task end),
        data: {
          description: $desc,
          notes: (if $notes == "" then null else $notes end)
        }
      }] |
      .metadata.total_entries = (.entries | length) |
      .metadata.last_updated = $ts
    ' "$PROGRESS_FILE" > "${PROGRESS_FILE}.tmp" && mv "${PROGRESS_FILE}.tmp" "$PROGRESS_FILE"

    echo '{"success": true, "entry_id": "'"$ENTRY_ID"'"}'
    ;;

  # List future tasks (from PR reviews, backlog)
  list-future)
    SPEC_NAME="$1"
    TASKS_FILE=$(find_tasks_json "$SPEC_NAME")

    if [ ! -f "$TASKS_FILE" ]; then
      echo '{"error": "tasks.json not found"}'
      exit 1
    fi

    jq '{
      total: (.future_tasks // [] | length),
      future_tasks: (.future_tasks // []),
      by_priority: (.future_tasks // [] | group_by(.priority) | map({(.[0].priority // "unset"): .}))
    }' "$TASKS_FILE"
    ;;

  # Promote future task to a wave task
  promote)
    FUTURE_ID="$1"
    TARGET_WAVE="$2"
    SPEC_NAME="$3"

    if [ -z "$FUTURE_ID" ] || [ -z "$TARGET_WAVE" ]; then
      echo '{"error": "Usage: task-operations.sh promote <future_id> <wave_number> [spec_name]"}'
      exit 1
    fi

    TASKS_FILE=$(find_tasks_json "$SPEC_NAME")

    if [ ! -f "$TASKS_FILE" ]; then
      echo '{"error": "tasks.json not found"}'
      exit 1
    fi

    # Verify file has future_tasks array (defensive check)
    if ! jq -e '.future_tasks // empty' "$TASKS_FILE" > /dev/null 2>&1; then
      echo '{"error": "No future_tasks array in tasks.json"}'
      exit 1
    fi

    TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    TMP_FILE="${TASKS_FILE}.promote.tmp"
    RESULT_FILE="${TASKS_FILE}.result.tmp"

    # Find the future task and promote it
    # IMPORTANT: Output goes to separate result file to avoid truncating original on failure
    if ! jq --arg fid "$FUTURE_ID" --arg wave "$TARGET_WAVE" --arg ts "$TIMESTAMP" '
      # Find the future task
      (.future_tasks // []) as $future |
      ($future | map(select(.id == $fid)) | first) as $item |

      if $item == null then
        {_promote_error: ("Future task " + $fid + " not found")}
      else
        # Generate new task ID: wave.N where N is next in wave
        ((.tasks // []) | map(select(.id | startswith($wave + "."))) | length + 1) as $next_num |
        ($wave + "." + ($next_num | tostring)) as $new_id |

        # Create the new task
        {
          id: $new_id,
          parent: $wave,
          wave: ($wave | tonumber),
          type: "subtask",
          title: $item.description,
          description: ("From PR #" + ($item.pr_number | tostring) + ": " + $item.original_comment),
          status: "pending",
          priority: "should",
          estimated_loc: 50,
          actual_loc: null,
          created_at: $ts,
          promoted_from: $fid,
          original_file_context: $item.file_context
        } as $new_task |

        # Update tasks.json - keep original structure, add new task, remove from future
        . + {
          tasks: (.tasks + [$new_task]),
          future_tasks: ($future | map(select(.id != $fid))),
          _promoted_task: $new_task,
          _removed_future_id: $fid
        } |

        # Update wave parent if exists
        .tasks = (.tasks | map(
          if .id == $wave then
            .subtasks = ((.subtasks // []) + [$new_id])
          else .
          end
        ))
      end
    ' "$TASKS_FILE" > "$TMP_FILE" 2>/dev/null; then
      echo '{"error": "jq processing failed"}'
      rm -f "$TMP_FILE"
      exit 1
    fi

    # Verify tmp file was created and is valid JSON
    if [ ! -s "$TMP_FILE" ]; then
      echo '{"error": "Failed to create temp file (empty output)"}'
      rm -f "$TMP_FILE"
      exit 1
    fi

    # Check if promotion had an error
    if jq -e '._promote_error' "$TMP_FILE" > /dev/null 2>&1; then
      ERROR_MSG=$(jq -r '._promote_error' "$TMP_FILE")
      echo '{"error": "'"$ERROR_MSG"'"}'
      rm -f "$TMP_FILE"
      exit 1
    fi

    # Extract result before modifying file
    RESULT=$(jq '{success: true, promoted_task: ._promoted_task, removed_future_id: ._removed_future_id}' "$TMP_FILE")

    # Create clean version without internal fields
    if ! jq 'del(._promoted_task, ._removed_future_id, ._promote_error)' "$TMP_FILE" > "$RESULT_FILE" 2>/dev/null; then
      echo '{"error": "Failed to clean temp file"}'
      rm -f "$TMP_FILE" "$RESULT_FILE"
      exit 1
    fi

    # Verify result file is valid before atomic move
    if ! jq -e '.tasks' "$RESULT_FILE" > /dev/null 2>&1; then
      echo '{"error": "Result file validation failed - tasks array missing"}'
      rm -f "$TMP_FILE" "$RESULT_FILE"
      exit 1
    fi

    # Atomic move - only now do we touch the original file
    mv "$RESULT_FILE" "$TASKS_FILE"
    rm -f "$TMP_FILE"

    echo "$RESULT"
    ;;

  # Promote all future tasks for a wave (e.g., all wave_5 priority tasks)
  promote-wave)
    TARGET_WAVE="$1"
    SPEC_NAME="$2"

    if [ -z "$TARGET_WAVE" ]; then
      echo '{"error": "Usage: task-operations.sh promote-wave <wave_number> [spec_name]"}'
      exit 1
    fi

    TASKS_FILE=$(find_tasks_json "$SPEC_NAME")

    if [ ! -f "$TASKS_FILE" ]; then
      echo '{"error": "tasks.json not found"}'
      exit 1
    fi

    # Verify file has future_tasks array
    if ! jq -e 'has("future_tasks")' "$TASKS_FILE" > /dev/null 2>&1; then
      echo '{"warning": "No future_tasks field in tasks.json"}'
      exit 0
    fi

    # Check if future_tasks is null or empty
    FUTURE_COUNT=$(jq '(.future_tasks // []) | length' "$TASKS_FILE")
    if [ "$FUTURE_COUNT" = "0" ] || [ -z "$FUTURE_COUNT" ]; then
      echo '{"warning": "future_tasks is empty or null"}'
      exit 0
    fi

    # Find future tasks with priority matching wave_N
    WAVE_PRIORITY="wave_${TARGET_WAVE}"
    MATCHING=$(jq --arg wp "$WAVE_PRIORITY" '(.future_tasks // []) | map(select(.priority == $wp)) | length' "$TASKS_FILE")

    if [ "$MATCHING" = "0" ] || [ -z "$MATCHING" ]; then
      echo '{"warning": "No future tasks found with priority '"$WAVE_PRIORITY"'"}'
      exit 0
    fi

    # Get list of FIDs to promote (save to avoid re-reading modified file)
    FID_LIST=$(jq -r --arg wp "$WAVE_PRIORITY" '(.future_tasks // []) | map(select(.priority == $wp)) | .[].id' "$TASKS_FILE")

    if [ -z "$FID_LIST" ]; then
      echo '{"warning": "No future task IDs extracted"}'
      exit 0
    fi

    PROMOTED=0
    FAILED=0
    PROMOTED_IDS="[]"
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Promote each matching task
    # Disable set -e for this loop so we can handle individual failures
    set +e
    for FID in $FID_LIST; do
      RESULT=$("$SCRIPT_DIR/task-operations.sh" promote "$FID" "$TARGET_WAVE" "$SPEC_NAME" 2>&1)
      if echo "$RESULT" | jq -e '.success' > /dev/null 2>&1; then
        PROMOTED=$((PROMOTED + 1))
        NEW_ID=$(echo "$RESULT" | jq -r '.promoted_task.id')
        PROMOTED_IDS=$(echo "$PROMOTED_IDS" | jq --arg id "$NEW_ID" --arg fid "$FID" '. + [{new_id: $id, from_future: $fid}]')
      else
        FAILED=$((FAILED + 1))
        # Log the error but continue with other tasks
        echo "Warning: Failed to promote $FID: $RESULT" >&2
      fi
    done
    set -e

    if [ "$PROMOTED" -gt 0 ]; then
      echo '{"success": true, "promoted_count": '"$PROMOTED"', "failed_count": '"$FAILED"', "target_wave": '"$TARGET_WAVE"', "promoted": '"$PROMOTED_IDS"'}'
    else
      echo '{"error": "No tasks were promoted", "failed_count": '"$FAILED"'}'
      exit 1
    fi
    ;;

  # Graduate a single future task to roadmap or next-spec queue
  graduate)
    FUTURE_ID="$1"
    DESTINATION="$2"  # roadmap, next-spec, or drop
    REASON="$3"       # Optional reason (required for drop)
    SPEC_NAME="$4"

    if [ -z "$FUTURE_ID" ] || [ -z "$DESTINATION" ]; then
      echo '{"error": "Usage: task-operations.sh graduate <future_id> <destination> [reason] [spec_name]"}'
      echo '{"destinations": ["roadmap", "next-spec", "drop"]}'
      exit 1
    fi

    TASKS_FILE=$(find_tasks_json "$SPEC_NAME")

    if [ ! -f "$TASKS_FILE" ]; then
      echo '{"error": "tasks.json not found"}'
      exit 1
    fi

    # Get the future task
    ITEM=$(jq --arg fid "$FUTURE_ID" '.future_tasks // [] | map(select(.id == $fid)) | first' "$TASKS_FILE")

    if [ "$ITEM" = "null" ] || [ -z "$ITEM" ]; then
      echo '{"error": "Future task '"$FUTURE_ID"' not found"}'
      exit 1
    fi

    TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    SPEC_PATH=$(jq -r '.spec_path // .spec' "$TASKS_FILE")

    case "$DESTINATION" in
      roadmap)
        # Append to roadmap.md
        ROADMAP_FILE="$PROJECT_DIR/.agent-os/product/roadmap.md"

        # Create roadmap file if it doesn't exist
        if [ ! -f "$ROADMAP_FILE" ]; then
          mkdir -p "$(dirname "$ROADMAP_FILE")"
          cat > "$ROADMAP_FILE" << 'ROADMAP_HEADER'
# Product Roadmap

## Backlog (from PR Reviews)

Items captured during code review that need future planning.

ROADMAP_HEADER
        fi

        # Extract item details
        DESCRIPTION=$(echo "$ITEM" | jq -r '.description')
        PR_NUM=$(echo "$ITEM" | jq -r '.pr_number // "N/A"')
        FILE_CTX=$(echo "$ITEM" | jq -r '.file_context // "N/A"')
        ORIGINAL=$(echo "$ITEM" | jq -r '.original_comment // ""')

        # Append to roadmap
        cat >> "$ROADMAP_FILE" << EOF

### $FUTURE_ID: $DESCRIPTION
- **Source**: PR #$PR_NUM
- **Context**: \`$FILE_CTX\`
- **Captured**: $TIMESTAMP
- **Details**: $ORIGINAL
EOF

        # Remove from future_tasks
        jq --arg fid "$FUTURE_ID" '
          .future_tasks = (.future_tasks // [] | map(select(.id != $fid)))
        ' "$TASKS_FILE" > "${TASKS_FILE}.tmp" && mv "${TASKS_FILE}.tmp" "$TASKS_FILE"

        echo '{"success": true, "future_id": "'"$FUTURE_ID"'", "destination": "roadmap", "file": "'"$ROADMAP_FILE"'"}'
        ;;

      next-spec)
        # Move to global backlog queue for next spec
        BACKLOG_FILE="$PROJECT_DIR/.agent-os/backlog/pending.json"

        # Create backlog file if it doesn't exist
        if [ ! -f "$BACKLOG_FILE" ]; then
          mkdir -p "$(dirname "$BACKLOG_FILE")"
          echo '{"items": [], "created": "'"$TIMESTAMP"'"}' > "$BACKLOG_FILE"
        fi

        # Add source spec info and move to backlog
        ENRICHED_ITEM=$(echo "$ITEM" | jq --arg spec "$SPEC_PATH" --arg ts "$TIMESTAMP" '
          . + {source_spec: $spec, graduated_at: $ts}
        ')

        jq --argjson item "$ENRICHED_ITEM" '
          .items += [$item] |
          .updated = "'"$TIMESTAMP"'"
        ' "$BACKLOG_FILE" > "${BACKLOG_FILE}.tmp" && mv "${BACKLOG_FILE}.tmp" "$BACKLOG_FILE"

        # Remove from future_tasks
        jq --arg fid "$FUTURE_ID" '
          .future_tasks = (.future_tasks // [] | map(select(.id != $fid)))
        ' "$TASKS_FILE" > "${TASKS_FILE}.tmp" && mv "${TASKS_FILE}.tmp" "$TASKS_FILE"

        echo '{"success": true, "future_id": "'"$FUTURE_ID"'", "destination": "next-spec", "file": "'"$BACKLOG_FILE"'"}'
        ;;

      drop)
        if [ -z "$REASON" ]; then
          echo '{"error": "Reason required when dropping a future task"}'
          exit 1
        fi

        # Log the drop to progress
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        "$SCRIPT_DIR/task-operations.sh" log-progress "backlog_dropped" "Dropped $FUTURE_ID: $REASON" "$SPEC_PATH" "" "" 2>/dev/null || true

        # Remove from future_tasks
        jq --arg fid "$FUTURE_ID" '
          .future_tasks = (.future_tasks // [] | map(select(.id != $fid)))
        ' "$TASKS_FILE" > "${TASKS_FILE}.tmp" && mv "${TASKS_FILE}.tmp" "$TASKS_FILE"

        echo '{"success": true, "future_id": "'"$FUTURE_ID"'", "destination": "dropped", "reason": "'"$REASON"'"}'
        ;;

      *)
        echo '{"error": "Invalid destination. Use: roadmap, next-spec, or drop"}'
        exit 1
        ;;
    esac
    ;;

  # Graduate all backlog items based on their future_type
  graduate-all)
    SPEC_NAME="$1"
    TASKS_FILE=$(find_tasks_json "$SPEC_NAME")

    if [ ! -f "$TASKS_FILE" ]; then
      echo '{"error": "tasks.json not found"}'
      exit 1
    fi

    # Check for future_tasks
    FUTURE_COUNT=$(jq '(.future_tasks // []) | length' "$TASKS_FILE")
    if [ "$FUTURE_COUNT" = "0" ] || [ -z "$FUTURE_COUNT" ]; then
      echo '{"success": true, "message": "No future tasks to graduate", "roadmap_items": 0, "wave_tasks": 0}'
      exit 0
    fi

    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    ROADMAP_GRADUATED=0
    WAVE_TASKS_REMAINING=0
    WAVE_TASK_IDS="[]"

    # Process ROADMAP_ITEM types - auto-graduate to roadmap.md
    ROADMAP_IDS=$(jq -r '.future_tasks // [] | map(select(.future_type == "ROADMAP_ITEM")) | .[].id' "$TASKS_FILE")

    set +e
    for FID in $ROADMAP_IDS; do
      if [ -n "$FID" ]; then
        RESULT=$("$SCRIPT_DIR/task-operations.sh" graduate "$FID" "roadmap" "" "$SPEC_NAME" 2>&1)
        if echo "$RESULT" | jq -e '.success' > /dev/null 2>&1; then
          ROADMAP_GRADUATED=$((ROADMAP_GRADUATED + 1))
        else
          echo "Warning: Failed to graduate $FID to roadmap: $RESULT" >&2
        fi
      fi
    done
    set -e

    # Collect remaining WAVE_TASK items (need user decision)
    # Re-read the file since we modified it
    TASKS_FILE=$(find_tasks_json "$SPEC_NAME")
    WAVE_TASK_IDS=$(jq '[.future_tasks // [] | map(select(.future_type == "WAVE_TASK" or .future_type == null)) | .[].id]' "$TASKS_FILE")
    WAVE_TASKS_REMAINING=$(echo "$WAVE_TASK_IDS" | jq 'length')

    # Get details of remaining wave tasks for user review
    WAVE_TASKS_DETAIL=$(jq '[.future_tasks // [] | map(select(.future_type == "WAVE_TASK" or .future_type == null)) | .[] | {id, description, file_context, priority}]' "$TASKS_FILE")

    echo '{
      "success": true,
      "roadmap_graduated": '"$ROADMAP_GRADUATED"',
      "wave_tasks_remaining": '"$WAVE_TASKS_REMAINING"',
      "wave_tasks": '"$WAVE_TASKS_DETAIL"',
      "message": "ROADMAP_ITEM items auto-graduated to roadmap.md. WAVE_TASK items require user decision."
    }'
    ;;

  # Import items from global backlog into current spec
  import-backlog)
    TARGET_WAVE="$1"
    SPEC_NAME="$2"

    if [ -z "$TARGET_WAVE" ]; then
      echo '{"error": "Usage: task-operations.sh import-backlog <target_wave> [spec_name]"}'
      exit 1
    fi

    BACKLOG_FILE="$PROJECT_DIR/.agent-os/backlog/pending.json"
    TASKS_FILE=$(find_tasks_json "$SPEC_NAME")

    if [ ! -f "$BACKLOG_FILE" ]; then
      echo '{"success": true, "message": "No pending backlog items", "imported": 0}'
      exit 0
    fi

    if [ ! -f "$TASKS_FILE" ]; then
      echo '{"error": "tasks.json not found"}'
      exit 1
    fi

    # Count items in backlog
    BACKLOG_COUNT=$(jq '.items | length' "$BACKLOG_FILE")
    if [ "$BACKLOG_COUNT" = "0" ]; then
      echo '{"success": true, "message": "Backlog is empty", "imported": 0}'
      exit 0
    fi

    TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # Move all pending backlog items to current spec's future_tasks with wave priority
    WAVE_PRIORITY="wave_${TARGET_WAVE}"

    jq --slurpfile backlog "$BACKLOG_FILE" --arg wp "$WAVE_PRIORITY" --arg ts "$TIMESTAMP" '
      .future_tasks = (.future_tasks // []) + [
        $backlog[0].items[] | . + {priority: $wp, imported_at: $ts}
      ]
    ' "$TASKS_FILE" > "${TASKS_FILE}.tmp" && mv "${TASKS_FILE}.tmp" "$TASKS_FILE"

    # Clear the backlog
    echo '{"items": [], "created": "'"$TIMESTAMP"'", "cleared_at": "'"$TIMESTAMP"'"}' > "$BACKLOG_FILE"

    echo '{"success": true, "imported": '"$BACKLOG_COUNT"', "target_wave": '"$TARGET_WAVE"', "priority": "'"$WAVE_PRIORITY"'"}'
    ;;

  # Determine the next available wave number
  determine-next-wave)
    SPEC_NAME="$1"
    TASKS_FILE=$(find_tasks_json "$SPEC_NAME")

    if [ ! -f "$TASKS_FILE" ]; then
      echo '{"error": "tasks.json not found"}'
      exit 1
    fi

    # Find the highest wave number from parent tasks
    # Wave can be in: .wave, .parallelization.wave, or extracted from .priority "wave_N"
    HIGHEST=$(jq '
      [
        (.tasks // [])[] |
        select(.type == "parent") |
        (
          if .wave then .wave
          elif .parallelization.wave then .parallelization.wave
          elif .priority and (.priority | type == "string") and (.priority | test("^wave_[0-9]+$")) then
            (.priority | capture("wave_(?<n>[0-9]+)") | .n | tonumber)
          else 0
          end
        )
      ] | max // 0
    ' "$TASKS_FILE")

    NEXT_WAVE=$((HIGHEST + 1))

    echo '{
      "success": true,
      "current_highest": '"$HIGHEST"',
      "next_wave": '"$NEXT_WAVE"'
    }'
    ;;

  # Add expanded task (parent + subtasks) from backlog expansion
  add-expanded-task)
    EXPANDED_JSON="$1"
    SPEC_NAME="$2"

    if [ -z "$EXPANDED_JSON" ]; then
      echo '{"error": "Usage: task-operations.sh add-expanded-task <expanded_json> [spec_name]"}'
      exit 1
    fi

    TASKS_FILE=$(find_tasks_json "$SPEC_NAME")

    if [ ! -f "$TASKS_FILE" ]; then
      echo '{"error": "tasks.json not found"}'
      exit 1
    fi

    TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    TMP_FILE="${TASKS_FILE}.expand.tmp"

    # Parse the expanded JSON
    FUTURE_ID=$(echo "$EXPANDED_JSON" | jq -r '.future_id')
    PARENT_TASK=$(echo "$EXPANDED_JSON" | jq '.parent_task')
    SUBTASKS=$(echo "$EXPANDED_JSON" | jq '.subtasks')
    TARGET_WAVE=$(echo "$PARENT_TASK" | jq -r '.wave // 0')

    if [ "$FUTURE_ID" = "null" ] || [ "$PARENT_TASK" = "null" ]; then
      echo '{"error": "Invalid expanded_json format. Required: future_id, parent_task, subtasks"}'
      exit 1
    fi

    # Extract parent task ID for wave update
    PARENT_ID=$(echo "$PARENT_TASK" | jq -r '.id')

    # Add parent task, subtasks, remove from future_tasks, update summary AND execution_strategy
    if ! jq --arg fid "$FUTURE_ID" \
           --argjson parent "$PARENT_TASK" \
           --argjson subs "$SUBTASKS" \
           --arg ts "$TIMESTAMP" \
           --arg pid "$PARENT_ID" \
           --argjson wave "$TARGET_WAVE" '
      # Add parent task with timestamp
      .tasks += [($parent + {created_at: $ts})] |

      # Add subtasks with timestamps
      .tasks += [$subs[] | . + {created_at: $ts}] |

      # Remove from future_tasks
      .future_tasks = (.future_tasks // [] | map(select(.id != $fid))) |

      # Update execution_strategy.waves - add to existing wave or create new one
      .execution_strategy.waves = (
        if (.execution_strategy.waves | map(select(.wave_id == $wave)) | length) > 0 then
          # Wave exists - add parent task ID to it (if not already present)
          .execution_strategy.waves | map(
            if .wave_id == $wave then
              .tasks = (.tasks + [$pid] | unique)
            else .
            end
          )
        else
          # Wave does not exist - create it
          .execution_strategy.waves + [{
            wave_id: $wave,
            tasks: [$pid],
            rationale: "Expanded from WAVE_TASK backlog items"
          }]
        end
      ) |

      # Update the timestamp
      .updated = $ts |

      # Recalculate summary
      .summary = {
        total_tasks: (.tasks | length),
        parent_tasks: (.tasks | map(select(.type == "parent")) | length),
        subtasks: (.tasks | map(select(.type == "subtask")) | length),
        completed: (.tasks | map(select(.status == "pass")) | length),
        in_progress: (.tasks | map(select(.status == "in_progress")) | length),
        blocked: (.tasks | map(select(.status == "blocked")) | length),
        pending: (.tasks | map(select(.status == "pending")) | length),
        overall_percent: (((.tasks | map(select(.status == "pass")) | length) / (.tasks | length)) * 100 | floor)
      }
    ' "$TASKS_FILE" > "$TMP_FILE" 2>/dev/null; then
      echo '{"error": "jq processing failed"}'
      rm -f "$TMP_FILE"
      exit 1
    fi

    # Validate result
    if ! jq -e '.tasks' "$TMP_FILE" > /dev/null 2>&1; then
      echo '{"error": "Result validation failed"}'
      rm -f "$TMP_FILE"
      exit 1
    fi

    # Atomic move
    mv "$TMP_FILE" "$TASKS_FILE"

    SUBTASK_COUNT=$(echo "$SUBTASKS" | jq 'length')

    echo '{
      "success": true,
      "expanded_from": "'"$FUTURE_ID"'",
      "parent_task_id": "'"$PARENT_ID"'",
      "target_wave": '"$TARGET_WAVE"',
      "subtasks_added": '"$SUBTASK_COUNT"',
      "message": "Expanded '"$FUTURE_ID"' into parent task '"$PARENT_ID"' (wave '"$TARGET_WAVE"') with '"$SUBTASK_COUNT"' subtasks"
    }'
    ;;

  # Remove a future task after it's been expanded into main tasks (v3.6.0)
  remove-future-task)
    FUTURE_ID="$1"
    SPEC_NAME="$2"
    TASKS_FILE=$(find_tasks_json "$SPEC_NAME")

    if [ -z "$FUTURE_ID" ]; then
      echo '{"error": "Usage: task-operations.sh remove-future-task <future_id> [spec_name]"}'
      exit 1
    fi

    if [ ! -f "$TASKS_FILE" ]; then
      echo '{"error": "tasks.json not found"}'
      exit 1
    fi

    # Check if future task exists
    EXISTS=$(jq --arg fid "$FUTURE_ID" '.future_tasks // [] | map(select(.id == $fid)) | length' "$TASKS_FILE")

    if [ "$EXISTS" = "0" ]; then
      echo '{
        "success": false,
        "error": "Future task '"$FUTURE_ID"' not found"
      }'
      exit 1
    fi

    # Create temp file and remove the future task
    TEMP_FILE=$(mktemp)
    jq --arg fid "$FUTURE_ID" '
      .future_tasks = (.future_tasks // [] | map(select(.id != $fid)))
    ' "$TASKS_FILE" > "$TEMP_FILE"

    # Atomic replace
    mv "$TEMP_FILE" "$TASKS_FILE"

    echo '{
      "success": true,
      "removed": "'"$FUTURE_ID"'",
      "message": "Future task '"$FUTURE_ID"' removed after expansion"
    }'
    ;;

  # Update subtask group status (v4.2 - subtask parallelization)
  update-group)
    TASK_ID="$1"
    GROUP_ID="$2"
    STATUS="$3"
    SPEC_NAME="$4"

    if [ -z "$TASK_ID" ] || [ -z "$GROUP_ID" ] || [ -z "$STATUS" ]; then
      echo '{"error": "Usage: task-operations.sh update-group <task_id> <group_id> <status> [spec_name]"}'
      exit 1
    fi

    TASKS_FILE=$(find_tasks_json "$SPEC_NAME")

    if [ ! -f "$TASKS_FILE" ]; then
      echo '{"error": "tasks.json not found"}'
      exit 1
    fi

    TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # Update group status in subtask_execution
    jq --arg tid "$TASK_ID" --arg gid "$GROUP_ID" --arg status "$STATUS" --arg ts "$TIMESTAMP" '
      .tasks |= map(
        if .id == $tid and .subtask_execution != null then
          .subtask_execution.groups |= map(
            if .group_id == ($gid | tonumber) then
              . + {status: $status, updated_at: $ts}
            else .
            end
          )
        else .
        end
      ) |
      .updated = $ts
    ' "$TASKS_FILE" > "${TASKS_FILE}.tmp" && mv "${TASKS_FILE}.tmp" "$TASKS_FILE"

    echo '{"success": true, "task_id": "'"$TASK_ID"'", "group_id": '"$GROUP_ID"', "status": "'"$STATUS"'"}'
    ;;

  # Add artifacts to a subtask group (v4.2 - subtask parallelization)
  group-artifacts)
    TASK_ID="$1"
    GROUP_ID="$2"
    ARTIFACTS_JSON="$3"
    SPEC_NAME="$4"

    if [ -z "$TASK_ID" ] || [ -z "$GROUP_ID" ] || [ -z "$ARTIFACTS_JSON" ]; then
      echo '{"error": "Usage: task-operations.sh group-artifacts <task_id> <group_id> <artifacts_json> [spec_name]"}'
      exit 1
    fi

    TASKS_FILE=$(find_tasks_json "$SPEC_NAME")

    if [ ! -f "$TASKS_FILE" ]; then
      echo '{"error": "tasks.json not found"}'
      exit 1
    fi

    TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # Add artifacts to specific group
    jq --arg tid "$TASK_ID" --arg gid "$GROUP_ID" --argjson artifacts "$ARTIFACTS_JSON" --arg ts "$TIMESTAMP" '
      .tasks |= map(
        if .id == $tid and .subtask_execution != null then
          .subtask_execution.groups |= map(
            if .group_id == ($gid | tonumber) then
              . + {
                artifacts: $artifacts,
                completed_at: $ts
              }
            else .
            end
          )
        else .
        end
      ) |
      .updated = $ts
    ' "$TASKS_FILE" > "${TASKS_FILE}.tmp" && mv "${TASKS_FILE}.tmp" "$TASKS_FILE"

    echo '{"success": true, "task_id": "'"$TASK_ID"'", "group_id": '"$GROUP_ID"'}'
    ;;

  # Get subtask group status for a task (v4.2 - subtask parallelization)
  group-status)
    TASK_ID="$1"
    SPEC_NAME="$2"

    if [ -z "$TASK_ID" ]; then
      echo '{"error": "Usage: task-operations.sh group-status <task_id> [spec_name]"}'
      exit 1
    fi

    TASKS_FILE=$(find_tasks_json "$SPEC_NAME")

    if [ ! -f "$TASKS_FILE" ]; then
      echo '{"error": "tasks.json not found"}'
      exit 1
    fi

    jq --arg tid "$TASK_ID" '
      .tasks[] |
      select(.id == $tid) |
      if .subtask_execution != null then
        {
          task_id: .id,
          mode: .subtask_execution.mode,
          total_groups: (.subtask_execution.groups | length),
          groups: [.subtask_execution.groups[] | {
            group_id,
            tdd_unit,
            status: (.status // "pending"),
            subtasks,
            files_affected,
            artifacts: (.artifacts // null)
          }],
          group_waves: .subtask_execution.group_waves
        }
      else
        {
          task_id: .id,
          mode: "sequential",
          message: "No subtask parallelization configured"
        }
      end
    ' "$TASKS_FILE"
    ;;

  # Expand all WAVE_TASK items in future_tasks (returns data for skill to process)
  list-wave-tasks)
    SPEC_NAME="$1"
    TASKS_FILE=$(find_tasks_json "$SPEC_NAME")

    if [ ! -f "$TASKS_FILE" ]; then
      echo '{"error": "tasks.json not found"}'
      exit 1
    fi

    # Get next wave number
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    NEXT_WAVE_RESULT=$("$SCRIPT_DIR/task-operations.sh" determine-next-wave "$SPEC_NAME" 2>&1)
    NEXT_WAVE=$(echo "$NEXT_WAVE_RESULT" | jq -r '.next_wave // 1')

    # Get all WAVE_TASK items with full details
    WAVE_TASKS=$(jq --arg nw "$NEXT_WAVE" '[
      .future_tasks // [] |
      map(select(.future_type == "WAVE_TASK" or .future_type == null)) |
      .[] |
      {
        id,
        description,
        file_context,
        rationale: .original_comment,
        future_type: (.future_type // "WAVE_TASK"),
        priority
      }
    ]' "$TASKS_FILE")

    WAVE_TASK_COUNT=$(echo "$WAVE_TASKS" | jq 'length')
    SPEC_FOLDER=$(jq -r '.spec_path // .spec' "$TASKS_FILE")

    echo '{
      "success": true,
      "spec_folder": "'"$SPEC_FOLDER"'",
      "target_wave": '"$NEXT_WAVE"',
      "wave_tasks": '"$WAVE_TASKS"',
      "count": '"$WAVE_TASK_COUNT"',
      "message": "Found '"$WAVE_TASK_COUNT"' WAVE_TASK items ready for expansion into wave '"$NEXT_WAVE"'"
    }'
    ;;

  # Get wave information for a spec
  # Usage: task-operations.sh wave-info [spec_name]
  wave-info)
    SPEC_NAME="$1"
    TASKS_FILE=$(find_tasks_json "$SPEC_NAME")

    if [ ! -f "$TASKS_FILE" ]; then
      echo '{"error": "tasks.json not found"}'
      exit 1
    fi

    # Get execution strategy and wave details
    jq '
      # Get total waves
      (.execution_strategy.waves // []) as $waves |
      ($waves | length) as $total_waves |

      # Find current wave (first with pending tasks)
      .tasks as $tasks |
      ($waves | map(select(
        .tasks as $wave_tasks |
        ($tasks | map(select(.id as $id | $wave_tasks | index($id))) | map(select(.status == "pending" or .status == "in_progress")) | length) > 0
      )) | .[0].wave_id // ($total_waves + 1)) as $current_wave |

      # Calculate per-wave progress
      ($waves | map({
        wave_id,
        task_ids: .tasks,
        rationale: (.rationale // null),
        tasks_total: (.tasks | length),
        tasks_completed: (
          .tasks as $wave_tasks |
          $tasks | map(select(.id as $id | $wave_tasks | index($id) and .status == "pass")) | length
        ),
        tasks_pending: (
          .tasks as $wave_tasks |
          $tasks | map(select(.id as $id | $wave_tasks | index($id) and .status == "pending")) | length
        ),
        tasks_in_progress: (
          .tasks as $wave_tasks |
          $tasks | map(select(.id as $id | $wave_tasks | index($id) and .status == "in_progress")) | length
        ),
        status: (
          .tasks as $wave_tasks |
          ($tasks | map(select(.id as $id | $wave_tasks | index($id))) | map(select(.status == "pass")) | length) as $completed |
          ($wave_tasks | length) as $total |
          if $completed == $total then "completed"
          elif ($tasks | map(select(.id as $id | $wave_tasks | index($id) and .status == "in_progress")) | length) > 0 then "in_progress"
          else "pending"
          end
        )
      })) as $wave_details |

      # Return comprehensive wave info
      {
        spec: .spec,
        total_waves: $total_waves,
        current_wave: $current_wave,
        is_final_wave: ($current_wave == $total_waves),
        all_complete: ($current_wave > $total_waves),
        execution_mode: (.execution_strategy.mode // "sequential"),
        waves: $wave_details,
        summary: {
          waves_completed: ($wave_details | map(select(.status == "completed")) | length),
          waves_in_progress: ($wave_details | map(select(.status == "in_progress")) | length),
          waves_pending: ($wave_details | map(select(.status == "pending")) | length)
        }
      }
    ' "$TASKS_FILE"
    ;;

  help|*)
    cat << 'EOF'
Agent OS v4.4.0 Task Operations

Usage: task-operations.sh <command> [args]

Commands:
  status [spec_name]                    Get task status and summary
  update <task_id> <status> [spec]      Update task status
  artifacts <task_id> <json> [spec]     Add artifacts to task
  collect-artifacts [since_commit]      Collect artifacts from git diff
  validate-names <names_json>           Validate names exist in codebase
  progress [count] [type]               Get progress log entries
  log-progress <type> <desc> [args]     Log progress entry
  list-future [spec_name]               List future tasks (backlog)
  promote <future_id> <wave> [spec]     Promote future task to wave
  promote-wave <wave_num> [spec]        Promote all tasks for a wave
  graduate <fid> <dest> [reason] [spec] Graduate future task to destination
  graduate-all [spec_name]              Auto-graduate all backlog items
  import-backlog <wave> [spec]          Import pending backlog into spec
  determine-next-wave [spec]            Get next available wave number
  add-expanded-task <json> [spec]       Add expanded parent+subtasks
  remove-future-task <id> [spec]        Remove future task after expansion
  list-wave-tasks [spec]                List WAVE_TASK items for expansion
  wave-info [spec_name]                 Get comprehensive wave progress info

Subtask Group Commands (v4.2):
  update-group <tid> <gid> <status>     Update subtask group status
  group-artifacts <tid> <gid> <json>    Add artifacts to subtask group
  group-status <task_id> [spec]         Get subtask group status for a task

Graduation destinations: roadmap, next-spec, drop

Status values: pending, in_progress, pass, blocked

Examples:
  task-operations.sh status auth-feature
  task-operations.sh update "1.2" "pass"
  task-operations.sh list-future
  task-operations.sh promote F1 5
  task-operations.sh promote-wave 5
  task-operations.sh graduate F1 roadmap
  task-operations.sh graduate F2 next-spec
  task-operations.sh graduate F3 drop "Not needed"
  task-operations.sh graduate-all
  task-operations.sh import-backlog 8
  task-operations.sh determine-next-wave
  task-operations.sh list-wave-tasks
  task-operations.sh add-expanded-task '{"future_id":"F1","parent_task":{...},"subtasks":[...]}'
  task-operations.sh remove-future-task F1
  task-operations.sh collect-artifacts HEAD~3
  task-operations.sh validate-names '["login", "validateToken"]'
  task-operations.sh log-progress task_completed "Implemented login"
  task-operations.sh wave-info frontend-ui
EOF
    ;;
esac
