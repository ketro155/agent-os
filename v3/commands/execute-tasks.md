# Execute Tasks (v5.5.0)

Execute tasks from a specification with **flat team orchestration** and **visible split-pane teammates**.

## Parameters
- `spec_name` (required): Specification folder name
- `tasks` (optional): Specific task IDs, "all", or "next" (default: "next")
- `--status`: Show current state without executing
- `--retry`: Reset current wave and restart
- `--recover`: Delete state and start fresh

## Quick Start

```bash
# Execute next pending task (recommended)
/execute-tasks auth-feature

# Execute all pending tasks
/execute-tasks auth-feature tasks:all

# Check status
/execute-tasks auth-feature --status
```

## Architecture (v5.5.0)

The main session is the **team lead**. Teammates are visible in split-panes (`Shift+Down` to cycle).

```
main session (team lead, orchestrated by this command)
  |
  +-- Task(phase1-discovery)          <-- quick subagent, returns task list
  |
  +-- TeamCreate("wave-1")            <-- main session creates team
  |   +-- phase2-impl-A               <-- VISIBLE PANE
  |   +-- phase2-impl-B               <-- VISIBLE PANE
  |   +-- code-reviewer               <-- VISIBLE PANE (if enabled)
  |
  +-- Wave 1 verify --> TeamDelete
  +-- TeamCreate("wave-2")
  |   +-- ...more visible teammates
  |
  +-- All waves done --> TeamDelete
  +-- Task(phase3-delivery)           <-- subagent for PR creation
  +-- review-watcher teammate         <-- VISIBLE PANE
```

**Key change from v4.1**: No nested orchestrator agents. The main session drives TeamCreate, monitors teammates, and verifies artifacts directly. This eliminates 3 intermediary agents (execute-spec-orchestrator, wave-lifecycle-agent, wave-orchestrator) and makes every teammate visible in split-pane mode.

## For Claude Code

### Step 0: Auto-Promote Future Tasks (MANDATORY)

> MUST RUN BEFORE PHASE 1 - Promotes backlog items from PR reviews into the current wave.

```bash
SPEC_NAME="[spec_name]"
NEXT_WAVE=$(bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/task-operations.sh" status "$SPEC_NAME" | jq -r '
  .next_task.wave //
  (.tasks | map(select(.status == "pending")) | first | .wave) //
  empty
')

FUTURE_COUNT=$(bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/task-operations.sh" list-future "$SPEC_NAME" | jq -r --arg w "wave_$NEXT_WAVE" '
  [.future_tasks[] | select(.priority == $w)] | length
')

if [ "$FUTURE_COUNT" -gt 0 ]; then
  INFORM: "Auto-promoting $FUTURE_COUNT future tasks to wave $NEXT_WAVE..."
  bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/task-operations.sh" promote-wave "$NEXT_WAVE" "$SPEC_NAME"
fi
```

### Step 1: Phase 1 Discovery (Subagent)

```javascript
const discovery = Task({
  subagent_type: "phase1-discovery",
  prompt: `Analyze tasks for spec: ${spec_name}
           Requested tasks: ${tasks}
           Return execution configuration.`
})

const config = JSON.parse(discovery)

if (config.tasks_to_execute.length === 0) {
  INFORM: "All tasks complete! Suggest: Create new spec or review PR."
  RETURN
}
```

### Step 2: Confirm Execution Mode (if multi-task)

```javascript
if (config.tasks_to_execute.length > 1 && config.parallel_config) {
  const answer = AskUserQuestion({
    questions: [{
      question: "How would you like to execute these tasks?",
      header: "Execution Mode",
      options: [
        { label: "Parallel Waves (Teams)", description: "Visible split-pane teammates, ~1.5x faster" },
        { label: "Single Task", description: "Most reliable, one at a time" }
      ]
    }]
  })
}
```

### Step 3: Handle Flags

```javascript
if (flags.status) {
  const state = bash `${CLAUDE_PROJECT_DIR}/.claude/scripts/execute-spec-operations.sh status ${spec_name}`
  INFORM: `Status:\n${state}`
  RETURN
}
if (flags.retry) {
  bash `${CLAUDE_PROJECT_DIR}/.claude/scripts/execute-spec-operations.sh reset ${spec_name}`
}
if (flags.recover) {
  bash `${CLAUDE_PROJECT_DIR}/.claude/scripts/execute-spec-operations.sh delete ${spec_name}`
}
```

### Step 4: Initialize Execution State

