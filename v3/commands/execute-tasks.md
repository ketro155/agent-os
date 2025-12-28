# Execute Tasks (v4.1)

Execute tasks from a specification using native Claude Code features with wave-orchestrated parallel execution.

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

v4.1 adds wave orchestration for better context management and hallucination prevention:

| v3.0 | v4.1 |
|------|------|
| Direct Phase 2 spawning | Wave Orchestrator per wave |
| Context accumulates in main agent | Context isolated per wave |
| Artifact claims trusted | Artifact claims grep-verified |
| Can exhaust context on large specs | Scales to any spec size |

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
Wave Orchestrator(s) → Isolated execution per wave
        │
        ├── Single Task: Direct Phase 2 agent
        │
        └── Parallel Waves:
            ┌─────────────────────────────────────────────┐
            │  Wave 1 Orchestrator                        │
            │  ├── Verify predecessor artifacts (none)    │
            │  ├── Spawn Phase 2 agents (parallel)        │
            │  ├── Collect & verify artifacts             │
            │  └── Return: verified_context_for_wave_2    │
            └─────────────────────────────────────────────┘
                            ↓ (verified context)
            ┌─────────────────────────────────────────────┐
            │  Wave 2 Orchestrator                        │
            │  ├── Verify predecessor artifacts (wave 1)  │
            │  ├── Spawn Phase 2 agents (parallel)        │
            │  ├── Collect & verify artifacts             │
            │  └── Return: verified_context_for_wave_3    │
            └─────────────────────────────────────────────┘
                            ↓
                    [Continue for all waves]
        ↓
[Completion Gate] → Verify all waves completed
        ↓
Phase 3 Agent → Final tests, PR, documentation  ⚠️ MANDATORY
        ↓
