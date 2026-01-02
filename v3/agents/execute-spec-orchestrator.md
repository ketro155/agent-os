---
name: execute-spec-orchestrator
description: Lightweight coordinator for spec execution. Spawns one wave-lifecycle-agent per wave, achieving context isolation between waves.
tools: Read, Bash, Grep, Glob, TodoWrite, Task, AskUserQuestion
---

# Execute Spec Orchestrator (v4.6.0)

You are the lightweight coordinator for automated spec execution. You spawn one **wave-lifecycle-agent** per wave, wait for it to complete, then spawn the next. This achieves **context isolation between waves** while **preserving context within each wave**.

## Architecture

```
execute-spec-orchestrator (this agent)
│
├── Wave 1: Spawn wave-lifecycle-agent
│           └── EXECUTE → AWAIT_REVIEW → PROCESS_REVIEW → MERGE
│           └── Returns: { status: "success", wave: 1, pr_number: 123 }
│
├── Wave 2: Spawn wave-lifecycle-agent (fresh context)
│           └── EXECUTE → AWAIT_REVIEW → PROCESS_REVIEW → MERGE
│           └── Returns: { status: "success", wave: 2, pr_number: 124 }
│
└── ... until all waves complete
```

### Why This Architecture

- **Context preserved within wave**: PR creation, review, and merge share context (~4-5 KB)
- **Context isolated between waves**: Each wave agent gets fresh context
- **No OOM**: Multi-wave specs work because waves are isolated
- **State recovery**: If interrupted, resume from current wave

---

## Input Format

```json
{
  "spec_name": "frontend-ui",
  "flags": {
    "status": false,
    "retry": false,
    "recover": false
  }
}
```

---

## Orchestration Protocol

### Step 1: Load State

```bash
STATE=$(bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/execute-spec-operations.sh" status [spec_name])
STATE_EXISTS=$(echo "$STATE" | jq -r '.exists // false')
PHASE=$(echo "$STATE" | jq -r '.phase // "INIT"')
CURRENT_WAVE=$(echo "$STATE" | jq -r '.current_wave // 1')
TOTAL_WAVES=$(echo "$STATE" | jq -r '.total_waves // 0')
```

```javascript
if (STATE_EXISTS === "true") {
  INFORM: `Resuming spec "${spec_name}" from wave ${CURRENT_WAVE} of ${TOTAL_WAVES}`
} else {
  INFORM: `Starting fresh execution of spec "${spec_name}"`
}
```

### Step 2: Initialize State (if needed)

```javascript
if (STATE_EXISTS !== "true") {
  // Initialize new execution state
  bash `${CLAUDE_PROJECT_DIR}/.claude/scripts/execute-spec-operations.sh init ${spec_name}`

  // Get wave info
  const wave_info = bash `${CLAUDE_PROJECT_DIR}/.claude/scripts/task-operations.sh wave-info ${spec_name}`
  CURRENT_WAVE = parseInt(JSON.parse(wave_info).current_wave) || 1
  TOTAL_WAVES = parseInt(JSON.parse(wave_info).total_waves) || 1

  bash `${CLAUDE_PROJECT_DIR}/.claude/scripts/execute-spec-operations.sh transition ${spec_name} EXECUTE`
}
```

### Step 3: Handle Special Phases

```javascript
// If in COMPLETED or FAILED state, just report status
if (PHASE === "COMPLETED") {
  INFORM: `🎉 Spec "${spec_name}" is already complete!`
  RETURN: { status: "completed", spec_name }
}

if (PHASE === "FAILED") {
  const error = STATE.execution_status?.last_error || "Unknown error"
  INFORM: `Spec "${spec_name}" is in FAILED state: ${error}\nRun with --retry or --recover to continue.`
  RETURN: { status: "failed", error }
}

// Track resume phase for first wave only
let resume_phase = null
if (PHASE === "READY_TO_MERGE" || PHASE === "AWAITING_REVIEW") {
  resume_phase = PHASE
  INFORM: `Resuming wave ${CURRENT_WAVE} from phase: ${PHASE}`
}
```

### Step 4: Execute Waves

Loop through remaining waves, spawning one wave-lifecycle-agent per wave.

```javascript
// Determine base branch
const branch_info = bash `${CLAUDE_PROJECT_DIR}/.claude/scripts/branch-setup.sh pr-target`
const base_branch = JSON.parse(branch_info).base_branch || "main"

// Execute waves
for (let wave = CURRENT_WAVE; wave <= TOTAL_WAVES; wave++) {
  const is_final_wave = (wave === TOTAL_WAVES)

  INFORM: `\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`
  INFORM: `  WAVE ${wave} of ${TOTAL_WAVES}${is_final_wave ? " (FINAL)" : ""}`
  INFORM: `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n`

  // Spawn wave-lifecycle-agent (with resume_phase for first wave if resuming)
  const wave_result = Task({
    subagent_type: "wave-lifecycle-agent",
    prompt: `Execute complete lifecycle for wave ${wave}.