```javascript
// Initialize state if fresh start
const STATE = bash `${CLAUDE_PROJECT_DIR}/.claude/scripts/execute-spec-operations.sh status ${spec_name}`
const stateData = JSON.parse(STATE)

if (!stateData.exists) {
  bash `${CLAUDE_PROJECT_DIR}/.claude/scripts/execute-spec-operations.sh init ${spec_name}`
  bash `${CLAUDE_PROJECT_DIR}/.claude/scripts/execute-spec-operations.sh transition ${spec_name} EXECUTE`
}

// Run parallel analysis
const PARALLEL_ANALYSIS = bash `npx tsx "${CLAUDE_PROJECT_DIR}/.claude/scripts/wave-parallel.ts" analyze \
  "${CLAUDE_PROJECT_DIR}/.agent-os/specs/${spec_name}/tasks.json"`

const analysis = JSON.parse(PARALLEL_ANALYSIS)
const TOTAL_WAVES = analysis.waves.length
let CURRENT_WAVE = stateData.current_wave || 1

// Determine base branch
const branch_info = bash `${CLAUDE_PROJECT_DIR}/.claude/scripts/branch-setup.sh pr-target`
const base_branch = JSON.parse(branch_info).base_branch || "main"

INFORM: `Parallel analysis: ${TOTAL_WAVES} waves, ~${analysis.estimated_speedup}x speedup`
```

### Step 5: Single Task Mode

For a single task, skip team orchestration:

```javascript
if (config.execution_mode === "single") {
  Task({
    subagent_type: "phase2-implementation",
    prompt: `Execute task: ${config.tasks_to_execute[0]}
             Context: ${JSON.stringify(config.task_context)}
             Return structured result with artifacts.`
  })
  // Skip to Step 9 (Phase 3)
}
```

### Step 6: Wave Loop (Main Session as Team Lead)

> CRITICAL: This is the core orchestration loop. The main session creates teams,
> spawns visible teammates, monitors artifacts, and verifies results.

```javascript
const TEAMS_ENABLED = process.env.AGENT_OS_TEAMS === 'true'
const CODE_REVIEW_ENABLED = process.env.AGENT_OS_CODE_REVIEW === 'true'
const MAX_TEAMMATES = parseInt(process.env.AGENT_OS_MAX_TEAMMATES || '5')
let predecessorArtifacts = { verified: true }

WAVE_LOOP: while (CURRENT_WAVE <= TOTAL_WAVES) {
  const is_final_wave = (CURRENT_WAVE === TOTAL_WAVES)
  const wave_config = analysis.waves.find(w => w.wave_id === CURRENT_WAVE) || {
    tasks: [], can_parallel: false, isolation_score: 1.0
  }

  INFORM: `\n--- WAVE ${CURRENT_WAVE} of ${TOTAL_WAVES}${is_final_wave ? " (FINAL)" : ""} ---`
  INFORM: `Tasks: ${wave_config.tasks.join(', ')} | Parallel: ${wave_config.can_parallel}`
```

#### Step 6a: Verify Predecessor Artifacts (MANDATORY)

```javascript
  // BLOCKING GATE - Cannot proceed without verification
  if (CURRENT_WAVE > 1) {
    for (const exp of predecessorArtifacts.exports_added || []) {
      const found = bash `grep -rq "export.*${exp}" src/ && echo "found" || echo "missing"`
      if (found.trim() !== "found") {
        INFORM: `BLOCKED: Missing predecessor export: ${exp}`
        bash `${CLAUDE_PROJECT_DIR}/.claude/scripts/execute-spec-operations.sh fail ${spec_name} "Missing export: ${exp}"`
        RETURN: { status: "blocked", wave: CURRENT_WAVE, blocker: `Missing export: ${exp}` }
      }
    }
    for (const file of predecessorArtifacts.files_created || []) {
      const found = bash `[ -f "${file}" ] && echo "found" || echo "missing"`
      if (found.trim() !== "found") {
        INFORM: `BLOCKED: Missing predecessor file: ${file}`
        RETURN: { status: "blocked", wave: CURRENT_WAVE, blocker: `Missing file: ${file}` }
      }
    }
  }
```

#### Step 6b: Granularity Selection

