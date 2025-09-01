#!/bin/bash
# Pre-flight checks and setup - migrated from instructions/meta/pre-flight.md

# PRE-FLIGHT RULES STATE FILE
PRE_FLIGHT_STATE=".agent-os/session/pre-flight-state.json"

# Initialize pre-flight rules tracking
init_pre_flight_rules() {
  mkdir -p .agent-os/session
  cat > "$PRE_FLIGHT_STATE" <<EOF
{
  "initialized": "$(date)",
  "rules": {
    "subagent_delegation": "IMPORTANT: For any step that specifies a subagent in the subagent=\"\" XML attribute you MUST use the specified subagent",
    "xml_processing": "Process XML blocks sequentially",
    "step_execution": "Read and execute every numbered step in the process_flow EXACTLY as instructions specify",
    "clarification_protocol": "If clarification needed, stop and ask user specific numbered questions",
    "template_compliance": "Use exact templates as provided"
  },
  "checks_performed": [],
  "subagents_required": [],
  "clarifications_needed": []
}
EOF
}

# Environment validation
check_environment() {
  local errors=0
  
  # Check for required tools
  for tool in git node npm; do
    if ! command -v $tool &> /dev/null; then
      echo "ERROR: Required tool '$tool' not found"
      ((errors++))
    fi
  done
  
  # Check git status
  if [ -d .git ]; then
    if [ -n "$(git status --porcelain)" ]; then
      echo "WARNING: Uncommitted changes in repository"
    fi
  fi
  
  # Check for Agent-OS configuration
  if [ ! -f config.yml ] && [ ! -f .agent-os/config.yml ]; then
    echo "WARNING: No Agent-OS configuration found"
  fi
  
  # Record environment check
  if [ -f "$PRE_FLIGHT_STATE" ]; then
    jq '.checks_performed += ["environment_validation"]' "$PRE_FLIGHT_STATE" > "${PRE_FLIGHT_STATE}.tmp"
    mv "${PRE_FLIGHT_STATE}.tmp" "$PRE_FLIGHT_STATE"
  fi
  
  return $errors
}

# Cache initialization
initialize_cache() {
  mkdir -p .agent-os/cache
  
  # Create cache index if doesn't exist
  if [ ! -f .agent-os/cache/index.json ]; then
    echo '{"created": "'$(date)'", "entries": {}}' > .agent-os/cache/index.json
  fi
  
  # Clean old cache entries (older than 24 hours)
  find .agent-os/cache -type f -mtime +1 -name "*.cache" -delete 2>/dev/null
  
  # Record cache initialization
  if [ -f "$PRE_FLIGHT_STATE" ]; then
    jq '.checks_performed += ["cache_initialization"]' "$PRE_FLIGHT_STATE" > "${PRE_FLIGHT_STATE}.tmp"
    mv "${PRE_FLIGHT_STATE}.tmp" "$PRE_FLIGHT_STATE"
  fi
}

# Specification loading
load_specifications() {
  local spec_dirs=("specs" "specifications" "docs/specs")
  
  for dir in "${spec_dirs[@]}"; do
    if [ -d "$dir" ]; then
      export SPEC_PATH="$dir"
      echo "Specifications found at: $SPEC_PATH"
      break
    fi
  done
  
  # Record specification loading
  if [ -f "$PRE_FLIGHT_STATE" ]; then
    jq --arg path "${SPEC_PATH:-none}" '.spec_path = $path | .checks_performed += ["specification_loading"]' "$PRE_FLIGHT_STATE" > "${PRE_FLIGHT_STATE}.tmp"
    mv "${PRE_FLIGHT_STATE}.tmp" "$PRE_FLIGHT_STATE"
  fi
}

# Check for subagent requirements in command
check_subagent_requirements() {
  local command_file="${1:-}"
  
  if [ -n "$command_file" ] && [ -f "$command_file" ]; then
    # Look for subagent attributes in XML blocks
    local subagents=$(grep -o 'subagent="[^"]*"' "$command_file" 2>/dev/null | sed 's/subagent="//' | sed 's/"//' | sort -u)
    
    if [ -n "$subagents" ]; then
      echo "Subagents required for this command:"
      echo "$subagents" | while read -r agent; do
        echo "  - $agent"
        # Record required subagent
        if [ -f "$PRE_FLIGHT_STATE" ]; then
          jq --arg agent "$agent" '.subagents_required += [$agent]' "$PRE_FLIGHT_STATE" > "${PRE_FLIGHT_STATE}.tmp"
          mv "${PRE_FLIGHT_STATE}.tmp" "$PRE_FLIGHT_STATE"
        fi
      done
    fi
  fi
}

# Verify XML processing capability
verify_xml_processing() {
  # Check if command contains XML blocks that need processing
  local xml_blocks=$(find commands -name "*.md" -exec grep -l '<[a-z_]*>' {} \; 2>/dev/null | wc -l)
  
  if [ $xml_blocks -gt 0 ]; then
    echo "XML block processing required for $xml_blocks command files"
    
    # Record XML processing requirement
    if [ -f "$PRE_FLIGHT_STATE" ]; then
      jq --arg count "$xml_blocks" '.xml_blocks_found = ($count | tonumber) | .checks_performed += ["xml_processing_verification"]' "$PRE_FLIGHT_STATE" > "${PRE_FLIGHT_STATE}.tmp"
      mv "${PRE_FLIGHT_STATE}.tmp" "$PRE_FLIGHT_STATE"
    fi
  fi
}

# Display pre-flight rules reminder
display_rules_reminder() {
  echo ""
  echo "╔════════════════════════════════════════════════════════════════╗"
  echo "║                    PRE-FLIGHT RULES ACTIVE                     ║"
  echo "╠════════════════════════════════════════════════════════════════╣"
  echo "║ 1. SUBAGENT DELEGATION: Use specified subagents when required  ║"
  echo "║ 2. XML PROCESSING: Process XML blocks sequentially             ║"
  echo "║ 3. STEP EXECUTION: Execute every step EXACTLY as specified     ║"
  echo "║ 4. CLARIFICATION: Ask numbered questions when needed           ║"
  echo "║ 5. TEMPLATES: Use exact templates as provided                  ║"
  echo "╚════════════════════════════════════════════════════════════════╝"
  echo ""
}

# Main pre-flight execution
main() {
  echo "=== Agent-OS Pre-Flight Checks ==="
  
  # Initialize pre-flight rules tracking
  init_pre_flight_rules
  
  # Run environment checks
  if ! check_environment; then
    echo "Pre-flight checks failed"
    exit 1
  fi
  
  # Initialize cache
  initialize_cache
  
  # Load specifications
  load_specifications
  
  # Check for subagent requirements
  check_subagent_requirements "${AGENT_OS_COMMAND_FILE:-}"
  
  # Verify XML processing capability
  verify_xml_processing
  
  # Set up session
  export AGENT_OS_SESSION_ID=$(uuidgen)
  echo "Session initialized: $AGENT_OS_SESSION_ID"
  
  # Display rules reminder
  display_rules_reminder
  
  echo "=== Pre-Flight Complete ==="
}

# Execute if not sourced
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi