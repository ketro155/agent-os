---
name: changelog-writer
description: "Auto-invoke after spec completion in Phase 3 to update CHANGELOG.md. Auto-detects change type from spec content and git diff. Asks user only when uncertain (<70% confidence)."
allowed-tools: Read, Write, Grep, Glob, Bash
---

# Changelog Writer Skill

Automatically generates and maintains CHANGELOG.md entries after spec completion using Keep a Changelog format.

**Core Principle:** AUTO-DETECT CHANGE TYPE, DOCUMENT FOR HUMANS

## When to Use This Skill

Claude should invoke this skill:
- **During Phase 3 delivery** after recap creation (Step 8.5)
- **When user explicitly requests** changelog update
- **After completing a spec** if changelog update was skipped

## Workflow

### Step 1: Collect Input Data

```
REQUIRED:
  - spec_folder: Path to spec folder (e.g., .agent-os/specs/2025-01-15-auth-feature/)
  - spec_name: Spec identifier (e.g., auth-feature)

OPTIONAL:
  - pr_number: PR number if created (from git-workflow)
  - pr_url: Full PR URL
```

### Step 2: Auto-Detect Change Type

Use hybrid detection combining spec content analysis and git diff patterns.

**Signal 1: Spec Content Analysis**

```bash
# Read spec.md and spec-lite.md for keywords
SPEC_CONTENT=$(cat [SPEC_FOLDER]/spec.md [SPEC_FOLDER]/spec-lite.md 2>/dev/null)
```

Keyword → Type mapping (case-insensitive):

| Keywords | Type | Weight |
|----------|------|--------|
| fix, bug, error, issue, crash, broken, resolve, patch | `bugfix` | 0.4 |
| add, new, implement, create, feature, introduce, enable | `feature` | 0.4 |
| breaking, remove, deprecate, incompatible, major, migrate | `breaking` | 0.5 |
| refactor, clean, improve, optimize, reorganize, simplify | `refactor` | 0.3 |
| doc, readme, comment, explain, document, guide | `docs` | 0.3 |
| test, spec, coverage, assertion | `test` | 0.3 |
| chore, dependency, update, upgrade, maintenance | `chore` | 0.3 |

**Signal 2: Git Diff Analysis**

```bash
# Analyze file changes
git diff --name-status main...HEAD 2>/dev/null || git diff --name-status HEAD~10...HEAD
```

Pattern → Type mapping:

| Pattern | Type | Weight |
|---------|------|--------|
| >50% files are "A" (added) | `feature` | 0.3 |
| >50% files are "M" (modified) | `bugfix` or `refactor` | 0.2 |
| Any "D" (deleted) in src/ or lib/ | `breaking` | 0.4 |
| Only *.md or docs/ changed | `docs` | 0.4 |
| Only test files changed | `test` | 0.4 |

**Confidence Calculation**

```
FOR each type:
  confidence[type] = sum(weights for matching signals)

detected_type = type with highest confidence
confidence_score = max(confidence values)

IF confidence_score >= 0.7:
  PROCEED with detected_type (no user prompt)
ELSE:
  ASK user: "Detected '[TYPE]' (confidence: X%). Correct? [Y/n/feature/bugfix/breaking/refactor/docs]"
```

### Step 3: Extract Feature Summary

```
READ: [SPEC_FOLDER]/spec-lite.md (preferred) OR [SPEC_FOLDER]/spec.md

EXTRACT:
  - First sentence of Overview or Description section
  - Limit to 80 characters
  - Remove markdown formatting

EXAMPLE:
  "User authentication with JWT tokens and refresh token support"
```

### Step 4: Map Type to Changelog Section

| Type | Section | Semver |
|------|---------|--------|
| feature | Added | MINOR |
| bugfix | Fixed | PATCH |
| breaking | Changed (with BREAKING: prefix) | MAJOR |
| refactor | Changed | PATCH |
| docs | Changed | PATCH |
| test | Changed | PATCH |
| chore | Changed | PATCH |

