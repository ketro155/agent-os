#!/bin/bash
# Git workflow automation

# Auto-commit changes
auto_commit() {
  local message="${1:-Auto-commit by Agent-OS}"
  local files_changed=$(git status --porcelain | wc -l)
  
  if [ $files_changed -eq 0 ]; then
    echo "No changes to commit"
    return 0
  fi
  
  # Stage all changes
  git add -A
  
  # Generate commit message if not provided
  if [ "$message" = "Auto-commit by Agent-OS" ]; then
    local summary=$(git diff --cached --stat | tail -1)
    message="feat(agent-os): $summary"
  fi
  
  # Commit changes
  git commit -m "$message"
  echo "Committed $files_changed files"
}

# Create feature branch
create_feature_branch() {
  local branch_name="$1"
  
  if [ -z "$branch_name" ]; then
    branch_name="feat/agent-os-$(date +%Y%m%d-%H%M%S)"
  fi
  
  git checkout -b "$branch_name"
  echo "Created branch: $branch_name"
}

# Sync with remote
sync_remote() {
  local current_branch=$(git branch --show-current)
  
  # Fetch latest changes
  git fetch origin
  
  # Check if branch exists on remote
  if git ls-remote --heads origin "$current_branch" | grep -q "$current_branch"; then
    # Pull if remote branch exists
    git pull origin "$current_branch"
    echo "Synced with remote: $current_branch"
  else
    echo "Branch not on remote: $current_branch"
  fi
}

# Create backup tag
create_backup_tag() {
  local tag_name="backup/$(date +%Y%m%d-%H%M%S)"
  local description="${1:-Backup before Agent-OS operation}"
  
  git tag -a "$tag_name" -m "$description"
  echo "Created backup tag: $tag_name"
}

# Check for conflicts
check_conflicts() {
  local conflicts=$(git diff --name-only --diff-filter=U | wc -l)
  
  if [ $conflicts -gt 0 ]; then
    echo "WARNING: $conflicts merge conflicts detected"
    git diff --name-only --diff-filter=U
    return 1
  fi
  
  echo "No conflicts detected"
  return 0
}

# Main execution
main() {
  case "${1:-status}" in
    "commit")
      auto_commit "${2:-}"
      ;;
    "branch")
      create_feature_branch "${2:-}"
      ;;
    "sync")
      sync_remote
      ;;
    "backup")
      create_backup_tag "${2:-}"
      ;;
    "conflicts")
      check_conflicts
      ;;
    "status")
      git status --short
      ;;
    *)
      echo "Usage: $0 {commit|branch|sync|backup|conflicts|status} [args]"
      exit 1
      ;;
  esac
}

# Hook event handling
if [ -n "$HOOK_EVENT" ]; then
  case "$HOOK_EVENT" in
    "pre-command")
      # Create backup before major operations
      if [ "$AGENT_OS_COMMAND" = "migrate" ] || [ "$AGENT_OS_COMMAND" = "execute-tasks" ]; then
        create_backup_tag "Pre-$AGENT_OS_COMMAND"
      fi
      ;;
    "post-command")
      # Auto-commit if configured
      if [ "$AUTO_COMMIT" = "true" ]; then
        auto_commit "Auto-commit after $AGENT_OS_COMMAND"
      fi
      ;;
  esac
fi

# Execute if not sourced
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi