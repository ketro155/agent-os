# Create Tasks

## Quick Navigation
- [Description](#description)
- [Parameters](#parameters)
- [Dependencies](#dependencies)
- [Task Tracking](#task-tracking)
- [Core Instructions](#core-instructions)
- [State Management](#state-management)
- [Error Handling](#error-handling)
- [Subagent Integration](#subagent-integration)

## Description
Create a tasks list with sub-tasks to execute a feature based on its spec. This command analyzes an approved specification and generates an actionable task breakdown with proper sequencing, dependency management, and **parallel execution analysis** (v2.0).

**v2.0 Feature**: Automatically analyzes task dependencies and generates execution waves for parallel async agent execution.

## Parameters
- `spec_folder_path` (required): Path to the approved specification folder
- `codebase_aware` (optional): Enable codebase reference integration for task complexity estimation

## Dependencies
**Required State Files:**
- `.agent-os/specs/[spec-folder]/spec.md` (read for task generation)
- `.agent-os/specs/[spec-folder]/sub-specs/technical-spec.md` (read for technical details)
- `.agent-os/codebase/` (conditional - for task complexity estimation)

**Expected Directories:**
- `.agent-os/specs/[spec-folder]/` (specification folder)
- `.agent-os/standards/` (coding standards)

**Creates Files:**
- `.agent-os/specs/[spec-folder]/tasks.md` (human-readable task breakdown)
- `.agent-os/specs/[spec-folder]/tasks.json` (machine-readable, primary format)
- `.agent-os/specs/[spec-folder]/context-summary.json` (pre-computed context per task)

## Task Tracking
**IMPORTANT: Use Claude's TodoWrite tool throughout execution:**
```javascript
// Example todos for this command workflow (v2.0)
const todos = [
  { content: "Read and analyze specification documents", status: "pending", activeForm: "Reading and analyzing specification documents" },
  { content: "Analyze codebase references if available", status: "pending", activeForm: "Analyzing codebase references if available" },
  { content: "Generate task breakdown structure", status: "pending", activeForm: "Generating task breakdown structure" },
  { content: "Create tasks.md and tasks.json files", status: "pending", activeForm: "Creating tasks.md and tasks.json files" },
  { content: "Analyze parallel execution opportunities", status: "pending", activeForm: "Analyzing parallel execution opportunities" },
  { content: "Generate context-summary.json with parallel context", status: "pending", activeForm: "Generating context-summary.json with parallel context" },
  { content: "Present execution strategy summary", status: "pending", activeForm: "Presenting execution strategy summary" },
  { content: "Request execution confirmation", status: "pending", activeForm: "Requesting execution confirmation" }
];
// Update status to "in_progress" when starting each task
// Mark as "completed" immediately after finishing
```

## For Claude Code
When executing this command:
1. **Initialize TodoWrite** with the workflow steps above for visibility
2. Read specification documents from the provided spec folder
3. Use Write tool to create files as specified
4. Handle codebase reference integration conditionally
5. **Update TodoWrite** status throughout execution
6. Present clear execution readiness check

---

## SECTION: Core Instructions
<!-- BEGIN EMBEDDED CONTENT -->

# Spec Creation Rules

## Overview

With the user's approval, proceed to creating a tasks list based on the current feature spec.

## Process Flow

### Step 1: Create tasks.md and tasks.json (writing-plans + tdd skills)

Use the writing-plans skill to create detailed micro-tasks and the tdd skill to enforce test-first structure. Generate both human-readable (tasks.md) and machine-readable (tasks.json) formats.

**Core Principle:** DOCUMENT EVERYTHING THE EXECUTOR NEEDS TO KNOW

**Writing Plans Approach:**
```
ACTION: writing-plans skill structures task breakdown
WORKFLOW:
  1. Break down hierarchically: Feature → Components → Tasks → Subtasks
  2. Each subtask should be 2-5 minutes of focused work
  3. Include exact file paths and complete code examples
  4. Follow TDD structure for each task
```

**TDD Task Structure (tdd skill):**
```
FOR each behavior/component:
  1. Write failing test for [behavior]
  2. Verify test fails (RED)
  3. Implement minimal code (GREEN)
  4. Verify test passes
  5. Commit
```

Create BOTH files inside of the current feature's spec folder using the Write tool.

**Task Structure:**
- **Major Tasks**:
  - Count: 1-5
  - Format: numbered checklist
  - Grouping: by feature or component
- **Subtasks**:
  - Count: up to 8 per major task
  - Format: decimal notation (1.1, 1.2)
  - First subtask: write tests (TDD RED phase)
  - Implementation subtask: minimal code (TDD GREEN phase)
  - Last subtask: verify all tests pass

**tasks.md Template (Human-Readable):**
```markdown
# Spec Tasks

## Tasks

- [ ] 1. [MAJOR_TASK_DESCRIPTION]
  - [ ] 1.1 Write failing tests for [COMPONENT] (TDD RED)
  - [ ] 1.2 Verify tests fail as expected
  - [ ] 1.3 Implement [COMPONENT] (TDD GREEN)
  - [ ] 1.4 Verify all tests pass
  - [ ] 1.5 Commit changes

- [ ] 2. [MAJOR_TASK_DESCRIPTION]
  - [ ] 2.1 Write failing tests for [COMPONENT] (TDD RED)
  - [ ] 2.2 Implement [COMPONENT] (TDD GREEN)
```

**tasks.json Template (Machine-Readable):**
```json
{
  "version": "1.0",
  "spec": "[SPEC_FOLDER_NAME]",
  "spec_path": ".agent-os/specs/[SPEC_FOLDER]/",
  "created": "[ISO_TIMESTAMP]",
  "updated": "[ISO_TIMESTAMP]",
  "tasks": [
    {
      "id": "1",
      "type": "parent",
      "description": "[MAJOR_TASK_DESCRIPTION]",
      "status": "pending",
      "subtasks": ["1.1", "1.2", "1.3", "1.4", "1.5"],
      "progress_percent": 0
    },
    {
      "id": "1.1",
      "type": "subtask",
      "parent": "1",
      "description": "Write failing tests for [COMPONENT] (TDD RED)",
      "status": "pending",
      "attempts": 0
    }
  ],
  "summary": {
    "total_tasks": 0,
    "parent_tasks": 0,
    "subtasks": 0,
    "completed": 0,
    "pending": 0,
    "overall_percent": 0
  }
}
```

**Ordering Principles:**
- Consider technical dependencies
- **Enforce TDD approach** (test before implementation)
- Group related functionality
- Build incrementally
- Micro-tasks (2-5 min each)

**Codebase Reference Integration:**

**Conditional Analysis:**
```
IF .agent-os/codebase/ exists:
  ANALYZE: Existing function signatures and patterns relevant to spec requirements
  IDENTIFY: Reusable components and established integration points
  ESTIMATE: Task complexity based on existing implementations vs new development
  REFERENCE: Existing functions that can be extended or integrated
ELSE:
  PROCEED: With standard task breakdown for greenfield development
```

**Task Enhancement:**
- Reference existing functions in implementation steps
- Adjust complexity estimates based on code reuse opportunities
- Include integration tasks for existing components
- Consider refactoring needs for legacy code integration

### Step 1.5: Analyze Parallel Execution Opportunities (NEW v2.0)

After creating tasks, analyze dependencies to identify parallel execution opportunities.

**Purpose:** Enable async agent execution by pre-computing which tasks can run in parallel.

**Instructions:**
```
ACTION: Analyze task dependencies for parallel execution
USE_PATTERN: ANALYZE_PARALLELIZATION_PATTERN from @shared/task-json.md

FOR each parent task:
  EXTRACT from technical-spec.md:
    - Files to be created/modified
    - Dependencies on other components
    - Shared state (database tables, config, etc.)

  CLASSIFY dependencies:
    - HARD: Must complete before next (shared file writes)
    - SOFT: Could parallelize with careful coordination
    - NONE: Fully independent

BUILD dependency graph:
  FOR each task pair (A, B):
    IF A modifies files that B reads/modifies:
      A blocks B (sequential required)
    ELSE IF A.output IS B.input (logical dependency):
      A blocks B
    ELSE:
      A can_parallel_with B

GENERATE execution waves:
  Wave 1 = tasks with no blocked_by
  Wave N = tasks whose blocked_by are all in waves < N

CALCULATE metrics:
  - estimated_parallel_speedup = sequential_time / parallel_time
  - max_concurrent_workers = max(tasks in any wave)
  - isolation_scores per task

ADD to tasks.json:
  - execution_strategy (top-level)
  - parallelization (per parent task)
```

**Output Format:**
```json
{
  "execution_strategy": {
    "mode": "sequential|parallel_waves|fully_parallel",
    "waves": [
      { "wave_id": 1, "tasks": ["1", "2"], "rationale": "..." }
    ],
    "estimated_parallel_speedup": 1.5,
    "max_concurrent_workers": 2
  }
}
```

### Step 1.6: Generate context-summary.json with Parallel Context (UPDATED v2.0)

After creating tasks and analyzing parallelization, pre-compute context summaries.

**Purpose:** Reduce context overhead during execute-tasks by pre-computing what each task needs, including parallel coordination instructions.

**Instructions:**
```
ACTION: Generate context summary with parallel context
USE_PATTERN: GENERATE_CONTEXT_SUMMARY_PATTERN from @shared/context-summary.md
USE_PATTERN: GENERATE_PARALLEL_CONTEXT_PATTERN from @shared/context-summary.md

FOR each task in tasks.json:
  EXTRACT:
    - Relevant spec sections (by keyword matching task description)
    - Files likely to be modified (from technical-spec.md)
    - Codebase references for those files (if .agent-os/codebase/ exists)
    - Applicable standards (coding style, patterns)
  ESTIMATE: Token count for this task's context

  IF task is parent AND has parallelization data:
    ADD parallel_context:
      - wave number
      - concurrent_tasks list
      - conflict_risk (low/medium/high)
      - shared_resources
      - prerequisite_outputs (for dependent tasks)
      - worker_instructions (coordination guidance)

  STORE: In context-summary.json

CALCULATE: Total estimated tokens, average per task, parallel summary
```

**context-summary.json Template:**
```json
{
  "version": "1.0",
  "spec": "[SPEC_FOLDER_NAME]",
  "generated": "[ISO_TIMESTAMP]",
  "source_hashes": {
    "spec.md": "[HASH]",
    "technical-spec.md": "[HASH]",
    "tasks.md": "[HASH]"
  },
  "global_context": {
    "product_pitch": "[FROM_MISSION]",
    "tech_stack": ["[TECH1]", "[TECH2]"],
    "branch_name": "[DERIVED_FROM_SPEC_FOLDER]"
  },
  "tasks": {
    "1": {
      "summary": "[TASK_DESCRIPTION]",
      "spec_sections": ["[SECTION1]", "[SECTION2]"],
      "relevant_files": ["[FILE1]", "[FILE2]"],
      "codebase_refs": {
        "functions": [],
        "imports": [],
        "schemas": []
      },
      "standards": {
        "patterns": [],
        "testing": []
      },
      "estimated_tokens": 0
    }
  },
  "metadata": {
    "total_tasks": 0,
    "total_estimated_tokens": 0,
    "average_tokens_per_task": 0
  }
}
```

**Benefits:**
- ~73% reduction in per-task context tokens during execution
- Enables orchestrator pattern for multi-task sessions
- Pre-filters codebase references to relevant files only
- Workers receive exactly what they need, nothing more

### Step 2: Execution Readiness Check (UPDATED v2.0)

Evaluate readiness to begin implementation by presenting task summary with parallel execution strategy.

**Readiness Summary:**
- **Present to User**:
  - Spec name and description
  - Total tasks and parallel execution strategy
  - Estimated speedup from parallelization
  - First wave tasks (if parallel mode)
  - Key deliverables

**Execution Prompt (Parallel Mode):**
```
PROMPT: "The spec planning is complete with parallel execution analysis.

**Execution Strategy:** [MODE: sequential|parallel_waves]
**Total Tasks:** [N] parent tasks across [W] execution waves
**Estimated Parallel Speedup:** [X]x faster than sequential

**Wave 1 Tasks (can run in parallel):**
- Task 1: [TITLE]
- Task 2: [TITLE] (if applicable)

**Estimated Time:**
- Sequential: ~[X] minutes
- Parallel: ~[Y] minutes

Would you like me to proceed? Options:
1. **Execute Wave 1** - Run all Wave 1 tasks in parallel (recommended)
2. **Execute Task 1 only** - Single task focus
3. **Review plan** - Examine parallel analysis before proceeding

Type '1', '2', or '3' (or describe your preference)."
```

**Execution Prompt (Sequential Mode):**
```
PROMPT: "The spec planning is complete.

**Execution Strategy:** Sequential (tasks have dependencies)
**Total Tasks:** [N] parent tasks

**Task 1:** [FIRST_TASK_TITLE]
[BRIEF_DESCRIPTION_OF_TASK_1_AND_SUBTASKS]

Would you like me to proceed with implementing Task 1?

Type 'yes' to proceed with Task 1, or let me know if you'd like to review or modify the plan first."
```

**Execution Flow:**
```
IF parallel_mode AND user_chooses_wave:
  REFERENCE: @.agent-os/instructions/core/execute-tasks.md
  MODE: parallel_waves
  EXECUTE: All tasks in Wave 1 using async agents
ELSE IF user_chooses_single_task:
  REFERENCE: @.agent-os/instructions/core/execute-tasks.md
  MODE: direct_single
  FOCUS: Only Task 1 and its subtasks
ELSE:
  WAIT: For user clarification or modifications
```

<!-- END EMBEDDED CONTENT -->

---

## SECTION: State Management

Use patterns from @shared/state-patterns.md for file operations.

**Create-tasks specific:** Validate spec folder exists, read spec documents, check for existing tasks.md before overwriting.

---

## SECTION: Error Handling

See @shared/error-recovery.md for general recovery procedures.

### Create-tasks Specific Error Handling

| Error | Recovery |
|-------|----------|
| Spec folder not found | Verify path, run create-spec first |
| Spec reading failure | Continue with available docs, note gaps in breakdown |
| Task generation failure | Fall back to basic template, allow manual entry |
| Codebase reference failure | Continue without, use standard complexity estimates |
| File creation conflict | Prompt overwrite, backup existing tasks.md |

## File Creation
Use the native Write tool for creating the tasks.md file with proper formatting and structure.