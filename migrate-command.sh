#!/bin/bash
# migrate-command.sh - Migrates commands to embedded instruction format

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Usage function
usage() {
  echo "Usage: $0 <command-name> [options]"
  echo ""
  echo "Migrates a command to the new embedded instruction format"
  echo ""
  echo "Arguments:"
  echo "  command-name    Name of the command to migrate (e.g., debug, execute-tasks)"
  echo ""
  echo "Options:"
  echo "  --backup        Create backup of original files"
  echo "  --validate      Validate migration after completion"
  echo "  --all           Migrate all commands"
  echo ""
  echo "Examples:"
  echo "  $0 debug --backup --validate"
  echo "  $0 execute-tasks"
  echo "  $0 --all"
  exit 1
}

# Check if command exists
check_command_exists() {
  local cmd_name="$1"
  local cmd_file="commands/${cmd_name}.md"
  
  if [ ! -f "$cmd_file" ]; then
    echo -e "${RED}Error: Command file not found: $cmd_file${NC}"
    return 1
  fi
  
  return 0
}

# Extract instruction reference from command
get_instruction_reference() {
  local cmd_file="$1"
  
  # Look for @.agent-os/instructions/ references
  local instruction_ref=$(grep -o '@\.agent-os/instructions/[^[:space:]]*\.md' "$cmd_file" | head -1)
  
  if [ -z "$instruction_ref" ]; then
    echo -e "${YELLOW}Warning: No instruction reference found in $cmd_file${NC}"
    return 1
  fi
  
  # Convert reference to actual path
  echo "$instruction_ref" | sed 's|@\.agent-os/||'
}

# Resolve execute-tasks special case
resolve_execute_tasks_instructions() {
  local primary="instructions/core/execute-tasks.md"
  local secondary="instructions/core/execute-task.md"
  
  if [ -f "$primary" ] && [ -f "$secondary" ]; then
    echo "$primary $secondary"
  elif [ -f "$primary" ]; then
    echo "$primary"
  else
    echo ""
  fi
}

# Extract pre-flight and post-flight references
extract_meta_references() {
  local instruction_file="$1"
  local meta_refs=""
  
  if [ -f "$instruction_file" ]; then
    # Check for pre-flight reference
    if grep -q "pre-flight\.md\|<pre_flight_check>" "$instruction_file"; then
      meta_refs="pre-flight "
    fi
    
    # Check for post-flight reference
    if grep -q "post-flight\.md\|<post_flight_check>" "$instruction_file"; then
      meta_refs="${meta_refs}post-flight "
    fi
    
    # Check for validation references
    if grep -q "spec-validation\.md\|validation" "$instruction_file"; then
      meta_refs="${meta_refs}spec-validation"
    fi
  fi
  
  echo "$meta_refs"
}

# Extract subagent requirements
extract_subagent_requirements() {
  local instruction_file="$1"
  local subagents=""
  
  if [ -f "$instruction_file" ]; then
    # Extract subagent attributes from step definitions
    subagents=$(grep -o 'subagent="[^"]*"' "$instruction_file" 2>/dev/null | \
                sed 's/subagent="//' | sed 's/"//' | sort -u | tr '\n' ' ')
  fi
  
  echo "$subagents"
}

# Create embedded command from template
create_embedded_command() {
  local cmd_name="$1"
  local cmd_file="commands/${cmd_name}.md"
  local instruction_files="$2"
  local backup="$3"
  
  echo -e "${GREEN}Migrating: $cmd_name${NC}"
  
  # Create backup if requested
  if [ "$backup" = "true" ]; then
    cp "$cmd_file" "${cmd_file}.backup-$(date +%Y%m%d-%H%M%S)"
    echo "  Backup created: ${cmd_file}.backup-*"
  fi
  
  # Read original command content
  local original_content=$(cat "$cmd_file")
  local description=$(echo "$original_content" | head -5 | grep -v "^#" | grep -v "^$" | head -1)
  
  # Start building new command file
  local new_file="commands/${cmd_name}.md.new"
  
  # Extract metadata from instruction files
  local meta_refs=""
  local subagents=""
  local category="workflow"
  local complexity="moderate"
  
  for inst_file in $instruction_files; do
    if [ -f "$inst_file" ]; then
      meta_refs="$meta_refs $(extract_meta_references "$inst_file")"
      subagents="$subagents $(extract_subagent_requirements "$inst_file")"
    fi
  done
  
  # Determine category and complexity
  case "$cmd_name" in
    "debug")
      category="development"
      complexity="complex"
      ;;
    "analyze-product"|"plan-product")
      category="analysis"
      ;;
    "execute-tasks"|"create-tasks")
      category="workflow"
      complexity="complex"
      ;;
    "index-codebase")
      category="infrastructure"
      ;;
  esac
  
  # Write new command file with embedded instructions
  cat > "$new_file" <<EOF
