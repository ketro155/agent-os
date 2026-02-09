#!/bin/bash
# Agent OS v4.12.0 - Setup Hook
# Triggers: claude --init, --init-only, --maintenance
# Purpose: One-time project initialization, directory creation, version check
set -e

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
EXPECTED_VERSION="4.12.0"

# 1. Create .agent-os directory structure (idempotent via mkdir -p)
for dir in state progress scratch scratch/tool_outputs memory memory/pinned \
           memory/sessions metrics metrics/transcripts logs specs plans cache \
           schemas standards standards/global standards/frontend standards/backend \
           standards/testing test-plans test-results recaps; do
  mkdir -p "$PROJECT_DIR/.agent-os/$dir"
done

# 2. Initialize version.json if missing
VERSION_FILE="$PROJECT_DIR/.agent-os/version.json"
if [ ! -f "$VERSION_FILE" ]; then
  cat > "$VERSION_FILE" << EOF
{"agent_os_version":"$EXPECTED_VERSION","initialized_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)"}
EOF
fi

# 3. Initialize progress.json if missing
PROGRESS_FILE="$PROJECT_DIR/.agent-os/progress/progress.json"
if [ ! -f "$PROGRESS_FILE" ]; then
  cat > "$PROGRESS_FILE" << EOF
{"metadata":{"created_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","total_entries":0},"entries":[]}
EOF
fi

# 4. Initialize session_stats.json if missing
STATS_FILE="$PROJECT_DIR/.agent-os/scratch/session_stats.json"
if [ ! -f "$STATS_FILE" ]; then
  echo '{"tasks_completed":0,"bytes_offloaded":0,"offload_count":0,"estimated_tokens_saved":0}' > "$STATS_FILE"
fi

# 5. Persist CLAUDE_PROJECT_DIR
if [ -n "$CLAUDE_ENV_FILE" ] && [ -n "$CLAUDE_PROJECT_DIR" ]; then
  echo "export CLAUDE_PROJECT_DIR=\"$CLAUDE_PROJECT_DIR\"" >> "$CLAUDE_ENV_FILE"
fi

# 6. Output
cat << EOF
{"continue":true,"systemMessage":"Agent OS v${EXPECTED_VERSION} initialized. Run /plan-product or /analyze-product to get started."}
EOF
