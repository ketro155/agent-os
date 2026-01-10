---
name: wave-lifecycle-agent
description: Executes complete lifecycle for a single wave. Preserves context within wave, returns when wave is merged or failed.
tools: Read, Bash, Grep, Glob, TodoWrite, Task, AskUserQuestion
model: sonnet
---

# Wave Lifecycle Agent

You execute the complete lifecycle for a **single wave** of a spec. You handle all phases from task execution through PR merge, preserving context throughout so that PR creation, review processing, and merge decisions all share the same context.

## Why This Agent Exists

The orchestrator spawns one wave-lifecycle-agent per wave to achieve:
- **Context preservation within wave**: PR number, review feedback, and merge decisions stay in same context
- **Context isolation between waves**: Each wave gets fresh context (~4-5 KB)
- **No OOM**: Multi-wave specs work because waves are isolated from each other

---

## Input Format

```json
{
  "spec_name": "frontend-ui",
  "wave_number": 2,
  "total_waves": 4,
  "is_final_wave": false,
  "base_branch": "feature/frontend-ui",
  "resume_phase": null
}
```

**Resume support**: If `resume_phase` is provided (`"AWAITING_REVIEW"` or `"READY_TO_MERGE"`), skip to that phase instead of starting from EXECUTE.

---

## Wave Lifecycle Flow

```
┌─────────────────────────────────────────────────────────────────┐
│  EXECUTE: Spawn executor → Create PR                            │
│           Capture pr_number in context                          │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  AWAITING_REVIEW: Poll for bot review (internal loop)           │
│                   Max 15 polls (~30 minutes)                    │
│                   If timeout → EXIT with timeout status         │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  REVIEW_PROCESSING: Spawn review executor                       │
│                     If commits made → back to AWAITING_REVIEW   │
│                     If approved/no changes → continue           │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  READY_TO_MERGE: Merge PR to target branch                      │
│                  Final wave → Require user confirmation         │
│                  Wave PR → Auto-merge to feature branch         │
└─────────────────────────────────────────────────────────────────┘
                              ↓
                    RETURN success to orchestrator
```

---

## Implementation Protocol

### Step 0: Check for Resume

```javascript
// Extract input
const { spec_name, wave_number, total_waves, is_final_wave, base_branch, resume_phase } = input

// If resuming, get existing PR number from state
let pr_number = null
let pr_url = null

if (resume_phase) {
  const state = bash `${CLAUDE_PROJECT_DIR}/.claude/scripts/execute-spec-operations.sh status ${spec_name}`
  const stateData = JSON.parse(state)
  pr_number = stateData.pr_number

  INFORM: `Resuming wave ${wave_number} from phase: ${resume_phase}`

  if (resume_phase === "AWAITING_REVIEW") {
    // Skip to Step 2
    GOTO: await_review_phase
  } else if (resume_phase === "READY_TO_MERGE") {
    // Skip to Step 4
    GOTO: merge_phase
  }
}
```

### Step 1: Execute Tasks (EXECUTE Phase)

Spawn an isolated executor agent to run `/execute-tasks` for this wave.

```javascript
INFORM: `Starting wave ${wave_number} of ${total_waves} for spec "${spec_name}"...`

// Spawn executor agent
const execute_result = Task({
  subagent_type: "general-purpose",
  prompt: `You are an executor agent. Read and execute the /execute-tasks command.

## Your Task
Execute wave ${wave_number} of spec "${spec_name}".

## Instructions
1. Read the command file:
   \`\`\`bash
   cat "${CLAUDE_PROJECT_DIR}/.claude/commands/execute-tasks.md"
   \`\`\`

2. Follow ALL instructions in that file for:
   - Spec: ${spec_name}
   - Wave: ${wave_number}

3. This includes spawning phase1-discovery, wave-orchestrator, and phase3-delivery agents.

4. When complete, return ONLY this JSON summary:

\`\`\`json
{
  "status": "success" | "failed",
  "wave": ${wave_number},
  "tasks_completed": <number>,
  "tasks_failed": <number>,
  "pr_number": <PR number if created>,
  "pr_url": "<PR URL if created>",
  "error": "<error message if failed>"
}
\`\`\`

## Important
- Only return the JSON summary above
- Do NOT return verbose logs or phase outputs
`
})

// Process result
const result = JSON.parse(execute_result)

if (result.status !== "success" || !result.pr_number) {
  RETURN: {
    status: "failed",
    wave: wave_number,
    phase: "EXECUTE",
    error: result.error || "Wave execution failed - no PR created"
  }
}

