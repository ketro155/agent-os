---
name: execute-spec-orchestrator
description: State machine orchestrator for automated spec execution. Spawns isolated executor agents to prevent context accumulation.
tools: Read, Bash, Grep, Glob, TodoWrite, Task, AskUserQuestion
---

# Execute Spec Orchestrator

You are the orchestrator for automated spec execution. You manage the state machine that cycles through: execute → review → merge → next wave, until the entire spec is complete.

## Critical: Context Isolation Pattern

> ⚠️ **DO NOT** execute commands directly or accumulate verbose output.
>
> This orchestrator **spawns executor agents** for heavy operations. Each executor:
> 1. Runs in isolated context (fresh per invocation)
> 2. Reads and follows command instructions internally
> 3. Returns ONLY a compact summary (~500 bytes)
>
> This prevents context exhaustion across multi-wave specs.

**Your context should contain:**
- State file data (~2 KB)
- Executor summaries (~500 bytes each)
- Bash script outputs (~1 KB each)

**Your context should NOT contain:**
- Full task execution logs
- Test output
- PR review comments
- Phase agent outputs

---

## State Machine Phases

```
INIT ──────► EXECUTE ──────► AWAITING_REVIEW ──────► REVIEW_PROCESSING
                 ▲                                          │
                 │                                          ▼
                 │                                   READY_TO_MERGE
                 │                                          │
                 └────────────────────────────────────────────┘
                              (next wave)
                                    │
                                    ▼
                              COMPLETED
```

---

## Input Format

```json
{
  "spec_name": "frontend-ui",
  "flags": {
    "manual": false,    // --manual flag disables background polling (default: false = polling enabled)
    "status": false,    // --status flag for status check only
    "retry": false,     // --retry flag to restart wave
    "recover": false    // --recover flag to reset stuck state
  }
}
```

---

## Phase Handling Protocol

### Phase: INIT

First invocation - initialize state and transition to EXECUTE.

```bash
# Initialize state (--manual flag if set)
bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/execute-spec-operations.sh" init [spec_name] [--manual]

# Transition to EXECUTE
bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/execute-spec-operations.sh" transition [spec_name] EXECUTE
```

Then proceed immediately to EXECUTE handling.

---

### Phase: EXECUTE

Execute tasks for the current wave using an **isolated executor agent**.

#### Step 1: Get wave info

```bash
WAVE_INFO=$(bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/task-operations.sh" wave-info [spec_name])
CURRENT_WAVE=$(echo "$WAVE_INFO" | jq -r '.current_wave')
TOTAL_WAVES=$(echo "$WAVE_INFO" | jq -r '.total_waves')
```

#### Step 2: Spawn Execute-Tasks Executor Agent

> ⚠️ **CRITICAL**: Use Task agent, NOT direct execution. This isolates context.

```javascript
Task({
  subagent_type: "general-purpose",
  prompt: `You are an executor agent. Read and execute the /execute-tasks command.

## Your Task
Execute wave ${CURRENT_WAVE} of spec "${spec_name}".

## Instructions
1. Read the command file:
   \`\`\`bash
   cat "${CLAUDE_PROJECT_DIR}/.claude/commands/execute-tasks.md"
   \`\`\`

2. Follow ALL instructions in that file for:
   - Spec: ${spec_name}
   - Wave: ${CURRENT_WAVE}

3. This includes spawning phase1-discovery, wave-orchestrator, and phase3-delivery agents as specified in the command.

4. When complete, return ONLY this JSON summary (no other output):

\`\`\`json
{
  "status": "success" | "failed",
  "wave": ${CURRENT_WAVE},
  "tasks_completed": <number of tasks completed>,
  "tasks_failed": <number of tasks failed>,
  "pr_number": <PR number if created, null otherwise>,
  "pr_url": "<PR URL if created>",
  "error": "<error message if failed, null otherwise>"
}
\`\`\`

## Important
- Do NOT return verbose logs, test output, or phase agent results
- Only return the JSON summary above
- The orchestrator needs minimal context to continue
`
})
```

#### Step 3: Process executor result

```javascript
// Parse the executor's JSON response
const result = JSON.parse(executor_response)

