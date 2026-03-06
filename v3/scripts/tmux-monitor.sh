#!/bin/bash
# Agent OS v5.5.0 - Task Progress Dashboard
# Single-pane tmux dashboard showing task progress.
# Split-pane teammate visibility replaces the multi-pane agent monitor.
set -e

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
SESSION_NAME="aos-monitor"
ACTION="${1:-start}"

# Find active spec
find_spec() {
  local state_dir="$PROJECT_DIR/.agent-os/state"
  if [ -f "$state_dir/execution-state.json" ]; then
    jq -r '.spec_name // empty' "$state_dir/execution-state.json" 2>/dev/null
  fi
}

# Check tmux is installed
check_tmux() {
  if ! command -v tmux &> /dev/null; then
    echo '{"status":"error","error":"tmux_not_installed","message":"tmux is required. Install: brew install tmux (macOS) or apt install tmux (Linux)"}'
    exit 1
  fi
}

case "$ACTION" in
  start)
    check_tmux
    if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
      ATTACH_CMD="tmux attach -t $SESSION_NAME"
      if [ "$TERM_PROGRAM" = "iTerm.app" ]; then
        ATTACH_CMD="tmux -CC attach -t $SESSION_NAME"
      fi
      echo "{\"status\":\"already_running\",\"session\":\"$SESSION_NAME\",\"attach\":\"$ATTACH_CMD\"}"
      exit 0
    fi

    SPEC=$(find_spec)
    TASKS_JSON="$PROJECT_DIR/.agent-os/specs/${SPEC:-*}/tasks.json"

    # Create session with task progress pane
    tmux new-session -d -s "$SESSION_NAME" -n "progress" \
      "watch -n 5 'echo \"=== Task Progress ===\"; echo; \
      if ls $TASKS_JSON 2>/dev/null | head -1 > /dev/null 2>&1; then \
        jq -r \"[.tasks[] | \\\"  \\(.id) [\\(.status // \\\"pending\\\")] \\(.title // .description)\\\"] | .[]\" $TASKS_JSON 2>/dev/null; \
        echo; \
        jq -r \".summary // {}\" $TASKS_JSON 2>/dev/null; \
      else \
        echo \"  No active spec found\"; \
      fi; \
      echo; echo \"=== Wave Progress ===\"; \
      if ls $TASKS_JSON 2>/dev/null | head -1 > /dev/null 2>&1; then \
        jq -r \"if .computed.waves then [.computed.waves[] | \\\"  Wave \\(.wave_id): \\(.tasks | length) tasks\\\"] | .[] else \\\"  No wave data\\\" end\" $TASKS_JSON 2>/dev/null; \
      fi; \
      echo; echo \"Updated: \$(date +%H:%M:%S) | Ctrl+C to exit\"'"

    ATTACH_CMD="tmux attach -t $SESSION_NAME"
    if [ "$TERM_PROGRAM" = "iTerm.app" ]; then
      ATTACH_CMD="tmux -CC attach -t $SESSION_NAME"
    fi
    echo "{\"status\":\"started\",\"session\":\"$SESSION_NAME\",\"panes\":1,\"attach\":\"$ATTACH_CMD\"}"
    ;;

  stop)
    if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
      tmux kill-session -t "$SESSION_NAME"
      echo '{"status":"stopped","session":"'"$SESSION_NAME"'"}'
    else
      echo '{"status":"not_running"}'
    fi
    ;;

  status)
    if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
      SPEC=$(find_spec)
      PANES=$(tmux list-panes -t "$SESSION_NAME" 2>/dev/null | wc -l | tr -d ' ')
      echo "{\"status\":\"running\",\"session\":\"$SESSION_NAME\",\"panes\":$PANES,\"spec\":\"${SPEC:-none}\"}"
    else
      echo '{"status":"not_running"}'
    fi
    ;;

  refresh)
    if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
      tmux kill-session -t "$SESSION_NAME" 2>/dev/null
    fi
    exec "$0" start
    ;;

  *)
    echo '{"status":"error","error":"unknown_action","message":"Usage: tmux-monitor.sh [start|stop|status|refresh]"}'
    exit 1
    ;;
esac
