# Execute Tasks (v3.0)

Execute tasks from a specification using native Claude Code features.

## Parameters
- `spec_name` (required): Specification folder name
- `tasks` (optional): Specific task IDs, "all", or "next" (default: "next")

## Quick Start

```bash
# Execute next pending task (recommended)
/execute-tasks auth-feature

# Execute specific tasks
/execute-tasks auth-feature tasks:1,2

# Execute all pending tasks
/execute-tasks auth-feature tasks:all
```

## How It Works

v3.0 uses native Claude Code features instead of embedded instructions:

| v2.x | v3.0 |
|------|------|
| Embedded instructions (475 lines) | Native subagents + memory |
| task-sync skill | PostToolUse hooks |
| Manual phase loading | Automatic subagent invocation |
| Dual-format sync | JSON primary, MD auto-generated |

## Execution Flow

```
SessionStart hook → Load progress context
        ↓
Phase 1 Agent → Task discovery, mode selection
        ↓
[User confirms execution mode]
        ↓
Phase 2 Agent(s) → TDD implementation (parallel if applicable)
        ↓
Phase 3 Agent → Final tests, PR, documentation
        ↓
SessionEnd hook → Log progress, checkpoint
```

## For Claude Code

### Step 1: Get Task Status

```bash
# Check current task status
.claude/scripts/task-operations.sh status auth-feature
```

### Step 2: Invoke Phase 1 Discovery

```javascript
Task({
  subagent_type: "phase1-discovery",
  prompt: `Analyze tasks for spec: ${spec_name}
           Requested tasks: ${tasks}
           Return execution configuration.`
})
```

### Step 3: Confirm Execution Mode (if multi-task)

If Phase 1 returns multiple tasks with parallel capability:

```javascript
AskUserQuestion({
  questions: [{
    question: "How would you like to execute these tasks?",
    header: "Mode",
    options: [
      { label: "Parallel Waves", description: "~1.5x faster for independent tasks" },
      { label: "Single Task", description: "Most reliable, one at a time" }
    ]
  }]
})
```

### Step 4: Execute Tasks

**Single Task Mode:**
```javascript
Task({
  subagent_type: "phase2-implementation",
  prompt: `Execute task: ${task}
           Context: ${context_from_phase1}
           Return structured result with artifacts.`
})
```

**Parallel Wave Mode:**
```javascript
// Spawn parallel workers for wave
for (task of wave.tasks) {
  Task({
    subagent_type: "phase2-implementation",
    run_in_background: true,
    prompt: `Execute task: ${task}...`
  })
}

// Collect results
for (agentId of active_workers) {
  AgentOutputTool({ agentId, block: true })
}
```

### Step 5: Update Task Status

After each task completes:

```bash
# Mark task complete
.claude/scripts/task-operations.sh update "1.2" "pass"

# Add artifacts
.claude/scripts/task-operations.sh artifacts "1.2" '{"files_created":["src/auth/login.ts"],"exports_added":["login"]}'

# Or collect artifacts automatically from git
ARTIFACTS=$(.claude/scripts/task-operations.sh collect-artifacts HEAD~1)
.claude/scripts/task-operations.sh artifacts "1.2" "$ARTIFACTS"
```

### Step 6: Invoke Phase 3 Delivery

After all tasks complete:

```javascript
Task({
  subagent_type: "phase3-delivery",
  prompt: `Complete delivery for spec: ${spec_name}
           Completed tasks: ${completed_tasks}
           Create PR and documentation.`
})
```

## Task Operations (Shell Script)

All task operations use `.claude/scripts/task-operations.sh`:

```bash
# Get status
.claude/scripts/task-operations.sh status [spec_name]

# Update task
.claude/scripts/task-operations.sh update <task_id> <status> [spec_name]

# Add artifacts
.claude/scripts/task-operations.sh artifacts <task_id> <json> [spec_name]

# Collect artifacts from git
.claude/scripts/task-operations.sh collect-artifacts [since_commit]

# Validate names exist
.claude/scripts/task-operations.sh validate-names '["functionName"]'

# Get progress
.claude/scripts/task-operations.sh progress [count] [type]

# Log progress
.claude/scripts/task-operations.sh log-progress <type> <description>
```

## Hooks (Automatic)

These run without explicit invocation:

- **SessionStart**: Loads progress, validates environment
- **PreToolUse (git commit)**: Validates build, tests, types
- **PostToolUse (Write/Edit)**: Regenerates tasks.md from JSON
- **SessionEnd**: Logs session summary, creates checkpoint

## Extended Thinking

For complex tasks, extended thinking is automatically available. The implementation agent will use deeper reasoning for:

- Architectural decisions
- Complex debugging
- Trade-off analysis

## Error Handling

### Task Blocked
```
Phase 2 returns: { status: "blocked", blocker: "..." }
→ Log to progress
→ Offer: Skip task / Attempt fix / Stop execution
```

### Tests Failing
```
PreToolUse hook blocks commit
→ Must fix before proceeding
→ Cannot be bypassed
```

### All Tasks Complete
```
Phase 1 returns: { tasks_to_execute: [] }
→ Inform user all tasks done
→ Suggest: Create new spec or review PR
```

## Comparison: v2.x vs v3.0

| Aspect | v2.x | v3.0 |
|--------|------|------|
| Command size | 475 lines | ~120 lines |
| Phase loading | Manual Read tool | Native subagents |
| Validation | Skills (can be skipped) | Hooks (mandatory) |
| Task sync | task-sync skill | PostToolUse hook |
| Task format | MD + JSON (sync issues) | JSON primary |
| Operations | Inline code | Shell script |
| Recovery | Custom patterns | Native checkpointing |

## Dependencies

**Required:**
- `.agent-os/tasks/[spec]/tasks.json` (v3.0 format)
- `.claude/agents/phase*.md` (native subagents)
- `.claude/hooks/*` (validation hooks)
- `.claude/scripts/task-operations.sh` (task management)

**No MCP server required** - all operations use native Bash tool with shell scripts.
