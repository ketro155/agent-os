---
name: tmux-monitor
description: Manages a live tmux dashboard showing agent lifecycle events, task progress, and latest transcripts in real-time. Use during /execute-tasks runs to monitor agent activity visually. Use when user says "start monitor", "show agent dashboard", "tmux monitor", or "watch agent activity".
version: 1.0.0
metadata:
  author: Agent OS
  category: monitoring
---

# tmux Monitor Skill

Manages a live tmux dashboard showing agent lifecycle, task progress, and transcripts in real-time.

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

Determine the command from user arguments. If no argument given, check status first — if already running show status, otherwise start.

```bash
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
MONITOR_SCRIPT="$PROJECT_DIR/.claude/scripts/tmux-monitor.sh"

# Default: check if running, start if not
ARGS="$1"
if [ -z "$ARGS" ]; then
  if command -v tmux &> /dev/null && tmux has-session -t aos-monitor 2>/dev/null; then
    ARGS="status"
  else
    ARGS="start"
  fi
fi

if [ ! -x "$MONITOR_SCRIPT" ]; then
  echo '{"status":"error","error":"script_missing","message":"tmux-monitor.sh not found or not executable. Ensure Agent OS is installed."}'
  exit 1
fi

bash "$MONITOR_SCRIPT" "$ARGS"
```

## Response Format

Parse the JSON output and present it to the user:

### On `start` success:

Use the `attach` field from JSON output for the correct command (auto-detects iTerm2 `-CC` mode).

```
Monitor started with 3 panes:
  - Agent Lifecycle (live tail of agents.jsonl)
  - Task Progress (refreshes every 5s)
  - Latest Transcript (refreshes every 10s)

Attach from another terminal: <attach command from JSON>
Detach with: Ctrl+B, then D
```

### On `status`:
```
Monitor: Running (3 panes)
Agent Events: 42 entries, last modified 2026-02-10T14:30:00
Transcripts: 8 files, latest: phase2_20260210_143022.txt
Active Spec: my-feature
```

### On `stop`:
```
Monitor session terminated.
```

### On `tmux_not_installed` error:
```
tmux is required but not installed.

Install with:
  macOS:  brew install tmux
  Ubuntu: sudo apt install tmux
  Fedora: sudo dnf install tmux

After installing, run /tmux-monitor again.
```

### On `already_running`:

Use the `attach` field from JSON output for the correct command.

```
Monitor is already running.
Attach with: <attach command from JSON>
Use /tmux-monitor refresh to restart with updated paths.
```
