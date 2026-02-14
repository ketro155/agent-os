---
paths:
  - ".claude/agents/**"
---

# Teams Integration (v5.4.0)

> Native Claude Code Teams integration for peer coordination within Agent OS.
> Enables real-time artifact sharing, message-based review notification, incremental verification, and group-level parallelism.

## Overview

Agent OS v5.1.0 introduces a **hybrid orchestration model**:

- **Teams mode** (`AGENT_OS_TEAMS=true`): Wave-level tasks coordinate as teammates with peer messaging
- **Legacy mode** (`AGENT_OS_TEAMS=false`): Hierarchical `Task()` spawning with `run_in_background` + `TaskOutput` (unchanged)

```
┌─────────────────────────────────────────────────────────────────────┐
│                     HYBRID ORCHESTRATION MODEL                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Cross-wave: Task() spawning (context isolation preserved)          │
│    execute-spec-orchestrator                                        │
│      └── Task(wave-lifecycle-agent) per wave                       │
│                                                                     │
│  Within-wave: Teams (peer coordination enabled)                     │
│    wave-orchestrator (team lead)                                    │
│      ├── phase2-impl-A (teammate) ──SendMessage──┐                 │
│      ├── phase2-impl-B (teammate) ←──────────────┘                 │
│      └── Collects results, runs Ralph verification                 │
│                                                                     │
│  Review wait: Teams (message-based notification)                    │
│    execute-spec-orchestrator                                        │
│      └── review-watcher (teammate) ──SendMessage→ orchestrator     │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Feature Flag

| Variable | Default | Purpose |
|----------|---------|---------|
| `AGENT_OS_TEAMS` | `false` | Enable Teams-based wave coordination and review watching |
| `AGENT_OS_MAX_TEAMMATES` | `5` | Maximum concurrent teammates per wave team (v5.2.0) |
| `AGENT_OS_CODE_REVIEW` | `false` | Enable two-tier code review (Sonnet + Opus) (v5.4.0) |

Set in `.claude/settings.json` under `env`:

```json
{
  "env": {
    "AGENT_OS_TEAMS": "true"
  }
}
```

**Both modes produce identical outputs.** The flag only changes the coordination mechanism, not the task execution or verification logic.

## Prerequisite: Claude Code Agent Teams (v5.3.0)

Agent Teams is a **research preview** feature in Claude Code (v2.1.32+). To use Teams mode, the Claude Code feature flag must be enabled:

```bash
# Set in environment
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1

# Or in ~/.claude.json
# { "experimental": { "agent_teams": true } }
```

Without this flag, `TeamCreate`, `SendMessage`, and other Teams tools may not be available. If `AGENT_OS_TEAMS=true` is set but Teams tools are unavailable, the setup hook emits a warning.

**Note**: Claude Code v2.1.20+ also shows a **PR review status indicator** in the prompt footer (colored dot showing approved/pending/changes-requested). This is complementary to the `review-watcher` agent — the indicator is user-facing, while review-watcher provides programmatic notification within the Teams workflow.

## When to Use Teams vs Task()

```
┌─────────────────────────────────────┐
│  Need peer communication?           │
│  (artifact sharing, notifications)  │
└──────────────┬──────────────────────┘
               │
          YES  │  NO
               │
               ▼
┌──────────────────────┐    ┌─────────────────────────┐
│  Need context        │    │  Use Task()             │
│  isolation?          │    │  (hierarchical spawning) │
│  (cross-wave)        │    └─────────────────────────┘
└──────────────────────┘
       │           │
      YES          NO
       │           │
       ▼           ▼
