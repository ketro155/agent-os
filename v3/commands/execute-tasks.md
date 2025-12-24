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
Step 0 → Auto-promote future_tasks to current wave (MANDATORY)
        ↓
Phase 1 Agent → Task discovery, mode selection, branch validation
        ↓
[User confirms execution mode]
        ↓
Phase 2 Agent(s) → TDD implementation
        │
        ├── Single Task: One agent
        └── Parallel Waves: Multiple agents per wave, waves in sequence
        ↓
[Completion Gate] → Verify all agents collected, all tasks updated
        ↓
Phase 3 Agent → Final tests, PR, documentation  ⚠️ MANDATORY
        ↓
SessionEnd hook → Log progress, checkpoint
```

> **CRITICAL**: Phase 3 MUST always run. It creates the PR. Never skip.

## For Claude Code

### Step 0: Auto-Promote Future Tasks (MANDATORY)

> ⚠️ **MUST RUN BEFORE PHASE 1** - This step promotes backlog items from PR reviews into the current wave.

```bash
# 1. Get the next wave number to execute
SPEC_NAME="[spec_name]"
NEXT_WAVE=$(bash .claude/scripts/task-operations.sh status "$SPEC_NAME" | jq -r '
  .next_task.wave //
  (.tasks | map(select(.status == "pending")) | first | .wave) //
  empty
')

# 2. Check for future tasks tagged for this wave
FUTURE_COUNT=$(bash .claude/scripts/task-operations.sh list-future "$SPEC_NAME" | jq -r --arg w "wave_$NEXT_WAVE" '
  [.future_tasks[] | select(.priority == $w)] | length
')

# 3. If there are future tasks, promote them
if [ "$FUTURE_COUNT" -gt 0 ]; then
  echo "🔄 Auto-promoting $FUTURE_COUNT future tasks to wave $NEXT_WAVE..."
  bash .claude/scripts/task-operations.sh promote-wave "$NEXT_WAVE" "$SPEC_NAME"
fi
```

**Why this step exists:**
- PR review captures deferred items to `future_tasks` with `priority: "wave_5"`
- This step ensures those items become real tasks BEFORE Phase 1 discovers tasks
- Without this, backlog items would never get executed

### Step 1: Get Task Status

```bash
# Check current task status (now includes promoted tasks)
bash .claude/scripts/task-operations.sh status auth-feature
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
// IMPORTANT: Process ALL waves in order
for (wave of parallel_config.waves) {

  // Spawn parallel workers for this wave
  const waveAgents = [];
  for (task of wave.tasks) {
    const agentId = Task({
      subagent_type: "phase2-implementation",
      run_in_background: true,
      prompt: `Execute task: ${task}
               Context: ${context_from_phase1}
               Return structured result with artifacts.`
    });
    waveAgents.push(agentId);
  }

  // Collect ALL results from this wave before next wave
  for (agentId of waveAgents) {
    const result = TaskOutput({ task_id: agentId, block: true });
    // Process result, update task status (Step 5)
  }

  // Update task status for completed tasks in this wave
  // (see Step 5 below)
}

// After ALL waves complete → MUST proceed to Step 6
```

### Step 5: Update Task Status

After each task completes:

```bash
# Mark task complete
bash .claude/scripts/task-operations.sh update "1.2" "pass"

# Add artifacts
bash .claude/scripts/task-operations.sh artifacts "1.2" '{"files_created":["src/auth/login.ts"],"exports_added":["login"]}'

# Or collect artifacts automatically from git
ARTIFACTS=$(bash .claude/scripts/task-operations.sh collect-artifacts HEAD~1)
bash .claude/scripts/task-operations.sh artifacts "1.2" "$ARTIFACTS"
```

### Step 5.5: Completion Gate (MANDATORY)

> ⛔ **BLOCKING GATE** - MUST verify before proceeding to Phase 3

After ALL tasks/waves have completed, verify:

```
CHECKLIST before Phase 3:

☑️ All background agents collected (no pending TaskOutput calls)
☑️ All task statuses updated in tasks.json
☑️ No more waves remaining in parallel_config.waves

IF any task blocked or failed:
  → Log blockers
  → Still proceed to Phase 3 (PR includes partial work)

IF all checks pass OR partial completion acceptable:
  → MUST proceed to Step 6
  → Do NOT skip Phase 3 regardless of execution mode
  → Do NOT end session without Phase 3

VIOLATION: Ending without Phase 3 invocation = incomplete delivery
```

---

### Step 6: Invoke Phase 3 Delivery (MANDATORY)

> ⚠️ **ALWAYS REQUIRED** - This step creates the PR. Never skip.

```javascript
Task({
  subagent_type: "phase3-delivery",
  prompt: `Complete delivery for spec: ${spec_name}
           Completed tasks: ${completed_tasks}
           Create PR and documentation.`
})
```

**This step MUST run regardless of:**
- Execution mode (single task, parallel waves, sequential)
- Task success/failure status
- Number of tasks completed

## Task Operations (Shell Script)

All task operations use `.claude/scripts/task-operations.sh`:

```bash
# Get status
bash .claude/scripts/task-operations.sh status [spec_name]

# Update task
bash .claude/scripts/task-operations.sh update <task_id> <status> [spec_name]

# Add artifacts
bash .claude/scripts/task-operations.sh artifacts <task_id> <json> [spec_name]

# Collect artifacts from git
bash .claude/scripts/task-operations.sh collect-artifacts [since_commit]

# Validate names exist
bash .claude/scripts/task-operations.sh validate-names '["functionName"]'

# Get progress
bash .claude/scripts/task-operations.sh progress [count] [type]

# Log progress
bash .claude/scripts/task-operations.sh log-progress <type> <description>
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
- `.agent-os/specs/[spec]/tasks.json` (v3.0 format)
- `.claude/agents/phase*.md` (native subagents)
- `.claude/hooks/*` (validation hooks)
- `.claude/scripts/task-operations.sh` (task management)

**No MCP server required** - all operations use native Bash tool with shell scripts.
