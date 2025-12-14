#!/bin/bash
# Agent OS v3.0 - Post File Change Hook
# Replaces: task-sync skill
# Automatically regenerates tasks.md when tasks.json changes

set -e

# Get the file path from environment (set by Claude Code)
FILE_PATH="${TOOL_INPUT_FILE_PATH:-$1}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# Only process tasks.json files
if [[ "$FILE_PATH" == *"tasks.json" ]]; then
  # Check if it's a v3 format file
  VERSION=$(jq -r '.version // "unknown"' "$FILE_PATH" 2>/dev/null || echo "unknown")

  if [[ "$VERSION" == "3"* ]]; then
    # Regenerate markdown
    SCRIPT_DIR="$(dirname "$0")/../scripts"

    if [ -f "$SCRIPT_DIR/json-to-markdown.js" ]; then
      node "$SCRIPT_DIR/json-to-markdown.js" "$FILE_PATH"

      cat << EOF
{
  "continue": true,
  "systemMessage": "tasks.md auto-regenerated from tasks.json"
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