---
id: $cmd_name
version: 2.0.0
description: ${description:-Command description}
metadata:
  author: system
  category: $category
  complexity: $complexity
  migrated_from:
    command: $cmd_file
    instructions: [$instruction_files]
    migration_date: $(date)
    
dependencies:
  subagents: [$(echo $subagents | sed 's/ /, /g' | sed 's/, $//')]
  external_tools: []
  embedded_standards: []
  
configuration:
  cacheable: true
  timeout: 300
  parallel_safe: false
  
hooks:
  session_start: $(echo "$meta_refs" | grep -q "pre-flight" && echo "pre-flight" || echo "optional")
  pre_execution: optional  
  post_execution: $(echo "$meta_refs" | grep -q "post-flight" && echo "post-flight" || echo "optional")
  error_handling: optional
  
cross_references:
  meta_instructions: [$(echo "$meta_refs" | tr ' ' '\n' | grep -v '^$' | sed 's/^/"/;s/$/"/' | tr '\n' ',' | sed 's/,$//')]
  utilities: [$(echo "$meta_refs" | grep -q "validation" && echo '"spec-validation"' || echo "")]
  standards: ["code-style", "best-practices"]
  
resolution_strategy:
  pre_flight: embedded
  post_flight: embedded
  validation: embedded
  cross_refs: inline
---

# $(echo "$cmd_name" | tr '-' ' ' | sed 's/\b\(.\)/\u\1/g')

## Overview
$(echo "$description")

EOF

  # Embed instruction content
  for inst_file in $instruction_files; do
    if [ -f "$inst_file" ]; then
      echo "" >> "$new_file"
      echo "<!-- ========================================" >> "$new_file"
      echo "     EMBEDDED FROM: $inst_file" >> "$new_file"
      echo "     ======================================== -->" >> "$new_file"
      echo "" >> "$new_file"
      
      # Skip the YAML front matter and embed the rest
      awk 'BEGIN{skip=1} /^---$/{if(skip==1){skip=0; getline; next} else {skip=0}} skip==0{print}' "$inst_file" >> "$new_file"
    fi
  done
  
  # Add original command content at the end
  echo "" >> "$new_file"
  echo "<!-- ========================================" >> "$new_file"
  echo "     ORIGINAL COMMAND CONTENT" >> "$new_file"
  echo "     ======================================== -->" >> "$new_file"
  echo "" >> "$new_file"
  echo "## Legacy Command Reference" >> "$new_file"
  echo "" >> "$new_file"
  echo "This command previously referenced external instruction files." >> "$new_file"
  echo "All instructions are now embedded above for reliability and performance." >> "$new_file"
  
  # Replace original file
  mv "$new_file" "$cmd_file"
  
  echo -e "  ${GREEN}✓${NC} Migration complete: $cmd_file"
}

