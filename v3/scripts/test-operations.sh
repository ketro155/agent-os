#!/bin/bash
# Agent OS v4.6 - Test Operations Script
# Manages browser test plans and reports
# Called by hooks and agents for test management

set -e

COMMAND="${1:-help}"
shift || true

# Robust project directory detection
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
TEST_PLANS_DIR="$PROJECT_DIR/.agent-os/test-plans"
TEST_REPORTS_DIR="$PROJECT_DIR/.agent-os/test-reports"

# Ensure directories exist
ensure_dirs() {
  mkdir -p "$TEST_PLANS_DIR"
  mkdir -p "$TEST_REPORTS_DIR"
}

# Find test plan by name
find_test_plan() {
  local plan_name="$1"

  if [ -n "$plan_name" ]; then
    local plan_file="$TEST_PLANS_DIR/$plan_name/test-plan.json"
    if [ -f "$plan_file" ]; then
      echo "$plan_file"
    fi
  else
    # Find most recent test plan
    find "$TEST_PLANS_DIR" -name "test-plan.json" -type f 2>/dev/null | \
      xargs ls -t 2>/dev/null | head -1
  fi
}

case "$COMMAND" in

  # ─────────────────────────────────────────────────────────────
  # TEST PLAN OPERATIONS
  # ─────────────────────────────────────────────────────────────

  # List all test plans
  list-plans)
    ensure_dirs

    if [ ! -d "$TEST_PLANS_DIR" ] || [ -z "$(ls -A "$TEST_PLANS_DIR" 2>/dev/null)" ]; then
      echo '{"plans": []}'
      exit 0
    fi

    find "$TEST_PLANS_DIR" -name "test-plan.json" -type f 2>/dev/null | while read -r f; do
      jq -c '{
        name: .name,
        base_url: .base_url,
        scenarios: (.scenarios | length),
        fixtures: (.fixtures | keys | length),
        scope: .source.scope,
        created: .created,
        path: input_filename
      }' "$f" 2>/dev/null
    done | jq -s '{plans: .}'
    ;;

  # Get test plan details
  plan-status)
    PLAN_NAME="$1"
    PLAN_FILE=$(find_test_plan "$PLAN_NAME")

    if [ -z "$PLAN_FILE" ] || [ ! -f "$PLAN_FILE" ]; then
      echo '{"error": "Test plan not found"}'
      exit 1
    fi

    jq '{
      name: .name,
      base_url: .base_url,
      source: .source,
      total_scenarios: (.scenarios | length),
      prerequisites: [.scenarios[] | select(.is_prerequisite == true) | .id],
      by_priority: {
        critical: [.scenarios[] | select(.priority == "critical")] | length,
        high: [.scenarios[] | select(.priority == "high")] | length,
        medium: [.scenarios[] | select(.priority == "medium")] | length,
        low: [.scenarios[] | select(.priority == "low")] | length
      },
      fixtures: (.fixtures | keys),
      default_evidence: .default_evidence,
      summary: .summary
    }' "$PLAN_FILE"
    ;;

  # Create a new test plan
  create-plan)
    PLAN_NAME="$1"
    BASE_URL="$2"
    SOURCE_TYPE="$3"
    SOURCE_VALUE="$4"
    SCOPE="${5:-regression}"

    if [ -z "$PLAN_NAME" ] || [ -z "$BASE_URL" ]; then
      echo '{"error": "Usage: test-operations.sh create-plan <name> <base_url> [source_type] [source_value] [scope]"}'
      exit 1
    fi

    ensure_dirs

    PLAN_DIR="$TEST_PLANS_DIR/$PLAN_NAME"
    mkdir -p "$PLAN_DIR"

    TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    cat > "$PLAN_DIR/test-plan.json" << EOF
{
  "version": "1.0",
  "name": "$PLAN_NAME",
  "description": "",
  "created": "$TIMESTAMP",
  "updated": "$TIMESTAMP",
  "source": {
    "type": "${SOURCE_TYPE:-feature}",
    "value": "${SOURCE_VALUE:-}",
    "scope": "$SCOPE"
  },
  "base_url": "$BASE_URL",
  "default_evidence": {
    "screenshots": true,
    "console_logs": true,
    "network_requests": true,
    "gif_recording": false
  },
  "fixtures": {},
  "scenarios": [],
  "summary": {
    "total_scenarios": 0,
    "by_priority": {
      "critical": 0,
      "high": 0,
      "medium": 0,
      "low": 0
    },
    "estimated_duration_seconds": 0
  }
}
EOF

    echo '{"success": true, "plan_path": "'"$PLAN_DIR"'", "plan_file": "'"$PLAN_DIR/test-plan.json"'"}'
    ;;

  # Add a fixture to a test plan
  add-fixture)
    PLAN_NAME="$1"
    FIXTURE_NAME="$2"
    FIXTURE_JSON="$3"

    if [ -z "$PLAN_NAME" ] || [ -z "$FIXTURE_NAME" ] || [ -z "$FIXTURE_JSON" ]; then
      echo '{"error": "Usage: test-operations.sh add-fixture <plan_name> <fixture_name> <fixture_json>"}'
      exit 1
    fi

    PLAN_FILE=$(find_test_plan "$PLAN_NAME")

    if [ -z "$PLAN_FILE" ] || [ ! -f "$PLAN_FILE" ]; then
      echo '{"error": "Test plan not found"}'
      exit 1
    fi

    TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    jq --arg name "$FIXTURE_NAME" --argjson fixture "$FIXTURE_JSON" --arg ts "$TIMESTAMP" '
      .fixtures[$name] = $fixture |
      .updated = $ts
    ' "$PLAN_FILE" > "${PLAN_FILE}.tmp" && mv "${PLAN_FILE}.tmp" "$PLAN_FILE"

    echo '{"success": true, "fixture": "'"$FIXTURE_NAME"'"}'
    ;;

  # Add a scenario to a test plan
  add-scenario)
    PLAN_NAME="$1"
    SCENARIO_JSON="$2"

    if [ -z "$PLAN_NAME" ] || [ -z "$SCENARIO_JSON" ]; then
      echo '{"error": "Usage: test-operations.sh add-scenario <plan_name> <scenario_json>"}'
      exit 1
    fi

    PLAN_FILE=$(find_test_plan "$PLAN_NAME")

    if [ -z "$PLAN_FILE" ] || [ ! -f "$PLAN_FILE" ]; then
      echo '{"error": "Test plan not found"}'
      exit 1
    fi

    TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    jq --argjson scenario "$SCENARIO_JSON" --arg ts "$TIMESTAMP" '
      .scenarios += [$scenario] |
      .summary.total_scenarios = (.scenarios | length) |
      .summary.by_priority = {
        critical: [.scenarios[] | select(.priority == "critical")] | length,
        high: [.scenarios[] | select(.priority == "high")] | length,
        medium: [.scenarios[] | select(.priority == "medium")] | length,
        low: [.scenarios[] | select(.priority == "low")] | length
      } |
      .updated = $ts
    ' "$PLAN_FILE" > "${PLAN_FILE}.tmp" && mv "${PLAN_FILE}.tmp" "$PLAN_FILE"

    SCENARIO_ID=$(echo "$SCENARIO_JSON" | jq -r '.id')
    echo '{"success": true, "scenario_id": "'"$SCENARIO_ID"'"}'
    ;;

  # Get execution order for a test plan (topological sort based on dependencies)
  execution-order)
    PLAN_NAME="$1"
    PLAN_FILE=$(find_test_plan "$PLAN_NAME")

    if [ -z "$PLAN_FILE" ] || [ ! -f "$PLAN_FILE" ]; then
      echo '{"error": "Test plan not found"}'
      exit 1
    fi

    # Output scenarios ordered by: prerequisites first, then by dependency chain
    jq '
      # First, get prerequisite scenarios
      .scenarios as $all |
      [$all[] | select(.is_prerequisite == true)] as $prereqs |

      # Then non-prereqs with no dependencies
      [$all[] | select(.is_prerequisite != true and (.entry_criteria.depends_on | length) == 0)] as $independent |

      # Then remaining scenarios
      [$all[] | select(.is_prerequisite != true and (.entry_criteria.depends_on | length) > 0)] as $dependent |

      {
        execution_order: (
          ($prereqs | map(.id)) +
          ($independent | map(.id)) +
          ($dependent | sort_by(.entry_criteria.depends_on | length) | map(.id))
        ),
        prerequisites: ($prereqs | map({id: .id, name: .name})),
        total_scenarios: ($all | length),
        dependency_graph: [$all[] | {
          id: .id,
          depends_on: (.entry_criteria.depends_on // []),
          required_fixtures: (.entry_criteria.required_fixtures // [])
        }]
      }
    ' "$PLAN_FILE"
    ;;

  # ─────────────────────────────────────────────────────────────
  # TEST REPORT OPERATIONS
  # ─────────────────────────────────────────────────────────────

  # List test reports
  list-reports)
    PLAN_NAME="$1"
    ensure_dirs

    if [ ! -d "$TEST_REPORTS_DIR" ] || [ -z "$(ls -A "$TEST_REPORTS_DIR" 2>/dev/null)" ]; then
      echo '{"reports": []}'
      exit 0
    fi

    if [ -n "$PLAN_NAME" ]; then
      find "$TEST_REPORTS_DIR" -name "test-report.json" -path "*$PLAN_NAME*" -type f 2>/dev/null
    else
      find "$TEST_REPORTS_DIR" -name "test-report.json" -type f 2>/dev/null
    fi | while read -r f; do
      jq -c '{
        plan_name: .plan_name,
        executed_at: .executed_at,
        duration_seconds: .duration_seconds,
        passed: .summary.passed,
        failed: .summary.failed,
        skipped: .summary.skipped,
        pass_rate: .summary.pass_rate,
        path: input_filename
      }' "$f" 2>/dev/null
    done | jq -s '{reports: (. | sort_by(.executed_at) | reverse)}'
    ;;

  # Get latest report for a plan
  latest-report)
    PLAN_NAME="$1"

    if [ -z "$PLAN_NAME" ]; then
      echo '{"error": "Usage: test-operations.sh latest-report <plan_name>"}'
      exit 1
    fi

    LATEST=$(find "$TEST_REPORTS_DIR" -name "test-report.json" -path "*$PLAN_NAME*" -type f 2>/dev/null | \
             xargs ls -t 2>/dev/null | head -1)

    if [ -z "$LATEST" ]; then
      echo '{"error": "No reports found for plan: '"$PLAN_NAME"'"}'
      exit 1
    fi

    cat "$LATEST"
    ;;

  # Initialize a new test report from a plan
  init-report)
    PLAN_NAME="$1"
    PLAN_FILE=$(find_test_plan "$PLAN_NAME")

    if [ -z "$PLAN_FILE" ] || [ ! -f "$PLAN_FILE" ]; then
      echo '{"error": "Test plan not found"}'
      exit 1
    fi

    ensure_dirs

    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    REPORT_FOLDER="$TEST_REPORTS_DIR/${PLAN_NAME}-${TIMESTAMP}"
    mkdir -p "$REPORT_FOLDER/evidence"

    # Create initial report structure from plan
    jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg folder "$REPORT_FOLDER" '
      {
        version: "1.0",
        plan_name: .name,
        plan_path: input_filename,
        executed_at: $ts,
        completed_at: null,
        duration_seconds: 0,
        environment: {
          base_url: .base_url,
          browser: "Chrome (MCP)",
          viewport: "1280x720"
        },
        summary: {
          total_scenarios: (.scenarios | length),
          passed: 0,
          failed: 0,
          error: 0,
          skipped: 0,
          pass_rate: 0,
          effective_pass_rate: 0
        },
        failures: [],
        skipped: [],
        scenarios: [.scenarios[] | {
          id: .id,
          name: .name,
          priority: .priority,
          is_prerequisite: (.is_prerequisite // false),
          depends_on: (.entry_criteria.depends_on // []),
          required_fixtures: (.entry_criteria.required_fixtures // []),
          status: "pending",
          duration_ms: 0,
          steps_total: (.steps | length),
          steps_passed: 0,
          steps_failed: 0,
          failed_step_id: null,
          failure_message: null,
          evidence_folder: ("evidence/" + .id + "/")
        }],
        evidence_summary: {
          screenshots_captured: 0,
          console_logs_captured: 0,
          network_logs_captured: 0,
          gifs_recorded: 0,
          total_size_mb: 0
        }
      }
    ' "$PLAN_FILE" > "$REPORT_FOLDER/test-report.json"

    # Create evidence subdirectories for each scenario
    jq -r '.scenarios[].id' "$PLAN_FILE" 2>/dev/null | while read -r sid; do
      mkdir -p "$REPORT_FOLDER/evidence/$sid"
    done

    echo '{"success": true, "report_path": "'"$REPORT_FOLDER"'", "report_file": "'"$REPORT_FOLDER/test-report.json"'"}'
    ;;

  # Update scenario status in a report
  update-scenario)
    REPORT_FILE="$1"
    SCENARIO_ID="$2"
    STATUS="$3"
    DURATION="${4:-0}"
    FAILURE_MSG="$5"

    if [ ! -f "$REPORT_FILE" ] || [ -z "$SCENARIO_ID" ] || [ -z "$STATUS" ]; then
      echo '{"error": "Usage: test-operations.sh update-scenario <report_file> <scenario_id> <status> [duration_ms] [failure_message]"}'
      exit 1
    fi

    TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    jq --arg id "$SCENARIO_ID" --arg status "$STATUS" --arg dur "$DURATION" --arg ts "$TIMESTAMP" --arg msg "${FAILURE_MSG:-}" '
      .scenarios |= map(
        if .id == $id then
          .status = $status |
          .duration_ms = ($dur | tonumber) |
          .completed_at = $ts |
          if $msg != "" then .failure_message = $msg else . end
        else .
        end
      ) |
      # Recalculate summary
      .summary.passed = ([.scenarios[] | select(.status == "passed")] | length) |
      .summary.failed = ([.scenarios[] | select(.status == "failed" or .status == "error")] | length) |
      .summary.skipped = ([.scenarios[] | select(.status == "skipped")] | length) |
      .summary.pass_rate = (
        if .summary.total_scenarios > 0 then
          ((.summary.passed / .summary.total_scenarios) * 100 | floor)
        else 0 end
      ) |
      .summary.effective_pass_rate = (
        ((.summary.total_scenarios - .summary.skipped) as $executed |
        if $executed > 0 then
          ((.summary.passed / $executed) * 100 | floor)
        else 0 end)
      )
    ' "$REPORT_FILE" > "${REPORT_FILE}.tmp" && mv "${REPORT_FILE}.tmp" "$REPORT_FILE"

    echo '{"success": true, "scenario_id": "'"$SCENARIO_ID"'", "status": "'"$STATUS"'"}'
    ;;

  # Mark scenario as skipped due to prerequisite failure
  skip-scenario)
    REPORT_FILE="$1"
    SCENARIO_ID="$2"
    BLOCKED_BY="$3"

    if [ ! -f "$REPORT_FILE" ] || [ -z "$SCENARIO_ID" ] || [ -z "$BLOCKED_BY" ]; then
      echo '{"error": "Usage: test-operations.sh skip-scenario <report_file> <scenario_id> <blocked_by>"}'
      exit 1
    fi

    TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # Get scenario name
    SCENARIO_NAME=$(jq -r --arg id "$SCENARIO_ID" '.scenarios[] | select(.id == $id) | .name' "$REPORT_FILE")

    jq --arg id "$SCENARIO_ID" --arg blocked "$BLOCKED_BY" --arg ts "$TIMESTAMP" --arg name "$SCENARIO_NAME" '
      .scenarios |= map(
        if .id == $id then
          .status = "skipped" |
          .skip_reason = ("Prerequisite " + $blocked + " failed") |
          .completed_at = $ts
        else .
        end
      ) |
      .skipped += [{
        scenario_id: $id,
        scenario_name: $name,
        skip_reason: ("Prerequisite " + $blocked + " failed"),
        blocked_by: $blocked
      }] |
      .summary.skipped = ([.scenarios[] | select(.status == "skipped")] | length) |
      .summary.pass_rate = (
        if .summary.total_scenarios > 0 then
          ((.summary.passed / .summary.total_scenarios) * 100 | floor)
        else 0 end
      )
    ' "$REPORT_FILE" > "${REPORT_FILE}.tmp" && mv "${REPORT_FILE}.tmp" "$REPORT_FILE"

    echo '{"success": true, "scenario_id": "'"$SCENARIO_ID"'", "status": "skipped", "blocked_by": "'"$BLOCKED_BY"'"}'
    ;;

  # Add failure to report
  add-failure)
    REPORT_FILE="$1"
    FAILURE_JSON="$2"

    if [ ! -f "$REPORT_FILE" ] || [ -z "$FAILURE_JSON" ]; then
      echo '{"error": "Usage: test-operations.sh add-failure <report_file> <failure_json>"}'
      exit 1
    fi

    jq --argjson failure "$FAILURE_JSON" '
      .failures += [$failure] |
      .summary.failed = (.failures | length)
    ' "$REPORT_FILE" > "${REPORT_FILE}.tmp" && mv "${REPORT_FILE}.tmp" "$REPORT_FILE"

    echo '{"success": true}'
    ;;

  # Update evidence summary
  update-evidence)
    REPORT_FILE="$1"
    EVIDENCE_TYPE="$2"
    INCREMENT="${3:-1}"

    if [ ! -f "$REPORT_FILE" ] || [ -z "$EVIDENCE_TYPE" ]; then
      echo '{"error": "Usage: test-operations.sh update-evidence <report_file> <type> [increment]"}'
      exit 1
    fi

    jq --arg type "$EVIDENCE_TYPE" --arg inc "$INCREMENT" '
      .evidence_summary[$type + "_captured"] = ((.evidence_summary[$type + "_captured"] // 0) + ($inc | tonumber))
    ' "$REPORT_FILE" > "${REPORT_FILE}.tmp" && mv "${REPORT_FILE}.tmp" "$REPORT_FILE"

    echo '{"success": true}'
    ;;

  # Finalize report
  finalize-report)
    REPORT_FILE="$1"

    if [ ! -f "$REPORT_FILE" ]; then
      echo '{"error": "Report file not found"}'
      exit 1
    fi

    TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    jq --arg ts "$TIMESTAMP" '
      .completed_at = $ts |
      .duration_seconds = (
        (($ts | fromdateiso8601) - (.executed_at | fromdateiso8601)) | floor
      ) |
      # Find blocked scenarios for failures that are prerequisites
      .failures |= map(
        . as $failure |
        if .is_prerequisite then
          .blocked_scenarios = [
            $root.scenarios[] |
            select(.depends_on | contains([$failure.scenario_id])) |
            .id
          ]
        else .
        end
      )
    ' "$REPORT_FILE" > "${REPORT_FILE}.tmp" && mv "${REPORT_FILE}.tmp" "$REPORT_FILE"

    # Calculate evidence folder size
    REPORT_DIR=$(dirname "$REPORT_FILE")
    EVIDENCE_SIZE=$(du -sm "$REPORT_DIR/evidence" 2>/dev/null | cut -f1 || echo "0")

    jq --arg size "$EVIDENCE_SIZE" '
      .evidence_summary.total_size_mb = ($size | tonumber)
    ' "$REPORT_FILE" > "${REPORT_FILE}.tmp" && mv "${REPORT_FILE}.tmp" "$REPORT_FILE"

    echo '{"success": true, "completed_at": "'"$TIMESTAMP"'"}'
    ;;

  # Get prerequisites that must pass before a scenario
  check-prerequisites)
    REPORT_FILE="$1"
    SCENARIO_ID="$2"

    if [ ! -f "$REPORT_FILE" ] || [ -z "$SCENARIO_ID" ]; then
      echo '{"error": "Usage: test-operations.sh check-prerequisites <report_file> <scenario_id>"}'
      exit 1
    fi

    jq --arg id "$SCENARIO_ID" '
      .scenarios[] | select(.id == $id) |
      .depends_on as $deps |
      {
        scenario_id: $id,
        depends_on: $deps,
        required_fixtures: .required_fixtures,
        prerequisites_status: [
          $root.scenarios[] |
          select(.id | IN($deps[])) |
          {id: .id, status: .status, name: .name}
        ],
        can_execute: (
          [$root.scenarios[] | select(.id | IN($deps[])) | .status] |
          all(. == "passed")
        ),
        blocking_failures: [
          $root.scenarios[] |
          select(.id | IN($deps[]) and (.status == "failed" or .status == "error")) |
          .id
        ]
      }
    ' "$REPORT_FILE"
    ;;

  # ─────────────────────────────────────────────────────────────
  # HELP
  # ─────────────────────────────────────────────────────────────

  help|*)
    cat << 'EOF'
