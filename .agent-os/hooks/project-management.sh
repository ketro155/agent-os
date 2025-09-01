#!/bin/bash
# Project orchestration and management

# Project state management
PROJECT_STATE_FILE=".agent-os/project-state.json"
PROJECT_CONFIG_FILE="config.yml"

# Initialize project state
init_project_state() {
  if [ ! -f "$PROJECT_STATE_FILE" ]; then
    cat > "$PROJECT_STATE_FILE" <<EOF
{
  "initialized": "$(date)",
  "version": "2.0.0",
  "project_name": "$(basename "$(pwd)")",
  "active_commands": [],
  "recent_tasks": [],
  "cache_stats": {
    "hits": 0,
    "misses": 0,
    "size": "0"
  },
  "workflow_history": [],
  "environment": {
    "node_version": "$(node -v 2>/dev/null || echo 'not installed')",
    "npm_version": "$(npm -v 2>/dev/null || echo 'not installed')",
    "python_version": "$(python3 --version 2>/dev/null || echo 'not installed')"
  }
}
EOF
    echo "Project state initialized"
  fi
}

# Track command execution
track_command() {
  local command="$1"
  local status="${2:-started}"
  local timestamp="$(date)"
  
  if [ ! -f "$PROJECT_STATE_FILE" ]; then
    init_project_state
  fi
  
  # Add to active commands or move to history
  if [ "$status" = "started" ]; then
    jq --arg cmd "$command" --arg ts "$timestamp" \
      '.active_commands += [{"command": $cmd, "started": $ts}]' \
      "$PROJECT_STATE_FILE" > "$PROJECT_STATE_FILE.tmp"
  else
    # Move from active to history
    jq --arg cmd "$command" --arg st "$status" --arg ts "$timestamp" \
      '.active_commands = [.active_commands[] | select(.command != $cmd)] | 
       .workflow_history += [{"command": $cmd, "status": $st, "completed": $ts}]' \
      "$PROJECT_STATE_FILE" > "$PROJECT_STATE_FILE.tmp"
  fi
  
  mv "$PROJECT_STATE_FILE.tmp" "$PROJECT_STATE_FILE"
}

# Track task execution
track_task() {
  local task_id="$1"
  local task_description="$2"
  local status="${3:-pending}"
  
  jq --arg id "$task_id" --arg desc "$task_description" --arg st "$status" \
    '.recent_tasks = ([{"id": $id, "description": $desc, "status": $st, "timestamp": now}] + .recent_tasks) | .recent_tasks = .recent_tasks[0:10]' \
    "$PROJECT_STATE_FILE" > "$PROJECT_STATE_FILE.tmp"
  mv "$PROJECT_STATE_FILE.tmp" "$PROJECT_STATE_FILE"
  
  echo "Task tracked: $task_id - $status"
}

# Update cache statistics
update_cache_stats() {
  local cache_dir=".agent-os/cache"
  
  if [ -d "$cache_dir" ]; then
    local cache_size=$(du -sh "$cache_dir" 2>/dev/null | cut -f1)
    local cache_files=$(find "$cache_dir" -type f | wc -l)
    
    jq --arg size "$cache_size" --arg files "$cache_files" \
      '.cache_stats.size = $size | .cache_stats.files = ($files | tonumber)' \
      "$PROJECT_STATE_FILE" > "$PROJECT_STATE_FILE.tmp"
    mv "$PROJECT_STATE_FILE.tmp" "$PROJECT_STATE_FILE"
  fi
}

# Orchestrate workflow
orchestrate_workflow() {
  local workflow_type="$1"
  shift
  local args="$@"
  
  case "$workflow_type" in
    "pre-command")
      # Pre-command setup
      echo "Setting up for command execution..."
      track_command "$args" "started"
      
      # Run pre-flight checks
      if [ -x ".agent-os/hooks/pre-flight.sh" ]; then
        .agent-os/hooks/pre-flight.sh
      fi
      ;;
      
    "post-command")
      # Post-command cleanup
      echo "Cleaning up after command execution..."
      track_command "$args" "completed"
      
      # Run post-flight cleanup
      if [ -x ".agent-os/hooks/post-flight.sh" ]; then
        .agent-os/hooks/post-flight.sh
      fi
      
      # Update cache stats
      update_cache_stats
      ;;
      
    "validate-spec")
      # Validate specifications
      if [ -x ".agent-os/hooks/spec-validation.sh" ]; then
        .agent-os/hooks/spec-validation.sh "$args"
      else
        echo "Spec validation hook not found"
      fi
      ;;
      
    "index-codebase")
      # Trigger codebase indexing
      if [ -x ".agent-os/hooks/codebase-indexer.sh" ]; then
        .agent-os/hooks/codebase-indexer.sh build
      else
        echo "Codebase indexer hook not found"
      fi
      ;;
      
    "session")
      # Session management
      if [ -x ".agent-os/hooks/session-management.sh" ]; then
        HOOK_EVENT="$args" .agent-os/hooks/session-management.sh
      else
        echo "Session management hook not found"
      fi
      ;;
      
    *)
      echo "Unknown workflow: $workflow_type"
      echo "Available workflows: pre-command, post-command, validate-spec, index-codebase, session"
      return 1
      ;;
  esac
}

