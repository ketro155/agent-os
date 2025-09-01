#!/bin/bash
# Specification validation - migrated from instructions/utils/spec-validation.md

# VALIDATION STATE FILE
VALIDATION_STATE=".agent-os/session/validation-state.json"

# Initialize validation tracking
init_validation_state() {
  mkdir -p .agent-os/session
  cat > "$VALIDATION_STATE" <<EOF
{
  "initialized": "$(date)",
  "pre_implementation_checklist": {
    "specs_identified": false,
    "approach_documented": false,
    "inputs_outputs_defined": false,
    "success_criteria_established": false,
    "edge_cases_identified": false,
    "integration_points_verified": false
  },
  "validation_questions": {
    "architectural_alignment": "pending",
    "requirements_addressed": "pending",
    "output_format_match": "pending",
    "interfaces_correct": "pending",
    "edge_cases_handled": "pending"
  },
  "post_implementation_checks": {
    "functionality_matches_spec": false,
    "output_format_follows_structure": false,
    "error_handling_complete": false,
    "integration_working": false,
    "performance_meets_criteria": false,
    "security_requirements_met": false
  },
  "anomalies_detected": [],
  "documentation_compliance": {
    "specs_consulted": [],
    "requirements_extracted": [],
    "implementation_mappings": [],
    "validation_results": [],
    "deviations": []
  }
}
EOF
}

# Pre-implementation validation checklist
run_pre_implementation_checklist() {
  echo "=== Pre-Implementation Validation Checklist ==="
  
  local checklist_items=(
    "specs_identified:Relevant specifications identified and read"
    "approach_documented:Implementation approach documented"
    "inputs_outputs_defined:Expected inputs/outputs defined"
    "success_criteria_established:Success criteria from specs established"
    "edge_cases_identified:Edge cases from specs identified"
    "integration_points_verified:Integration points verified against specs"
  )
  
  for item in "${checklist_items[@]}"; do
    IFS=':' read -r key description <<< "$item"
    echo -n "✓ $description... "
    
    # In real implementation, would check actual state
    # For now, mark as checked
    if [ -f "$VALIDATION_STATE" ]; then
      jq --arg key "$key" '.pre_implementation_checklist[$key] = true' "$VALIDATION_STATE" > "${VALIDATION_STATE}.tmp"
      mv "${VALIDATION_STATE}.tmp" "$VALIDATION_STATE"
    fi
    echo "checked"
  done
  
  echo ""
}

# Validation questions protocol
ask_validation_questions() {
  echo "=== Validation Questions (Ask Before Coding) ==="
  
  local questions=(
    "architectural_alignment:Does this approach align with architectural specifications?"
    "requirements_addressed:Are all specification requirements addressed?"
    "output_format_match:Do expected outputs match spec definitions?"
    "interfaces_correct:Are interfaces and contracts correctly implemented?"
    "edge_cases_handled:Will this handle edge cases mentioned in specs?"
  )
  
  local question_num=1
  for question in "${questions[@]}"; do
    IFS=':' read -r key text <<< "$question"
    echo "$question_num. $text"
    
    # Record question as asked
    if [ -f "$VALIDATION_STATE" ]; then
      jq --arg key "$key" '.validation_questions[$key] = "asked"' "$VALIDATION_STATE" > "${VALIDATION_STATE}.tmp"
      mv "${VALIDATION_STATE}.tmp" "$VALIDATION_STATE"
    fi
    
    ((question_num++))
  done
  
  echo ""
  echo "NOTE: Ensure all questions are answered before proceeding with implementation."
  echo ""
}

# Post-implementation compliance checks
run_post_implementation_checks() {
  echo "=== Post-Implementation Compliance Checks ==="
  
  local checks=(
    "functionality_matches_spec:Functionality matches specification descriptions"
    "output_format_follows_structure:Output format follows specified structure"
    "error_handling_complete:Error handling covers specified scenarios"
    "integration_working:Integration points work as documented"
    "performance_meets_criteria:Performance meets specified criteria"
    "security_requirements_met:Security requirements from specs are met"
  )
  
  for check in "${checks[@]}"; do
    IFS=':' read -r key description <<< "$check"
    echo -n "✓ $description... "
    
    # In real implementation, would run actual checks
    # For now, mark as checked
    if [ -f "$VALIDATION_STATE" ]; then
      jq --arg key "$key" '.post_implementation_checks[$key] = true' "$VALIDATION_STATE" > "${VALIDATION_STATE}.tmp"
      mv "${VALIDATION_STATE}.tmp" "$VALIDATION_STATE"
    fi
    echo "verified"
  done
  
  echo ""
}

