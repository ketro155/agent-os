#!/bin/bash
# Agent OS v5.3.0 - Setup Hook
# Triggers: claude --init, --init-only, --maintenance
# Purpose: One-time project initialization, directory creation, version check
set -e

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
EXPECTED_VERSION="${AGENT_OS_VERSION:-5.2.0}"

# 1. Create .agent-os directory structure (idempotent via mkdir -p)
for dir in state state/checkpoints progress scratch scratch/tool_outputs \
           memory memory/pinned memory/sessions metrics metrics/transcripts \
           logs specs plans cache schemas product backlog \
           standards standards/global standards/frontend standards/backend \
           standards/testing test-plans test-results test-reports recaps; do
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

# 6. Validate Teams tools availability (v5.3.0)
TEAMS_WARNING=""
if [ "${AGENT_OS_TEAMS}" = "true" ]; then
  # Check if CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS is likely enabled
  # We can't directly test tool availability from a hook, but we can warn if the env var isn't set
  if [ -z "${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS}" ] && [ "${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS}" != "1" ]; then
    TEAMS_WARNING=" Warning: AGENT_OS_TEAMS=true but CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS may not be set. Teams tools require this Claude Code feature flag."
  fi
fi

# 7. Output
cat << EOF
{"continue":true,"systemMessage":"Agent OS v${EXPECTED_VERSION} initialized.${TEAMS_WARNING} Run /plan-product or /analyze-product to get started."}
EOF
