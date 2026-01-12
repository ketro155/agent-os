---
name: subtask-expansion
description: Generate TDD-structured subtasks for a parent task based on complexity analysis. Invoke when a task needs subtask breakdown during execute-tasks workflow.
version: 1.0.0
---

# Subtask Expansion Skill

Generate TDD-structured subtasks for parent tasks based on complexity analysis. This skill centralizes subtask generation logic previously embedded in phase1-discovery Step 1.7.

## When to Use

- During `/execute-tasks` when a task has `needs_subtask_expansion: true`
- When phase1-discovery encounters tasks without subtasks
- When expanding future_tasks promoted to regular tasks

## Input Format

You receive task context:

```json
{
  "task": {
    "id": "5",
    "description": "Implement user authentication with JWT tokens",
    "file_context": "src/auth/",
    "source": "pr_feedback|backlog|spec"
  },
  "complexity_override": "LOW|MEDIUM|HIGH|null",
  "spec_context": "Optional spec summary for additional context"
}
```

## Complexity Analysis

### Step 1: Check for Override

```javascript
if (input.complexity_override) {
  complexity = input.complexity_override;
  reasoning = "Using explicit complexity_override from task definition";
} else {
  complexity = analyzeKeywords(task.description);
}
```

### Step 2: Keyword-Based Analysis (if no override)

Analyze the task description for complexity signals:

| Complexity | Keywords | Subtask Count |
|------------|----------|---------------|
| **LOW** | fix, add, update, remove, rename, tweak, adjust | 3 subtasks |
| **MEDIUM** | implement, create, extend, integrate, build, develop | 4 subtasks |
| **HIGH** | refactor, redesign, migrate, overhaul, architect, rewrite | 5 subtasks |

**Analysis Logic:**

```javascript
const COMPLEXITY_KEYWORDS = {
  LOW: ["fix", "add", "update", "remove", "rename", "tweak", "adjust", "correct", "minor"],
  MEDIUM: ["implement", "create", "extend", "integrate", "build", "develop", "enhance"],
  HIGH: ["refactor", "redesign", "migrate", "overhaul", "architect", "rewrite", "restructure"]
};

function analyzeKeywords(description) {
  const descLower = description.toLowerCase();
  
  // Check HIGH first (takes precedence)
  for (const keyword of COMPLEXITY_KEYWORDS.HIGH) {
    if (descLower.includes(keyword)) {
      return "HIGH";
    }
  }
  
  // Check MEDIUM next
  for (const keyword of COMPLEXITY_KEYWORDS.MEDIUM) {
    if (descLower.includes(keyword)) {
      return "MEDIUM";
    }
  }
  
  // Default to LOW for simple tasks
  return "LOW";
}
```

### Step 3: Additional Complexity Factors

Adjust complexity upward if:

- **Multiple files mentioned** (+1 level if 3+ files)
- **Integration keywords** present ("API", "database", "external")
- **Test requirements** explicit ("with tests", "full coverage")

```javascript
function adjustComplexity(baseComplexity, task) {
  let adjustment = 0;
  
  // File count adjustment
  const fileMatches = task.description.match(/\b\w+\.(ts|js|tsx|jsx|md)\b/g) || [];
  if (fileMatches.length >= 3) adjustment++;
  
  // Integration adjustment
  const integrationKeywords = ["api", "database", "external", "third-party"];
  if (integrationKeywords.some(k => task.description.toLowerCase().includes(k))) {
    adjustment++;
  }
  
  // Apply adjustment (cap at HIGH)
  const levels = ["LOW", "MEDIUM", "HIGH"];
  const currentIndex = levels.indexOf(baseComplexity);
  const newIndex = Math.min(currentIndex + adjustment, 2);
  
  return levels[newIndex];
}
```

## Subtask Generation

### TDD Structure Template

All subtasks follow mandatory TDD structure:

```javascript
function generateSubtasks(task, complexity) {
  const subtaskCount = { LOW: 3, MEDIUM: 4, HIGH: 5 }[complexity];
  const subtasks = [];
  
  // Subtask 1: Always RED phase (write failing tests)
  subtasks.push({
    id: `${task.id}.1`,
    type: "subtask",
    parent: task.id,
    description: `Write failing tests for ${extractFunctionality(task)} (TDD RED)`,
    status: "pending",
    tdd_phase: "red",
    attempts: 0
  });
  
  // Middle subtasks: GREEN phase (implementation)
  const implementationSteps = generateImplementationSteps(task, subtaskCount - 2);
  for (let i = 0; i < implementationSteps.length; i++) {
    subtasks.push({
      id: `${task.id}.${i + 2}`,
      type: "subtask",
      parent: task.id,
      description: `${implementationSteps[i]} (TDD GREEN)`,
      status: "pending",
      tdd_phase: "green",
      attempts: 0
    });
  }
  
  // Last subtask: Always VERIFY phase
  subtasks.push({
    id: `${task.id}.${subtaskCount}`,
    type: "subtask",
    parent: task.id,
    description: "Verify all tests pass and commit",
    status: "pending",
    tdd_phase: "verify",
    attempts: 0
  });
  
  return subtasks;
}
```

