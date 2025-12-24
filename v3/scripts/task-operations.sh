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

    TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # Find the future task and promote it
    jq --arg fid "$FUTURE_ID" --arg wave "$TARGET_WAVE" --arg ts "$TIMESTAMP" '
      # Find the future task
      (.future_tasks // []) as $future |
      ($future | map(select(.id == $fid)) | first) as $item |

      if $item == null then
        {error: ("Future task " + $fid + " not found")}
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

        # Update tasks.json
        .tasks += [$new_task] |
        .future_tasks = ($future | map(select(.id != $fid))) |

        # Update wave parent if exists
        .tasks = (.tasks | map(
          if .id == $wave then
            .subtasks = ((.subtasks // []) + [$new_id])
          else .
          end
        )) |

        {success: true, promoted_task: $new_task, removed_future_id: $fid}
      end
    ' "$TASKS_FILE" > "${TASKS_FILE}.tmp"

    # Check if promotion succeeded
    if jq -e '.error' "${TASKS_FILE}.tmp" > /dev/null 2>&1; then
      cat "${TASKS_FILE}.tmp"
      rm "${TASKS_FILE}.tmp"
      exit 1
    fi

    # Extract result, update file
    RESULT=$(jq '{success, promoted_task, removed_future_id}' "${TASKS_FILE}.tmp")
    jq 'del(.success, .promoted_task, .removed_future_id)' "${TASKS_FILE}.tmp" > "$TASKS_FILE"
    rm "${TASKS_FILE}.tmp"

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

    # Find future tasks with priority matching wave_N
    WAVE_PRIORITY="wave_${TARGET_WAVE}"
    MATCHING=$(jq --arg wp "$WAVE_PRIORITY" '(.future_tasks // []) | map(select(.priority == $wp)) | length' "$TASKS_FILE")

    if [ "$MATCHING" = "0" ]; then
      echo '{"warning": "No future tasks found with priority '"$WAVE_PRIORITY"'"}'
      exit 0
    fi

    PROMOTED=0
    # Promote each matching task
    for FID in $(jq -r --arg wp "$WAVE_PRIORITY" '(.future_tasks // []) | map(select(.priority == $wp)) | .[].id' "$TASKS_FILE"); do
      bash "$0" promote "$FID" "$TARGET_WAVE" "$SPEC_NAME" > /dev/null
      PROMOTED=$((PROMOTED + 1))
    done

    echo '{"success": true, "promoted_count": '"$PROMOTED"', "target_wave": '"$TARGET_WAVE"'}'
    ;;

  help|*)
    cat << 'EOF'
Agent OS v3.0 Task Operations

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

Status values: pending, in_progress, pass, blocked

Examples:
  task-operations.sh status auth-feature
  task-operations.sh update "1.2" "pass"
  task-operations.sh list-future
  task-operations.sh promote F1 5
  task-operations.sh promote-wave 5
  task-operations.sh collect-artifacts HEAD~3
  task-operations.sh validate-names '["login", "validateToken"]'
  task-operations.sh log-progress task_completed "Implemented login"
EOF
    ;;
esac
