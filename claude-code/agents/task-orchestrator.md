# Task Orchestrator Subagent

A lightweight orchestrator that manages task execution with minimal context footprint. Based on Anthropic's research on "Effective Harnesses for Long-Running Agents".

---

## Purpose

The orchestrator maintains minimal state while delegating implementation work to worker agents. This prevents context bloat by:
1. Starting each worker with fresh context
2. Passing only task-specific information
3. Receiving structured completion reports
4. Managing cross-task coordination

---

## When to Use

This subagent should be invoked via Task tool when:
- Executing multi-task workflows (execute-tasks command)
- Context window is at risk of filling up
- Tasks are independent enough to parallelize
- Session needs to span many tasks

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     TASK ORCHESTRATOR                            │
│  (Lightweight - minimal state, delegates implementation)         │
├─────────────────────────────────────────────────────────────────┤
│  State Held:                                                     │
│  • tasks.json reference (not full content)                       │
│  • Current task ID                                               │
│  • Worker completion status                                      │
│  • Test results summary (pass/fail count)                        │
│                                                                  │
│  Does NOT Hold:                                                  │
│  • Spec content                                                  │
│  • Code context                                                  │
│  • Implementation details                                        │
│  • Full codebase references                                      │
└─────────────────────────────────────────────────────────────────┘
           │
           │ Spawns with task-specific context
           ▼
┌─────────────────────────────────────────────────────────────────┐
│                      TASK WORKER                                 │
│  (Full implementation context for ONE task, then terminates)     │
├─────────────────────────────────────────────────────────────────┤
│  Receives (via prompt):                                          │
│  • Single task from tasks.json                                   │
│  • Pre-computed context summary for this task                    │
│  • Relevant codebase references (filtered)                       │
│  • Standards relevant to task type                               │
│                                                                  │
│  Returns (structured):                                           │
│  • Completion status (pass/fail/blocked)                         │
│  • Files modified                                                │
│  • Test results                                                  │
│  • Blocker description (if any)                                  │
│  • Duration estimate                                             │
└─────────────────────────────────────────────────────────────────┘
```

---

## Orchestrator Protocol

### Phase 1: Initialization

```
INPUT: spec_folder_path, tasks_to_execute (optional)

1. LOAD tasks.json from spec folder
   - Extract task list and summary
   - Do NOT load full spec content

2. READ context-summary.json for task context
   - Pre-computed summaries per task
   - Filtered codebase references

3. DETERMINE execution plan
   - Single task mode (default, recommended)
   - Multi-task mode (if user override)

4. LOG session_started to progress log

OUTPUT: Execution plan with task order
```

### Phase 2: Task Execution Loop

```
FOR each task in execution_plan:

  1. PREPARE worker context
     - Extract task from tasks.json
     - Get context summary for task ID
     - Filter codebase refs to relevant files only
     - Bundle into worker prompt

  2. SPAWN worker via Task tool
     REQUEST: Execute single task with provided context
     WORKER_TYPE: task-worker (implementation agent)

  3. WAIT for worker completion
     - Worker returns structured result
     - Do NOT re-process worker's implementation context

  4. PROCESS worker result
     - Update tasks.json status
     - Log task_completed or task_blocked
     - Aggregate test results

  5. VERIFY via tests
     - Run task-specific tests (if not already run by worker)
     - Confirm completion before next task

  6. CHECK for abort conditions
     - Too many blocked tasks
     - Critical test failures
     - User interrupt

  CONTINUE to next task OR terminate
END FOR
```

### Phase 3: Completion

```
1. RUN full test suite (via test-check skill)
   - Only if all tasks completed successfully

2. INVOKE git-workflow subagent
   - Commit changes
   - Create PR

3. LOG session_ended to progress log

4. RETURN summary to user
```

---

## Worker Invocation Template

When spawning a task worker, use this prompt structure:

```markdown
## Task Worker Prompt Template

You are a task worker agent. Execute the following single task and return a structured result.

### Task
- **ID**: {task.id}
- **Description**: {task.description}
- **Subtasks**: {task.subtasks as list}

### Context (Pre-computed)
{context_summary for this task from context-summary.json}

### Codebase References (Filtered)
{Only functions/imports relevant to this task}

### Standards to Follow
{Relevant standards sections only}

### Expected Output Format
Return JSON with:
```json
{
  "status": "pass|fail|blocked",
  "files_modified": ["path/to/file.ts"],
  "files_created": ["path/to/new.ts"],
  "test_results": {
    "ran": 5,
    "passed": 5,
    "failed": 0
  },
  "blocker": null,
  "notes": "Implementation notes",
  "duration_minutes": 15
}
```

### Constraints
- Focus ONLY on this task
- Follow TDD (test first, then implement)
- Commit after subtask completion
- Do NOT work on other tasks
```

---

## Context Budget

The orchestrator aims to stay under 20% of context window capacity:

| Component | Estimated Tokens | Purpose |
|-----------|------------------|---------|
| Orchestrator instructions | ~2,000 | Core protocol |
| tasks.json summary | ~500 | Task list overview |
| context-summary.json pointer | ~200 | Reference to full context |
| Worker results (accumulated) | ~300 per task | Completion tracking |
| **Total for 5 tasks** | ~4,500 | Well under budget |

Workers receive more context (~10,000 tokens) but start fresh each time.

---

## Integration with execute-tasks

The execute-tasks command can use the orchestrator in two modes:

### Mode A: Direct Execution (Current)
```
execute-tasks.md loads all instructions, executes in-place
Pros: Simpler, full context always available
Cons: Context bloat for long sessions
```

### Mode B: Orchestrated Execution (New)
```
execute-tasks.md invokes task-orchestrator subagent
Orchestrator spawns workers for each task
Pros: Fresh context per task, scalable
Cons: More overhead for simple tasks
```

**Selection criteria:**
- 1-2 tasks: Use Mode A (direct)
- 3+ tasks: Use Mode B (orchestrated)
- Context concerns: Always Mode B

---

## Error Handling

| Error | Orchestrator Action |
|-------|---------------------|
| Worker timeout | Retry once, then mark task blocked |
| Worker returns fail | Log blocker, continue to next task |
| Too many failures (3+) | Abort session, save state for resume |
| Test verification fails | Return to worker for fix OR mark blocked |
| Context overflow warning | Force Mode B, spawn fresh worker |

---

## State Management

The orchestrator uses tasks.json for persistent state:

```json
{
  "orchestrator_state": {
    "mode": "orchestrated",
    "current_task_index": 2,
    "workers_spawned": 3,
    "workers_completed": 2,
    "workers_failed": 0,
    "aggregate_results": {
      "tests_passed": 15,
      "tests_failed": 0,
      "files_modified": 8
    }
  }
}
```

This allows resumption if the orchestrator itself needs to restart.

---

## Usage Example

```
ACTION: Invoke task-orchestrator via Task tool
REQUEST: "Orchestrate task execution for spec:
          Spec: .agent-os/specs/auth-feature/
          Mode: orchestrated
          Tasks: all pending (or specific IDs)

          Use context-summary.json for worker context.
          Return aggregated results on completion."
```

---

## Benefits

1. **Prevents Context Bloat**: Workers start fresh
2. **Better Recovery**: Each task independently completable
3. **Parallel Potential**: Independent tasks could run in parallel (future)
4. **Cleaner Separation**: Coordination vs implementation clearly split
5. **Scalable**: Can handle arbitrarily long task lists
