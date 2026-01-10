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
  "version": "3.0",
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
  "version": "3.0",
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

### Step 1.7: Analyze Subtask Parallelization (NEW v4.2)

After parent-level parallelization, analyze subtasks for intra-task parallelization opportunities.

**Purpose:** Enable parallel execution of independent subtask groups within a parent task.

**Activation Threshold:**
- Parent task has 4+ subtasks
- All subtask groups have 0.9+ isolation score
- No shared file conflicts between groups

**Instructions:**
```
ACTION: Analyze subtask dependencies for parallel execution
FOR each parent task with 4+ subtasks:

  1. GROUP subtasks by TDD unit:
     PATTERN detection:
       - NEW GROUP starts at: "Write test", "Create test file", "Add tests for"
       - GROUP continues with: "Implement", "Add implementation", "Verify", "Commit"

     RESULT: Each group = complete RED→GREEN→VERIFY cycle
     Example:
       Group 1: ["1.1 Write test for login", "1.2 Implement login", "1.3 Verify login"]
       Group 2: ["1.4 Write test for logout", "1.5 Implement logout", "1.6 Verify logout"]

  2. EXTRACT files per group:
     FOR each group:
       PARSE subtask descriptions for file paths
       REFERENCE technical-spec.md for file mappings
       ADD to group.files_affected

  3. CALCULATE isolation score per group pair:
     FOR each (groupA, groupB) pair:
       shared_files = INTERSECTION(groupA.files_affected, groupB.files_affected)
       IF shared_files.length == 0:
         isolation = 1.0  # Fully independent
       ELSE:
         isolation = 1.0 - (shared_files.length / MAX(groupA.files, groupB.files))

       STORE: isolation_matrix[groupA][groupB] = isolation

  4. BUILD group waves:
     min_isolation = 0.9  # Conservative threshold

     IF ALL group pairs have isolation >= min_isolation:
       mode = "parallel_groups"
       Wave 1 = all groups (can run in parallel)
     ELSE:
       # Some groups conflict - build dependency chain
       FOR each group with conflicts:
         blocked_by = groups with shared files
       GENERATE waves based on blocked_by graph

     IF only 1 group OR all groups conflict:
       mode = "sequential"  # Fall back to current behavior

  5. ADD subtask_execution to parent task:
     IF mode == "parallel_groups":
       ADD to tasks.json parent task:
         "subtask_execution": {
           "mode": "parallel_groups",
           "groups": [...],
           "group_waves": [...],
           "isolation_threshold": 0.9
         }
```

**Output Format (added to parent task in tasks.json):**
```json
{
  "id": "1",
  "type": "parent",
  "subtasks": ["1.1", "1.2", "1.3", "1.4", "1.5", "1.6"],
  "subtask_execution": {
    "mode": "parallel_groups",
    "groups": [
      {
        "group_id": 1,
        "subtasks": ["1.1", "1.2", "1.3"],
        "files_affected": ["src/auth/login.ts", "tests/auth/login.test.ts"],
        "tdd_unit": "Login endpoint"
      },
      {
        "group_id": 2,
        "subtasks": ["1.4", "1.5", "1.6"],
        "files_affected": ["src/auth/logout.ts", "tests/auth/logout.test.ts"],
        "tdd_unit": "Logout endpoint"
      }
    ],
    "group_waves": [
      { "wave_id": 1, "groups": [1, 2], "rationale": "No file conflicts, isolation >= 0.9" }
    ],
    "isolation_threshold": 0.9
  }
}
```

**Expected Speedup:**
| Scenario | Sequential | Parallel Groups | Speedup |
|----------|------------|-----------------|---------|
| 2 independent groups (3 subtasks each) | 6 subtasks serial | 3 subtasks per worker | ~1.7x |
| 3 independent groups | 9 subtasks serial | 3 subtasks per worker | ~2.5x |
| All groups dependent | N subtasks | N subtasks | 1x (no change) |

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
---

## SECTION: Complexity Analysis (v4.9.0)

### Step 0.5: Analyze Task Complexity

Before generating subtasks, analyze each task for complexity and set `complexity_override` field.

**Complexity Analysis Function:**

```javascript
const analyzeComplexity = async (task, techSpec, codebaseRefs) => {
  // Base complexity from keywords
  const baseComplexity = detectKeywordComplexity(task.description);
  
  // Factor 1: File count from technical spec
  const filesAffected = extractFilesAffected(techSpec, task.description);
  const fileCountFactor = filesAffected.length >= 5 ? 2 : filesAffected.length >= 3 ? 1 : 0;
  
  // Factor 2: Import dependencies
  const importCount = await countImportsNeeded(task, codebaseRefs);
  const importFactor = importCount >= 5 ? 1 : 0;
  
  // Factor 3: Test requirements
  const testRequirements = detectTestRequirements(task.description, techSpec);
  const testFactor = testRequirements.includes('integration') || testRequirements.includes('e2e') ? 1 : 0;
  
  // Calculate final complexity
  const complexityScore = baseComplexity + fileCountFactor + importFactor + testFactor;
  
  return {
    complexity: scoreToLevel(complexityScore),
    reasoning: `Base: ${baseComplexity}, Files: +${fileCountFactor}, Imports: +${importFactor}, Tests: +${testFactor}`,
    filesAffected,
    importCount,
    testRequirements
  };
};

const detectKeywordComplexity = (description) => {
  const descLower = description.toLowerCase();
  
  const HIGH_KEYWORDS = ['refactor', 'redesign', 'migrate', 'overhaul', 'architect', 'rewrite'];
  const MEDIUM_KEYWORDS = ['implement', 'create', 'extend', 'integrate', 'build'];
  const LOW_KEYWORDS = ['fix', 'add', 'update', 'remove', 'rename', 'tweak'];
  
  if (HIGH_KEYWORDS.some(k => descLower.includes(k))) return 3;
  if (MEDIUM_KEYWORDS.some(k => descLower.includes(k))) return 2;
  return 1;
};

const scoreToLevel = (score) => {
  if (score >= 5) return 'HIGH';
  if (score >= 3) return 'MEDIUM';
  return 'LOW';
};
```