┌──────────┐  ┌──────────────────┐
│ Task()   │  │ Teams            │
│ (waves   │  │ (within-wave     │
│ stay     │  │  coordination)   │
│ isolated)│  └──────────────────┘
└──────────┘
```

### Decision Summary

| Scenario | Mechanism | Rationale |
|----------|-----------|-----------|
| Cross-wave orchestration | `Task()` | Context isolation between waves is critical |
| Within-wave task coordination | **Teams** | Peers share artifacts in real-time |
| Within-wave group coordination | **Teams** (v5.2) | Group workers share artifacts with lighter context |
| PR review waiting | **Teams** | Message notification replaces sleep loop |
| PR review cycle (discovery + impl) | `Task()` | Inherently sequential — no peer benefit |
| Hooks, state machine, TDD | No change | Orthogonal to coordination mechanism |

## Team Lifecycle

### Wave-Level Teams

```
1.   TeamCreate("wave-{spec}-{N}")
1.5  Choose granularity: task_level | group_level | hybrid (v5.2.0)
2.   TaskCreate for each work unit (task or subtask group)
3.   Spawn teammates (phase2-implementation or subtask-group-worker)
3.5  Spawn code-reviewer teammate if AGENT_OS_CODE_REVIEW=true (v5.4.0)
4.   Teammates claim tasks via TaskList → TaskUpdate
5.   Teammates broadcast artifacts via SendMessage
5.5  Team lead relays verified artifacts to sibling teammates (v5.2.0)
5.75 Team lead relays artifacts to code-reviewer for Tier 1 review (v5.4.0)
6.   Team lead validates artifacts incrementally
6.5  Team lead routes blocking findings to implementing teammate (v5.4.0)
7.   All tasks complete → full Ralph verification
7.5  shutdown_request to code-reviewer → invoke code-validator via Task() (v5.4.0)
8.   shutdown_request to all implementation teammates
9.   TeamDelete("wave-{spec}-{N}")
```

### Review Watcher Teams

```
1. TeamCreate("review-{spec}-{N}")
2. Spawn review-watcher teammate with PR number
3. Wait for message (review found OR timeout)
4. Re-invoke wave-lifecycle-agent with resume
5. shutdown_request to review-watcher
6. TeamDelete("review-{spec}-{N}")
```

## Artifact Broadcast Protocol

When a teammate creates a file or export that siblings may need, it broadcasts an artifact message:

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

1. **Only broadcast when creating new files or exports** — don't broadcast for internal modifications
2. **Include enough detail for siblings to import** — file paths and export names
3. **Team lead validates on receipt** — lightweight pre-check (file exists? export greps?)
4. **Siblings check broadcasts before re-implementing** — prevents duplicate utility functions

### Pre-Check on Receipt (Team Lead)

When the wave-orchestrator receives an artifact broadcast:

```bash
# Lightweight validation
for file in message.files_created:
  [ -f "$file" ] || SendMessage(teammate, "File missing: $file, fix before completing")

for export in message.exports_added:
  grep -rq "export.*${export}" src/ || SendMessage(teammate, "Export missing: ${export}")
```

If pre-check fails, the team lead sends a fix request message. The teammate wakes, fixes, and re-broadcasts. Full Ralph verification remains the final gate.

## Atomic Teammates: Group-Level Parallelism (v5.2.0)

v5.2.0 introduces **group-level teammates**: instead of one heavyweight `phase2-implementation` teammate per task, the wave-orchestrator can spawn lightweight `subtask-group-worker` teammates, each handling a single subtask group scoped to specific files.

```
┌─────────────────────────────────────────────────────────────────────┐
│                    ATOMIC TEAMMATES (v5.2.0)                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  v5.1 (task-level):                                                 │
│    wave-orchestrator (team lead)                                    │
│      ├── phase2-impl-0 (task 3 → 4 subtasks, heavy context)       │
│      └── phase2-impl-1 (task 4 → 3 subtasks, heavy context)       │
│                                                                     │
│  v5.2 (group-level):                                                │
│    wave-orchestrator (team lead)                                    │
│      ├── group-0 (task 3, group 1 → 2 subtasks, light context)    │
│      ├── group-1 (task 3, group 2 → 2 subtasks, light context)    │
│      ├── group-2 (task 4, group 1 → 2 subtasks, light context)    │
│      └── group-3 (task 4, group 2 → 1 subtask, light context)     │
│                                                                     │
│  Key: each group worker is scoped to files_affected — no conflicts  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Granularity Decision Tree

```
┌─────────────────────────────────────────┐
│  Any tasks have parallel_groups         │
│  with groups.length > 1?               │
└──────────────────┬──────────────────────┘
                   │
              NO   │   YES
                   │
                   ▼
┌──────────────┐  ┌────────────────────────────────────────┐
│ task_level   │  │  ALL tasks have parallel_groups?       │
│ (v5.1)       │  └──────────────────┬─────────────────────┘
└──────────────┘             YES     │     NO
                                     │
                              ┌──────┴──────┐
                              │             │
                              ▼             ▼
                        ┌──────────┐  ┌──────────┐
                        │ group_   │  │ hybrid   │
                        │ level    │  │          │
                        └──────────┘  └──────────┘
```

| Granularity | Teammate Type | TaskCreate Unit | When |
|-------------|--------------|-----------------|------|
| `task_level` | `phase2-implementation` | One per task | No parallel groups (v5.1 behavior) |
| `group_level` | `subtask-group-worker` | One per subtask group | All tasks have parallel groups |
| `hybrid` | Both types | Groups for groupable, tasks for rest | Mix of task types |

### Dynamic Teammate Cap

