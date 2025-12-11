# Execute Tasks - Phase 2: Task Execution Loop

Core implementation workflow with TDD. Loaded only when actively implementing tasks.

**Note**: This phase is for **direct execution mode** only. For parallel wave execution (v2.0), the task-orchestrator handles worker spawning and coordination via async agents.

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
1. CAPTURE task start commit for artifact collection:
   COMMAND: git rev-parse HEAD
   STORE: As task_start_commit (used in Step 7.7)

2. IF context-summary.json exists:
     LOAD: Task-specific context for current task ID
     EXTRACT:
       - spec_sections (relevant only)
       - codebase_refs (filtered to task files)
       - standards (applicable only)
     TOKENS: ~800 (vs ~3000 for full discovery)

   ELSE (fallback):
     ACTION: Use Explore agent for batched context retrieval
     REQUEST: Full context for task (original Step 7.3)

3. LOAD predecessor artifacts (v2.1):
   USE_PATTERN: QUERY_PREDECESSOR_ARTIFACTS_PATTERN from @shared/task-json.md
   IF task has dependencies (parallelization.blocked_by):
     QUERY: tasks.json for predecessor task artifacts
     EXTRACT: exports_added, files_created from completed predecessors
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

### Step 7.3: Verify Names (MANDATORY Gate) - Enhanced v2.1

Create reference sheet before any coding using predecessor artifacts + live verification.

**Name Verification Protocol (v2.1):**
```
USE_PATTERN: VERIFY_PREDECESSOR_OUTPUTS_PATTERN from @shared/task-json.md

STEP 1: Verify predecessor outputs exist
IF task has dependencies (from Step 7.1):
  FOR each predecessor in blocked_by:
    CHECK: predecessor.artifacts in tasks.json
    VERIFY: files_created actually exist on disk
    VERIFY: exports_added are grep-able in codebase
  IF verification fails:
    HALT: "Predecessor task [ID] outputs missing - may need re-execution"

STEP 2: Build reference sheet from artifacts + live search
CREATE reference sheet:

  1. From predecessor artifacts (trusted cache):
     - exports_added: Known function/class names from completed tasks
     - files_created: Known file paths to import from

  2. From existing codebase (live Grep verification):
     - Functions to call: GREP for exact names in relevant directories
     - Import paths: GREP for export statements to find exact paths
     - Types/interfaces: GREP for type definitions

  3. From context-summary codebase_refs (predicted, verify if critical):
     - Pre-computed refs may be stale
     - ALWAYS verify critical names with live Grep

STEP 3: Validation gate
  VALIDATION GATE:
  ✓ Do NOT guess names - use artifacts or live search
  ✓ Do NOT write code until names verified
  ✓ Predecessor artifacts are trusted (just completed)
  ✓ Pre-computed refs should be verified for critical items
  ✗ HALT if critical names missing after search

VERIFICATION COMMANDS:
  # Find function definition
  grep -r "export.*functionName" src/

  # Find exact import path
  grep -r "export.*ComponentName" --include="*.ts" --include="*.tsx" src/

  # Verify predecessor export exists
  grep "export.*${export_name}" [predecessor_file]
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

### Step 7.7: Collect Task Artifacts (v2.1)

Collect and record what this task created for cross-task verification.

**Artifact Collection:**
```
USE_PATTERN: COLLECT_ARTIFACTS_PATTERN from @shared/task-json.md

1. GET task start commit (stored at Step 7.1)
   COMMAND: git rev-parse HEAD (captured before task began)

2. COLLECT file changes via git diff:
   COMMAND: git diff --name-status [start_commit] HEAD
   EXTRACT:
     - files_modified: Lines starting with 'M'
     - files_created: Lines starting with 'A'
     - test_files: Any file matching *.test.* or *.spec.*

3. EXTRACT exports from new files:
   FOR each file in files_created:
     IF .ts/.js/.tsx/.jsx:
       GREP: "export (const|function|class|type)" [file]
     IF .py:
       GREP: "^def |^class " [file]
     ADD: Matching names to exports_added and functions_created

4. BUILD artifacts object:
   {
     "files_modified": [...],
     "files_created": [...],
     "functions_created": [...],
     "exports_added": [...],
     "test_files": [...]
   }

NOTE: This replaces the codebase-indexer subagent (deprecated v2.1)
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

After validation passes, mark complete and log with artifacts.

**Task Completion (v2.1 - includes artifacts):**
```
USE_PATTERN: UPDATE_TASK_METADATA_PATTERN from @shared/task-json.md

1. UPDATE tasks.json with:
   - status = "pass"
   - completed_at = now
   - artifacts = (from Step 7.7)
     {
       files_modified: [...],
       files_created: [...],
       functions_created: [...],
       exports_added: [...],
       test_files: [...]
     }

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
  files_created: [COUNT] new files
  exports_added: [LIST of key exports]
  next_steps: [NEXT_TASK_OR_PHASE]
```

**Why artifacts matter:**
- Enables subsequent tasks to verify predecessor outputs
- Replaces stale codebase-indexer with fresh data
- Supports cross-task name verification via QUERY_PREDECESSOR_ARTIFACTS_PATTERN

---

## Phase 2 Completion

After all tasks in loop complete:
- All assigned tasks executed
- Tests passing for each task
- Tasks.json updated
- Progress logged

**Next Phase**: Load `execute-phase3.md` for completion and delivery

---

## Parallel Execution Alternative (v2.0)

If `execution_strategy.mode == "parallel_waves"` was selected, Phase 2 is handled by the task-orchestrator subagent instead:

```
PARALLEL EXECUTION FLOW (handled by task-orchestrator):

FOR each wave in execution_strategy.waves:
  1. SPAWN all workers in wave simultaneously
     - Use Task tool with run_in_background: true
     - Each worker receives parallel_context from context-summary.json
     - Workers execute independently with no shared state

  2. COLLECT results via AgentOutputTool
     - Wait for all workers in wave to complete
     - Aggregate test results
     - Update tasks.json with completion status

  3. VERIFY wave completion
     - All workers must pass before next wave
     - Failed tasks block dependent waves

  CONTINUE to next wave
END FOR

RETURN: Aggregate results to main flow for Phase 3
```

**Benefits of Parallel Execution:**
- 1.5-3x speedup for specs with independent tasks
- Fresh context per worker (no accumulation)
- Automatic dependency handling via pre-computed waves
- Graceful fallback to sequential if needed
