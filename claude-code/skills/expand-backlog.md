---
name: expand-backlog
description: "Expand WAVE_TASK backlog items into proper parent/subtask structure. Auto-invoked by phase1-discovery when WAVE_TASK items need processing. Uses writing-plans patterns to generate detailed subtasks."
allowed-tools: Read, Grep, Glob, Write, Bash
---

# Expand Backlog Skill

Automatically expand WAVE_TASK items from future_tasks into proper parent + subtask structure for execution.

**Core Principle:** WAVE_TASK items contain enough context (description, file_context, rationale) to generate proper implementation tasks.

## When This Skill is Invoked

Claude should invoke this skill:
- **During phase1-discovery** when WAVE_TASK items are found in future_tasks
- **After graduate-all** returns remaining WAVE_TASK items
- **When user asks to process backlog items**

## Input Format

You receive a list of WAVE_TASK items:

```json
{
  "spec_folder": ".agent-os/specs/feature-name/",
  "wave_tasks": [
    {
      "id": "F1",
      "description": "Implement parallel batch processing",
      "file_context": "src/workers/batch-processor.ts",
      "rationale": "Current sequential processing is slow for large batches",
      "future_type": "WAVE_TASK"
    }
  ],
  "target_wave": 8
}
```

## Expansion Protocol

### Phase 1: Analyze Each WAVE_TASK

For each WAVE_TASK item:

```
READ: file_context to understand current code structure
IDENTIFY:
  - What exists in the file already
  - Integration points
  - Test patterns in use
  - Related files

EXTRACT from description:
  - Core functionality to add
  - Scope boundaries
  - Implicit requirements
```

### Phase 2: Generate Subtasks (writing-plans pattern)

Apply writing-plans skill patterns:

```
FOR each WAVE_TASK:
  1. BREAK DOWN into 3-5 subtasks (2-5 min each)

  2. FOLLOW TDD structure:
     - First subtask: Write failing tests
     - Middle subtasks: Implementation
     - Last subtask: Verify all tests pass

  3. INCLUDE for each subtask:
     - Exact file paths
     - What to add/modify
     - Expected outcome
```

**Subtask Template:**

```markdown
### [N].1 Write tests for [FUNCTIONALITY]
- File: `[test-file-path]`
- Add: Test cases for [specific behaviors]
- Verify: Tests fail (RED phase)

### [N].2 Implement [FUNCTIONALITY]
- File: `[source-file-path]`
- Add: [specific implementation]
- Pattern: Follow existing [pattern name] convention

### [N].3 Verify implementation
- Run: `npm test -- --grep "[test pattern]"`
- Expected: All tests pass
- Commit: Changes with descriptive message
```

### Phase 3: Create Task Structure

Generate JSON structure for each expanded task:

```json
{
  "id": "[WAVE]",
  "type": "parent",
  "description": "[FROM_WAVE_TASK_DESCRIPTION]",
  "status": "pending",
  "priority": "wave_[WAVE]",
  "wave": [WAVE],
  "expanded_from": "F1",
  "subtasks": ["[WAVE].1", "[WAVE].2", "[WAVE].3"],
  "progress_percent": 0,
  "file_context": "[FROM_WAVE_TASK]",
  "created_at": "[TIMESTAMP]"
}
```

And for each subtask:

```json
{
  "id": "[WAVE].[N]",
  "type": "subtask",
  "parent": "[WAVE]",
  "description": "[SUBTASK_DESCRIPTION]",
  "status": "pending",
  "attempts": 0,
  "file_path": "[EXACT_FILE_PATH]",
  "tdd_phase": "red|green|verify"
}
```

### Phase 4: Update tasks.json

Use the add-expanded-task command:

```bash
bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/task-operations.sh" add-expanded-task '<tasks_json>' [spec-name]
```

Where `<tasks_json>` is:

```json
{
  "future_id": "F1",
  "parent_task": { ... },
  "subtasks": [ ... ]
}
```

### Phase 5: Report Results

Return expansion summary:

```json
{
  "expanded": [
    {
      "from": "F1",
      "to_parent": "8",
      "subtasks_created": 3,
      "description": "Implement parallel batch processing"
    }
  ],
  "target_wave": 8,
  "total_subtasks_added": 3,
  "message": "Expanded 1 WAVE_TASK item into wave 8"
}
```

## Task Sizing Guidelines

| Size | Duration | Example |
|------|----------|---------|
| Too Small | < 1 min | "Add import statement" |
| Ideal | 2-5 min | "Add validation function with tests" |
| Too Large | > 10 min | "Implement full feature" |

**If original WAVE_TASK > 10 min work:** Break into multiple subtasks
**If < 3 min total:** Combine into single subtask + test

## TDD Structure Requirements

Every expansion MUST follow TDD structure:

```
[N].1 - Write failing tests (RED)
[N].2+ - Implement (GREEN)
[N].last - Verify all pass + commit
```

## Integration with Phase 1 Discovery

When phase1-discovery finds WAVE_TASK items:

1. Calls `determine-next-wave` to get target wave
2. Invokes this skill with WAVE_TASK list
3. Skill expands each item and writes to tasks.json
4. Returns to discovery with updated task list

## Error Handling

### Cannot Read file_context

```
IF file_context doesn't exist:
  - Generate generic subtasks based on description
  - Add "create file" as first subtask
  - Note: "New file - no existing patterns to follow"
```

### Ambiguous Description

```
IF description is too vague:
  - Generate high-level subtasks
  - Mark first subtask as "Clarify requirements"
  - Add TODO comment for refinement
```

### Complex Item (> 8 subtasks)

```
IF estimated subtasks > 8:
  - Split into multiple parent tasks
  - Create [N]a, [N]b parent tasks
  - Distribute subtasks across parents
```

## Example Expansion

**Input WAVE_TASK:**
```json
{
  "id": "F6",
  "description": "Add retry logic for failed API calls",
  "file_context": "src/api/client.ts",
  "rationale": "Network errors cause complete batch failures"
}
```

**Output Tasks:**

```json
{
  "parent_task": {
    "id": "8",
    "type": "parent",
    "description": "Add retry logic for failed API calls",
    "status": "pending",
    "wave": 8,
    "expanded_from": "F6",
    "subtasks": ["8.1", "8.2", "8.3", "8.4"]
  },
  "subtasks": [
    {
      "id": "8.1",
      "type": "subtask",
      "parent": "8",
      "description": "Write tests for retry behavior (TDD RED)",
      "file_path": "src/api/__tests__/client.test.ts",
      "tdd_phase": "red"
    },
    {
      "id": "8.2",
      "type": "subtask",
      "parent": "8",
      "description": "Implement exponential backoff retry wrapper",
      "file_path": "src/api/client.ts",
      "tdd_phase": "green"
    },
    {
      "id": "8.3",
      "type": "subtask",
      "parent": "8",
      "description": "Integrate retry wrapper into API methods",
      "file_path": "src/api/client.ts",
      "tdd_phase": "green"
    },
    {
      "id": "8.4",
      "type": "subtask",
      "parent": "8",
      "description": "Verify all tests pass and commit",
      "file_path": null,
      "tdd_phase": "verify"
    }
  ]
}
```