```javascript
  // Determine task-level vs group-level parallelism (v5.2.0 logic, absorbed from wave-orchestrator)
  const SPEC_FOLDER = `.agent-os/specs/${spec_name}/`
  const tasks_raw = bash `jq -c '[
    .tasks[] | select(.id as $id | ${JSON.stringify(wave_config.tasks)} | index($id))
    | { id: .id, description: (.description // .title), subtasks: [.subtasks[]?.id],
        context_summary: (.context_summary // {}),
        subtask_execution: (.subtask_execution // null),
        isolation_score: (.isolation_score // 1.0) }
  ]' "${SPEC_FOLDER}tasks.json"`
  const tasks = JSON.parse(tasks_raw)

  const hasParallelGroups = tasks.some(t =>
    t.subtask_execution?.mode === "parallel_groups" && t.subtask_execution?.groups?.length > 1
  )

  let granularity = "task_level"
  if (hasParallelGroups && tasks.every(t =>
    t.subtask_execution?.mode === "parallel_groups" && t.subtask_execution?.groups?.length > 1
  )) granularity = "group_level"
  else if (hasParallelGroups) granularity = "hybrid"

  // Dynamic teammate cap from isolation_score
  const avgIsolation = tasks.reduce((sum, t) => sum + (t.isolation_score || 1), 0) / tasks.length
  let cap
  if (avgIsolation >= 0.95) cap = Math.min(tasks.length, MAX_TEAMMATES, 5)
  else if (avgIsolation >= 0.80) cap = Math.min(tasks.length, MAX_TEAMMATES, 3)
  else if (avgIsolation >= 0.60) cap = Math.min(tasks.length, MAX_TEAMMATES, 2)
  else cap = 1
```

#### Step 6c: Create Team and Spawn Teammates

```javascript
  if (TEAMS_ENABLED && cap > 1) {
    const team_name = `wave-${spec_name}-${CURRENT_WAVE}`
    TeamCreate({ team_name, description: `Wave ${CURRENT_WAVE} for ${spec_name}` })

    // Create shared tasks
    for (const task of tasks) {
      TaskCreate({
        subject: `Task ${task.id}: ${task.description}`,
        description: JSON.stringify({
          task_id: task.id, subtasks: task.subtasks,
          context_summary: task.context_summary,
          predecessor_artifacts: predecessorArtifacts
        }),
        activeForm: `Implementing task ${task.id}`
      })
    }

    // Spawn implementation teammates (VISIBLE in split-panes)
    const agentType = (granularity === "task_level") ? "phase2-implementation" : "subtask-group-worker"
    const namePrefix = (agentType === "phase2-implementation") ? "impl" : "group"
    const teammates = []

    for (let i = 0; i < cap; i++) {
      const teammate = Task({
        subagent_type: agentType,
        team_name: team_name,
        name: `${namePrefix}-${i}`,
        prompt: `You are a teammate in wave team "${team_name}".

INSTRUCTIONS:
1. Use TaskList to find available (unblocked, unowned) tasks
2. Claim a task with TaskUpdate (set owner to your name)
3. Implement using TDD: RED -> GREEN -> REFACTOR
4. After each commit, broadcast artifacts via SendMessage:
   SendMessage({ type: "message", recipient: "${team_name}",
     content: JSON.stringify({
       event: "artifact_created", task_id: "...",
       files_created: [...], exports_added: [...], functions_created: [...]
     }), summary: "Task X artifacts ready" })
5. Mark task completed with TaskUpdate
6. Check TaskList for more available tasks
7. When no tasks remain, go idle

PREDECESSOR ARTIFACTS (VERIFIED):
${JSON.stringify(predecessorArtifacts)}
`
      })
      teammates.push(teammate)
    }

    // Spawn code-reviewer (utility, exempt from cap)
    if (CODE_REVIEW_ENABLED) {
      Task({
        subagent_type: "code-reviewer",
        team_name: team_name,
        name: "code-reviewer",
        prompt: `You are the code-reviewer in wave team "${team_name}".
Wait for artifact_for_review messages. Review for code smells, secrets, spec compliance.
Send findings via SendMessage to the team lead. Go idle between reviews.`
      })
    }
```

#### Step 6d: Monitor Artifacts and Validate

```javascript
    // Monitor: team lead receives artifact_created messages
    // For each received artifact:
    function onArtifactMessage(message) {
      const artifact = JSON.parse(message.content)

      // Pre-check: verify files exist
      for (const file of artifact.files_created || []) {
        const exists = bash `[ -f "${file}" ] && echo "found" || echo "missing"`
        if (exists.trim() !== "found") {
          SendMessage({ type: "message", recipient: message.sender,
            content: `Pre-check failed: File "${file}" not found. Fix before completing task.`,
            summary: `Fix missing file: ${file}` })
        }
      }
      // Pre-check: verify exports
      for (const exp of artifact.exports_added || []) {
        const exists = bash `grep -rq "export.*${exp}" src/ && echo "found" || echo "missing"`
        if (exists.trim() !== "found") {
          SendMessage({ type: "message", recipient: message.sender,
            content: `Pre-check failed: Export "${exp}" not found.`,
            summary: `Fix missing export: ${exp}` })
        }
      }

      // Relay to code-reviewer if enabled
      if (CODE_REVIEW_ENABLED) {
        SendMessage({ type: "message", recipient: "code-reviewer",
          content: JSON.stringify({
            event: "artifact_for_review",
            source_task: artifact.task_id,
            source_teammate: message.sender,
            files_created: artifact.files_created || [],
            exports_added: artifact.exports_added || []
          }), summary: `Review artifact from ${message.sender}` })
      }
    }
```

#### Step 6e: Collect Results and Cleanup Wave

```javascript
    // Wait for all shared tasks to be completed
    // (Monitor TaskList until all tasks show status: completed)

    // Shutdown code-reviewer
    if (CODE_REVIEW_ENABLED) {
      SendMessage({ type: "shutdown_request", recipient: "code-reviewer",
        content: "All tasks complete, Tier 1 review done" })

      // Invoke code-validator for deep Tier 2 review
      const changedFiles = bash `git diff --name-only ${base_branch}...HEAD`
      const deepReview = Task({
        subagent_type: "code-validator",
        prompt: `Deep code review for wave ${CURRENT_WAVE} of ${spec_name}.
CHANGED FILES: ${changedFiles}
SPEC FOLDER: ${SPEC_FOLDER}
Focus: design patterns, OWASP security, spec compliance, cross-task consistency.
Return structured findings JSON.`
      })
    }

    // Shutdown implementation teammates
    for (const mate of teammates) {
      SendMessage({ type: "shutdown_request", recipient: mate.name, content: "Wave complete" })
    }
    TeamDelete()

  } else {
    // Legacy / sequential mode: Task() with run_in_background
    for (const task of tasks) {
      const result = Task({
        subagent_type: "phase2-implementation",
        prompt: `Execute task ${task.id} for spec ${spec_name}.
Context: ${JSON.stringify(task.context_summary)}
Predecessor artifacts: ${JSON.stringify(predecessorArtifacts)}
Return: { task_id, status, artifacts }`
      })
    }
  }
```

#### Step 6f: Verify Wave Artifacts (Ralph Pattern)

```javascript
  // BLOCKING GATE - verify artifacts before advancing to next wave
  const waveArtifacts = { exports_added: [], files_created: [], functions_created: [], commits: [] }

  for (const task of tasks) {
    const taskResult = bash `jq -c '.tasks[] | select(.id == "${task.id}") | .artifacts // {}' "${SPEC_FOLDER}tasks.json"`
    const artifacts = JSON.parse(taskResult || '{}')

    for (const file of artifacts.files_created || []) {
      if (bash(`[ -f "${file}" ] && echo "found" || echo "missing"`).trim() === "found") {
        waveArtifacts.files_created.push(file)
      }
    }
    for (const exp of artifacts.exports_added || []) {
      if (bash(`grep -rq "export.*${exp}" src/ && echo "found" || echo "missing"`).trim() === "found") {
        waveArtifacts.exports_added.push(exp)
      }
    }
  }

  predecessorArtifacts = { verified: true, ...waveArtifacts }
  INFORM: `Wave ${CURRENT_WAVE} verified: ${waveArtifacts.files_created.length} files, ${waveArtifacts.exports_added.length} exports`
```

#### Step 6g: Advance Wave

```javascript
  bash `${CLAUDE_PROJECT_DIR}/.claude/scripts/execute-spec-operations.sh advance-wave ${spec_name}`

  if (is_final_wave) {
    bash `${CLAUDE_PROJECT_DIR}/.claude/scripts/execute-spec-operations.sh transition ${spec_name} COMPLETED`
    INFORM: `All ${TOTAL_WAVES} waves complete!`
    break WAVE_LOOP
  }

  CURRENT_WAVE++
  continue WAVE_LOOP
}
```

### Step 7: Completion Gate (MANDATORY)

```
CHECKLIST before Phase 3:

- All waves completed or partial completion acceptable
- All task statuses updated in tasks.json
- Artifact chain verified

IF any task blocked or failed:
  -> Log blockers
  -> Still proceed to Phase 3 (PR includes partial work)

VIOLATION: Ending without Phase 3 = incomplete delivery
```

### Step 8: Smoke E2E Validation (Final Wave Only)

```javascript
if (is_final_wave) {
  const TEST_PLAN = `.agent-os/test-plans/${spec_name}/test-plan.json`
  const plan_exists = bash `test -f "${TEST_PLAN}" && echo "exists" || echo "not_found"`

  if (plan_exists.includes("exists")) {
    INFORM: "Running smoke E2E tests before delivery..."
    const smoke = Task({
      subagent_type: "general-purpose",
      prompt: `Run smoke E2E tests for spec "${spec_name}".
Check .agent-os/test-plans/${spec_name}/.
Return JSON: { status: "pass"|"fail"|"skipped", total_scenarios, passed, failed, failures: [] }`
    })
    const result = JSON.parse(smoke)
    if (result.status === "fail") {
      INFORM: `Smoke E2E failed: ${result.failed}/${result.total_scenarios} scenarios`
      // Continue to Phase 3 but note failures
    }
  }
}
```

### Step 9: Phase 3 Delivery (MANDATORY)

> ALWAYS REQUIRED - Creates the PR. Never skip.

```javascript
Task({
  subagent_type: "phase3-delivery",
  prompt: `Complete delivery for spec: ${spec_name}
           Completed tasks: ${JSON.stringify(completed_tasks)}
           Create PR and documentation.`
})
```

### Step 10: Review Wait (Teams Mode)

```javascript
if (TEAMS_ENABLED) {
  // Spawn review-watcher as visible teammate
  const review_team = `review-${spec_name}`
  TeamCreate({ team_name: review_team, description: `Review watch for ${spec_name}` })

  Task({
    subagent_type: "review-watcher",
    team_name: review_team,
    name: "watcher",
    prompt: JSON.stringify({
      pr_number: pr_number,
      spec_name: spec_name,
      team_lead_name: "main"
    })
  })

  // Wait for review notification via SendMessage
  // When review arrives: spawn pr-review-implementation if needed
  // Cleanup:
  TeamDelete()
}
```

## Task Operations (Shell Script)

All task operations use `"${CLAUDE_PROJECT_DIR}/.claude/scripts/task-operations.sh"`:

```bash
bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/task-operations.sh" status [spec_name]
bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/task-operations.sh" update <task_id> <status> [spec_name]
bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/task-operations.sh" artifacts <task_id> <json> [spec_name]
bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/task-operations.sh" collect-artifacts [since_commit]
```

## Hooks (Automatic)

- **SessionStart**: Loads progress, validates environment
- **PreToolUse (git commit)**: Validates build, tests, types (command + prompt hooks)
- **PostToolUse (Write/Edit)**: Regenerates tasks.md from JSON
- **PreCompact**: Injects wave state before context compaction (v5.5.0)
- **UserPromptSubmit**: Injects active task context (v5.5.0)
- **Stop**: Logs incomplete work on premature exit (v5.5.0)
- **SessionEnd**: Logs session summary, creates checkpoint

## Error Handling

| Error | Action |
|-------|--------|
| Task blocked | Log blocker, continue other tasks, proceed to Phase 3 |
| Tests failing | PreToolUse hook blocks commit, must fix |
| All tasks complete | Inform user, suggest new spec or review |
| Predecessor artifact missing | HALT wave, report blocked status |
| TeamCreate fails | Fall back to legacy Task() mode |
| Teammate unresponsive | shutdown_request + continue |
| Review timeout | Notify user, manual intervention |

## Dependencies

**Required:**
- `.agent-os/specs/[spec]/tasks.json` (v4.0 format)
- `.claude/agents/phase*.md` (Phase 1, 2, 3 subagents)
- `.claude/hooks/*` (validation hooks)
- `.claude/scripts/task-operations.sh` (task management)
- `.claude/scripts/wave-parallel.ts` (dependency analysis)
- `.claude/scripts/execute-spec-operations.sh` (state management)

**For Teams mode:**
- `AGENT_OS_TEAMS=true` + `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`
- `teammateMode: "split-panes"` in settings.json

## Comparison: v4.1 vs v5.5.0

| Aspect | v4.1 | v5.5.0 |
|--------|------|--------|
| Spawn depth | 5 levels | 1 level (main -> teammates) |
| Teammate visibility | Hidden | Split-pane per teammate |
| Orchestrator agents | 3 (1,573 lines) | 0 (logic in command) |
| Context management | Isolated per wave | Main session + PreCompact hook |
| Artifact verification | Same (Ralph pattern) | Same (Ralph pattern) |
| Code review | Same (two-tier) | Same (two-tier) |
| User experience | Wait and hope | Watch live, intervene |
