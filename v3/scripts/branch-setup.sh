#!/bin/bash
# Agent OS v4.3.0 - Branch Setup Script
# Ensures proper wave branching structure for specs
# Called by phase1-discovery and phase3-delivery

set -e

COMMAND="${1:-help}"
shift || true

# Robust project directory detection (same as task-operations.sh)
detect_project_dir() {
  if [ -n "$CLAUDE_PROJECT_DIR" ] && [ -d "$CLAUDE_PROJECT_DIR/.agent-os" ]; then
    echo "$CLAUDE_PROJECT_DIR"
    return
  fi

  if [ -d "./.agent-os" ]; then
    pwd
    return
  fi

  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local project_dir="${script_dir%/.claude/scripts}"
  if [ -d "$project_dir/.agent-os" ]; then
    echo "$project_dir"
    return
  fi

  local current="$(pwd)"
  while [ "$current" != "/" ]; do
    if [ -d "$current/.agent-os" ]; then
      echo "$current"
      return
    fi
    current="$(dirname "$current")"
  done

  pwd
}

PROJECT_DIR="$(detect_project_dir)"

# Extract spec name from folder (removes date prefix if present)
# e.g., "2025-01-29-auth-system" -> "auth-system"
normalize_spec_name() {
  local spec_folder="$1"
  # Remove leading date pattern (YYYY-MM-DD-)
  echo "$spec_folder" | sed -E 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}-//'
}

# Check if a branch exists locally or remotely
branch_exists() {
  local branch="$1"
  local check_type="${2:-any}"  # "local", "remote", or "any"

  case "$check_type" in
    local)
      git branch --list "$branch" | grep -q .
      ;;
    remote)
      git ls-remote --heads origin "$branch" 2>/dev/null | grep -q .
      ;;
    any|*)
      git branch --list "$branch" | grep -q . || \
        git ls-remote --heads origin "$branch" 2>/dev/null | grep -q .
      ;;
  esac
}