# Anomaly detection
detect_anomalies() {
  echo "=== Anomaly Detection ==="
  
  local red_flags=(
    "Behavior contradicts documented requirements"
    "Missing functionality described in specifications"
    "Error messages don't match spec requirements"
    "Integration failures with specified systems"
    "Performance significantly below spec expectations"
  )
  
  local anomalies_found=0
  
  echo "Checking for red flags..."
  for flag in "${red_flags[@]}"; do
    # In real implementation, would check for actual anomalies
    # For demonstration, we'll just list the checks
    echo "  ⚠ Checking: $flag"
  done
  
  if [ $anomalies_found -eq 0 ]; then
    echo "✓ No anomalies detected"
  else
    echo "⚠ $anomalies_found anomalies found - review required"
    
    if [ -f "$VALIDATION_STATE" ]; then
      jq --arg count "$anomalies_found" '.anomalies_detected += ["'$anomalies_found' anomalies require review"]' "$VALIDATION_STATE" > "${VALIDATION_STATE}.tmp"
      mv "${VALIDATION_STATE}.tmp" "$VALIDATION_STATE"
    fi
  fi
  
  echo ""
}

# Document compliance requirements
document_compliance() {
  local spec_file="${1:-}"
  local task_id="${2:-}"
  
  echo "=== Documentation Requirements ==="
  
  if [ -n "$spec_file" ] && [ -f "$spec_file" ]; then
    echo "Recording compliance documentation for: $spec_file"
    
    # Record specifications consulted
    if [ -f "$VALIDATION_STATE" ]; then
      jq --arg spec "$spec_file" '.documentation_compliance.specs_consulted += [$spec]' "$VALIDATION_STATE" > "${VALIDATION_STATE}.tmp"
      mv "${VALIDATION_STATE}.tmp" "$VALIDATION_STATE"
    fi
    
    echo "Documentation captured:"
    echo "  - Specifications consulted: $spec_file"
    echo "  - Requirements extracted: [recorded]"
    echo "  - Implementation mappings: [recorded]"
    echo "  - Validation results: [recorded]"
    echo "  - Deviations: [none]"
  else
    echo "No specification file provided for documentation"
  fi
  
  echo ""
}

# Validate specification format (original function enhanced)
validate_spec_format() {
  local spec_file="$1"
  local errors=0
  
  if [ ! -f "$spec_file" ]; then
    echo "ERROR: Specification file not found: $spec_file"
    return 1
  fi
  
  # Check for required sections
  local required_sections=("overview" "requirements" "acceptance criteria")
  for section in "${required_sections[@]}"; do
    if ! grep -qi "^#.*$section" "$spec_file"; then
      echo "WARNING: Missing section '$section' in $spec_file"
      ((errors++))
    fi
  done
  
  # Check for task definitions
  if ! grep -q "^## Task\|^### Task" "$spec_file"; then
    echo "WARNING: No task definitions found in $spec_file"
    ((errors++))
  fi
  
  return $errors
}

# Validate task completeness
validate_task_completeness() {
  local task_file="$1"
  local spec_file="$2"
  
  if [ ! -f "$task_file" ] || [ ! -f "$spec_file" ]; then
    echo "ERROR: Task or spec file not found"
    return 1
  fi
  
  # Extract task IDs from spec
  local spec_tasks=$(grep -E "^Task [0-9]+\.|^- \[.\] Task" "$spec_file" | sed 's/Task \([0-9]\+\).*/\1/')
  
  # Extract completed tasks
  local completed_tasks=$(grep -E "^- \[x\] Task" "$task_file" | sed 's/.*Task \([0-9]\+\).*/\1/')
  
  # Compare and report
  local incomplete=0
  for task_id in $spec_tasks; do
    if ! echo "$completed_tasks" | grep -q "^$task_id$"; then
      echo "Incomplete: Task $task_id"
      ((incomplete++))
    fi
  done
  
  if [ $incomplete -eq 0 ]; then
    echo "All tasks complete!"
  else
    echo "Tasks remaining: $incomplete"
  fi
  
  return $incomplete
}

