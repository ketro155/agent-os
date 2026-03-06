---
paths:
  - ".claude/agents/**"
---

# Teams Integration (v5.5.0)

> Native Claude Code Teams integration for Agent OS.
> v5.5.0: Flat hierarchy with split-pane visibility. Main session is the team lead.

## Overview

Agent OS v5.5.0 introduces a **flat orchestration model** where the main session creates teams directly, making every teammate visible in split-pane mode.

```
BEFORE v5.5.0 (5 levels, teammates invisible):
  main -> Task(exec-spec) -> Task(wave-life) -> Task(wave-orch) -> TeamCreate
    -> phase2-impl (HIDDEN)  -> code-reviewer (HIDDEN)

AFTER v5.5.0 (1 level, teammates visible in split-panes):
  main session (team lead, orchestrated by /execute-tasks)
    +-- Task(phase1-discovery)       <-- quick subagent, returns task list
    +-- TeamCreate("wave-1")         <-- main session creates team
    |   +-- phase2-impl-A            <-- VISIBLE PANE (Shift+Down to cycle)
    |   +-- phase2-impl-B            <-- VISIBLE PANE
    |   +-- code-reviewer            <-- VISIBLE PANE (if enabled)
    +-- Wave 1 verify -> TeamDelete
    +-- TeamCreate("wave-2")
    |   +-- ...more visible teammates
    +-- All waves done -> TeamDelete
    +-- Task(phase3-delivery)        <-- subagent for PR creation
    +-- review-watcher               <-- VISIBLE PANE
```

**Key change**: The `/execute-tasks` command drives team creation directly from the main session. No nested orchestrator agents. `teammateMode: "split-panes"` in settings.json enables the visibility.

## Feature Flags

| Variable | Default | Purpose |
|----------|---------|---------|
| `AGENT_OS_TEAMS` | `true` | Enable Teams-based wave coordination |
| `AGENT_OS_MAX_TEAMMATES` | `5` | Maximum concurrent implementation teammates per wave |
| `AGENT_OS_CODE_REVIEW` | `false` | Enable two-tier code review (Sonnet + Opus) |

Set in `.claude/settings.json` under `env`.

## Prerequisite: Claude Code Agent Teams

Agent Teams requires Claude Code v2.1.32+ with the feature flag:

```bash
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
```

Without this flag, Teams tools (TeamCreate, SendMessage, etc.) may not be available. If `AGENT_OS_TEAMS=true` is set but Teams tools are unavailable, the setup hook emits a warning.

## Split-Pane Mode

`teammateMode: "split-panes"` in settings.json gives each teammate its own tmux pane:

- **Shift+Down**: Cycle to next teammate pane
- **Shift+Up**: Cycle to previous teammate pane
- Each pane shows the teammate's live output
- User can observe and intervene in real-time

This only works because teams are created by the **main session** (which owns the terminal). In the old nested architecture, teams were created by subagents that had no terminal access.

## Team Lifecycle

### Wave-Level Teams

```
1.   /execute-tasks reads wave config
2.   TeamCreate("wave-{spec}-{N}")
2.5  Granularity selection: task_level | group_level | hybrid
3.   TaskCreate for each work unit
4.   Spawn implementation teammates (visible in split-panes)
4.5  Spawn code-reviewer if AGENT_OS_CODE_REVIEW=true
5.   Teammates claim tasks via TaskList -> TaskUpdate
6.   Teammates broadcast artifacts via SendMessage
7.   Main session validates artifacts incrementally
7.5  Main session relays artifacts to code-reviewer
8.   All tasks complete -> full Ralph verification
8.5  shutdown_request to code-reviewer -> Task(code-validator)
9.   shutdown_request to all implementation teammates
10.  TeamDelete("wave-{spec}-{N}")
```

### Review Watcher

```
1. Task(phase3-delivery) creates PR
2. TeamCreate("review-{spec}")
3. Spawn review-watcher teammate (visible pane)
4. Wait for message (review found OR timeout)
5. If review received: Task(pr-review-implementation)
6. TeamDelete("review-{spec}")
```

## Artifact Broadcast Protocol

When a teammate creates a file or export that siblings may need:

### Message Schema

```json
{
  "event": "artifact_created",
  "task_id": "3",
  "files_created": ["src/auth/session.ts"],
  "exports_added": ["sessionCreate", "sessionDestroy"],
  "functions_created": ["sessionCreate", "sessionDestroy"]
}
```

### Broadcast Rules

1. **Only broadcast when creating new files or exports**
2. **Include enough detail for siblings to import**
3. **Main session validates on receipt** (file exists? export greps?)
4. **Siblings check broadcasts before re-implementing**

### Pre-Check on Receipt (Main Session)

```bash
for file in message.files_created:
  [ -f "$file" ] || SendMessage(teammate, "File missing: $file")

for export in message.exports_added:
  grep -rq "export.*${export}" src/ || SendMessage(teammate, "Export missing: ${export}")
```

## Granularity Selection (v5.2.0)

