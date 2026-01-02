# Execute Spec (v4.6.0)

Automate the complete spec execution cycle: execute waves → create PR → wait for review → process feedback → merge → advance to next wave. Repeat until the entire spec is complete.

## Parameters
- `spec_name` (required): Specification folder name
- `--status`: Show current execution state without taking action
- `--retry`: Restart entire wave after fixing failed tasks
- `--recover`: Reset stuck state and start fresh

## Quick Start

```bash
# Start executing a spec
/execute-spec frontend-ui

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

### Context Isolation Architecture (v4.6.0)

To prevent context exhaustion across multi-wave specs, we use a **wave-level agent** pattern:

```
/execute-spec [spec]
│
└── execute-spec-orchestrator (lightweight coordinator)
    │
    ├── Wave 1: wave-lifecycle-agent
    │   └── EXECUTE → AWAIT_REVIEW → PROCESS_REVIEW → MERGE
    │   └── Context preserved within wave (~4-5 KB)
    │
    ├── Wave 2: wave-lifecycle-agent (fresh context)
    │   └── EXECUTE → AWAIT_REVIEW → PROCESS_REVIEW → MERGE
    │
    └── ... until all waves complete
```

**Benefits:**
- **Context preserved within wave**: PR creation, review feedback, and merge decisions share context
- **Context isolated between waves**: Each wave agent gets fresh context
- **No OOM**: Multi-wave specs work because waves don't accumulate

### State Machine

```
/execute-spec [spec]
        ↓
┌───────────────────────────────────────────────────────────────┐
│  INIT → Load state or initialize new execution                │
└───────────────────────────────────────────────────────────────┘
        ↓
┌───────────────────────────────────────────────────────────────┐
│  For each wave: Spawn wave-lifecycle-agent                    │
│                                                               │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │  EXECUTE → Run /execute-tasks, create PR                │  │
│  └─────────────────────────────────────────────────────────┘  │
│                         ↓                                     │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │  AWAIT_REVIEW → Poll for Claude Code bot review         │  │
│  │                 (internal loop, max 30 min)             │  │
│  └─────────────────────────────────────────────────────────┘  │
│                         ↓                                     │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │  PROCESS_REVIEW → Run /pr-review-cycle                  │  │
│  │                   If commits → back to AWAIT_REVIEW     │  │
│  └─────────────────────────────────────────────────────────┘  │
│                         ↓                                     │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │  MERGE → Wave PR: Auto-merge to feature branch          │  │
│  │          Final PR: User confirmation for main merge     │  │
│  └─────────────────────────────────────────────────────────┘  │
│                                                               │
│  Wave agent returns → Orchestrator advances to next wave      │
└───────────────────────────────────────────────────────────────┘
        ↓
  All waves complete → COMPLETED 🎉
```

## Merge Strategy

| PR Type | Target Branch | Merge Behavior |
|---------|---------------|----------------|
| Wave PR | `feature/[spec]` | Auto-merge (reversible) |
| Final PR | `main` | User confirmation required |

Wave branches (e.g., `feature/auth-wave-1`) merge to the base feature branch, not main. Only the final wave triggers a merge to main, which requires explicit user confirmation.

## Example Session

### Typical Workflow

The orchestrator handles the entire spec automatically. You can check status anytime:

```bash
> /execute-spec frontend-ui

Starting execution of spec "frontend-ui"...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  WAVE 1 of 4
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Starting wave 1 of 4...
[executes wave 1, creates PR #123]
PR #123 created. Waiting for bot review...
Poll 1/15: No review yet. Waiting 120s...
Poll 2/15: No review yet. Waiting 120s...
Bot reviewed PR #123. Processing feedback...
[processes review, fixes issues]
Made 2 commit(s). Waiting for re-review...
[continues polling...]
PR #123 approved! Ready to merge.
Auto-merging wave PR #123 to feature/frontend-ui...
Wave 1 merged successfully!
Wave 1 complete. Advancing to wave 2...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  WAVE 2 of 4
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[continues automatically...]
```

### Review Timeout

If review polling times out, you'll be prompted to check manually:

```bash
> /execute-spec frontend-ui

⏱️ Review timeout for wave 2. Check PR #124 manually.
Re-run /execute-spec frontend-ui when review is available.
```

### Final Wave (Merge to Main)

```bash
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  WAVE 4 of 4 (FINAL)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PR #130 approved! Ready to merge.
This is the FINAL wave. PR will merge to main. Confirm merge?
[Yes, merge to main / No, wait]

> Yes, merge to main

Wave 4 merged successfully!

🎉 Spec "frontend-ui" is complete! All 4 waves merged.
```

## For Claude Code

### Step 1: Parse Arguments

```javascript
const args = parse_command_args()

const spec_name = args[0]  // Required
const flags = {
  status: args.includes('--status'),
  retry: args.includes('--retry'),
  recover: args.includes('--recover')
}

if (!spec_name) {
  INFORM: "Usage: /execute-spec <spec_name> [--status] [--retry] [--recover]"
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
  # Continue to orchestration
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
// Spawn the execute-spec-orchestrator agent to coordinate waves
Task({
  subagent_type: "execute-spec-orchestrator",
  prompt: `Execute spec: ${spec_name}

Input:
{
  "spec_name": "${spec_name}",
  "flags": {
    "status": false,
    "retry": ${flags.retry},
    "recover": ${flags.recover}
  }
}

Instructions:
1. Load or initialize execution state
2. For each wave: spawn wave-lifecycle-agent
3. Wait for wave completion, then advance
4. Return when spec is complete or error occurs
`
})
```

### Step 6: Handle Orchestrator Result

```javascript
// Process result from orchestrator
if (result.status === "completed") {
  INFORM: `🎉 Spec ${spec_name} execution complete!`
} else if (result.status === "timeout") {
  INFORM: `⏱️ Review timeout at wave ${result.wave}. Check PR #${result.pr_number} manually.\n\nRe-run: /execute-spec ${spec_name}`
} else if (result.status === "waiting") {
  INFORM: `⏸️ Execution paused.\n\nRun /execute-spec ${spec_name} when ready to continue.`
} else if (result.status === "failed") {
  INFORM: `❌ Execution failed at wave ${result.wave}: ${result.error}\n\nRun /execute-spec ${spec_name} --retry to retry.`
}
```

## State File

Execution state is persisted at: `.agent-os/state/execute-spec-[spec_name].json`

```json
{
  "spec_name": "frontend-ui",
  "current_wave": 2,
  "total_waves": 4,
  "phase": "EXECUTE",
  "pr_number": null,
  "review_status": {
    "bot_reviewed": false,
    "poll_count": 0
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
| Review timeout (30 min) | Exits polling. Check PR manually, re-run |
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
