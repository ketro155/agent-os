---
paths:
  - ".agent-os/tasks/**"
  - ".agent-os/specs/**"
---

# Execute Tasks Rules

## Task Execution Principles

### Single-Task Focus (Research-Backed)

When executing tasks:

1. **Default to single task** - Anthropic research shows single-task focus has higher completion rates
2. **Multi-task requires explicit choice** - User must confirm parallel or sequential execution
3. **Each task gets fresh context** - Subagents start clean to prevent quality degradation

### Mandatory TDD

Every implementation must follow TDD:

1. **Write failing test first** - No exceptions
2. **Run test to verify it fails** - Show the failure
3. **Implement minimal code** - Only what's needed to pass
4. **Run test to verify pass** - Show the success
5. **Refactor if needed** - Keep tests green

### Validation Gates (Cannot Skip)

PreToolUse hooks enforce:

- Build must pass before commit
- Tests must pass before commit
- Types must check before commit
- In-progress tasks must be resolved

These are **deterministic** - hooks always run regardless of model behavior.

## Task Status Transitions

```
pending → in_progress → pass
                    ↘ blocked (with blocker description)
```

### When to Mark Status

- `in_progress`: When starting work on task
- `pass`: When all subtasks complete AND tests pass
- `blocked`: When cannot proceed (missing dependency, unresolvable error)

## Artifact Collection

After completing a task, collect:

```json
{
  "files_created": ["src/auth/login.ts"],
  "files_modified": ["src/auth/index.ts"],
  "exports_added": ["login", "LoginError"],
  "functions_created": ["login", "validateCredentials"],
  "test_files": ["tests/auth/login.test.ts"]
}
```

Artifacts are used by subsequent tasks to verify dependencies.

## Background Commands

For long-running operations:

```javascript
// Run tests in background
Bash({
  command: "npm test",
  run_in_background: true
})

// Check output later
BashOutput({ bash_id: "...", filter: "PASS|FAIL" })
```

Use for:
- Full test suite (> 30 seconds)
- Build processes
- Dev server startup

## Progress Logging

Log these events:

| Event | When |
|-------|------|
| `session_started` | SessionStart hook (automatic) |
| `task_completed` | After each parent task passes |
| `task_blocked` | When blocker encountered |
| `session_ended` | SessionEnd hook (automatic) |

## Micro-Todo Pattern

For visibility during implementation:

```javascript
TodoWrite([
  { content: "Write test for login endpoint", status: "in_progress", activeForm: "Writing login test" },
  { content: "Implement login handler", status: "pending", activeForm: "Implementing handler" },
  { content: "Add input validation", status: "pending", activeForm: "Adding validation" },
  { content: "Run full test suite", status: "pending", activeForm: "Running tests" }
])
```

Update after each step completes.

## Checkpoint/Recovery

If session interrupted:

1. SessionEnd hook saves checkpoint
2. Next session: SessionStart hook loads context
3. Progress log shows where you left off
4. Resume from last successful step

Native Claude Code checkpointing (`Esc+Esc`) also available for quick rewind.