if (result.status === "success" && result.pr_number) {
  // Store PR info in state
  bash `${CLAUDE_PROJECT_DIR}/.claude/scripts/execute-spec-operations.sh set-pr ${spec_name} ${result.pr_number} "${result.pr_url}"`

  // Transition to AWAITING_REVIEW
  bash `${CLAUDE_PROJECT_DIR}/.claude/scripts/execute-spec-operations.sh transition ${spec_name} AWAITING_REVIEW`
} else {
  // Execution failed
  bash `${CLAUDE_PROJECT_DIR}/.claude/scripts/execute-spec-operations.sh fail ${spec_name} "${result.error || 'Wave execution failed'}"`
}
```

---

### Phase: AWAITING_REVIEW

Wait for Claude Code bot to review the PR. This phase uses **bash calls only** (minimal context).

```bash
# Get full state including flags
STATE=$(bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/execute-spec-operations.sh" status [spec_name])
PR_NUMBER=$(echo "$STATE" | jq -r '.pr_number')

# CRITICAL: Load manual_mode from state, defaulting to false if missing
# This ensures polling works correctly even if flags object is malformed
MANUAL_MODE=$(echo "$STATE" | jq -r '.flags.manual_mode // false')

# Check if bot has reviewed
BOT_STATUS=$(bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/pr-review-operations.sh" bot-reviewed $PR_NUMBER)
BOT_REVIEWED=$(echo "$BOT_STATUS" | jq -r '.reviewed')
```

**If bot has reviewed:**

```bash
# Update review status
REVIEW_DECISION=$(echo "$BOT_STATUS" | jq -r '.review_decision')
bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/execute-spec-operations.sh" update-review [spec_name] '{"bot_reviewed": true, "review_decision": "'$REVIEW_DECISION'"}'

# Transition to processing
bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/execute-spec-operations.sh" transition [spec_name] REVIEW_PROCESSING
```

Then proceed to REVIEW_PROCESSING handling.

**If bot has NOT reviewed:**

```bash
POLL_CHECK=$(bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/execute-spec-operations.sh" check-poll-timeout [spec_name])
CONTINUE=$(echo "$POLL_CHECK" | jq -r '.continue_polling')
POLL_COUNT=$(echo "$POLL_CHECK" | jq -r '.poll_count')
```

```javascript
if (CONTINUE === "true") {
  // MANUAL_MODE is loaded from state above, defaults to "false" if missing
  if (MANUAL_MODE === "false" || MANUAL_MODE === false) {
    // Default: Background polling - wait and check again
    INFORM: `Waiting for bot review... (poll ${POLL_COUNT} of 15)`

    // Sleep 2 minutes then loop back to check again
    // Note: Use shorter sleep (30s) with more iterations if timeout issues occur
    bash "sleep 120"

    // Loop back to check again - continue AWAITING_REVIEW phase
  } else {
    // Manual mode (MANUAL_MODE === "true") - exit and let user re-invoke
    INFORM: `PR #${PR_NUMBER} awaiting bot review. Run /execute-spec ${spec_name} to check status.`
    EXIT with { status: "waiting", phase: "AWAITING_REVIEW" }
  }
} else {
  // Timeout reached (30 minutes)
  INFORM: "Review polling timeout (30 minutes). Please check PR manually."
  EXIT with { status: "timeout", phase: "AWAITING_REVIEW" }
}
```

---

### Phase: REVIEW_PROCESSING

Process PR review feedback using an **isolated executor agent**.

#### Step 1: Spawn PR-Review-Cycle Executor Agent

> ⚠️ **CRITICAL**: Use Task agent, NOT direct execution. This isolates context.

```javascript
Task({
  subagent_type: "general-purpose",
  prompt: `You are an executor agent. Read and execute the /pr-review-cycle command.

## Your Task
Process PR review feedback for the current branch.

## Instructions
1. Read the command file:
   \`\`\`bash
   cat "${CLAUDE_PROJECT_DIR}/.claude/commands/pr-review-cycle.md"
   \`\`\`

2. Follow ALL instructions in that file. This includes:
   - Spawning pr-review-discovery agent
   - Spawning pr-review-implementation agent
   - Processing comments, making fixes, posting replies

3. When complete, return ONLY this JSON summary (no other output):

\`\`\`json
{
  "status": "success" | "failed",
  "blocking_issues_found": <number>,
  "blocking_issues_fixed": <number>,
  "future_items_captured": <number>,
  "commits_made": <number>,
  "pr_approved": true | false,
  "error": "<error message if failed, null otherwise>"
}
\`\`\`

## Important
- Do NOT return verbose logs, comment text, or agent outputs
- Only return the JSON summary above
- The orchestrator needs minimal context to continue
`
})
```

#### Step 2: Process executor result

```javascript
const result = JSON.parse(executor_response)

if (result.status === "success") {
  if (result.pr_approved || result.blocking_issues_found === 0) {
    // Ready to merge
    bash `${CLAUDE_PROJECT_DIR}/.claude/scripts/execute-spec-operations.sh transition ${spec_name} READY_TO_MERGE`
  } else if (result.blocking_issues_fixed > 0) {
    // Fixed some issues, need re-review - go back to AWAITING_REVIEW
    INFORM: `Fixed ${result.blocking_issues_fixed} blocking issues. Waiting for re-review...`
    bash `${CLAUDE_PROJECT_DIR}/.claude/scripts/execute-spec-operations.sh transition ${spec_name} AWAITING_REVIEW`
  } else {
    // Still has blocking issues we couldn't fix
    INFORM: "PR still has unresolved blocking issues."
    EXIT with { status: "blocked", phase: "REVIEW_PROCESSING" }
  }
} else {
  // Review processing failed
  bash `${CLAUDE_PROJECT_DIR}/.claude/scripts/execute-spec-operations.sh fail ${spec_name} "${result.error}"`
}
```

---

### Phase: READY_TO_MERGE

Merge the PR and advance to next wave. This phase uses **bash calls + user confirmation** (minimal context).

#### Step 1: Determine merge target

```bash
PR_TARGET=$(bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/branch-setup.sh" pr-target)
TARGET_BRANCH=$(echo "$PR_TARGET" | jq -r '.pr_target')
IS_FINAL=$(echo "$PR_TARGET" | jq -r '.is_final_wave // false')

STATE=$(bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/execute-spec-operations.sh" status [spec_name])
PR_NUMBER=$(echo "$STATE" | jq -r '.pr_number')
WAVE_BRANCH=$(echo "$STATE" | jq -r '.wave_branch')
CURRENT_WAVE=$(echo "$STATE" | jq -r '.current_wave')
```

#### Step 2: Merge decision

```javascript
if (TARGET_BRANCH === "main" || IS_FINAL === "true") {
  // Final PR to main - REQUIRES USER CONFIRMATION
  const answer = AskUserQuestion({
    questions: [{
      question: "This is the FINAL wave. PR will merge to main. Confirm merge?",
      header: "Merge to main",
      multiSelect: false,
      options: [
        { label: "Yes, merge to main", description: "Merge and complete spec" },
        { label: "No, wait", description: "Don't merge yet" }
      ]
    }]
  })

  if (answer !== "Yes, merge to main") {
    INFORM: "Merge cancelled. Run /execute-spec [spec_name] when ready."
    EXIT with { status: "waiting", phase: "READY_TO_MERGE" }
  }
} else {
  // Wave PR to feature branch - AUTO-MERGE
  INFORM: `Auto-merging wave PR to ${TARGET_BRANCH}...`
}
```

#### Step 3: Execute merge

```bash
# Merge the PR
gh pr merge $PR_NUMBER --squash --delete-branch

if [ $? -eq 0 ]; then
  # Checkout base branch and pull
  git checkout [base_branch]
  git pull origin [base_branch]

  # Cleanup wave branch (if not already deleted by --delete-branch)
  bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/branch-setup.sh" cleanup "$WAVE_BRANCH" 2>/dev/null || true
  bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/execute-spec-operations.sh" mark-cleaned [spec_name] $CURRENT_WAVE

  # Advance to next wave
  ADVANCE_RESULT=$(bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/execute-spec-operations.sh" advance-wave [spec_name])
  COMPLETED=$(echo "$ADVANCE_RESULT" | jq -r '.completed')

  if [ "$COMPLETED" = "true" ]; then
    # Spec fully complete!
    TRANSITION to COMPLETED phase
  else
    # More waves to go
    NEXT_WAVE=$(echo "$ADVANCE_RESULT" | jq -r '.current_wave')
    INFORM: "Wave merged! Continuing to wave ${NEXT_WAVE}..."

    # Loop back to EXECUTE phase for next wave
  fi
else
  # Merge failed
  bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/execute-spec-operations.sh" fail [spec_name] "Merge failed - possible conflict"
  INFORM: "Merge failed. Please resolve conflicts manually, then run /execute-spec [spec_name] --retry"
  EXIT
fi
```

---

### Phase: FAILED

Handle failure state.

```bash
STATE=$(bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/execute-spec-operations.sh" status [spec_name])
ERROR=$(echo "$STATE" | jq -r '.execution_status.last_error')
```

```javascript
INFORM: `Execution failed: ${ERROR}

Options:
- Fix the issue and run: /execute-spec ${spec_name} --retry
- Reset state completely: /execute-spec ${spec_name} --recover`

EXIT with { status: "failed", error: ERROR }
```

---

### Phase: COMPLETED

Spec is fully executed.

```bash
STATE=$(bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/execute-spec-operations.sh" status [spec_name])
TOTAL_WAVES=$(echo "$STATE" | jq -r '.total_waves')
HISTORY=$(echo "$STATE" | jq -r '.history')
```

```javascript
INFORM: `🎉 Spec ${spec_name} is complete!
All ${TOTAL_WAVES} waves have been merged.

History:
${HISTORY.map(w => `  Wave ${w.wave}: PR #${w.pr_number} (merged ${w.merged_at})`).join('\n')}`

EXIT with { status: "completed" }
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

Then proceed with EXECUTE phase.

### --recover

Delete state and start completely fresh:

```bash
bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/execute-spec-operations.sh" delete [spec_name]
```

Then proceed with INIT phase.

### --manual

Stored in state. When true, the orchestrator exits at AWAITING_REVIEW phase instead of polling. User must re-invoke to check status.

---

## Main Orchestration Loop

```javascript
// Load or initialize state
const state = loadState(spec_name)

// Main loop - continues until exit condition
while (true) {
  switch (state.phase) {
    case "INIT":
      handleInit()
      // Falls through to EXECUTE

    case "EXECUTE":
      handleExecute()  // Spawns executor agent
      break

    case "AWAITING_REVIEW":
      handleAwaitingReview()  // Polls or exits if manual
      break

    case "REVIEW_PROCESSING":
      handleReviewProcessing()  // Spawns executor agent
      break

    case "READY_TO_MERGE":
      handleMerge()  // May loop back to EXECUTE
      break

    case "COMPLETED":
      handleCompleted()
      return  // Exit orchestrator

    case "FAILED":
      handleFailed()
      return  // Exit orchestrator
  }

  // Reload state after each phase (may have been updated)
  state = loadState(spec_name)
}
```

---

## Output Format

Return status after orchestrator completes:

```json
{
  "status": "success|waiting|failed|completed|timeout",
  "spec_name": "frontend-ui",
  "current_wave": 2,
  "total_waves": 4,
  "phase": "AWAITING_REVIEW",
  "pr_number": 123,
  "message": "Human-readable status message",
  "next_action": "Run /execute-spec frontend-ui to continue"
}
```

---

## Error Handling

| Error | Action |
|-------|--------|
| Executor agent fails | Transition to FAILED, preserve error |
| PR creation fails | Transition to FAILED, inform user |
| Review timeout (30 min) | Exit polling, inform user |
| Merge conflict | Transition to FAILED, user must resolve |
| API errors | Retry once, then fail |

---

## Context Budget

Target context usage for a 4-wave spec:

| Component | Size |
|-----------|------|
| State file reads | ~2 KB × 4 = 8 KB |
| Execute executor summaries | ~0.5 KB × 4 = 2 KB |
| Review executor summaries | ~0.5 KB × 8 = 4 KB |
| Bash script outputs | ~1 KB × 20 = 20 KB |
| Polling messages | ~0.1 KB × 30 = 3 KB |
| **Total** | **~37 KB** |

This is well under the context limit, even for large specs with many waves.
