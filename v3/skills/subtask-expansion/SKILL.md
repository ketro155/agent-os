---
name: subtask-expansion
description: Breaks large tasks into smaller, testable subtasks following TDD structure (RED-GREEN-VERIFY) based on complexity analysis. Use during /execute-tasks when a task has needs_subtask_expansion, when phase1-discovery encounters tasks without subtasks, or when a task feels too big to implement in one pass. Use when user says "expand task", "generate subtasks", "break down task", "subtask expansion", "this task is too big", or "split this into smaller pieces". NOT for comparing implementation approaches (use /brainstorming).
version: 1.2.0
metadata:
  author: Agent OS
  category: workflow-automation
---

# Subtask Expansion Skill

Break large tasks into smaller, testable subtasks using TDD structure. This skill centralizes subtask generation logic previously embedded in phase1-discovery Step 1.7.

## When to Use

- During `/execute-tasks` when a task has `needs_subtask_expansion: true`
- When phase1-discovery encounters tasks without subtasks
- When expanding future_tasks promoted to regular tasks

## Input Format

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

### Priority Order

1. **`complexity_override`** (explicit in task definition) — always wins
2. **LLM contextual judgment** — if scope clearly exceeds what keywords suggest, override the heuristic. Set `complexity_source: "llm_judgment"` with a `reasoning` field.
3. **Keyword analysis** — fallback heuristic

### Keyword Heuristic

| Complexity | Keywords | Subtask Count |
|------------|----------|---------------|
| **LOW** | fix, add, update, remove, rename, tweak, adjust | 3 subtasks |
| **MEDIUM** | implement, create, extend, integrate, build, develop | 4 subtasks |
| **HIGH** | refactor, redesign, migrate, overhaul, architect, rewrite | 5 subtasks |

Check HIGH keywords first (they take precedence). Default to LOW if no keywords match.

### Adjustment Factors

Adjust complexity upward if:
- **Multiple files mentioned** (+1 level if 3+ files referenced)
- **Integration keywords** present ("API", "database", "external")
- **Test requirements** explicit ("with tests", "full coverage")

For the full analysis and generation algorithms, see `references/expansion-logic.md`.

## TDD Subtask Structure

All expansions follow this mandatory pattern:

| Position | Phase | Description |
|----------|-------|-------------|
| First | RED | Write failing tests for the task's functionality |
| Middle (1-3) | GREEN | Implementation steps (varies by task type) |
| Last | VERIFY | Verify all tests pass and commit |

### Implementation Steps by Task Type

| Task Type | Typical GREEN Steps |
|-----------|-------------------|
| **Feature** | Implement core, Add validation, Handle edge cases |
| **Refactor** | Extract logic, Update callers, Clean up, Update docs |
| **Bugfix** | Identify root cause, Apply fix |
| **Integration** | Set up connection, Implement handlers, Add error handling |

## Output Format

```json
{
  "status": "success",
  "task_id": "5",
  "complexity_detected": "MEDIUM",
  "complexity_source": "keyword_analysis|complexity_override|llm_judgment|adjusted",
  "reasoning": "Task contains 'implement' keyword suggesting MEDIUM complexity.",
  "subtasks": [
    { "id": "5.1", "type": "subtask", "parent": "5", "description": "Write failing tests for ... (TDD RED)", "status": "pending", "tdd_phase": "red", "attempts": 0 },
    { "id": "5.2", "type": "subtask", "parent": "5", "description": "Implement core ... (TDD GREEN)", "status": "pending", "tdd_phase": "green", "attempts": 0 },
    { "id": "5.3", "type": "subtask", "parent": "5", "description": "Add validation ... (TDD GREEN)", "status": "pending", "tdd_phase": "green", "attempts": 0 },
    { "id": "5.4", "type": "subtask", "parent": "5", "description": "Verify all tests pass and commit", "status": "pending", "tdd_phase": "verify", "attempts": 0 }
  ],
  "parent_task_updates": {
    "subtasks": ["5.1", "5.2", "5.3", "5.4"],
    "type": "parent",
    "needs_subtask_expansion": null
  }
}
```

## Error Handling

- Missing `task.id` or `task.description` → return `INVALID_INPUT` error
- Invalid `complexity_override` value → return `INVALID_COMPLEXITY_OVERRIDE` error

## Changelog

### v1.2.0 (2026-03-06)
- Extracted implementation logic to references/expansion-logic.md for context efficiency
- Improved description for broader user-facing triggering
- Added negative trigger for brainstorming disambiguation
- Reduced SKILL.md from 350 to ~110 lines

### v1.1.0 (2026-02-09)
- Added LLM override guidance for complexity determination
- Added additional complexity factors (file count, integration keywords)

### v1.0.0 (2026-01-09)
- Initial extraction from phase1-discovery Step 1.7
- Centralized complexity heuristics
- TDD-structured subtask templates
- Support for complexity_override field
