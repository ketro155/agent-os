#!/bin/bash
# Handles session state and continuity

case "$HOOK_EVENT" in
  "session-start")
    mkdir -p .agent-os/session
    echo "{\"started\": \"$(date)\", \"session_id\": \"$(uuidgen)\"}" > .agent-os/session/current.json
    ;;
  "session-end")
    if [ -f .agent-os/session/current.json ]; then
      mkdir -p .agent-os/session/completed
      mv .agent-os/session/current.json .agent-os/session/completed/$(date +%Y%m%d_%H%M%S).json
    fi
    ;;
  "session-save")
    if [ -f .agent-os/session/current.json ]; then
      # Save current session state
      jq ". + {\"last_checkpoint\": \"$(date)\", \"state\": \"$SESSION_STATE\"}" .agent-os/session/current.json > .agent-os/session/current.json.tmp
      mv .agent-os/session/current.json.tmp .agent-os/session/current.json
    fi
    ;;
  "session-restore")
    if [ -f .agent-os/session/current.json ]; then
      # Restore session state
      export SESSION_STATE=$(jq -r '.state // empty' .agent-os/session/current.json)
      echo "Session restored: $SESSION_STATE"
    fi
    ;;
esac