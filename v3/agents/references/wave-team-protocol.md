# Wave Team Protocol

> Reference document for /execute-tasks wave orchestration.
> v5.5.0: Main session is team lead. No nested orchestrator agents.

## Flat Architecture (v5.5.0)

```
main session (/execute-tasks, TEAM LEAD)
  TeamCreate("wave-{spec}-{N}")
  TaskCreate for each task in wave
  Spawn teammates (visible in split-panes)

  impl-0 (teammate, VISIBLE)        impl-1 (teammate, VISIBLE)
    +-- TaskList -> claim unblocked     +-- TaskList -> claim unblocked
    +-- TaskUpdate(in_progress)        +-- TaskUpdate(in_progress)
    +-- TDD: RED -> GREEN -> REFACTOR   +-- Receives artifact message
    +-- git commit                     +-- Uses sibling export
    +-- SendMessage(artifact_created)  +-- TaskUpdate(completed)
    +-- TaskUpdate(completed)          +-- Idle -> shutdown_response
    +-- Idle -> shutdown_response

  code-reviewer (teammate, VISIBLE, if AGENT_OS_CODE_REVIEW=true)
    +-- Receives artifact_for_review messages
    +-- Reviews for code smells, secrets, spec compliance
    +-- Sends findings to main session

  main session validates artifacts, relays to reviewer
  Full Ralph verification after all tasks
  shutdown_request to all -> TeamDelete
```

## Teammate Restrictions

```
Allowed teammates: [phase2-implementation, subtask-group-worker, code-reviewer]
```

Only these agent types may be spawned as teammates within wave teams.
`code-reviewer` is a utility teammate (exempt from `AGENT_OS_MAX_TEAMMATES` cap).

---

## Granularity Selection

Determine whether to spawn at task level or group level:

```javascript
const hasParallelGroups = tasks.some(t =>
  t.subtask_execution?.mode === "parallel_groups" && t.subtask_execution?.groups?.length > 1
)

let granularity = "task_level"
if (hasParallelGroups && tasks.every(t =>
  t.subtask_execution?.mode === "parallel_groups"
)) granularity = "group_level"
else if (hasParallelGroups) granularity = "hybrid"
```

### Dynamic Teammate Cap

```javascript
const MAX = parseInt(process.env.AGENT_OS_MAX_TEAMMATES || '5')
const avgIsolation = tasks.reduce((sum, t) => sum + (t.isolation_score || 1), 0) / tasks.length

let cap
if (avgIsolation >= 0.95) cap = Math.min(workUnits, MAX, 5)
else if (avgIsolation >= 0.80) cap = Math.min(workUnits, MAX, 3)
else if (avgIsolation >= 0.60) cap = Math.min(workUnits, MAX, 2)
else cap = 1
```

## Create Shared Tasks

```javascript
for (const task of tasks) {
  TaskCreate({
    subject: `Task ${task.id}: ${task.description}`,
    description: JSON.stringify({
      task_id: task.id,
      subtasks: task.subtasks,
      context_summary: task.context_summary,
      predecessor_artifacts: predecessorArtifacts
    }),
    activeForm: `Implementing task ${task.id}`
  })
}
```

## Spawn Teammates

```javascript
const agentType = (granularity === "task_level") ? "phase2-implementation" : "subtask-group-worker"
const namePrefix = (agentType === "phase2-implementation") ? "impl" : "group"

for (let i = 0; i < cap; i++) {
  Task({
    subagent_type: agentType,
    team_name: team_name,
    name: `${namePrefix}-${i}`,
    // For high-isolation tasks, add worktree isolation:
    // isolation: avgIsolation > 0.8 ? "worktree" : undefined,
    prompt: `You are a teammate in wave team "${team_name}".
1. TaskList -> claim unblocked task
2. TDD: RED -> GREEN -> REFACTOR
3. SendMessage artifact_created after each commit
4. TaskUpdate(completed) when done
5. Check TaskList for more tasks
6. Go idle when none remain

PREDECESSOR ARTIFACTS: ${JSON.stringify(predecessorArtifacts)}`
  })
}
```

## Artifact Validation

Main session validates artifacts as they arrive:

```javascript
function onArtifactMessage(message) {
  const artifact = JSON.parse(message.content)

  for (const file of artifact.files_created || []) {
    const exists = Bash(`[ -f "${file}" ] && echo "found" || echo "missing"`)
    if (exists.trim() !== "found") {
      SendMessage({ recipient: message.sender,
        content: `Pre-check failed: File "${file}" not found.` })
    }
  }

  for (const exp of artifact.exports_added || []) {
    const exists = Bash(`grep -rq "export.*${exp}" src/ && echo "found" || echo "missing"`)
    if (exists.trim() !== "found") {
      SendMessage({ recipient: message.sender,
        content: `Pre-check failed: Export "${exp}" not found.` })
    }
  }
}
```

## Code Review Integration

When `AGENT_OS_CODE_REVIEW=true`:

```javascript
// Relay artifact to code-reviewer after successful pre-check
if (CODE_REVIEW_ENABLED) {
  SendMessage({ recipient: "code-reviewer",
    content: JSON.stringify({
      event: "artifact_for_review",
      source_task: artifact.task_id,
      source_teammate: message.sender,
      files_created: artifact.files_created || [],
      exports_added: artifact.exports_added || []
    }) })
}

// Route blocking findings to implementer (max 2 fix attempts)
function onReviewFinding(finding) {
  if (finding.severity === "CRITICAL" || finding.severity === "HIGH") {
    const attempts = fixAttempts[finding.task_id] || 0
    if (attempts < 2) {
      SendMessage({ recipient: finding.source_teammate,
        content: `Fix: ${finding.description}\nFile: ${finding.file}:${finding.line}` })
      fixAttempts[finding.task_id] = attempts + 1
    }
  }
}
```

## Wave Cleanup

```javascript
// Shutdown code-reviewer -> invoke code-validator for deep Tier 2
if (CODE_REVIEW_ENABLED) {
  SendMessage({ type: "shutdown_request", recipient: "code-reviewer" })
  Task({ subagent_type: "code-validator", prompt: `Deep review...` })
}

// Shutdown implementation teammates
for (const mate of teammates) {
  SendMessage({ type: "shutdown_request", recipient: mate.name })
}
TeamDelete()
```

## Context Schema Reference

### PredecessorArtifacts

```typescript
interface PredecessorArtifacts {
  verified: boolean;
  exports_added?: string[];
  files_created?: string[];
  functions_created?: string[];
  commits?: string[];
}
```

---

## Changelog

### v5.5.0 (2026-03-06)
- Rewritten for flat architecture (main session as team lead)
- Removed nested orchestrator references
- Simplified from 610 lines to ~200 lines
- Added worktree isolation guidance
- Removed T4.5 sibling relay (teammates see shared codebase directly)

### v5.4.0 (2026-02-13)
- Code review integration (T4.75, T4.8, T5)
- Utility teammate exemption

### v5.2.0 (2026-02-12)
- Granularity selection, dynamic cap, artifact relay