The teammate cap is no longer static (`Math.min(tasks.length, 3)`). It's computed from `isolation_score`:

```
MAX = parseInt(AGENT_OS_MAX_TEAMMATES || '5')

avgIsolation >= 0.95 → cap = min(workUnits, MAX, 5)
avgIsolation >= 0.80 → cap = min(workUnits, MAX, 3)
avgIsolation >= 0.60 → cap = min(workUnits, MAX, 2)
avgIsolation <  0.60 → cap = 1  (sequential — too risky)
```

For **task-level**: `avgIsolation` is the mean of each task's `isolation_score`.
For **group-level**: `avgIsolation` is the mean pairwise Jaccard distance of `files_affected` across all groups.

### Artifact Relay Protocol

When team lead receives an `artifact_created` message and pre-check passes:

```
1. Validate artifact (file exists? export greps?)
2. On success: relay sibling_artifact to all OTHER active teammates
3. On failure: send fix request to originator only (no relay)
```

Relay message schema:

```json
{
  "event": "sibling_artifact",
  "source_task": "3",
  "source_group": 1,
  "files_created": ["src/auth/session.ts"],
  "exports_added": ["sessionCreate", "sessionDestroy"]
}
```

Receiving teammates check if they need any of the exports before re-implementing — preventing duplicate utility functions.

### Backward Compatibility

| Condition | Result |
|-----------|--------|
| `AGENT_OS_TEAMS=false` | Entirely unchanged flow (legacy Task() mode) |
| `AGENT_OS_TEAMS=true` + no `parallel_groups` | `task_level` granularity (v5.1 behavior) |
| `AGENT_OS_TEAMS=true` + `isolation_score < 0.6` | `cap = 1` (sequential, safe fallback) |

## Teammate Restrictions Convention

The `teammate_restrictions` convention documents which agent types can be spawned as teammates within a team. This mirrors the `Task(type)` convention for hierarchical spawning.

| Agent (Team Lead) | Allowed Teammates | Context |
|-------------------|-------------------|---------|
| `wave-orchestrator` | `phase2-implementation`, `subtask-group-worker`, `code-reviewer` | Wave task execution + semantic review |
| `execute-spec-orchestrator` | `review-watcher` | PR review polling |

**Documentation pattern** — add to agent body:

```markdown
## Teammate Restrictions
teammate_restrictions: [phase2-implementation, subtask-group-worker, code-reviewer]
```

## Utility Teammate Exemption (v5.4.0)

Certain teammates serve a **utility role** (review, monitoring) rather than implementation. These are **exempt from `AGENT_OS_MAX_TEAMMATES`** cap:

| Utility Teammate | Purpose | Why Exempt |
|-----------------|---------|------------|
| `code-reviewer` | Tier 1 semantic review | Doesn't consume implementation context slots |
| `review-watcher` | PR review polling | Minimal resource usage (Haiku model) |

The dynamic cap formula in wave-orchestrator T1.5 applies only to **implementation teammates** (`phase2-implementation`, `subtask-group-worker`). Utility teammates are spawned separately and do not count against the cap.

## Dual-Mode Version Routing

Agents that support both modes use the same env-var routing pattern as `AGENT_OS_TASKS_V4`:

```javascript
// In agent execution logic
const TEAMS_ENABLED = process.env.AGENT_OS_TEAMS === 'true';

if (TEAMS_ENABLED) {
  // Teams flow: TeamCreate → spawn teammates → message coordination
} else {
  // Legacy flow: Task(run_in_background) → TaskOutput(block)
}
```

**Critical**: Both paths must produce identical output formats. The wave result, artifact verification, and Ralph loop are the same regardless of coordination mechanism.

## Integration with Existing Systems

### Hooks

| Hook | Teams Compatibility | Notes |
|------|-------------------|-------|
| SubagentStart | Fires for teammates | Verified in Phase 0 |
| SubagentStop | Fires for teammates | Captures teammate transcripts |
| TaskCompleted | Works with shared TaskList | Increments session stats |
| **TeammateIdle** | Fires when teammate goes idle | **Logs lifecycle metrics** (v5.3.0) |
| PreToolUse (git) | Unchanged | Validation gates still apply |

### Agent Memory

Teammates with `memory: project` (e.g., `phase2-implementation`) still load project memory when spawned as teammates. Memory is scoped to the project, not the team.

### Context Offloading

SubagentStop hook offloads large teammate outputs the same way it handles Task() children. Token savings tracked in `session_stats.json`.

## Error Handling