SessionEnd hook → Log progress, checkpoint
```

> **CRITICAL**: Phase 3 MUST always run. It creates the PR. Never skip.

## Why Wave Orchestration?

**Problem**: In v3.0, the main agent accumulates all Phase 2 results, exhausting context on large specs.

**Solution**: Each wave runs in an isolated orchestrator that:
1. Receives only verified predecessor artifacts
2. Spawns and collects Phase 2 agents internally
3. Returns only a verified summary to the main agent

**Hallucination Prevention**: Before passing context to the next wave, artifacts are grep-verified:
- Claimed exports must exist: `grep -r "export.*functionName"`
- Claimed files must exist: `ls path/to/file`
- Unverified claims are flagged and excluded

## For Claude Code

### Step 0: Auto-Promote Future Tasks (MANDATORY)

> ⚠️ **MUST RUN BEFORE PHASE 1** - This step promotes backlog items from PR reviews into the current wave.

```bash
# 1. Get the next wave number to execute
SPEC_NAME="[spec_name]"
NEXT_WAVE=$(bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/task-operations.sh" status "$SPEC_NAME" | jq -r '
  .next_task.wave //
  (.tasks | map(select(.status == "pending")) | first | .wave) //
  empty
')

# 2. Check for future tasks tagged for this wave
FUTURE_COUNT=$(bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/task-operations.sh" list-future "$SPEC_NAME" | jq -r --arg w "wave_$NEXT_WAVE" '
  [.future_tasks[] | select(.priority == $w)] | length
')

# 3. If there are future tasks, promote them
if [ "$FUTURE_COUNT" -gt 0 ]; then
  echo "🔄 Auto-promoting $FUTURE_COUNT future tasks to wave $NEXT_WAVE..."
  bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/task-operations.sh" promote-wave "$NEXT_WAVE" "$SPEC_NAME"
fi
```

**Why this step exists:**
- PR review captures deferred items to `future_tasks` with `priority: "wave_5"`
- This step ensures those items become real tasks BEFORE Phase 1 discovers tasks
- Without this, backlog items would never get executed

### Step 1: Get Task Status

```bash
# Check current task status (now includes promoted tasks)
bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/task-operations.sh" status auth-feature
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
// For single task, use Phase 2 directly (no orchestration overhead)
Task({
  subagent_type: "phase2-implementation",
  prompt: `Execute task: ${task}
           Context: ${context_from_phase1}
           Return structured result with artifacts.`
})
```

**Parallel Wave Mode (v4.1 - Wave Orchestration):**
```javascript
// Initialize empty predecessor context for wave 1
let predecessorArtifacts = { verified: true };
let cumulativeArtifacts = { all_exports: [], all_files: [], all_commits: [] };

// Process each wave through its own orchestrator
for (const wave of parallel_config.waves) {

  // Build wave execution context (follows wave-context-v1 schema)
  const waveContext = {
    wave_number: wave.wave_id,
    spec_name: spec_name,
    spec_folder: `.agent-os/specs/${spec_name}/`,
    tasks: wave.tasks.map(taskId => getTaskDetails(taskId)),
    predecessor_artifacts: predecessorArtifacts,
    execution_mode: "parallel",
    git_branch: `feature/${spec_name}-wave-${wave.wave_id}`
  };

  // Spawn wave orchestrator (isolates context)
  const waveResult = Task({
    subagent_type: "wave-orchestrator",
    prompt: `
      Execute wave ${wave.wave_id} of ${parallel_config.waves.length}

      Wave Execution Context:
      ${JSON.stringify(waveContext, null, 2)}

      REQUIREMENTS:
      1. Verify ALL predecessor artifacts exist before starting
      2. Spawn Phase 2 agents for all tasks in parallel
      3. Collect and VERIFY all claimed artifacts
      4. Return verified context for next wave

      Return WaveResult per wave-context-v1 schema.
    `
  });

  // CHECK: Did wave complete successfully?
  if (waveResult.status === "blocked" || waveResult.status === "error") {
    console.log(`⚠️ Wave ${wave.wave_id} ${waveResult.status}: ${waveResult.blockers}`);
    // Continue to Phase 3 with partial completion
    break;
  }

  // UPDATE: Predecessor context for next wave
  predecessorArtifacts = waveResult.context_for_next_wave.predecessor_artifacts;
  cumulativeArtifacts = waveResult.cumulative_artifacts;

  // Log wave completion (main agent only sees summary)
  console.log(`✅ Wave ${wave.wave_id}: ${waveResult.tasks_completed.length} tasks, ${waveResult.verified_artifacts.files_created.length} files`);

  // Flag any unverified claims
  if (waveResult.unverified_claims?.length > 0) {
    console.log(`⚠️ ${waveResult.unverified_claims.length} unverified artifact claims - excluded from context chain`);
  }
}

// After ALL waves complete → MUST proceed to Step 6
```

### Step 4.5: Context Chain Integrity Check

> ⛔ **MANDATORY** - Verify context chain before Phase 3

```javascript
// Verify the final cumulative artifacts are consistent
const integrityCheck = {
  total_waves_completed: completedWaves.length,
  total_tasks_passed: cumulativeArtifacts.all_commits.length > 0,
  artifact_chain_verified: predecessorArtifacts.verified === true,
  unverified_claims_total: allUnverifiedClaims.length
};

if (integrityCheck.unverified_claims_total > 0) {
  console.log(`⚠️ Warning: ${integrityCheck.unverified_claims_total} artifact claims could not be verified`);
  console.log(`   These were excluded from the context chain to prevent hallucination`);
}
```

### Step 5: Update Task Status

After each task completes:

```bash
# Mark task complete
bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/task-operations.sh" update "1.2" "pass"

# Add artifacts
bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/task-operations.sh" artifacts "1.2" '{"files_created":["src/auth/login.ts"],"exports_added":["login"]}'

# Or collect artifacts automatically from git
ARTIFACTS=$(bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/task-operations.sh" collect-artifacts HEAD~1)
bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/task-operations.sh" artifacts "1.2" "$ARTIFACTS"
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

All task operations use `"${CLAUDE_PROJECT_DIR}/.claude/scripts/task-operations.sh"`:

```bash
# Get status
bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/task-operations.sh" status [spec_name]

# Update task
bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/task-operations.sh" update <task_id> <status> [spec_name]

# Add artifacts
bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/task-operations.sh" artifacts <task_id> <json> [spec_name]

# Collect artifacts from git
bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/task-operations.sh" collect-artifacts [since_commit]

# Validate names exist
bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/task-operations.sh" validate-names '["functionName"]'

# Get progress
bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/task-operations.sh" progress [count] [type]

# Log progress
bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/task-operations.sh" log-progress <type> <description>
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

## Comparison: v2.x vs v3.0 vs v4.1

| Aspect | v2.x | v3.0 | v4.1 |
|--------|------|------|------|
| Command size | 475 lines | ~120 lines | ~180 lines |
| Phase loading | Manual Read tool | Native subagents | Native subagents |
| Validation | Skills (can be skipped) | Hooks (mandatory) | Hooks + artifact verification |
| Task sync | task-sync skill | PostToolUse hook | PostToolUse hook |
| Task format | MD + JSON (sync issues) | JSON primary | JSON primary |
| Operations | Inline code | Shell script | Shell script |
| Recovery | Custom patterns | Native checkpointing | Native checkpointing |
| **Parallel execution** | Not supported | Direct Phase 2 spawning | Wave orchestrator pattern |
| **Context management** | N/A | Accumulates in main agent | Isolated per wave |
| **Artifact verification** | None | Trusted claims | Grep-verified claims |
| **Max spec size** | Limited | Limited by context | Unlimited (scales) |

## Dependencies

**Required:**
- `.agent-os/specs/[spec]/tasks.json` (v3.0 format)
- `.claude/agents/phase*.md` (native subagents)
- `.claude/agents/wave-orchestrator.md` (v4.1 wave orchestration)
- `.claude/hooks/*` (validation hooks)
- `.claude/scripts/task-operations.sh` (task management)

**Schemas:**
- `.agent-os/schemas/tasks-v3.json` (task format)
- `.agent-os/schemas/wave-context-v1.json` (wave orchestration contracts)

**No MCP server required** - all operations use native Bash tool with shell scripts.