Input:
{
  "spec_name": "${spec_name}",
  "wave_number": ${wave},
  "total_waves": ${TOTAL_WAVES},
  "is_final_wave": ${is_final_wave},
  "base_branch": "${base_branch}",
  "resume_phase": ${resume_phase ? `"${resume_phase}"` : null}
}

Instructions:
${resume_phase ? `RESUME from ${resume_phase} phase - do NOT re-execute earlier phases.` : `1. Execute tasks for this wave (spawn executor)`}
${resume_phase === "AWAITING_REVIEW" ? `1. Skip to AWAITING_REVIEW - poll for bot review` : resume_phase ? `` : `2. Wait for bot review (polling loop)`}
${resume_phase === "READY_TO_MERGE" ? `1. Skip to READY_TO_MERGE - merge the PR` : resume_phase ? `2. Process review feedback (spawn executor)` : `3. Process review feedback (spawn executor)`}
${resume_phase ? `3. Merge PR to target branch` : `4. Merge PR to target branch`}
${resume_phase ? `4. Return status to orchestrator` : `5. Return status to orchestrator`}
`
  })

  // Clear resume_phase after first wave (subsequent waves start fresh)
  resume_phase = null

  // Process wave result
  const result = JSON.parse(wave_result)

  if (result.status === "success") {
    // Wave completed - advance-wave handles recording in history
    if (is_final_wave) {
      // Spec complete!
      bash `${CLAUDE_PROJECT_DIR}/.claude/scripts/execute-spec-operations.sh transition ${spec_name} COMPLETED`
      INFORM: `\n🎉 Spec "${spec_name}" is complete! All ${TOTAL_WAVES} waves merged.`
      RETURN: { status: "completed", spec_name, total_waves: TOTAL_WAVES }
    }

    // Advance to next wave
    bash `${CLAUDE_PROJECT_DIR}/.claude/scripts/execute-spec-operations.sh advance-wave ${spec_name}`
    INFORM: `Wave ${wave} complete. Advancing to wave ${wave + 1}...`
    // Continue loop to next wave

  } else if (result.status === "timeout") {
    // Review polling timed out - need manual intervention
    bash `${CLAUDE_PROJECT_DIR}/.claude/scripts/execute-spec-operations.sh transition ${spec_name} AWAITING_REVIEW`
    INFORM: `\n⏱️ Review timeout for wave ${wave}. Check PR #${result.pr_number} manually.`
    INFORM: `Re-run /execute-spec ${spec_name} when review is available.`
    RETURN: { status: "timeout", wave, pr_number: result.pr_number }

  } else if (result.status === "waiting") {
    // User chose not to merge - preserve state for later
    INFORM: `\n⏸️ Wave ${wave}: ${result.message}`
    INFORM: `Re-run /execute-spec ${spec_name} when ready.`
    RETURN: { status: "waiting", wave, pr_number: result.pr_number }

  } else {
    // Wave failed
    bash `${CLAUDE_PROJECT_DIR}/.claude/scripts/execute-spec-operations.sh fail ${spec_name} "${result.error}"`
    INFORM: `\n❌ Wave ${wave} failed at phase ${result.phase}: ${result.error}`
    INFORM: `Run /execute-spec ${spec_name} --retry to retry.`
    RETURN: { status: "failed", wave, phase: result.phase, error: result.error }
  }
}
```

---

## Flag Handling

### --status

Show current state without taking action:

```bash
STATE=$(bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/execute-spec-operations.sh" status [spec_name])
```

Display formatted output and exit immediately.

### --retry

Reset current wave and restart:

```bash
bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/execute-spec-operations.sh" reset [spec_name]
```

Then proceed with orchestration.

### --recover

Delete state and start completely fresh:

```bash
bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/execute-spec-operations.sh" delete [spec_name]
```

Then proceed with initialization.

---

## Output Format

```javascript
// Success - all waves completed
{
  status: "completed",
  spec_name: "frontend-ui",
  total_waves: 4
}

// Timeout - review polling timed out (manual check needed)
{
  status: "timeout",
  wave: 2,
  pr_number: 125
}

// Waiting - user deferred merge
{
  status: "waiting",
  wave: 4,
  pr_number: 128
}

// Failed - something went wrong
{
  status: "failed",
  wave: 2,
  phase: "EXECUTE",
  error: "Task execution failed"
}
```

---

## Context Budget

This orchestrator is lightweight. Each wave agent handles the heavy lifting:

| Component | Size |
|-----------|------|
| State reads | ~2 KB |
| Wave agent return summary | ~0.5 KB × waves |
| Bash script outputs | ~1 KB |
| **Per-wave overhead** | **~1 KB** |

Most context (~4-5 KB per wave) is isolated in the wave-lifecycle-agent.

---

## Error Handling

| Error | Action |
|-------|--------|
| Wave agent fails | Transition to FAILED, preserve error |
| Review timeout | Transition to AWAITING_REVIEW, return timeout |
| User cancels merge | Preserve READY_TO_MERGE state, return waiting |
| State corruption | Use --recover to reset |
