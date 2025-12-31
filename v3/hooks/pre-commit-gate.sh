#!/bin/bash
# Agent OS v3.0 - Pre-Commit Validation Gate
# Replaces: build-check skill invocation, Phase 3 Step 9.7
# CANNOT be skipped - runs before every git commit

set -e

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
ERRORS=()
WARNINGS=()

echo "Running pre-commit validation gate..." >&2

# 1. Build Check
echo "  Checking build..." >&2
if [ -f "$PROJECT_DIR/package.json" ]; then
  # Check if build script exists
  if jq -e '.scripts.build' "$PROJECT_DIR/package.json" > /dev/null 2>&1; then
    if ! npm run build --silent 2>&1; then
      ERRORS+=("Build failed - fix errors before committing")
    fi
  fi
fi

# 2. Type Check (TypeScript)
if [ -f "$PROJECT_DIR/tsconfig.json" ]; then
  echo "  Checking types..." >&2
  if command -v npx &> /dev/null; then
    if ! npx tsc --noEmit 2>&1; then
      ERRORS+=("TypeScript errors found - fix before committing")
    fi
  fi
fi

# 3. Lint Check
echo "  Checking lint..." >&2
if [ -f "$PROJECT_DIR/package.json" ]; then
  if jq -e '.scripts.lint' "$PROJECT_DIR/package.json" > /dev/null 2>&1; then
    if ! npm run lint --silent 2>&1; then
      WARNINGS+=("Lint warnings found")
    fi
  fi
fi

# 4. Test Check (quick tests only)
echo "  Running quick tests..." >&2
if [ -f "$PROJECT_DIR/package.json" ]; then
  if jq -e '.scripts.test' "$PROJECT_DIR/package.json" > /dev/null 2>&1; then
    # Run tests with timeout
    if ! timeout 60 npm test --silent 2>&1; then
      ERRORS+=("Tests failed - all tests must pass before committing")
    fi
  fi
fi

# 5. Tasks Sync Check (v3.0, enhanced v4.5)
TASKS_FILE=$(find "$PROJECT_DIR/.agent-os/specs" -name "tasks.json" -type f 2>/dev/null | head -1)
if [ -n "$TASKS_FILE" ] && [ -f "$TASKS_FILE" ]; then
  echo "  Validating tasks.json..." >&2

  # Check for in_progress tasks (should be completed or pending)
  IN_PROGRESS=$(jq '[.tasks[] | select(.status == "in_progress")] | length' "$TASKS_FILE" 2>/dev/null || echo "0")
  if [ "$IN_PROGRESS" -gt 0 ]; then
    WARNINGS+=("$IN_PROGRESS task(s) still marked as in_progress")
  fi

  # Check artifacts are recorded for completed tasks
  MISSING_ARTIFACTS=$(jq '[.tasks[] | select(.status == "pass" and .type == "parent" and (.artifacts == null or .artifacts == {}))] | length' "$TASKS_FILE" 2>/dev/null || echo "0")
  if [ "$MISSING_ARTIFACTS" -gt 0 ]; then
    WARNINGS+=("$MISSING_ARTIFACTS completed task(s) missing artifacts")
  fi

  # v4.5: Check for orphaned future_tasks (should be auto-graduated by post-file-change hook)
  FUTURE_TASKS=$(jq '(.future_tasks // []) | length' "$TASKS_FILE" 2>/dev/null || echo "0")
  if [ "$FUTURE_TASKS" -gt 0 ]; then
    # Get details for warning message
    ROADMAP_COUNT=$(jq '[.future_tasks // [] | .[] | select(.future_type == "ROADMAP_ITEM")] | length' "$TASKS_FILE" 2>/dev/null || echo "0")
    WAVE_COUNT=$(jq '[.future_tasks // [] | .[] | select(.future_type == "WAVE_TASK" or .future_type == null)] | length' "$TASKS_FILE" 2>/dev/null || echo "0")

    DETAIL=""
    if [ "$ROADMAP_COUNT" -gt 0 ]; then
      DETAIL="$ROADMAP_COUNT ROADMAP"
    fi
    if [ "$WAVE_COUNT" -gt 0 ]; then
      if [ -n "$DETAIL" ]; then
        DETAIL="$DETAIL, $WAVE_COUNT WAVE_TASK"
      else
        DETAIL="$WAVE_COUNT WAVE_TASK"
      fi
    fi

    WARNINGS+=("$FUTURE_TASKS orphaned future_task(s) found ($DETAIL) - run task-operations.sh graduate-all to process")
  fi

  # v4.5: Check for tasks pending subtask expansion
  PENDING_EXPANSION=$(jq '[.tasks[] | select(.needs_subtask_expansion == true)] | length' "$TASKS_FILE" 2>/dev/null || echo "0")
  if [ "$PENDING_EXPANSION" -gt 0 ]; then
    WARNINGS+=("$PENDING_EXPANSION task(s) pending subtask expansion - will be expanded in phase1-discovery")
  fi
fi

# 6. Output result
if [ ${#ERRORS[@]} -gt 0 ]; then
  ERROR_MSG=$(printf '%s\\n' "${ERRORS[@]}")
  cat << EOF
{
  "continue": false,
  "permissionDecision": "deny",
  "systemMessage": "Pre-commit validation FAILED:\\n$ERROR_MSG\\n\\nFix these issues before committing."
}
EOF
  exit 0
fi

if [ ${#WARNINGS[@]} -gt 0 ]; then
  WARNING_MSG=$(printf '%s\\n' "${WARNINGS[@]}")
  cat << EOF
{
  "continue": true,
  "systemMessage": "Pre-commit validation passed with warnings:\\n$WARNING_MSG"
}
EOF
  exit 0
fi

cat << EOF
{
  "continue": true,
  "systemMessage": "Pre-commit validation passed"
}
EOF
