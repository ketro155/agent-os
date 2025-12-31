# Execute Spec (v4.4)

Automate the complete spec execution cycle: execute waves → create PR → wait for review → process feedback → merge → advance to next wave. Repeat until the entire spec is complete.

## Parameters
- `spec_name` (required): Specification folder name
- `--manual`: Disable background polling; requires manual invocations to check status
- `--status`: Show current execution state without taking action
- `--retry`: Restart entire wave after fixing failed tasks
- `--recover`: Reset stuck state and start fresh

## Quick Start

```bash
# Start executing a spec (background polling - runs continuously)
/execute-spec frontend-ui

# Start with manual polling (check status yourself)
/execute-spec frontend-ui --manual

# Check current status
/execute-spec frontend-ui --status

# Retry after fixing failed tasks
/execute-spec frontend-ui --retry

# Reset stuck state
/execute-spec frontend-ui --recover
```

## How It Works

This command automates the workflow you would normally do manually:
1. Run `/execute-tasks` for each wave
2. Wait for Claude Code bot review
3. Run `/pr-review-cycle` to address feedback
4. Merge the PR
5. Clean up the wave branch
6. Advance to next wave

### State Machine

```
/execute-spec [spec]
        ↓
┌───────────────────────────────────────────────────────────────┐
│  INIT → Load state or initialize new execution                │
└───────────────────────────────────────────────────────────────┘
        ↓
┌───────────────────────────────────────────────────────────────┐
│  EXECUTE → Run /execute-tasks for current wave                │
│           Creates PR via Phase 3                              │
└───────────────────────────────────────────────────────────────┘
        ↓
┌───────────────────────────────────────────────────────────────┐
│  AWAITING_REVIEW → Poll for Claude Code bot review            │
│                   (default: background polling)               │
│                   (--manual: user invokes to check)           │
└───────────────────────────────────────────────────────────────┘
        ↓
┌───────────────────────────────────────────────────────────────┐
│  REVIEW_PROCESSING → Run /pr-review-cycle                     │
│                     Address blocking issues                   │
│                     Capture future items                      │
└───────────────────────────────────────────────────────────────┘
        ↓
┌───────────────────────────────────────────────────────────────┐
│  READY_TO_MERGE → Execute merge                               │
│                  Wave PRs: Auto-merge to feature branch       │
│                  Final PR: User confirmation for main merge   │
│                  Cleanup wave branch                          │
└───────────────────────────────────────────────────────────────┘
        ↓
        ├── Next wave exists → Back to EXECUTE
        │
        └── All waves complete → COMPLETED 🎉
```

## Merge Strategy

| PR Type | Target Branch | Merge Behavior |
|---------|---------------|----------------|
| Wave PR | `feature/[spec]` | Auto-merge (reversible) |
| Final PR | `main` | User confirmation required |

Wave branches (e.g., `feature/auth-wave-1`) merge to the base feature branch, not main. Only the final wave triggers a merge to main, which requires explicit user confirmation.

## Example Session

### Default Behavior (Background Polling)

```bash
> /execute-spec frontend-ui

Starting wave 1 of 4. Executing tasks...
[executes wave 1, creates PR #123]

PR #123 created. Polling for bot review (2 min intervals, max 30 min)...
[polling in background]

Bot reviewed at 10:05. Processing feedback...
[runs pr-review-cycle]

2 blocking issues found. Implementing fixes...
[implements fixes, pushes]

Fixes pushed. Re-polling for updated review...
[polls again]

PR #123 approved! Auto-merging to feature/frontend-ui...
[merges, cleans branch]

Wave 1 complete. Starting wave 2 of 4...
[continues to wave 2]
```

### With `--manual` (Manual Polling)

```bash
> /execute-spec frontend-ui --manual

Starting wave 1 of 4. Executing tasks...
[executes wave 1, creates PR #123]

PR #123 created. Run /execute-spec frontend-ui to check status.

> /execute-spec frontend-ui

Checking PR #123 status...
Bot has reviewed. Processing feedback...
[processes feedback, implements fixes]

Fixes pushed. Run /execute-spec frontend-ui to continue.

> /execute-spec frontend-ui

PR #123 approved! Auto-merging to feature/frontend-ui...
Wave 1 complete. Advancing to wave 2...
```

### Final Wave (Merge to Main)

```bash
> /execute-spec frontend-ui

Wave 4 of 4 complete. PR #130 approved.
This is the FINAL wave - PR targets main.

Confirm merge to main? [Yes, merge / No, wait]

> Yes, merge

Merged to main! Cleaning up feature/frontend-ui branch.
Spec frontend-ui is complete! 🎉
```