| Granularity | Teammate Type | TaskCreate Unit | When |
|-------------|--------------|-----------------|------|
| `task_level` | `phase2-implementation` | One per task | No parallel groups |
| `group_level` | `subtask-group-worker` | One per subtask group | All tasks have parallel groups |
| `hybrid` | Both types | Groups for groupable, tasks for rest | Mix of task types |

### Dynamic Teammate Cap

```
MAX = parseInt(AGENT_OS_MAX_TEAMMATES || '5')

avgIsolation >= 0.95 -> cap = min(workUnits, MAX, 5)
avgIsolation >= 0.80 -> cap = min(workUnits, MAX, 3)
avgIsolation >= 0.60 -> cap = min(workUnits, MAX, 2)
avgIsolation <  0.60 -> cap = 1  (sequential)
```

## Utility Teammate Exemption

Certain teammates serve a utility role and are exempt from `AGENT_OS_MAX_TEAMMATES`:

| Utility Teammate | Purpose | Why Exempt |
|-----------------|---------|------------|
| `code-reviewer` | Tier 1 semantic review | Doesn't consume implementation slots |
| `review-watcher` | PR review polling | Minimal resource (Haiku model) |

## Two-Tier Code Review (v5.4.0)

When `AGENT_OS_CODE_REVIEW=true`:

```
TIER 1 (Sonnet teammate, during execution):
  Main session receives artifact_created
    -> pre-check (file exists?)
    -> relay to code-reviewer teammate
  code-reviewer reviews -> sends findings
    -> main session routes CRITICAL/HIGH to implementer (max 2 fix attempts)

TIER 2 (Opus subagent, at wave end):
  All tasks done -> shutdown code-reviewer
    -> Task(code-validator) with changed files + Tier 1 findings
    -> Deep analysis: design, security, spec, cross-task
    -> Block if unresolved CRITICAL/HIGH
```

### Fix Cycle Bound

```
MAX_REVIEW_FIX_ATTEMPTS = 2 (per finding per task)
Attempt 3+: Finding marked unresolved, escalated to Tier 2
```

## Teammate Restrictions

| Agent (Team Lead) | Allowed Teammates | Context |
|-------------------|-------------------|---------|
| Main session (/execute-tasks) | `phase2-implementation`, `subtask-group-worker`, `code-reviewer`, `review-watcher` | Wave execution + review |

## Worktree Isolation (v5.5.0)

For high-isolation tasks (isolation_score > 0.8), teammates can use `isolation: "worktree"`:

```javascript
Task({
  subagent_type: "phase2-implementation",
  team_name: team_name,
  isolation: "worktree",  // Each teammate gets isolated repo copy
  prompt: "..."
})
```

This eliminates file conflicts between parallel teammates working on different files. Auto-cleanup removes worktrees when teammate finishes.

## Legacy Mode

When `AGENT_OS_TEAMS=false`, execution falls back to sequential `Task()` spawning per task. No teams, no split-panes, no artifact broadcast. Same results, just slower and less visible.

## Error Handling

| Error | Tier | Recovery |
|-------|------|----------|
| TeamCreate fails | RECOVERABLE | Fall back to legacy Task() flow |
| Teammate unresponsive | RECOVERABLE | shutdown_request + re-spawn |
| Message delivery fails | TRANSIENT | Retry up to 3 times |
| TeamDelete fails | RECOVERABLE | Log warning, continue |
| Review-watcher timeout | RECOVERABLE | Notify user, manual intervention |
| code-reviewer crashes | RECOVERABLE | Warn + continue; Tier 2 covers full scope |
| code-validator timeout | RECOVERABLE | Warn + non-blocking pass with PR note |

## Security

- Teammates inherit tool restrictions from their agent definition
- Main session validates artifacts before trusting broadcasts
- `code-reviewer` has defense-in-depth (`disallowedTools`: Write, Edit, Bash)
- Team naming convention (`wave-{spec}-{N}`) prevents cross-spec conflicts

---

## Changelog

### v5.5.0 (2026-03-06)
- **BREAKING**: Flat hierarchy replaces nested orchestrator agents
- Main session is the team lead (no execute-spec-orchestrator, wave-lifecycle-agent, wave-orchestrator)
- `teammateMode: "split-panes"` for visible teammates
- Spawn depth: 5 levels -> 1 level
- Worktree isolation for high-isolation tasks
- Updated diagrams and lifecycle for flat architecture

### v5.4.0 (2026-02-13)
- Two-Tier Code Review Integration (T4.75, T4.8, T5 handoff)
- Utility Teammate Exemption (code-reviewer, review-watcher)
- Fix cycle bound (MAX_REVIEW_FIX_ATTEMPTS=2)

### v5.3.0 (2026-02-12)
- Prerequisite: CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
- TeammateIdle hook for lifecycle metrics

### v5.2.0 (2026-02-12)
- Atomic Teammates: group-level parallelism
- Dynamic teammate cap from isolation_score
- Artifact relay protocol

### v5.1.0 (2026-02-09)
- Initial Teams integration
- Wave-level peer coordination
- Review-watcher teammate
