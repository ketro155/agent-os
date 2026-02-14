#!/usr/bin/env bash
# test-skill-triggers.sh — Validate skill descriptions against Anthropic's trigger guide
# Ensures each skill has proper frontmatter, trigger phrases, WHAT/WHEN structure,
# and that overlapping skills have distinct trigger language.
#
# Usage: bash .claude/scripts/test-skill-triggers.sh
#
# Exit codes:
#   0 - All checks passed (warnings are non-blocking)
#   1 - One or more checks failed

set -euo pipefail

# ─── Project & directory resolution ──────────────────────────────────────────

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SKILLS_DIR="$PROJECT_DIR/.claude/skills"

# ─── Counters ────────────────────────────────────────────────────────────────

PASS=0
FAIL=0
WARN=0
TOTAL=0

# ─── Colors ──────────────────────────────────────────────────────────────────

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[0;33m'
CYAN=$'\033[0;36m'
BOLD=$'\033[1m'
DIM=$'\033[2m'
NC=$'\033[0m' # No Color

# ─── Helpers ─────────────────────────────────────────────────────────────────

# Safe arithmetic increment that won't trip set -e when value is 0.
inc() {
  local -n _ref=$1
  _ref=$(( _ref + 1 ))
}

# Extract YAML frontmatter value (single-line fields only).
# Handles the description spanning the entire line after "description: ".
# Usage: echo "$frontmatter" | extract_field "name"
extract_field() {
  local field="$1"
  grep -m1 "^${field}:" | sed "s/^${field}:[[:space:]]*//" || true
}

# Extract the YAML frontmatter block (between --- delimiters) from a SKILL.md.
# Returns the text between the first and second "---" lines.
extract_frontmatter() {
  local file="$1"
  awk '/^---$/ { count++; next } count == 1 { print } count >= 2 { exit }' "$file"
}

# Count quoted trigger phrases in a description string.
# Trigger phrases are text enclosed in double quotes within the description.
count_trigger_phrases() {
  local desc="$1"
  local count
  count=$(echo "$desc" | grep -oE '"[^"]+"' | wc -l | tr -d ' ')
  echo "$count"
}

# Extract quoted trigger phrases as a newline-separated list.
extract_trigger_phrases() {
  local desc="$1"
  echo "$desc" | grep -oE '"[^"]+"' | tr -d '"' || true
}

# Check if description starts with an action-oriented word (WHAT check).
# Action verbs: Verifies, Retrieves, Searches, Displays, Compresses, Adds, etc.
# Also accepts "When ..." pattern from Anthropic guide and noun-led starts.
check_what() {
  local desc="$1"
  # Starts with capitalized word that looks like a verb or "When"
  if echo "$desc" | grep -qE '^(When |[A-Z][a-z]+(s|es|ies|ed|ing)? )'; then
    return 0
  fi
  return 1
}

# Check if description contains a WHEN trigger condition.
# Looks for: "Use when", "when user", "Use before", "Use after", "Use during"
check_when() {
  local desc="$1"
  if echo "$desc" | grep -qiE '(Use when|when user|Use before|Use after|Use during|when you)'; then
    return 0
  fi
  return 1
}

# Check for negative trigger language (NOT for, not for).
# Recommended for skills that overlap with others.
check_negative_triggers() {
  local desc="$1"
  if echo "$desc" | grep -qE '(NOT for|not for|NOT when|Instead use)'; then
    return 0
  fi
  return 1
}

# Tokenize a description into lowercase words for overlap comparison.
# Strips punctuation and common stop words, returns sorted unique words.
tokenize_for_overlap() {
  local desc="$1"
  echo "$desc" \
    | tr '[:upper:]' '[:lower:]' \
    | tr -cs '[:alpha:]' '\n' \
    | grep -vE '^(a|an|the|is|are|was|were|be|been|being|have|has|had|do|does|did|will|would|shall|should|may|might|must|can|could|of|in|to|for|with|on|at|by|from|as|or|and|but|not|no|nor|so|if|when|use|this|that|it|its|you|your|user|says)$' \
    | sort -u \
    || true
}

# Compute Jaccard similarity between two word sets (0.0 to 1.0).
# Returns percentage as integer (0-100).
jaccard_similarity() {
  local words_a="$1"
  local words_b="$2"

  # Create temp files for set operations
  local tmp_a tmp_b
  tmp_a=$(mktemp)
  tmp_b=$(mktemp)
  echo "$words_a" | tr ' ' '\n' | sort -u > "$tmp_a"
  echo "$words_b" | tr ' ' '\n' | sort -u > "$tmp_b"

  local intersection union
  intersection=$(comm -12 "$tmp_a" "$tmp_b" | wc -l | tr -d ' ')
  union=$(cat "$tmp_a" "$tmp_b" | sort -u | wc -l | tr -d ' ')

  rm -f "$tmp_a" "$tmp_b"

  if [ "$union" -eq 0 ]; then
    echo 0
    return
  fi

  # Integer percentage
  echo $(( (intersection * 100) / union ))
}

# ─── Overlap groups ──────────────────────────────────────────────────────────

# Define groups of skills that could be confused with each other.
# Each group is a space-separated list of skill names.
declare -a OVERLAP_GROUPS
OVERLAP_GROUPS=(
  "context-read context-search context-stats context-summary"
  "tdd-helper test-guardian"
)

OVERLAP_GROUP_NAMES=(
  "Context management"
  "Testing"
)

# ─── Main validation ─────────────────────────────────────────────────────────

# Associative arrays to hold per-skill data for overlap checks
declare -A SKILL_DESCRIPTIONS
declare -A SKILL_TOKENS

echo ""
echo -e "${BOLD}==================================================${NC}"
echo -e "${BOLD}  SKILL TRIGGER TEST REPORT${NC}"
echo -e "${BOLD}==================================================${NC}"
echo ""

# Discover skills
if [ ! -d "$SKILLS_DIR" ]; then
  echo -e "${RED}ERROR: Skills directory not found: $SKILLS_DIR${NC}"
  exit 1
fi

# Collect skill files into array (handles spaces in paths safely)
SKILL_FILES=()
while IFS= read -r -d '' f; do
  SKILL_FILES+=("$f")
done < <(find "$SKILLS_DIR" -name "SKILL.md" -print0 | sort -z) || true

if [ ${#SKILL_FILES[@]} -eq 0 ]; then
  echo -e "${RED}ERROR: No SKILL.md files found in $SKILLS_DIR${NC}"
  exit 1
fi

# Validate each skill
for skill_file in "${SKILL_FILES[@]}"; do
  inc TOTAL

  skill_dir=$(dirname "$skill_file")
  skill_name_from_dir=$(basename "$skill_dir")
  status_icon=""
  status_parts=()
  has_failure=false

  # Extract frontmatter
  frontmatter=$(extract_frontmatter "$skill_file")

  # ── Check 1: name field exists ──
  name_value=$(echo "$frontmatter" | extract_field "name")
  if [ -z "$name_value" ]; then
    has_failure=true
    status_parts+=("${RED}name MISSING${NC}")
  fi

  # Use extracted name or fallback to directory name
  display_name="${name_value:-$skill_name_from_dir}"

  # ── Check 2: description field exists ──
  desc_value=$(echo "$frontmatter" | extract_field "description")
  if [ -z "$desc_value" ]; then
    has_failure=true
    status_parts+=("${RED}desc MISSING${NC}")
    # Cannot run further checks without a description
    status_icon="${RED}x${NC}"
    inc FAIL
    printf "  ${status_icon}  %-28s %s\n" "$display_name" "$(IFS=', '; echo "${status_parts[*]}")"
    continue
  fi

  # Store for overlap analysis
  SKILL_DESCRIPTIONS["$display_name"]="$desc_value"
  SKILL_TOKENS["$display_name"]=$(tokenize_for_overlap "$desc_value" | tr '\n' ' ')

  # ── Check 3: description length under 1,024 characters ──
  desc_len=${#desc_value}
  if [ "$desc_len" -gt 1024 ]; then
    has_failure=true
    status_parts+=("${RED}len ${desc_len}>1024${NC}")
  fi

  # ── Check 4: trigger phrases (quoted text) ──
  trigger_count=$(count_trigger_phrases "$desc_value")
  if [ "$trigger_count" -ge 3 ]; then
    status_parts+=("[${trigger_count} triggers]")
  elif [ "$trigger_count" -ge 1 ]; then
    # 1-2 triggers: warning, not failure
    status_parts+=("${YELLOW}[${trigger_count} triggers <3]${NC}")
  else
    has_failure=true
    status_parts+=("${RED}[0 triggers]${NC}")
  fi

  # ── Check 5: WHAT — starts with action verb/noun ──
  if check_what "$desc_value"; then
    status_parts+=("[WHAT ok]")
  else
    has_failure=true
    status_parts+=("${RED}[WHAT missing]${NC}")
  fi

  # ── Check 6: WHEN — contains usage trigger condition ──
  if check_when "$desc_value"; then
    status_parts+=("[WHEN ok]")
  else
    has_failure=true
    status_parts+=("${RED}[WHEN missing]${NC}")
  fi

  # ── Check 7: negative triggers (warning only) ──
  # Only warn for skills that belong to an overlap group
  in_overlap_group=false
  for group in "${OVERLAP_GROUPS[@]}"; do
    if echo "$group" | grep -qw "$display_name"; then
      in_overlap_group=true
      break
    fi
  done

  if [ "$in_overlap_group" = true ]; then
    if ! check_negative_triggers "$desc_value"; then
      status_parts+=("${YELLOW}[no negative]${NC}")
      inc WARN
    fi
  fi

  # ── Emit result line ──
  if [ "$has_failure" = true ]; then
    status_icon="${RED}x${NC}"
    inc FAIL
  else
    status_icon="${GREEN}ok${NC}"
    inc PASS
  fi

  printf "  ${status_icon}  %-28s %s\n" "$display_name" "$(IFS='  '; echo "${status_parts[*]}")"
done

# ─── Overlap analysis ────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}OVERLAP CHECK:${NC}"

overlap_failures=0

for i in "${!OVERLAP_GROUPS[@]}"; do
  group="${OVERLAP_GROUPS[$i]}"
  group_name="${OVERLAP_GROUP_NAMES[$i]}"
  read -ra members <<< "$group"

  max_similarity=0
  worst_pair=""

  # Compare all pairs within the group
  for (( a=0; a<${#members[@]}; a++ )); do
    for (( b=a+1; b<${#members[@]}; b++ )); do
      name_a="${members[$a]}"
      name_b="${members[$b]}"

      tokens_a="${SKILL_TOKENS[$name_a]:-}"
      tokens_b="${SKILL_TOKENS[$name_b]:-}"

      if [ -z "$tokens_a" ] || [ -z "$tokens_b" ]; then
        continue
      fi

      similarity=$(jaccard_similarity "$tokens_a" "$tokens_b")

      if [ "$similarity" -gt "$max_similarity" ]; then
        max_similarity=$similarity
        worst_pair="${name_a} <-> ${name_b}"
      fi
    done
  done

  if [ "$max_similarity" -gt 50 ]; then
    echo -e "  ${RED}x${NC}  ${group_name} group: ${RED}OVERLAPPING${NC} (similarity: ${max_similarity}%, ${worst_pair})"
    inc overlap_failures
  else
    echo -e "  ${GREEN}ok${NC} ${group_name} group: ${GREEN}DISTINCT${NC} (max similarity: ${max_similarity}%)"
  fi
done

if [ "$overlap_failures" -gt 0 ]; then
  FAIL=$(( FAIL + overlap_failures ))
fi

# ─── Summary ─────────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}==================================================${NC}"
if [ "$FAIL" -gt 0 ]; then
  echo -e "  Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}, ${YELLOW}${WARN} warnings${NC}"
else
  echo -e "  Results: ${GREEN}${PASS} passed${NC}, ${FAIL} failed, ${YELLOW}${WARN} warnings${NC}"
fi
echo -e "  Skills scanned: ${TOTAL}"
echo -e "${BOLD}==================================================${NC}"
echo ""

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi

exit 0
