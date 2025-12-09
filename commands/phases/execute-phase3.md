# Execute Tasks - Phase 3: Completion and Delivery

Final verification, git workflow, and documentation. Loaded after all tasks complete.

---

## Phase 3: Task Completion and Delivery

### Step 8: Run All Tests

Run full test suite to ensure no regressions.

**Smart Test Execution:**
```
IF test results cached (last 5 minutes) AND all passing:
  SKIP: Re-running tests
  USE: Cached results
  SAVE: 15-30 seconds

ELSE:
  ACTION: test-check skill auto-invokes
  REQUEST: Run full test suite
  VERIFY: 100% pass rate
  FIX: Any failures before proceeding
```

### Step 9: Specification Compliance Check

Verify spec validation completed during execution.

**Smart Skip Logic:**
```
IF execute-task validated specs (Phase 2 Step 7.9):
  SKIP: Full re-validation
  VERIFY: No new violations reported
  PROCEED: To build verification

ELSE IF validation incomplete:
  PERFORM: Quick compliance check on changed files
  FOCUS: New functionality only
```

### Step 9.5: Build Verification

The build-check skill auto-invokes before commit.

**Instructions:**
```
ACTION: Get modified files
COMMAND: git diff --name-only [BASE_BRANCH]...HEAD

ACTION: Get remaining tasks for context
READ: tasks.json for uncompleted tasks

ACTION: build-check skill auto-invokes
CONTEXT: "Check build before commit for [SPEC_NAME]:
          - Modified files: [LIST]
          - Completed tasks: [LIST]
          - Future tasks: [REMAINING_UNCOMPLETED]"

ANALYZE: Decision (COMMIT | FIX_REQUIRED | DOCUMENT_AND_COMMIT)
```

**Decision Handling:**

```
IF FIX_REQUIRED:
  DISPLAY: List of must-fix errors
  ACTION: Fix each error
  VERIFY: Re-run until COMMIT decision
  THEN: Proceed to git workflow

IF DOCUMENT_AND_COMMIT:
  DISPLAY: Acceptable errors and reasoning
  SAVE: Commit message addendum
  NOTE: Errors will be fixed by future tasks
  PROCEED: To git workflow with addendum

IF COMMIT:
  NOTE: All checks passed
  PROCEED: To git workflow
```

### Step 9.6: Build-Check Gate (MANDATORY)

**Validation Checkpoint:**
```
VERIFY before git workflow:

☐ Build Verification Evidence:
  - Build command executed
  - Output captured and analyzed
  - Exit code checked

☐ Diagnostics Check Evidence:
  - mcp__ide__getDiagnostics called
  - Type errors classified
  - Lint warnings reviewed

☐ Decision Documentation:
  - Clear decision recorded
  - Fixes applied if FIX_REQUIRED
  - Addendum prepared if DOCUMENT_AND_COMMIT

VALIDATION:
  IF all evidence AND decision is COMMIT/DOCUMENT_AND_COMMIT:
    ✓ PROCEED to git workflow
  ELSE IF missing verification:
    ✗ HALT - Run build-check
  ELSE IF FIX_REQUIRED:
    ✗ HALT - Apply fixes first
```

### Step 10: Git Workflow

Create commit, push, and PR.

**Instructions:**
```
ACTION: Use git-workflow subagent via Task tool
REQUEST: "Complete git workflow for [SPEC_NAME]:
          - Spec: [SPEC_FOLDER_PATH]
          - Changes: All modified files
          - Target: main branch
          - Description: [SUMMARY]
          - Commit addendum: [BUILD_CHECK_ADDENDUM if any]"
SAVE: PR URL for summary
```

### Step 11: Task Completion Verification

Verify all tasks are marked complete.

**Instructions:**
```
ACTION: Use project-manager subagent via Task tool
REQUEST: "Verify task completion:
          - Read tasks.json
          - Check all tasks have status 'pass'
          - Verify blockers are documented
          - Update any discrepancies"
```

### Step 12: Roadmap Progress Update (Conditional)

Update roadmap only if tasks completed roadmap items.

**Smart Check:**
```
QUICK_CHECK: Task names against roadmap keywords

IF no matches:
  SKIP: Entire step
  SAVE: 3-5 seconds

ELSE IF matches found:
  EVALUATE: Did tasks complete roadmap items?
  IF YES:
    ACTION: Use project-manager subagent
    UPDATE: Mark roadmap items complete
```

### Step 13: Documentation and Summary

Create recap and completion summary.

**Batched Request:**
```
ACTION: Use project-manager subagent via Task tool
REQUEST: "Complete documentation:

  TASK 1 - Create recap:
  - Create: .agent-os/recaps/[SPEC_FOLDER_NAME].md
  - Template: Recap format with completed features
  - Include: Context from spec-lite.md
  - Document: [SPEC_FOLDER_PATH]

  TASK 2 - Generate summary:
  - List completed tasks with descriptions
  - Note any issues encountered
  - Include testing instructions
  - Add PR link from Step 10

  Return both outputs"
```

**Recap Template:**
```markdown
# [yyyy-mm-dd] Recap: Feature Name

Recaps what was built for .agent-os/specs/[spec-folder-name]/spec.md.

## Recap
[1 paragraph summary plus bullet list of completions]

## Context
[Summary from spec-lite.md]
```

### Step 14: Completion Notification

Alert user that tasks are complete.

**Instructions:**
```
ACTION: Play completion sound
COMMAND: afplay /System/Library/Sounds/Glass.aiff
PURPOSE: Alert user
```

### Step 15: Log Session End

Log to progress log for cross-session memory.

**Instructions:**
```
ACTION: Append to progress log
ENTRY_TYPE: session_ended
DATA:
  spec: [SPEC_FOLDER_NAME]
  summary: [BRIEF_SUMMARY]
  tasks_completed: [LIST_OF_TASK_IDS]
  pr_url: [PR_URL_IF_CREATED]
  next_steps: [SUGGESTED_NEXT]

FILE: .agent-os/progress/progress.json
ALSO: Regenerate progress.md
```

---

## Phase 3 Completion

After Phase 3 completes:
- All tests passing
- Build verified
- Git commit and PR created
- Documentation generated
- Progress logged
- User notified

**Workflow Complete!**

---

## Error Recovery Reference

| Error | Action |
|-------|--------|
| Test failures | Return to Phase 2, fix and re-verify |
| Build errors (own files) | Fix immediately, re-run build-check |
| Build errors (other files) | DOCUMENT_AND_COMMIT, create task |
| Git workflow failure | Retry once, then manual fallback |
| PR creation failure | Push changes, manual PR |

See @shared/error-recovery.md for detailed procedures.
