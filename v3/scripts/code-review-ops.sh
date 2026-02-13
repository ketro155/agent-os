#!/usr/bin/env bash
# code-review-ops.sh - Code review coordination logic for wave-orchestrator
# v5.4.0 - Two-tier code review system
#
# Usage:
#   code-review-ops.sh accumulate <findings-file> <finding-json>
#   code-review-ops.sh is-blocking <finding-json>
#   code-review-ops.sh route-fix <finding-json>
#   code-review-ops.sh combine <tier1-findings-file> <tier2-output-json>
#   code-review-ops.sh should-retry <task-id> <attempt> <max-attempts>

set -euo pipefail

COMMAND="${1:-}"
shift || true

# ═══════════════════════════════════════════════════════════════════
# accumulate - Add a Tier 1 finding to the findings file
# ═══════════════════════════════════════════════════════════════════
accumulate() {
  local findings_file="$1"
  local finding_json="$2"

  # Create file if it doesn't exist
  if [ ! -f "$findings_file" ]; then
    echo '{"tier1_findings":[]}' > "$findings_file"
  fi

  # Append finding to the array
  local tmp_file="${findings_file}.tmp"
  jq --argjson finding "$finding_json" \
    '.tier1_findings += [$finding]' \
    "$findings_file" > "$tmp_file"
  mv "$tmp_file" "$findings_file"

  echo "Finding accumulated ($(jq '.tier1_findings | length' "$findings_file") total)"
}

# ═══════════════════════════════════════════════════════════════════
# is-blocking - Check if a finding is blocking (CRITICAL or HIGH)
# Returns: exit 0 if blocking, exit 1 if not
# ═══════════════════════════════════════════════════════════════════
is_blocking() {
  local finding_json="$1"

  local severity
  severity=$(echo "$finding_json" | jq -r '.severity // "LOW"')

  case "$severity" in
    CRITICAL|HIGH)
      echo "true"
      exit 0
      ;;
    *)
      echo "false"
      exit 1
      ;;
  esac
}

# ═══════════════════════════════════════════════════════════════════
# route-fix - Determine which teammate should receive a fix request
# Returns: teammate name from source_teammate field
# ═══════════════════════════════════════════════════════════════════
route_fix() {
  local finding_json="$1"

  local teammate
  teammate=$(echo "$finding_json" | jq -r '.source_teammate // "unknown"')

  echo "$teammate"
}

# ═══════════════════════════════════════════════════════════════════
# combine - Merge Tier 1 + Tier 2 findings, deduplicate, compute status
# Returns: combined findings JSON with blocking decision
# ═══════════════════════════════════════════════════════════════════
combine() {
  local tier1_file="$1"
  local tier2_json="$2"

  # Read Tier 1 findings (or empty array)
  local tier1_findings='[]'
  if [ -f "$tier1_file" ]; then
    tier1_findings=$(jq '.tier1_findings // []' "$tier1_file")
  fi

  # Parse Tier 2 findings
  local tier2_findings
  tier2_findings=$(echo "$tier2_json" | jq '.findings // []')

  local tier2_status
  tier2_status=$(echo "$tier2_json" | jq -r '.status // "pass"')

  # Combine all findings
  local all_findings
  all_findings=$(jq -n \
    --argjson t1 "$tier1_findings" \
    --argjson t2 "$tier2_findings" \
    '$t1 + $t2')

  # Count severities
  local critical high medium low
  critical=$(echo "$all_findings" | jq '[.[] | select(.severity == "CRITICAL")] | length')
  high=$(echo "$all_findings" | jq '[.[] | select(.severity == "HIGH")] | length')
  medium=$(echo "$all_findings" | jq '[.[] | select(.severity == "MEDIUM")] | length')
  low=$(echo "$all_findings" | jq '[.[] | select(.severity == "LOW")] | length')

  # Determine blocking status
  local has_unresolved_blocking=false
  local unresolved_count=0

  if [ "$critical" -gt 0 ] || [ "$high" -gt 0 ]; then
    has_unresolved_blocking=true
    unresolved_count=$((critical + high))
  fi

  # Build combined output
  jq -n \
    --argjson tier1 "$tier1_findings" \
    --argjson tier2 "$tier2_findings" \
    --argjson all "$all_findings" \
    --argjson critical "$critical" \
    --argjson high "$high" \
    --argjson medium "$medium" \
    --argjson low "$low" \
    --argjson has_blocking "$has_unresolved_blocking" \
    --argjson unresolved "$unresolved_count" \
    --arg tier2_status "$tier2_status" \
    '{
      combined_status: (if $has_blocking then "fail" else "pass" end),
      has_unresolved_blocking: $has_blocking,
      unresolved_count: $unresolved,
      summary: {
        critical: $critical,
        high: $high,
        medium: $medium,
        low: $low,
        total: ($critical + $high + $medium + $low)
      },
      tier1: {
        findings_count: ($tier1 | length),
        findings: $tier1
      },
      tier2: {
        status: $tier2_status,
        findings_count: ($tier2 | length),
        findings: $tier2
      },
      all_findings: $all
    }'
}

# ═══════════════════════════════════════════════════════════════════
# should-retry - Check if fix cycle should continue or terminate
# Returns: exit 0 if should retry, exit 1 if exhausted
# ═══════════════════════════════════════════════════════════════════
should_retry() {
  local task_id="$1"
  local attempt="$2"
  local max_attempts="${3:-2}"

  if [ "$attempt" -lt "$max_attempts" ]; then
    echo "true"
    echo "Attempt $attempt/$max_attempts for task $task_id - retry allowed" >&2
    exit 0
  else
    echo "false"
    echo "Attempt $attempt/$max_attempts for task $task_id - exhausted, escalate to Tier 2" >&2
    exit 1
  fi
}

# ═══════════════════════════════════════════════════════════════════
# Command dispatch
# ═══════════════════════════════════════════════════════════════════
case "$COMMAND" in
  accumulate)
    accumulate "$@"
    ;;
  is-blocking)
    is_blocking "$@"
    ;;
  route-fix)
    route_fix "$@"
    ;;
  combine)
    combine "$@"
    ;;
  should-retry)
    should_retry "$@"
    ;;
  *)
    echo "Usage: code-review-ops.sh {accumulate|is-blocking|route-fix|combine|should-retry} [args...]" >&2
    echo "" >&2
    echo "Commands:" >&2
    echo "  accumulate <findings-file> <finding-json>    Add Tier 1 finding to file" >&2
    echo "  is-blocking <finding-json>                   Check if CRITICAL/HIGH (exit 0=yes)" >&2
    echo "  route-fix <finding-json>                     Get source teammate name" >&2
    echo "  combine <tier1-file> <tier2-json>            Merge tiers, compute blocking" >&2
    echo "  should-retry <task-id> <attempt> [max=2]     Check fix cycle bound" >&2
    exit 1
    ;;
esac