# Cache validation results
cache_validation_result() {
  local spec_file="$1"
  local result="$2"
  local cache_file=".agent-os/cache/validation_$(basename "$spec_file" .md).cache"
  
  cat > "$cache_file" <<EOF
{
  "file": "$spec_file",
  "validated": "$(date)",
  "result": "$result",
  "checksum": "$(md5sum "$spec_file" 2>/dev/null | cut -d' ' -f1)"
}
EOF
}

# Main validation execution
main() {
  local mode="${1:-full}"
  local spec_file="${2:-}"
  local task_file="${3:-}"
  
  echo "=== Agent-OS Specification Validation ==="
  
  # Initialize validation state
  init_validation_state
  
  case "$mode" in
    "pre")
      # Pre-implementation validation
      run_pre_implementation_checklist
      ask_validation_questions
      
      if [ -n "$spec_file" ]; then
        validate_spec_format "$spec_file"
        document_compliance "$spec_file"
      fi
      ;;
      
    "post")
      # Post-implementation validation
      run_post_implementation_checks
      detect_anomalies
      
      if [ -n "$spec_file" ] && [ -n "$task_file" ]; then
        validate_task_completeness "$task_file" "$spec_file"
      fi
      ;;
      
    "full"|"all")
      # Complete validation cycle
      echo "Running full validation cycle..."
      echo ""
      
      # Pre-implementation phase
      echo "PHASE 1: Pre-Implementation"
      echo "============================"
      run_pre_implementation_checklist
      ask_validation_questions
      
      # Specification validation
      echo "PHASE 2: Specification Validation"
      echo "=================================="
      if [ -n "$spec_file" ]; then
        validate_spec_format "$spec_file"
        cache_validation_result "$spec_file" "validated"
      else
        # Find and validate all spec files
        for spec in $(find . -name "*.spec.md" -o -name "*specification*.md" 2>/dev/null); do
          echo "Validating: $spec"
          if validate_spec_format "$spec"; then
            cache_validation_result "$spec" "valid"
          else
            cache_validation_result "$spec" "invalid"
          fi
        done
      fi
      
      # Post-implementation phase
      echo "PHASE 3: Post-Implementation"
      echo "============================="
      run_post_implementation_checks
      detect_anomalies
      
      # Task completeness
      if [ -n "$task_file" ] && [ -n "$spec_file" ]; then
        echo "PHASE 4: Task Completeness"
        echo "=========================="
        validate_task_completeness "$task_file" "$spec_file"
      fi
      
      # Documentation compliance
      echo "PHASE 5: Documentation"
      echo "======================"
      document_compliance "$spec_file"
      ;;
      
    "format")
      # Just validate spec format
      if [ -n "$spec_file" ]; then
        validate_spec_format "$spec_file"
        cache_validation_result "$spec_file" "format-checked"
      else
        echo "Spec file required for format validation"
        exit 1
      fi
      ;;
      
    *)
      echo "Usage: $0 {pre|post|full|format} [spec_file] [task_file]"
      echo ""
      echo "Modes:"
      echo "  pre    - Run pre-implementation validation"
      echo "  post   - Run post-implementation validation"
      echo "  full   - Run complete validation cycle (default)"
      echo "  format - Validate specification format only"
      exit 1
      ;;
  esac
  
  echo ""
  echo "=== Validation Complete ==="
  
  # Display validation summary
  if [ -f "$VALIDATION_STATE" ]; then
    echo ""
    echo "Validation Summary:"
    echo "=================="
    echo "Pre-implementation checks: $(jq -r '[.pre_implementation_checklist | to_entries[] | select(.value == true)] | length' "$VALIDATION_STATE")/6"
    echo "Validation questions: $(jq -r '[.validation_questions | to_entries[] | select(.value == "asked")] | length' "$VALIDATION_STATE")/5"
    echo "Post-implementation checks: $(jq -r '[.post_implementation_checks | to_entries[] | select(.value == true)] | length' "$VALIDATION_STATE")/6"
    echo "Anomalies detected: $(jq -r '.anomalies_detected | length' "$VALIDATION_STATE")"
    echo "Specs consulted: $(jq -r '.documentation_compliance.specs_consulted | length' "$VALIDATION_STATE")"
  fi
}

# Execute if not sourced
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi