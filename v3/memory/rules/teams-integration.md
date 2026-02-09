# Teams Integration (v5.1.0)

> Native Claude Code Teams integration for peer coordination within Agent OS.
> Enables real-time artifact sharing, message-based review notification, and incremental verification.

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

Set in `.claude/settings.json` under `env`:

```json
{
  "env": {
    "AGENT_OS_TEAMS": "true"
  }
}
```

**Both modes produce identical outputs.** The flag only changes the coordination mechanism, not the task execution or verification logic.

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
| PR review waiting | **Teams** | Message notification replaces sleep loop |
| PR review cycle (discovery + impl) | `Task()` | Inherently sequential — no peer benefit |
| Hooks, state machine, TDD | No change | Orthogonal to coordination mechanism |

## Team Lifecycle

### Wave-Level Teams

```
1. TeamCreate("wave-{spec}-{N}")
2. TaskCreate for each task (with blockedBy from depends_on)
3. Spawn phase2-implementation teammates
4. Teammates claim tasks via TaskList → TaskUpdate
5. Teammates broadcast artifacts via SendMessage
6. Team lead validates artifacts incrementally
7. All tasks complete → full Ralph verification
8. shutdown_request to all teammates
9. TeamDelete("wave-{spec}-{N}")
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

## Teammate Restrictions Convention

The `teammate_restrictions` convention documents which agent types can be spawned as teammates within a team. This mirrors the `Task(type)` convention for hierarchical spawning.

| Agent (Team Lead) | Allowed Teammates | Context |
|-------------------|-------------------|---------|
| `wave-orchestrator` | `phase2-implementation`, `subtask-group-worker` | Wave task execution |
| `execute-spec-orchestrator` | `review-watcher` | PR review polling |

**Documentation pattern** — add to agent body:

```markdown
## Teammate Restrictions
teammate_restrictions: [phase2-implementation, subtask-group-worker]
```

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

## Security Considerations

- Teammates inherit tool restrictions from their agent definition — a `phase2-implementation` teammate has the same tools whether spawned via `Task()` or as a teammate
- Team lead verifies artifacts before trusting broadcasts — don't blindly merge claimed exports
- `review-watcher` has minimal tools (Read, Bash, SendMessage) — cannot modify codebase
- Team naming convention (`wave-{spec}-{N}`) prevents cross-spec team conflicts

---

## Changelog

### v5.1.0 (2026-02-09)
- Initial Teams integration system
- Wave-level peer coordination with artifact broadcast
- Review-watcher teammate for message-based review notification
- Incremental verification pre-check on artifact receipt
- Teammate restrictions convention
- Dual-mode version routing with AGENT_OS_TEAMS flag
