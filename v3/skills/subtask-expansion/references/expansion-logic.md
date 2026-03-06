# Subtask Expansion Logic Reference

> Implementation pseudocode for complexity analysis and subtask generation.
> Read this when you need the detailed algorithm or want to understand the generation logic.

## Keyword Analysis Function

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

## Complexity Adjustment Function

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

## Subtask Generation Function

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

## Implementation Step Generation

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
  return task.description
    .replace(/^(implement|create|add|fix|refactor|update|build)\s+/i, "")
    .replace(/\s*\(.*\)$/, "")
    .trim();
}
```

## Integration with phase1-discovery

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
    await updateTasksJson(task.id, expansionResult);
  }
}
```