### Step 5: Update CHANGELOG.md

**Locate or Create File**

```bash
# Check if CHANGELOG.md exists
if [ -f "CHANGELOG.md" ]; then
  # File exists, will insert entry
else
  # Create from template (see below)
fi
```

**Entry Format**

```markdown
- [SUMMARY] from `[SPEC_NAME]` (PR #[NUMBER])
```

Examples:
```markdown
- User authentication with JWT tokens from `2025-01-15-auth-feature` (PR #123)
- BREAKING: Changed API response format for `/users` endpoint from `2025-01-16-api-v2` (PR #125)
- Fixed null pointer in checkout flow from `2025-01-14-checkout-fix` (PR #120)
```

**Insertion Logic**

```
FIND: ## [Unreleased] section

IF section exists:
  FIND: ### [SECTION_NAME] subsection

  IF subsection exists:
    INSERT: Entry as last item in subsection
  ELSE:
    CREATE: Subsection in correct order
    INSERT: Entry as first item

ELSE:
  CREATE: [Unreleased] section after header
  CREATE: Subsection
  INSERT: Entry
```

**Section Order** (Keep a Changelog standard):
1. Added
2. Changed
3. Deprecated
4. Removed
5. Fixed
6. Security

### Step 6: Calculate Semver Suggestion

```bash
# Find current version from CHANGELOG.md
CURRENT=$(grep -oE '## \[([0-9]+\.[0-9]+\.[0-9]+)\]' CHANGELOG.md | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')

# Default if no version found
CURRENT="${CURRENT:-0.0.0}"

# Parse components
MAJOR=$(echo $CURRENT | cut -d. -f1)
MINOR=$(echo $CURRENT | cut -d. -f2)
PATCH=$(echo $CURRENT | cut -d. -f3)

# Calculate suggestion based on type
case $TYPE in
  breaking) SUGGESTED="$((MAJOR+1)).0.0" ;;
  feature)  SUGGESTED="$MAJOR.$((MINOR+1)).0" ;;
  *)        SUGGESTED="$MAJOR.$MINOR.$((PATCH+1))" ;;
esac
```

### Step 7: Report Summary

```markdown
## Changelog Update Summary

**Spec:** [SPEC_NAME]
**Detected Type:** [TYPE] (confidence: [X]%)
**Section:** [SECTION_NAME]

### Entry Added
```
[ENTRY_TEXT]
```

### Semver Suggestion
| Current | Suggested | Reason |
|---------|-----------|--------|
| [CURRENT] | [SUGGESTED] | [TYPE] ([SEMVER_IMPACT]) |

### [Unreleased] Status
- Added: X entries
- Changed: Y entries
- Fixed: Z entries

**Total unreleased changes:** N
```

## CHANGELOG.md Template

For new projects without a changelog:

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

### Changed

### Fixed
```

## Error Handling

| Scenario | Action |
|----------|--------|
| No spec folder found | WARN: Skip changelog, report error |
| No CHANGELOG.md | CREATE: From template |
| Malformed CHANGELOG.md | APPEND: At end with warning |
| No [Unreleased] section | CREATE: After header |
| Git diff fails | Use spec analysis only (reduce confidence by 0.2) |
| Write fails | Report error, provide manual instructions |

## Key Principles

1. **Auto-detect first**: Always attempt automatic detection before asking
2. **Confidence-based prompting**: Only ask when uncertain (<70%)
3. **Human-readable**: Entries should make sense to developers
4. **Non-blocking**: Failures should warn but not stop delivery
5. **Atomic writes**: Use temp file + rename for safe updates
6. **Keep a Changelog**: Follow the standard format strictly

## Integration Points

- **Phase 3 Delivery (Step 8.5)**: Primary invocation point after recap
- **git-workflow agent**: Receives PR number and URL
- **Recap document**: Can extract summary from recap if spec-lite unavailable