// Store PR info in our context for later phases
pr_number = result.pr_number
pr_url = result.pr_url

// Store PR in state file for resume support
bash `${CLAUDE_PROJECT_DIR}/.claude/scripts/execute-spec-operations.sh set-pr ${spec_name} ${pr_number} "${pr_url}"`

INFORM: `PR #${pr_number} created. Waiting for bot review...`
```

### Step 2: Wait for Review (AWAITING_REVIEW Phase)

:await_review_phase

Poll for Claude Code bot review. This is an internal loop within this agent.

> **IMPORTANT**: This step may be executed multiple times if re-review is needed after code fixes.
> The `review_cycle` variable tracks which review iteration we're on.

```javascript
// Review cycle tracking (for re-review after fixes)
let review_cycle = 1

// Main review loop - repeats if commits require re-review
REVIEW_LOOP: while (true) {

  INFORM: `Review cycle ${review_cycle}: Polling for bot review...`

  // Poll configuration
  const MAX_POLLS = 15
  const POLL_INTERVAL = 120  // 2 minutes
  let poll_count = 0
  let bot_reviewed = false
  let review_decision = null

  // Polling loop
  while (poll_count < MAX_POLLS) {
    poll_count++

    // Sync poll count to state for crash recovery
    bash `${CLAUDE_PROJECT_DIR}/.claude/scripts/execute-spec-operations.sh update-review ${spec_name} '{"poll_count": ${poll_count}}'`

    // Check if bot has reviewed
    const bot_status = bash `${CLAUDE_PROJECT_DIR}/.claude/scripts/pr-review-operations.sh bot-reviewed ${pr_number}`
    const status = JSON.parse(bot_status)

    if (status.reviewed === true) {
      bot_reviewed = true
      review_decision = status.review_decision
      break
    }

    INFORM: `Poll ${poll_count}/${MAX_POLLS}: No review yet. Waiting ${POLL_INTERVAL}s...`

    // Sleep (bash command)
    bash `sleep ${POLL_INTERVAL}`
  }

  // Check for timeout
  if (!bot_reviewed) {
    RETURN: {
      status: "timeout",
      wave: wave_number,
      phase: "AWAITING_REVIEW",
      pr_number: pr_number,
      message: `Review polling timeout (${MAX_POLLS * POLL_INTERVAL / 60} minutes). Check PR manually.`
    }
  }

  INFORM: `Bot reviewed PR #${pr_number} (cycle ${review_cycle}). Processing feedback...`

  // Step 3: Process Review (REVIEW_PROCESSING Phase)
  const review_result = Task({
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

3. When complete, return ONLY this JSON summary:

\`\`\`json
{
  "status": "success" | "failed",
  "blocking_issues_found": <number>,
  "blocking_issues_fixed": <number>,
  "future_items_captured": <number>,
  "commits_made": <number>,
  "pr_approved": true | false,
  "error": "<error message if failed>"
}
\`\`\`

## Important
- Only return the JSON summary above
- commits_made determines if re-review is needed
`
  })

  const review = JSON.parse(review_result)

  if (review.status !== "success") {
    RETURN: {
      status: "failed",
      wave: wave_number,
      phase: "REVIEW_PROCESSING",
      pr_number: pr_number,
      error: review.error
    }
  }

  // Decision point: continue to merge or loop for re-review?
  if (review.pr_approved) {
    INFORM: `PR #${pr_number} approved! Ready to merge.`
    break REVIEW_LOOP  // Exit to merge phase

  } else if ((review.commits_made || 0) > 0) {
    // Code changes made - need re-review
    INFORM: `Made ${review.commits_made} commit(s). Starting re-review cycle...`
    review_cycle++

    // Reset state for new review cycle
    bash `${CLAUDE_PROJECT_DIR}/.claude/scripts/execute-spec-operations.sh update-review ${spec_name} '{"poll_count": 0, "bot_reviewed": false}'`

    // Continue REVIEW_LOOP - will poll again for new review
    continue REVIEW_LOOP

  } else {
    // No code changes - ready to merge
    INFORM: `No blocking issues. Ready to merge.`
    break REVIEW_LOOP  // Exit to merge phase
  }
}
```

### Step 4: Merge PR (READY_TO_MERGE Phase)

:merge_phase

Merge the PR to the appropriate target branch.

```javascript
// Determine merge target
const pr_target = bash `${CLAUDE_PROJECT_DIR}/.claude/scripts/branch-setup.sh pr-target`
const target_info = JSON.parse(pr_target)
const TARGET_BRANCH = target_info.pr_target || base_branch

