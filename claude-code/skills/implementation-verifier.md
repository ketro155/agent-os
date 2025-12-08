---
name: implementation-verifier
description: "End-to-end implementation verification skill. Auto-invoke after completing all tasks in a spec to verify task completion, update roadmap, run full test suite, and generate verification report. Ensures implementations match specifications before delivery."
allowed-tools: Read, Write, Bash, Glob, Grep, TodoWrite
---

# Implementation Verifier Skill

Validates that all implementation work is complete, tests pass, and deliverables match specifications before marking a feature as done.

**Core Principle:** VERIFY BEFORE DELIVERY

## When to Use This Skill

Claude should invoke this skill:
- **After completing all tasks** in a specification
- **Before creating a PR** for feature delivery
- **When user asks** to verify implementation completeness
- **Before running `/complete-tasks`** phase

**Not for:** Mid-implementation checks (use test-check instead), debugging (use systematic-debugging)

## Verification Workflow

### Phase 1: Task Completion Audit

**1.1 Check Task Status**
```
ACTION: Read tasks.md from current spec
SCAN: All task checkboxes
COUNT: Completed vs total tasks

IF any tasks unchecked:
  REPORT: "Found N incomplete tasks:"
  LIST: Unchecked task IDs and descriptions
  ASK: "Should I mark these as blocked, or are they actually complete?"
  WAIT: For user response
```

**1.2 Validate Task Evidence**
```
FOR EACH completed task:
  CHECK: Does implementation exist?
  CHECK: Are tests present for this task?
  CHECK: Does code match spec requirements?

IF missing evidence:
  WARN: "Task X.Y marked complete but missing:"
  LIST: Missing components
```

### Phase 2: Specification Compliance

**2.1 Load Specification**
```
ACTION: Read spec.md and technical-spec.md
EXTRACT: All requirements and deliverables
CREATE: Compliance checklist
```

**2.2 Verify Each Requirement**
```
FOR EACH spec requirement:
  SEARCH: Codebase for implementation
  VERIFY: Behavior matches specification

  IF implemented:
    MARK: ✅ Requirement satisfied
  ELSE:
    MARK: ❌ Missing: [requirement]
    NOTE: Expected location/behavior
```

**2.3 Check Scope Boundaries**
```
VERIFY: No out-of-scope items implemented
VERIFY: All in-scope items addressed

IF scope creep detected:
  WARN: "Implementation includes unspecified features:"
  LIST: Out-of-scope additions
  ASK: "Should these be documented or removed?"
```

### Phase 3: Test Suite Validation

**3.1 Run Full Test Suite**
```
ACTION: Execute test command
CAPTURE: All output including failures

IF tests pass:
  REPORT: "✅ All N tests passing"
ELSE:
  REPORT: "❌ Test failures detected:"
  LIST: Failed tests with reasons
  HALT: Do not proceed until tests pass
```

**3.2 Check Test Coverage**
```
ACTION: Run coverage report (if available)
ANALYZE: Coverage for new code

IF coverage < threshold:
  WARN: "Test coverage below threshold"
  LIST: Uncovered files/functions
```

### Phase 4: Roadmap Synchronization

**4.1 Load Roadmap**
```
ACTION: Read .agent-os/product/roadmap.md
FIND: Items matching this specification
```

**4.2 Update Completion Status**
```
FOR EACH matching roadmap item:
  IF all related tasks complete:
    UPDATE: Mark item as [x] completed
    ADD: Completion date
  ELSE:
    SKIP: Leave unchecked
    NOTE: "Roadmap item partially complete"
```

**4.3 Identify Next Items**
```
SCAN: Next uncompleted roadmap items
REPORT: "Next roadmap priorities:"
LIST: Top 3 upcoming items
```

### Phase 5: Generate Verification Report

**5.1 Create Report**
```
PATH: .agent-os/verification/YYYY-MM-DD-[spec-name].md
```

**5.2 Report Template**
```markdown
# Implementation Verification Report

> Spec: [SPEC_NAME]
> Verified: [TIMESTAMP]
> Status: [PASS/FAIL]

## Summary

| Metric | Status |
|--------|--------|
| Tasks Complete | X/Y ✅ |
| Tests Passing | X/Y ✅ |
| Spec Compliance | X/Y ✅ |
| Roadmap Updated | Yes/No |

## Task Audit

### Completed Tasks
- [x] Task 1.1 - [Description]
- [x] Task 1.2 - [Description]

### Issues Found
[None or list of issues]

## Specification Compliance

### Requirements Met
- ✅ [Requirement 1]
- ✅ [Requirement 2]

### Requirements Not Met
[None or list]

## Test Results

```
[Test output summary]
```

### Coverage
[Coverage report if available]

## Roadmap Updates

### Completed Items
- [x] [Roadmap item] - Completed [DATE]

### Next Priorities
1. [Next item]
2. [Second item]

## Verification Outcome

**Result:** [PASS/FAIL]

[If PASS]
✅ Implementation verified. Ready for PR creation.

[If FAIL]
❌ Issues must be resolved before delivery:
1. [Issue 1]
2. [Issue 2]

---
*Verified by implementation-verifier skill*
```

## Output Format

### Quick Summary (Always Show)
```markdown
## Verification Summary: [Spec Name]

| Check | Result |
|-------|--------|
| Tasks | ✅ 5/5 complete |
| Tests | ✅ 42 passing |
| Spec Compliance | ✅ All requirements met |
| Roadmap | ✅ Updated |

**Status:** Ready for delivery ✅
```

### Failure Summary
```markdown
## Verification Summary: [Spec Name]

| Check | Result |
|-------|--------|
| Tasks | ❌ 4/5 complete |
| Tests | ❌ 3 failing |
| Spec Compliance | ✅ All requirements met |
| Roadmap | ⏸️ Not updated |

**Status:** Issues found ❌

### Required Actions
1. Complete Task 1.3: Database migration
2. Fix failing tests:
   - `user.test.ts`: Expected 200, got 401
   - `auth.test.ts`: Timeout after 5000ms
   - `api.test.ts`: Missing mock data
```

## Integration with Agent OS

### In execute-tasks.md
After all tasks complete, implementation-verifier auto-invokes to validate before PR creation.

### In complete-tasks workflow
Verifier runs as prerequisite to generating recap and creating PR.

### Blocking Behavior
If verification fails:
- PR creation blocked
- User notified of issues
- Specific remediation steps provided

## Key Principles

1. **Complete Before Moving On**: Don't skip verification steps
2. **Evidence-Based**: Every claim backed by actual checks
3. **Actionable Failures**: When failing, provide specific fix instructions
4. **Non-Destructive**: Verification is read-only until user approves changes
5. **Roadmap Awareness**: Always update project progress tracking

## Error Handling

| Scenario | Recovery |
|----------|----------|
| tasks.md not found | Search for task files, ask user for location |
| Tests timeout | Report timeout, suggest test isolation |
| Roadmap missing | Skip roadmap update, note in report |
| Partial spec coverage | Report coverage gaps, don't fail entirely |
| Cannot determine test command | Ask user for test command |
