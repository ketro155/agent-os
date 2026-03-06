---
name: tmux-monitor
description: Manages a task progress dashboard in tmux. Use alongside split-pane teammate mode for a complete monitoring view. Use when user says "start monitor", "show progress dashboard", "tmux monitor", or "watch task progress".
version: 2.0.0
metadata:
  author: Agent OS
  category: monitoring
---

# tmux Monitor Skill (v5.5.0)

Task progress dashboard for tmux. Shows task status and wave progress in a single pane.

**Note**: In v5.5.0, teammate activity is visible directly in split-panes (`Shift+Down` to cycle). This dashboard provides the bird's-eye task view that split-panes don't offer.

## Usage

```
/tmux-monitor            # Start (or show status if already running)
/tmux-monitor stop       # Stop the session
/tmux-monitor status     # Check if running
/tmux-monitor refresh    # Restart with updated file paths
```

## Instructions

1. Parse the user's argument (default: no argument = smart start/status)
2. Run the monitoring script
3. Present results in human-friendly format

## Implementation

```bash
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
MONITOR_SCRIPT="$PROJECT_DIR/.claude/scripts/tmux-monitor.sh"

ARGS="$1"
if [ -z "$ARGS" ]; then
  if command -v tmux &> /dev/null && tmux has-session -t aos-monitor 2>/dev/null; then
    ARGS="status"
  else
    ARGS="start"
  fi
fi

if [ ! -x "$MONITOR_SCRIPT" ]; then
  echo '{"status":"error","error":"script_missing","message":"tmux-monitor.sh not found or not executable."}'
  exit 1
fi

bash "$MONITOR_SCRIPT" "$ARGS"
```

## Response Format

### On `start` success:

```
Progress dashboard started (1 pane):
  - Task & Wave Progress (refreshes every 5s)

Teammate activity is visible in split-panes (Shift+Down to cycle).

Attach from another terminal: <attach command from JSON>
Detach with: Ctrl+B, then D
```

### On `status`:
```
Dashboard: Running (1 pane)
Active Spec: my-feature
```

### On `stop`:
```
Dashboard session terminated.
```

### On `tmux_not_installed` error:
```
tmux is required but not installed.

Install with:
  macOS:  brew install tmux
  Ubuntu: sudo apt install tmux
```