# Get project status
get_project_status() {
  if [ ! -f "$PROJECT_STATE_FILE" ]; then
    echo "Project not initialized"
    return 1
  fi
  
  echo "=== Project Status ==="
  echo "Project: $(jq -r '.project_name' "$PROJECT_STATE_FILE")"
  echo "Initialized: $(jq -r '.initialized' "$PROJECT_STATE_FILE")"
  echo ""
  echo "Active Commands:"
  jq -r '.active_commands[] | "  - " + .command + " (started: " + .started + ")"' "$PROJECT_STATE_FILE"
  echo ""
  echo "Recent Tasks:"
  jq -r '.recent_tasks[0:5][] | "  - [" + .status + "] " + .description' "$PROJECT_STATE_FILE"
  echo ""
  echo "Cache Stats:"
  echo "  Size: $(jq -r '.cache_stats.size' "$PROJECT_STATE_FILE")"
  echo "  Files: $(jq -r '.cache_stats.files // 0' "$PROJECT_STATE_FILE")"
  echo "====================="
}

# Clean up old data
cleanup_old_data() {
  local days="${1:-7}"
  
  echo "Cleaning up data older than $days days..."
  
  # Clean old cache files
  find .agent-os/cache -type f -mtime +$days -delete 2>/dev/null
  
  # Clean old session files
  find .agent-os/session/completed -type f -mtime +$days -delete 2>/dev/null
  
  # Clean old reports
  find .agent-os/reports -type f -mtime +$days -delete 2>/dev/null
  
  # Trim workflow history
  jq '.workflow_history = .workflow_history[-100:]' "$PROJECT_STATE_FILE" > "$PROJECT_STATE_FILE.tmp"
  mv "$PROJECT_STATE_FILE.tmp" "$PROJECT_STATE_FILE"
  
  echo "Cleanup complete"
}

# Generate project report
generate_project_report() {
  local report_file=".agent-os/reports/project-status-$(date +%Y%m%d-%H%M%S).md"
  mkdir -p .agent-os/reports
  
  cat > "$report_file" <<EOF
# Project Status Report

**Generated:** $(date)  
**Project:** $(jq -r '.project_name' "$PROJECT_STATE_FILE")

## Recent Activity

### Active Commands
$(jq -r '.active_commands[] | "- " + .command + " (started: " + .started + ")"' "$PROJECT_STATE_FILE")

### Recent Tasks (Last 10)
$(jq -r '.recent_tasks[] | "- [" + .status + "] " + .description + " (" + (.timestamp | todate) + ")"' "$PROJECT_STATE_FILE")

## System Status

### Environment
$(jq -r '.environment | to_entries[] | "- " + .key + ": " + .value' "$PROJECT_STATE_FILE")

### Cache Statistics
- Size: $(jq -r '.cache_stats.size' "$PROJECT_STATE_FILE")
- Files: $(jq -r '.cache_stats.files // 0' "$PROJECT_STATE_FILE")

## Workflow History (Last 10)
$(jq -r '.workflow_history[-10:][] | "- " + .command + " [" + .status + "] - " + .completed' "$PROJECT_STATE_FILE")
EOF
  
  echo "Report generated: $report_file"
}

# Main execution
main() {
  case "${1:-status}" in
    "init")
      init_project_state
      ;;
    "track-command")
      track_command "${2:-}" "${3:-}"
      ;;
    "track-task")
      track_task "${2:-}" "${3:-}" "${4:-}"
      ;;
    "orchestrate")
      shift
      orchestrate_workflow "$@"
      ;;
    "status")
      get_project_status
      ;;
    "cleanup")
      cleanup_old_data "${2:-7}"
      ;;
    "report")
      generate_project_report
      ;;
    *)
      echo "Usage: $0 {init|track-command|track-task|orchestrate|status|cleanup|report} [args]"
      echo ""
      echo "Commands:"
      echo "  init                    - Initialize project state"
      echo "  track-command <cmd> <status> - Track command execution"
      echo "  track-task <id> <desc> <status> - Track task progress"
      echo "  orchestrate <workflow> [args] - Run workflow orchestration"
      echo "  status                  - Show project status"
      echo "  cleanup [days]          - Clean old data (default: 7 days)"
      echo "  report                  - Generate status report"
      exit 1
      ;;
  esac
}

# Execute if not sourced
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi