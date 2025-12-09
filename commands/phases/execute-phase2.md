# Execute Tasks - Phase 2: Task Execution Loop

Core implementation workflow with TDD. Loaded only when actively implementing tasks.

---

## Phase 2: Task Execution Loop

### Step 7: Execute Tasks

Execute all assigned parent tasks and their subtasks.

**Execution Flow:**
```
FOR each parent_task assigned in Phase 1:
  EXECUTE the following sub-workflow:
    → Step 7.1: Load Task Context
    → Step 7.2: Task Understanding
    → Step 7.3: Verify Names (mandatory gate)
    → Step 7.4: Approach Design
    → Step 7.5: TDD Execution
    → Step 7.6: Test Verification
    → Step 7.7: Update Codebase References
    → Step 7.8: Task Status Updates
    → Step 7.9: Output Validation
    → Step 7.10: Mark Complete and Log

  UPDATE: tasks.json status
  SAVE: Cache state
END FOR
```

### Step 7.1: Load Task Context

Use pre-computed context from context-summary.json.

**Instructions:**
```
IF context-summary.json exists:
  LOAD: Task-specific context for current task ID
  EXTRACT:
    - spec_sections (relevant only)
    - codebase_refs (filtered to task files)
    - standards (applicable only)
  TOKENS: ~800 (vs ~3000 for full discovery)

ELSE (fallback):
  ACTION: Use Explore agent for batched context retrieval
  REQUEST: Full context for task (original Step 7.3)
```

### Step 7.2: Task Understanding
Map task requirements to loaded context.

**Task Analysis:**
```
FROM tasks.json:
  - Parent task description
  - All subtask descriptions
  - Dependencies
  - Expected outcomes

FROM context-summary:
  - Relevant spec sections
  - Files to modify
  - Patterns to follow
```

### Step 7.3: Verify Names (MANDATORY Gate)

Create reference sheet before any coding.

**Name Verification Protocol:**
```
IF codebase_refs exist in task context:

  CREATE reference sheet:

  1. Functions to call:
     - Exact spelling and casing
     - Expected parameters
     - Return types

  2. Components/modules to import:
     - Exact import paths
     - Named vs default exports

  3. Variables/classes to reference:
     - Exact names
     - Types and interfaces

  4. Schemas/models to use:
     - Table/column names
     - API endpoints
     - Data structures

  VALIDATION GATE:
  ✓ Do NOT guess names
  ✓ Do NOT write code until names verified
  ✓ If unsure, search codebase first
  ✗ HALT if critical names missing
```

### Step 7.4: Approach Design
Document implementation strategy before coding.

**Approach Documentation:**
```markdown
## Implementation Approach

### Specification Alignment
- Relevant specs: [from context summary]
- Key requirements: [extracted]
- Constraints: [from specs]

### Implementation Strategy
- Approach: [method]
- Files to modify: [from context]
- Dependencies: [identified]

### Validation Criteria
- Success metrics
- Acceptance criteria
- Error scenarios
```

**Pre-Implementation Validation:**
- ✓ Strategy aligns with specs
- ✓ Outputs match requirements
- ✓ Reference sheet created
- ✗ HALT if approach conflicts

### Step 7.5: TDD Execution

The tdd skill auto-invokes for test-driven development.

**Core Principle:** NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST

**TDD Cycle:**
```
1. RED:    Write failing test
2. GREEN:  Write minimal code to pass
3. REFACTOR: Clean up, tests stay green
4. COMMIT: After each passing test
```

**Subtask Execution:**

```
Subtask 1 - Write Tests (RED):
  - Write tests based on spec requirements
  - Include unit, integration, edge cases
  - Run tests - verify they FAIL
  - Mark subtask complete

Middle Subtasks - Implement (GREEN):
  - Implement functionality per specs
  - Make tests pass (minimal code)
  - Refactor while green
  - Mark each subtask complete

Final Subtask - Verify:
  - Run entire test suite
  - Fix any failures
  - Confirm spec compliance
  - Mark complete
```

### Step 7.5.1: TDD Gate (MANDATORY)

**Validation Checkpoint:**
```
VERIFY before proceeding:

☐ RED Phase Evidence:
  - Test file created BEFORE production code
  - Test executed and FAILED
  - Failure documented

☐ GREEN Phase Evidence:
  - Production code written AFTER failing test
  - Test re-executed and PASSED
  - Implementation is minimal

☐ REFACTOR Phase Evidence:
  - Cleanup occurred
  - Tests remained GREEN

VALIDATION:
  IF all verified: PROCEED
  IF RED phase missing: HALT - delete code, restart TDD
  IF evidence missing: WARNING - document deviation
```

### Step 7.6: Test Verification

Run and verify task-specific tests.

**Instructions:**
```
ACTION: test-check skill auto-invokes
REQUEST: Run tests for this task's test files
CACHE: Results in session-cache.json
VERIFY: 100% pass rate for task tests
```

### Step 7.7: Update Codebase References (Conditional)

Update references if production code changed.

**Smart Skip Logic:**
```
CHECK: Git diff for actual code changes

IF only test files or docs changed:
  SKIP: No production code to index

ELSE IF only minor changes (< 5 lines):
  CONSIDER: Skip if no signature changes

ELSE:
  ACTION: Use codebase-indexer subagent
  REQUEST: Update for modified files only
```

### Step 7.8: Task Status Updates

Update task statuses in tasks.json.

**Update Format:**
```
- Completed: status = "pass"
- Incomplete: status = "pending"
- Blocked: status = "blocked", blocker = "[description]"
```

**Sync to Markdown:**
```
After JSON update, sync to tasks.md:
- [x] = pass
- [ ] = pending
- [ ] ⚠️ = blocked
```

### Step 7.9: Output Validation

Validate against specifications before marking complete.

**Validation Checklist:**

```
Specification Compliance:
✓ Output format matches spec
✓ Data structures follow schemas
✓ Business rules enforced
✓ Interfaces correctly implemented
✓ Error handling covers scenarios

Quality Checks:
✓ Expected functionality delivered
✓ Edge cases handled
✓ Dependencies work
✓ Performance meets criteria
✓ No requirements missed
```

**Evidence Requirements:**
```
INVALID: "Tests should pass now"
VALID:   "Tests pass: npm test exit code 0"
```

### Step 7.10: Mark Complete and Log Progress

After validation passes, mark complete and log.

**Task Completion:**
```
1. UPDATE: tasks.json with status = "pass"
2. SYNC: tasks.md checkboxes
3. LOG: task_completed to progress log
```

**Progress Log Entry:**
```
ENTRY_TYPE: task_completed
DATA:
  spec: [SPEC_FOLDER_NAME]
  task_id: [PARENT_TASK_ID]
  description: [TASK_DESCRIPTION]
  duration_minutes: [ESTIMATED]
  notes: [KEY_ACCOMPLISHMENTS]
  next_steps: [NEXT_TASK_OR_PHASE]
```

---

## Phase 2 Completion

After all tasks in loop complete:
- All assigned tasks executed
- Tests passing for each task
- Tasks.json updated
- Progress logged

**Next Phase**: Load `execute-phase3.md` for completion and delivery