// Final wave requires user confirmation
if (is_final_wave) {
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
    // Update state to preserve position
    bash `${CLAUDE_PROJECT_DIR}/.claude/scripts/execute-spec-operations.sh transition ${spec_name} READY_TO_MERGE`

    RETURN: {
      status: "waiting",
      wave: wave_number,
      phase: "READY_TO_MERGE",
      pr_number: pr_number,
      message: "Merge cancelled by user. Re-run to continue."
    }
  }
} else {
  INFORM: `Auto-merging wave PR #${pr_number} to ${TARGET_BRANCH}...`
}

// Execute merge
const merge_result = bash `gh pr merge ${pr_number} --squash --delete-branch 2>&1 || echo "MERGE_FAILED"`

if (merge_result.includes("MERGE_FAILED")) {
  RETURN: {
    status: "failed",
    wave: wave_number,
    phase: "READY_TO_MERGE",
    pr_number: pr_number,
    error: "Merge failed - possible conflict. Resolve manually."
  }
}

// Checkout base branch and pull
bash `git checkout ${base_branch} && git pull origin ${base_branch}`

INFORM: `Wave ${wave_number} merged successfully!`
```

### Step 5: Return Success

```javascript
RETURN: {
  status: "success",
  wave: wave_number,
  pr_number: pr_number,
  merged_to: TARGET_BRANCH
}
```

---

## Output Format

Return one of these statuses to the orchestrator:

```javascript
// Success - wave completed
{
  status: "success",
  wave: 2,
  pr_number: 125,
  merged_to: "feature/frontend-ui"
}

// Failed - something went wrong
{
  status: "failed",
  wave: 2,
  phase: "EXECUTE" | "AWAITING_REVIEW" | "REVIEW_PROCESSING" | "READY_TO_MERGE",
  pr_number: 125,  // if available
  error: "Description of what failed"
}

// Timeout - review polling timed out
{
  status: "timeout",
  wave: 2,
  phase: "AWAITING_REVIEW",
  pr_number: 125,
  message: "Review polling timeout. Check PR manually."
}

// Waiting - user chose not to merge
{
  status: "waiting",
  wave: 2,
  phase: "READY_TO_MERGE",
  pr_number: 125,
  message: "Merge cancelled by user. Re-run to continue."
}
```

---

## Context Budget

This agent handles the complete wave lifecycle in a single context:

| Component | Size |
|-----------|------|
| Input params | ~0.5 KB |
| Execute executor summary | ~0.5 KB |
| Review executor summary(s) | ~0.5 KB × review cycles |
| Bash outputs (PR ops, git) | ~2 KB |
| Polling status messages | ~1 KB |
| **Total per wave** | **~4-5 KB** (may increase with re-reviews) |

This is well within safe limits while preserving all wave-related context.

---

## Error Handling

| Error | Action |
|-------|--------|
| Task execution fails | Return failed with phase=EXECUTE |
| PR creation fails | Return failed with phase=EXECUTE |
| Review timeout (30 min) | Return timeout, orchestrator handles |
| Review processing fails | Return failed with phase=REVIEW_PROCESSING |
| Merge conflict | Return failed with phase=READY_TO_MERGE |
| User cancels merge | Return waiting, orchestrator handles |

---

## Error Handling

This agent uses standardized error handling from `rules/error-handling.md`:

```javascript
// Error handling for wave lifecycle
const handleWaveError = (err, phase) => {
  return handleError({
    code: mapErrorToCode(err),
    agent: 'wave-lifecycle-agent',
    operation: `wave_${phase}`,
    details: { wave_number: waveNumber, phase: phase }
  });
};

// Example: Task execution failure
if (taskResult.status === 'fail') {
  return handleError({
    code: 'E101',
    agent: 'wave-lifecycle-agent',
    operation: 'task_execution',
    details: { task_id: taskId, error: taskResult.error }
  });
}

// Example: PR review timeout
if (reviewResult.status === 'timeout') {
  return handleError({
    code: 'E108',
    agent: 'wave-lifecycle-agent',
    operation: 'review_polling',
    details: { pr_number: prNumber, timeout_ms: timeoutMs }
  });
}
```

---

## Changelog

### v4.9.0 (2026-01-10)
- Standardized error handling with error-handling.md rule
- Added parallel task execution support

### v4.6.0
- Initial wave lifecycle agent
- Context isolation between waves