| Error | Tier | Recovery |
|-------|------|----------|
| TeamCreate fails | RECOVERABLE | Fall back to legacy Task() flow |
| Teammate unresponsive | RECOVERABLE | shutdown_request + re-spawn |
| Message delivery fails | TRANSIENT | Retry up to 3 times |
| TeamDelete fails | RECOVERABLE | Log warning, continue (cleanup) |
| Review-watcher timeout | RECOVERABLE | Notify orchestrator, manual intervention |

## Two-Tier Code Review Integration (v5.4.0)

When `AGENT_OS_CODE_REVIEW=true`, wave-orchestrator integrates a two-tier review system:

```
┌─────────────────────────────────────────────────────────────────────┐
│                    TWO-TIER CODE REVIEW (v5.4.0)                     │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  TIER 1 (Sonnet teammate, parallel during execution):               │
│    wave-orchestrator receives artifact_created                      │
│      → T4 pre-check (file exists?)                                  │
│      → T4.5 sibling relay                                           │
│      → T4.75 relay to code-reviewer                                 │
│    code-reviewer reviews → sends findings                           │
│      → T4.8 route CRITICAL/HIGH to implementer (max 2 fix attempts)│
│      → Accumulate all findings to file                              │
│                                                                     │
│  TIER 2 (Opus subagent, sequential at wave end):                    │
│    T5: All tasks done → shutdown code-reviewer                      │
│      → Task(code-validator) with changed files + Tier 1 findings    │
│      → Deep analysis: design, security, spec, cross-task            │
│      → Combine Tier 1 + Tier 2 → block if unresolved CRITICAL/HIGH │
│                                                                     │
│  LEGACY MODE (AGENT_OS_TEAMS=false):                                │
│    Only Tier 2 runs with IS_STANDALONE=true                         │
│    Tier 2 expands scope to cover Tier 1 checks                     │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Fix Cycle Bound

To prevent infinite reviewer-implementer feedback loops:

```
MAX_REVIEW_FIX_ATTEMPTS = 2 (per finding per task)

Attempt 1: Route fix request to implementer
Attempt 2: Route second fix request
Attempt 3+: Finding marked unresolved, escalated to Tier 2
```

### Error Resilience

| Failure | Recovery |
|---------|----------|
| code-reviewer crashes | Warn + continue; Tier 2 safety net covers full scope |
| code-validator timeout (E005) | Warn + non-blocking pass with PR note |
| code-validator crash (E206) | Warn + non-blocking pass with PR note |

## Security Considerations

- Teammates inherit tool restrictions from their agent definition — a `phase2-implementation` teammate has the same tools whether spawned via `Task()` or as a teammate
- Team lead verifies artifacts before trusting broadcasts — don't blindly merge claimed exports
- `review-watcher` has minimal tools (Read, Bash, SendMessage) — cannot modify codebase
- `code-reviewer` has defense-in-depth (disallowedTools: Write, Edit, Bash, NotebookEdit) — identifies but never fixes issues
- Team naming convention (`wave-{spec}-{N}`) prevents cross-spec team conflicts

---

## Changelog

### v5.4.0 (2026-02-13)
- Added Two-Tier Code Review Integration section (T4.75, T4.8, T5 handoff)
- Added `AGENT_OS_CODE_REVIEW` to feature flag table
- Added `code-reviewer` to wave-orchestrator teammate restrictions
- Added Utility Teammate Exemption section (code-reviewer, review-watcher exempt from cap)
- Added fix cycle bound documentation (MAX_REVIEW_FIX_ATTEMPTS=2)
- Added error resilience table for code review failures
- Updated wave-level team lifecycle with code review steps (3.5, 5.75, 6.5, 7.5)
- Added code-reviewer to security considerations (defense-in-depth)

### v5.3.0 (2026-02-12)
- Added Prerequisite section: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` required for Teams tools
- Added TeammateIdle hook to Hooks compatibility table
- Noted PR review status indicator (v2.1.20) as complementary to review-watcher

### v5.2.0 (2026-02-12)
- Atomic Teammates: group-level parallelism with subtask-group-worker teammates
- Granularity decision tree (task_level / group_level / hybrid)
- Dynamic teammate cap based on isolation_score (replaces static cap of 3)
- Artifact relay protocol for sibling artifact sharing
- `AGENT_OS_MAX_TEAMMATES` env var (default: 5)
- Backward compatibility: no parallel_groups → task_level (v5.1 behavior)
- Updated wave-level team lifecycle with granularity and relay steps

### v5.1.0 (2026-02-09)
- Initial Teams integration system
- Wave-level peer coordination with artifact broadcast
- Review-watcher teammate for message-based review notification
- Incremental verification pre-check on artifact receipt
- Teammate restrictions convention
- Dual-mode version routing with AGENT_OS_TEAMS flag