# Validate migrated command
validate_migration() {
  local cmd_name="$1"
  local cmd_file="commands/${cmd_name}.md"
  
  echo -e "${YELLOW}Validating: $cmd_name${NC}"
  
  local errors=0
  
  # Check for required metadata
  if ! grep -q "^version: 2.0.0" "$cmd_file"; then
    echo -e "  ${RED}✗${NC} Missing version 2.0.0"
    ((errors++))
  else
    echo -e "  ${GREEN}✓${NC} Version 2.0.0 found"
  fi
  
  # Check for embedded instructions
  if ! grep -q "EMBEDDED FROM:" "$cmd_file"; then
    echo -e "  ${RED}✗${NC} No embedded instructions found"
    ((errors++))
  else
    echo -e "  ${GREEN}✓${NC} Embedded instructions found"
  fi
  
  # Check for metadata section
  if ! grep -q "^metadata:" "$cmd_file"; then
    echo -e "  ${RED}✗${NC} Missing metadata section"
    ((errors++))
  else
    echo -e "  ${GREEN}✓${NC} Metadata section found"
  fi
  
  # Check for dependencies section
  if ! grep -q "^dependencies:" "$cmd_file"; then
    echo -e "  ${RED}✗${NC} Missing dependencies section"
    ((errors++))
  else
    echo -e "  ${GREEN}✓${NC} Dependencies section found"
  fi
  
  if [ $errors -eq 0 ]; then
    echo -e "  ${GREEN}✓ Validation passed${NC}"
    return 0
  else
    echo -e "  ${RED}✗ Validation failed with $errors errors${NC}"
    return 1
  fi
}

# Migrate all commands
migrate_all_commands() {
  local backup="$1"
  local validate="$2"
  
  echo -e "${GREEN}Migrating all commands...${NC}"
  echo ""
  
  local commands=(
    "debug"
    "analyze-product"
    "create-spec"
    "create-tasks"
    "execute-tasks"
    "index-codebase"
    "plan-product"
  )
  
  for cmd in "${commands[@]}"; do
    if check_command_exists "$cmd"; then
      # Get instruction files
      local instruction_files=""
      
      if [ "$cmd" = "execute-tasks" ]; then
        # Special case for execute-tasks
        instruction_files=$(resolve_execute_tasks_instructions)
      else
        local inst_ref=$(get_instruction_reference "commands/${cmd}.md")
        if [ -n "$inst_ref" ]; then
          instruction_files="$inst_ref"
        fi
      fi
      
      if [ -n "$instruction_files" ]; then
        create_embedded_command "$cmd" "$instruction_files" "$backup"
        
        if [ "$validate" = "true" ]; then
          validate_migration "$cmd"
        fi
      else
        echo -e "${YELLOW}Skipping $cmd: No instruction reference found${NC}"
      fi
    fi
    
    echo ""
  done
  
  echo -e "${GREEN}All commands migrated!${NC}"
}

# Main execution
main() {
  # Parse arguments
  if [ $# -eq 0 ]; then
    usage
  fi
  
  local cmd_name=""
  local backup="false"
  local validate="false"
  local migrate_all="false"
  
  while [ $# -gt 0 ]; do
    case "$1" in
      --help|-h)
        usage
        ;;
      --backup)
        backup="true"
        shift
        ;;
      --validate)
        validate="true"
        shift
        ;;
      --all)
        migrate_all="true"
        shift
        ;;
      -*)
        echo "Unknown option: $1"
        usage
        ;;
      *)
        cmd_name="$1"
        shift
        ;;
    esac
  done
  
  # Execute migration
  if [ "$migrate_all" = "true" ]; then
    migrate_all_commands "$backup" "$validate"
  elif [ -n "$cmd_name" ]; then
    if check_command_exists "$cmd_name"; then
      # Get instruction files
      local instruction_files=""
      
      if [ "$cmd_name" = "execute-tasks" ]; then
        instruction_files=$(resolve_execute_tasks_instructions)
      else
        local inst_ref=$(get_instruction_reference "commands/${cmd_name}.md")
        if [ -n "$inst_ref" ]; then
          instruction_files="$inst_ref"
        fi
      fi
      
      if [ -n "$instruction_files" ]; then
        create_embedded_command "$cmd_name" "$instruction_files" "$backup"
        
        if [ "$validate" = "true" ]; then
          validate_migration "$cmd_name"
        fi
      else
        echo -e "${RED}No instruction files found for $cmd_name${NC}"
        exit 1
      fi
    fi
  else
    usage
  fi
}

# Run main function
main "$@"