### Implementation Step Generation

Based on task type, generate appropriate middle subtasks:

| Task Type | Implementation Steps |
|-----------|---------------------|
| **Feature** | Implement core, Add validation, Handle edge cases |
| **Refactor** | Extract logic, Update callers, Clean up, Update docs |
| **Bugfix** | Identify root cause, Apply fix |
| **Integration** | Set up connection, Implement handlers, Add error handling |

```javascript
function generateImplementationSteps(task, count) {
  const descLower = task.description.toLowerCase();
  
  if (descLower.includes("refactor") || descLower.includes("extract")) {
    return [
      `Extract ${extractFunctionality(task)} logic into separate module`,
      "Update all callers to use new module",
      count > 2 ? "Clean up and remove old code" : null,
      count > 3 ? "Update documentation" : null
    ].filter(Boolean).slice(0, count);
  }
  
  if (descLower.includes("fix") || descLower.includes("bug")) {
    return [
      `Identify and fix root cause of ${extractFunctionality(task)}`,
      count > 1 ? "Add regression prevention" : null
    ].filter(Boolean).slice(0, count);
  }
  
  if (descLower.includes("integrate") || descLower.includes("api")) {
    return [
      `Implement ${extractFunctionality(task)} integration`,
      "Add request/response handling",
      count > 2 ? "Implement error handling and retry logic" : null
    ].filter(Boolean).slice(0, count);
  }
  
  // Default: Feature implementation
  return [
    `Implement core ${extractFunctionality(task)} functionality`,
    count > 1 ? "Add input validation and error handling" : null,
    count > 2 ? "Handle edge cases and boundary conditions" : null
  ].filter(Boolean).slice(0, count);
}

function extractFunctionality(task) {
  // Extract main functionality description from task
  // Remove common prefixes and clean up
  return task.description
    .replace(/^(implement|create|add|fix|refactor|update|build)\s+/i, "")
    .replace(/\s*\(.*\)$/, "")  // Remove parenthetical notes
    .trim();
}
```

## Output Format

Return structured JSON:

```json
{
  "status": "success",
  "task_id": "5",
  "complexity_detected": "MEDIUM",
  "complexity_source": "keyword_analysis|complexity_override|adjusted",
  "reasoning": "Task contains 'implement' keyword suggesting MEDIUM complexity. No override provided.",
  "subtasks": [
    {
      "id": "5.1",
      "type": "subtask",
      "parent": "5",
      "description": "Write failing tests for user authentication with JWT tokens (TDD RED)",
      "status": "pending",
      "tdd_phase": "red",
      "attempts": 0
    },
    {
      "id": "5.2",
      "type": "subtask",
      "parent": "5",
      "description": "Implement core user authentication with JWT tokens functionality (TDD GREEN)",
      "status": "pending",
      "tdd_phase": "green",
      "attempts": 0
    },
    {
      "id": "5.3",
      "type": "subtask",
      "parent": "5",
      "description": "Add input validation and error handling (TDD GREEN)",
      "status": "pending",
      "tdd_phase": "green",
      "attempts": 0
    },
    {
      "id": "5.4",
      "type": "subtask",
      "parent": "5",
      "description": "Verify all tests pass and commit",
      "status": "pending",
      "tdd_phase": "verify",
      "attempts": 0
    }
  ],
  "parent_task_updates": {
    "subtasks": ["5.1", "5.2", "5.3", "5.4"],
    "type": "parent",
    "needs_subtask_expansion": null
  }
}
```

## Error Handling

```javascript
if (!task.id || !task.description) {
  return {
    status: "error",
    error: "INVALID_INPUT",
    message: "Task must have id and description fields"
  };
}

if (complexity_override && !["LOW", "MEDIUM", "HIGH"].includes(complexity_override)) {
  return {
    status: "error",
    error: "INVALID_COMPLEXITY_OVERRIDE",
    message: `complexity_override must be LOW, MEDIUM, or HIGH. Got: ${complexity_override}`
  };
}
```

## Integration with phase1-discovery

This skill is invoked from phase1-discovery Step 1.7:

```javascript
// In phase1-discovery Step 1.7
for (const task of tasksNeedingExpansion) {
  const expansionResult = await Skill({
    skill: "subtask-expansion",
    args: JSON.stringify({
      task: task,
      complexity_override: task.complexity_override || null,
      spec_context: specSummary
    })
  });
  
  if (expansionResult.status === "success") {
    // Update tasks.json with new subtasks
    await updateTasksJson(task.id, expansionResult);
  }
}
```

## Changelog

### v1.0.0 (2026-01-09)
- Initial extraction from phase1-discovery Step 1.7
- Centralized complexity heuristics
- TDD-structured subtask templates
- Support for complexity_override field