# Get current wave number from tasks.json
get_current_wave() {
  local spec_name="$1"
  local tasks_file="$PROJECT_DIR/.agent-os/specs/$spec_name/tasks.json"

  if [ ! -f "$tasks_file" ]; then
    echo "1"
    return
  fi

  # Find the first wave with pending tasks
  local wave
  wave=$(jq -r '
    .execution_strategy.waves as $waves |
    .tasks as $tasks |
    ($waves // []) |
    map(select(
      .tasks as $wave_tasks |
      ($tasks | map(select(.id as $id | $wave_tasks | index($id))) | map(select(.status == "pending")) | length) > 0
    )) |
    .[0].wave_id // 1
  ' "$tasks_file" 2>/dev/null)

  echo "${wave:-1}"
}

# Get total waves from tasks.json
get_total_waves() {
  local spec_name="$1"
  local tasks_file="$PROJECT_DIR/.agent-os/specs/$spec_name/tasks.json"

  if [ ! -f "$tasks_file" ]; then
    echo "1"
    return
  fi

  local total
  total=$(jq -r '.execution_strategy.waves | length // 1' "$tasks_file" 2>/dev/null)
  echo "${total:-1}"
}

case "$COMMAND" in

  # Validate and setup branch structure for a wave
  # Usage: branch-setup.sh setup <spec_name> [wave_number]
  # Returns JSON with branch info and PR target
  setup)
    SPEC_NAME="$1"
    WAVE_NUMBER="${2:-}"

    if [ -z "$SPEC_NAME" ]; then
      echo '{"error": "Usage: branch-setup.sh setup <spec_name> [wave_number]", "status": "error"}'
      exit 1
    fi

    # Normalize spec name (remove date prefix)
    NORMALIZED_SPEC=$(normalize_spec_name "$SPEC_NAME")

    # Auto-detect wave if not provided
    if [ -z "$WAVE_NUMBER" ]; then
      WAVE_NUMBER=$(get_current_wave "$SPEC_NAME")
    fi

    TOTAL_WAVES=$(get_total_waves "$SPEC_NAME")

    # Define branch names
    BASE_BRANCH="feature/$NORMALIZED_SPEC"
    WAVE_BRANCH="feature/$NORMALIZED_SPEC-wave-$WAVE_NUMBER"

    # Get current branch
    CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")

    # Track what we did
    ACTIONS_TAKEN=()
    WARNINGS=()

    # Step 1: Ensure base branch exists
    if ! branch_exists "$BASE_BRANCH"; then
      # Check if we're on main/master
      MAIN_BRANCH="main"
      if ! branch_exists "main" "local"; then
        MAIN_BRANCH="master"
      fi

      # Create base branch from main
      git checkout "$MAIN_BRANCH" 2>/dev/null || true
      git pull origin "$MAIN_BRANCH" --ff-only 2>/dev/null || true
      git checkout -b "$BASE_BRANCH" 2>/dev/null

      # Push base branch to remote
      if git push -u origin "$BASE_BRANCH" 2>/dev/null; then
        ACTIONS_TAKEN+=("created_base_branch")
      else
        WARNINGS+=("failed_to_push_base_branch")
      fi
    else
      # Base branch exists - make sure we have it locally
      if ! branch_exists "$BASE_BRANCH" "local"; then
        git fetch origin "$BASE_BRANCH" 2>/dev/null || true
        git checkout -b "$BASE_BRANCH" "origin/$BASE_BRANCH" 2>/dev/null || true
        ACTIONS_TAKEN+=("fetched_base_branch")
      fi
    fi

    # Step 2: Ensure wave branch exists (created from base, not main!)
    if ! branch_exists "$WAVE_BRANCH"; then
      # Switch to base branch first
      git checkout "$BASE_BRANCH" 2>/dev/null
      git pull origin "$BASE_BRANCH" --ff-only 2>/dev/null || true

      # Create wave branch from base
      git checkout -b "$WAVE_BRANCH" 2>/dev/null
      ACTIONS_TAKEN+=("created_wave_branch")

      # Push wave branch
      if git push -u origin "$WAVE_BRANCH" 2>/dev/null; then
        ACTIONS_TAKEN+=("pushed_wave_branch")
      else
        WARNINGS+=("failed_to_push_wave_branch")
      fi
    else
      # Wave branch exists - switch to it
      if [ "$CURRENT_BRANCH" != "$WAVE_BRANCH" ]; then
        # Fetch latest first
        git fetch origin "$WAVE_BRANCH" 2>/dev/null || true

        if branch_exists "$WAVE_BRANCH" "local"; then
          git checkout "$WAVE_BRANCH" 2>/dev/null
          git pull origin "$WAVE_BRANCH" --ff-only 2>/dev/null || true
        else
          git checkout -b "$WAVE_BRANCH" "origin/$WAVE_BRANCH" 2>/dev/null
        fi
        ACTIONS_TAKEN+=("switched_to_wave_branch")
      else
        ACTIONS_TAKEN+=("already_on_wave_branch")
      fi
    fi

    # Determine PR target
    # Wave branches always PR to base branch, not main
    PR_TARGET="$BASE_BRANCH"
    IS_FINAL_WAVE="false"
    if [ "$WAVE_NUMBER" -eq "$TOTAL_WAVES" ]; then
      IS_FINAL_WAVE="true"
    fi

    # Output structured result
    ACTIONS_JSON=$(printf '%s\n' "${ACTIONS_TAKEN[@]}" | jq -R . | jq -s .)
    WARNINGS_JSON=$(printf '%s\n' "${WARNINGS[@]}" | jq -R . | jq -s . 2>/dev/null || echo '[]')

    cat <<EOF
{
  "status": "success",
  "spec_name": "$SPEC_NAME",
  "normalized_spec": "$NORMALIZED_SPEC",
  "wave_number": $WAVE_NUMBER,
  "total_waves": $TOTAL_WAVES,
  "branches": {
    "base": "$BASE_BRANCH",
    "wave": "$WAVE_BRANCH",
    "current": "$(git branch --show-current)"
  },
  "pr_target": "$PR_TARGET",
  "is_final_wave": $IS_FINAL_WAVE,
  "final_pr_target": "main",
  "actions_taken": $ACTIONS_JSON,
  "warnings": $WARNINGS_JSON
}
EOF
    ;;

  # Get PR target for current branch
  # Usage: branch-setup.sh pr-target [spec_name]
  pr-target)
    SPEC_NAME="$1"
    CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")

    if [ -z "$CURRENT_BRANCH" ]; then
      echo '{"error": "Not in a git repository or no branch checked out", "status": "error"}'
      exit 1
    fi

    # Check if this is a wave branch
    if [[ "$CURRENT_BRANCH" =~ ^feature/(.+)-wave-([0-9]+)$ ]]; then
      NORMALIZED_SPEC="${BASH_REMATCH[1]}"
      WAVE_NUMBER="${BASH_REMATCH[2]}"
      BASE_BRANCH="feature/$NORMALIZED_SPEC"

      # Wave branches ALWAYS target base branch
      cat <<EOF
{
  "status": "success",
  "current_branch": "$CURRENT_BRANCH",
  "branch_type": "wave",
  "wave_number": $WAVE_NUMBER,
  "pr_target": "$BASE_BRANCH",
  "is_wave_pr": true,
  "note": "Wave PRs merge to base feature branch, not main"
}
EOF
    elif [[ "$CURRENT_BRANCH" =~ ^feature/(.+)$ ]]; then
      # Base feature branch - targets main
      cat <<EOF
{
  "status": "success",
  "current_branch": "$CURRENT_BRANCH",
  "branch_type": "base",
  "pr_target": "main",
  "is_wave_pr": false,
  "note": "Base feature branch PRs merge to main"
}
EOF
    else
      # Not a feature branch
      cat <<EOF
{
  "status": "success",
  "current_branch": "$CURRENT_BRANCH",
  "branch_type": "other",
  "pr_target": "main",
  "is_wave_pr": false,
  "note": "Non-feature branches default to main"
}
EOF
    fi
    ;;

  # Validate current branch matches expected wave
  # Usage: branch-setup.sh validate <spec_name> <wave_number>
  validate)
    SPEC_NAME="$1"
    EXPECTED_WAVE="$2"

    if [ -z "$SPEC_NAME" ] || [ -z "$EXPECTED_WAVE" ]; then
      echo '{"error": "Usage: branch-setup.sh validate <spec_name> <wave_number>", "status": "error"}'
      exit 1
    fi

    NORMALIZED_SPEC=$(normalize_spec_name "$SPEC_NAME")
    EXPECTED_BRANCH="feature/$NORMALIZED_SPEC-wave-$EXPECTED_WAVE"
    CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
    BASE_BRANCH="feature/$NORMALIZED_SPEC"

    if [ "$CURRENT_BRANCH" = "$EXPECTED_BRANCH" ]; then
      cat <<EOF
{
  "status": "valid",
  "current_branch": "$CURRENT_BRANCH",
  "expected_branch": "$EXPECTED_BRANCH",
  "base_branch": "$BASE_BRANCH",
  "base_exists": $(branch_exists "$BASE_BRANCH" && echo "true" || echo "false")
}
EOF
    else
      cat <<EOF
{
  "status": "invalid",
  "current_branch": "$CURRENT_BRANCH",
  "expected_branch": "$EXPECTED_BRANCH",
  "base_branch": "$BASE_BRANCH",
  "base_exists": $(branch_exists "$BASE_BRANCH" && echo "true" || echo "false"),
  "action_required": "Run: branch-setup.sh setup $SPEC_NAME $EXPECTED_WAVE"
}
EOF
      exit 1
    fi
    ;;

  # Show current branch info
  # Usage: branch-setup.sh info
  info)
    CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")

    if [ -z "$CURRENT_BRANCH" ]; then
      echo '{"error": "Not in a git repository", "status": "error"}'
      exit 1
    fi

    # Parse branch name
    if [[ "$CURRENT_BRANCH" =~ ^feature/(.+)-wave-([0-9]+)$ ]]; then
      NORMALIZED_SPEC="${BASH_REMATCH[1]}"
      WAVE_NUMBER="${BASH_REMATCH[2]}"
      BASE_BRANCH="feature/$NORMALIZED_SPEC"
      BRANCH_TYPE="wave"
    elif [[ "$CURRENT_BRANCH" =~ ^feature/(.+)$ ]]; then
      NORMALIZED_SPEC="${BASH_REMATCH[1]}"
      WAVE_NUMBER="null"
      BASE_BRANCH="$CURRENT_BRANCH"
      BRANCH_TYPE="base"
    else
      NORMALIZED_SPEC="null"
      WAVE_NUMBER="null"
      BASE_BRANCH="null"
      BRANCH_TYPE="other"
    fi

    cat <<EOF
{
  "status": "success",
  "current_branch": "$CURRENT_BRANCH",
  "branch_type": "$BRANCH_TYPE",
  "spec_name": $([ "$NORMALIZED_SPEC" = "null" ] && echo "null" || echo "\"$NORMALIZED_SPEC\""),
  "wave_number": $WAVE_NUMBER,
  "base_branch": $([ "$BASE_BRANCH" = "null" ] && echo "null" || echo "\"$BASE_BRANCH\""),
  "base_exists": $([ "$BASE_BRANCH" != "null" ] && branch_exists "$BASE_BRANCH" && echo "true" || echo "false")
}
EOF
    ;;

  # Cleanup a merged wave branch (local and remote)
  # Usage: branch-setup.sh cleanup <branch_name>
  cleanup)
    BRANCH_NAME="$1"

    if [ -z "$BRANCH_NAME" ]; then
      echo '{"error": "Usage: branch-setup.sh cleanup <branch_name>"}'
      exit 1
    fi

    CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")

    # Don't delete the branch we're on
    if [ "$CURRENT_BRANCH" = "$BRANCH_NAME" ]; then
      echo '{"error": "Cannot delete current branch. Switch to another branch first."}'
      exit 1
    fi

    # Safety: Don't delete main/master or base feature branches
    if [[ "$BRANCH_NAME" =~ ^(main|master)$ ]]; then
      echo '{"error": "Cannot delete main/master branch"}'
      exit 1
    fi

    # Warn if trying to delete a base feature branch (not a wave branch)
    if [[ "$BRANCH_NAME" =~ ^feature/[^-]+-[^-]+$ ]] && [[ ! "$BRANCH_NAME" =~ -wave-[0-9]+$ ]]; then
      echo '{"warning": "This appears to be a base feature branch, not a wave branch. Proceeding anyway..."}'
    fi

    DELETED_LOCAL=false
    DELETED_REMOTE=false
    ERRORS=()

    # Delete local branch
    if branch_exists "$BRANCH_NAME" "local"; then
      if git branch -d "$BRANCH_NAME" 2>/dev/null; then
        DELETED_LOCAL=true
      else
        # Try force delete if branch not fully merged (already merged to base)
        if git branch -D "$BRANCH_NAME" 2>/dev/null; then
          DELETED_LOCAL=true
        else
          ERRORS+=("failed_to_delete_local")
        fi
      fi
    fi

    # Delete remote branch
    if branch_exists "$BRANCH_NAME" "remote"; then
      if git push origin --delete "$BRANCH_NAME" 2>/dev/null; then
        DELETED_REMOTE=true
      else
        ERRORS+=("failed_to_delete_remote")
      fi
    fi

    ERRORS_JSON=$(printf '%s\n' "${ERRORS[@]}" | jq -R . | jq -s . 2>/dev/null || echo '[]')

    cat <<EOF
{
  "status": "success",
  "branch": "$BRANCH_NAME",
  "deleted_local": $DELETED_LOCAL,
  "deleted_remote": $DELETED_REMOTE,
  "errors": $ERRORS_JSON
}
EOF
    ;;

  help|*)
    cat <<EOF
Agent OS Branch Setup Script v4.4.1

Commands:
  setup <spec_name> [wave]  Setup branch structure for a wave (creates base + wave branch)
  pr-target [spec_name]     Get the correct PR target for current branch
  validate <spec> <wave>    Validate current branch matches expected wave
  info                      Show current branch info
  cleanup <branch_name>     Delete a merged wave branch (local and remote)

Examples:
  # Setup branches for wave 3 of auth-feature
  branch-setup.sh setup auth-feature 3

  # Get PR target for current branch
  branch-setup.sh pr-target

  # Validate we're on the right branch
  branch-setup.sh validate auth-feature 3

  # Delete a merged wave branch
  branch-setup.sh cleanup feature/auth-feature-wave-1

Wave Branching Strategy:
  main
    └── feature/[spec-name]        (base - shared across waves)
          ├── feature/[spec-name]-wave-1
          ├── feature/[spec-name]-wave-2
          └── feature/[spec-name]-wave-3

PR Targets:
  - Wave branches → base feature branch (NOT main)
  - Base feature branch → main (final merge)
EOF
    ;;

esac