**Apply to Tasks:**

```javascript
FOR each task in generated_tasks:
  complexity = await analyzeComplexity(task, technicalSpec, codebaseRefs)
  
  task.complexity_override = complexity.complexity
  task.complexity_reasoning = complexity.reasoning
  
  LOG: `Task ${task.id}: ${complexity.complexity} - ${complexity.reasoning}`
```

### Task Template Selection

When generating tasks, select appropriate templates from `.claude/templates/tasks/`:

```javascript
const selectTaskTemplate = (task, specType) => {
  const descLower = task.description.toLowerCase();
  
  // Pattern matching for template selection
  if (descLower.includes('endpoint') || descLower.includes('api') || descLower.includes('route')) {
    return loadTemplate('api-endpoint.json');
  }
  
  if (descLower.includes('component') || descLower.includes('ui') || descLower.includes('react')) {
    return loadTemplate('react-component.json');
  }
  
  if (descLower.includes('fix') || descLower.includes('bug') || descLower.includes('error')) {
    return loadTemplate('bugfix.json');
  }
  
  if (descLower.includes('refactor') || descLower.includes('extract') || descLower.includes('restructure')) {
    return loadTemplate('refactor.json');
  }
  
  // Default: Use spec-type based template or generic
  return null; // Use inline generation
};

const loadTemplate = (templateName) => {
  const templatePath = `.claude/templates/tasks/${templateName}`;
  IF file exists templatePath:
    RETURN JSON.parse(readFile(templatePath))
  ELSE:
    RETURN null
};
```

---

## SECTION: Spec Validation Gate (v4.9.0)

### Step 0: Validate Spec Completeness

Before generating tasks, validate the spec has required sections.

**Validation Function:**

```javascript
const validateSpec = async (specContent) => {
  const errors = [];
  const warnings = [];
  
  // Required sections
  const REQUIRED_SECTIONS = [
    { pattern: /##\s*Overview/i, name: 'Overview' },
    { pattern: /##\s*User Stories/i, name: 'User Stories' },
    { pattern: /##\s*Expected Deliverable/i, name: 'Expected Deliverable' }
  ];
  
  for (const section of REQUIRED_SECTIONS) {
    if (!section.pattern.test(specContent)) {
      errors.push(`Missing required section: ${section.name}`);
    }
  }
  
  // Recommended sections (warnings only)
  const RECOMMENDED_SECTIONS = [
    { pattern: /##\s*Spec Scope/i, name: 'Spec Scope' },
    { pattern: /##\s*Out of Scope/i, name: 'Out of Scope' },
    { pattern: /##\s*Technical/i, name: 'Technical Requirements' }
  ];
  
  for (const section of RECOMMENDED_SECTIONS) {
    if (!section.pattern.test(specContent)) {
      warnings.push(`Recommended section missing: ${section.name}`);
    }
  }
  
  // Content quality checks
  const userStoryMatch = specContent.match(/##\s*User Stories[\s\S]*?(?=##|$)/i);
  if (userStoryMatch) {
    const storyCount = (userStoryMatch[0].match(/###\s*Story/gi) || []).length;
    if (storyCount === 0) {
      warnings.push('No user stories found in User Stories section');
    }
  }
  
  return {
    valid: errors.length === 0,
    errors,
    warnings,
    canProceed: errors.length === 0  // Warnings don't block
  };
};
```

**Validation Gate:**

```javascript
// At start of create-tasks execution
const specContent = await readFile(specPath);
const validation = await validateSpec(specContent);

IF !validation.valid:
  DISPLAY: "Spec validation failed:"
  FOR error in validation.errors:
    DISPLAY: "  - " + error
  
  PROMPT: "Spec is incomplete. Options:
    1. Continue anyway (not recommended)
    2. Return to edit spec
    3. Show what's missing"
  
  IF user_chooses_continue:
    LOG: "Proceeding with incomplete spec (user override)"
  ELSE:
    HALT: Return to spec editing
ELSE:
  IF validation.warnings.length > 0:
    DISPLAY: "Spec validation passed with warnings:"
    FOR warning in validation.warnings:
      DISPLAY: "  ⚠ " + warning
```

---

## Changelog

### v4.9.0 (2026-01-09)
- Added complexity analysis with multi-factor scoring
- Added task template selection from `.claude/templates/tasks/`
- Added spec validation gate with required/recommended sections
- Added `complexity_override` field generation for tasks