## For Claude Code

### Step 1: Parse Arguments

```javascript
const args = parse_command_args()

const spec_name = args[0]  // Required
const flags = {
  manual: args.includes('--manual'),  // Default is background polling; --manual disables it
  status: args.includes('--status'),
  retry: args.includes('--retry'),
  recover: args.includes('--recover')
}

if (!spec_name) {
  INFORM: "Usage: /execute-spec <spec_name> [--manual] [--status] [--retry] [--recover]"
  EXIT
}
```

### Step 2: Handle --status Flag

```bash
if flags.status:
  STATUS=$(bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/execute-spec-operations.sh" status [spec_name])

  if [ "$(echo "$STATUS" | jq -r '.exists')" = "false" ]; then
    INFORM: "No execution in progress for [spec_name]. Run /execute-spec [spec_name] to start."
    EXIT
  fi

  # Display formatted status
  PHASE=$(echo "$STATUS" | jq -r '.phase')
  WAVE=$(echo "$STATUS" | jq -r '.current_wave')
  TOTAL=$(echo "$STATUS" | jq -r '.total_waves')
  PR=$(echo "$STATUS" | jq -r '.pr_number // "N/A"')

  INFORM: "
  Execute Spec Status: [spec_name]
  ─────────────────────────────────
  Phase: $PHASE
  Wave: $WAVE of $TOTAL
  PR: #$PR
  Last Updated: $(echo "$STATUS" | jq -r '.updated_at')
  "
  EXIT
```

### Step 3: Handle --recover Flag

```bash
if flags.recover:
  bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/execute-spec-operations.sh" delete [spec_name]
  INFORM: "State reset. Starting fresh..."
  # Continue to initialization
```

### Step 4: Handle --retry Flag

```bash
if flags.retry:
  bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/execute-spec-operations.sh" reset [spec_name]
  INFORM: "Retrying current wave..."
  # Continue to orchestration
```

### Step 5: Spawn Orchestrator Agent

```javascript
// Spawn the execute-spec-orchestrator agent to handle the state machine
Task({
  subagent_type: "execute-spec-orchestrator",
  prompt: `Execute spec: ${spec_name}

Input:
{
  "spec_name": "${spec_name}",
  "flags": {
    "manual": ${flags.manual},
    "status": false,
    "retry": ${flags.retry},
    "recover": ${flags.recover}
  }
}

Instructions:
1. Load or initialize execution state
2. Determine current phase
3. Execute appropriate action for phase
4. Update state and report progress
5. Unless --manual mode, poll for review in background
6. Continue until wave complete or user intervention needed
`
})
```

### Step 6: Handle Orchestrator Result

```javascript
// Process result from orchestrator
if (result.status === "completed") {
  INFORM: `🎉 Spec ${spec_name} execution complete!`
} else if (result.status === "waiting") {
  INFORM: `${result.message}\n\nRun /execute-spec ${spec_name} to continue.`
} else if (result.status === "failed") {
  INFORM: `❌ Execution failed: ${result.message}\n\nRun /execute-spec ${spec_name} --retry to retry.`
}
```

## State File

Execution state is persisted at: `.agent-os/state/execute-spec-[spec_name].json`

```json
{
  "spec_name": "frontend-ui",
  "current_wave": 2,
  "total_waves": 4,
  "phase": "AWAITING_REVIEW",
  "pr_number": 125,
  "review_status": {
    "bot_reviewed": false,
    "poll_count": 3
  },
  "history": [
    {
      "wave": 1,
      "pr_number": 123,
      "merged_at": "2025-12-30T15:00:00Z"
    }
  ]
}
```

## Error Handling

| Error | Recovery |
|-------|----------|
| Task execution fails | Stops cycle. Fix issues, run `--retry` |
| PR creation fails | Stops cycle. Check git status, run `--retry` |
| Review timeout (30 min) | Exits polling. Check PR manually |
| Merge conflict | Stops cycle. Resolve conflict, run `--retry` |
| Stuck state | Run `--recover` to reset |

## Safety Guarantees

1. **Wave PRs never merge to main** - Only to base feature branch
2. **Final PR always requires confirmation** - Before merging to main
3. **Bot review always required** - No skip option
4. **Task failures halt cycle** - No partial PRs

## Related Commands

- `/execute-tasks` - Execute single wave (called internally)
- `/pr-review-cycle` - Process PR feedback (called internally)
- `/create-tasks` - Create tasks from spec (prerequisite)