Agent OS Test Operations

Usage: test-operations.sh <command> [args]

TEST PLAN COMMANDS:
  list-plans                          List all test plans
  plan-status <plan_name>             Get test plan details
  create-plan <name> <url> [type] [value] [scope]  Create new test plan
  add-fixture <plan> <name> <json>    Add fixture to plan
  add-scenario <plan> <json>          Add scenario to plan
  execution-order <plan>              Get execution order (topological sort)

TEST REPORT COMMANDS:
  list-reports [plan_name]            List test reports
  latest-report <plan_name>           Get latest report for a plan
  init-report <plan_name>             Initialize report from plan
  update-scenario <file> <id> <status> [duration_ms] [message]
  skip-scenario <file> <id> <blocked_by>  Mark as skipped
  add-failure <file> <failure_json>   Add failure to report
  update-evidence <file> <type> [n]   Update evidence count
  finalize-report <file>              Finalize report with timing
  check-prerequisites <file> <id>     Check if scenario can run

STATUS VALUES:
  pending, passed, failed, error, skipped

EXAMPLES:
  test-operations.sh create-plan auth-tests http://localhost:3000 feature login regression
  test-operations.sh add-scenario auth-tests '{"id":"S1","name":"Login test",...}'
  test-operations.sh init-report auth-tests
  test-operations.sh update-scenario ./report.json S1 passed 15234
  test-operations.sh skip-scenario ./report.json S3 S1
  test-operations.sh finalize-report ./report.json
EOF
    ;;

esac
