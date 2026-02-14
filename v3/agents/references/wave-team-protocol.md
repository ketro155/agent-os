# Wave Team Protocol

> Reference document for wave-orchestrator. Loaded on demand when working in `.claude/agents/`.
> See the main agent definition for core execution logic.

## Teams Mode Architecture (v5.1.0)

```
wave-orchestrator (TEAM LEAD)
  TeamCreate("wave-{spec}-{N}")
  TaskCreate for each task in wave (with blockedBy from depends_on)
  Spawn phase2-implementation teammates

  phase2-impl-A (teammate)          phase2-impl-B (teammate)
    ├── TaskList -> claim unblocked     ├── TaskList -> claim unblocked
    ├── TaskUpdate(in_progress)        ├── TaskUpdate(in_progress)
    ├── TDD: RED -> GREEN -> REFACTOR   ├── Receives artifact message from A
    ├── git commit                     ├── Uses A's export instead of re-creating
    ├── SendMessage(artifact_created)  ├── TaskUpdate(completed)
    ├── TaskUpdate(completed)          └── Idle -> shutdown_response
    └── Idle -> shutdown_response

  wave-orchestrator collects results
  Runs full Ralph verification (unchanged)
  shutdown_request to all teammates
  TeamDelete("wave-{spec}-{N}")
```

## Teammate Restrictions

```
teammate_restrictions: [phase2-implementation, subtask-group-worker, code-reviewer]
```

Only `phase2-implementation`, `subtask-group-worker`, and `code-reviewer` agent types may be spawned as teammates within wave teams. Note: `code-reviewer` is a utility teammate (exempt from `AGENT_OS_MAX_TEAMMATES` cap).

---

## T1: Create Team

```javascript
const team_name = `wave-${input.spec_name}-${input.wave_number}`;
TeamCreate({ team_name, description: `Wave ${input.wave_number} for ${input.spec_name}` });
```

## T1.5: Choose Teammate Granularity (v5.2.0)

Determine whether to spawn teammates at **task level** (v5.1 behavior) or **group level** (new in v5.2):

```javascript
// Check if any tasks have parallel subtask groups
const hasParallelGroups = input.tasks.some(t =>
  t.subtask_execution?.mode === "parallel_groups" && t.subtask_execution?.groups?.length > 1
);

// Granularity decision
let granularity;
if (!hasParallelGroups) {
  granularity = "task_level";  // No parallel groups -- v5.1 behavior
} else if (input.tasks.every(t =>
  t.subtask_execution?.mode === "parallel_groups" && t.subtask_execution?.groups?.length > 1
)) {
  granularity = "group_level";  // All tasks have parallel groups
} else {
  granularity = "hybrid";       // Mix of groupable and non-groupable tasks
}

// Compute work units for teammate cap
let workUnits;
if (granularity === "task_level") {
  workUnits = input.tasks.length;
} else if (granularity === "group_level") {
  workUnits = input.tasks.reduce((sum, t) => sum + (t.subtask_execution?.groups?.length || 1), 0);
} else {
  // hybrid: count groups for groupable tasks, 1 per non-groupable task
  workUnits = input.tasks.reduce((sum, t) => {
    return sum + (t.subtask_execution?.mode === "parallel_groups"
      ? (t.subtask_execution?.groups?.length || 1)
      : 1);
  }, 0);
}

// Dynamic teammate cap based on isolation_score (replaces static cap of 3)
const MAX = parseInt(process.env.AGENT_OS_MAX_TEAMMATES || '5');

let avgIsolation;
if (granularity === "task_level") {
  // Use existing task-level isolation_score average
  avgIsolation = input.tasks.reduce((sum, t) => sum + (t.isolation_score || 0), 0) / input.tasks.length;
} else {
  // Compute average pairwise isolation from files_affected across all groups
  const allGroups = input.tasks.flatMap(t => t.subtask_execution?.groups || []);
  let totalIsolation = 0, pairs = 0;
  for (let i = 0; i < allGroups.length; i++) {
    for (let j = i + 1; j < allGroups.length; j++) {
      const filesA = new Set(allGroups[i].files_affected || []);
      const filesB = new Set(allGroups[j].files_affected || []);
      const overlap = [...filesA].filter(f => filesB.has(f)).length;
      const union = new Set([...filesA, ...filesB]).size;
      totalIsolation += union === 0 ? 1 : 1 - (overlap / union);
      pairs++;
    }
  }
  avgIsolation = pairs > 0 ? totalIsolation / pairs : 1;
}

// Dynamic cap applies to IMPLEMENTATION teammates only
// Utility teammates (code-reviewer, review-watcher) are exempt
let cap;
if (avgIsolation >= 0.95) cap = Math.min(workUnits, MAX, 5);
else if (avgIsolation >= 0.80) cap = Math.min(workUnits, MAX, 3);
else if (avgIsolation >= 0.60) cap = Math.min(workUnits, MAX, 2);
else cap = 1;  // Low isolation -- sequential is safest

// Code review feature flag (v5.4.0)
const CODE_REVIEW_ENABLED = process.env.AGENT_OS_CODE_REVIEW === 'true';
```

## T2: Create Shared Tasks

Task creation depends on the granularity chosen in T1.5:

```javascript
if (granularity === "task_level") {
  // -- TASK-LEVEL (v5.1 behavior) ----------------------------------------
  for (const task of input.tasks) {
    TaskCreate({
      subject: `Task ${task.id}: ${task.description}`,
      description: JSON.stringify({
        task_id: task.id,
        subtasks: task.subtasks,
        context_summary: task.context_summary,
        predecessor_artifacts: input.predecessor_artifacts
      }),
      activeForm: `Implementing task ${task.id}`
    });
    // Set up dependencies using blockedBy from depends_on
    // (TaskUpdate with addBlockedBy after all tasks created)
  }

} else if (granularity === "group_level") {
  // -- GROUP-LEVEL (v5.2.0) -----------------------------------------------
  // Create one shared task per subtask group, with description = SubtaskGroupContext JSON
  const groupTaskIds = {};  // Map group_key -> shared task ID
  for (const task of input.tasks) {
    const groups = task.subtask_execution?.groups || [];
    for (const group of groups) {
      const groupKey = `${task.id}-g${group.group_id}`;
      const sharedTask = TaskCreate({
        subject: `Group ${groupKey}: ${group.tdd_unit}`,
        description: JSON.stringify({
          task_id: task.id,
          task_description: task.description,
          group: group,
          subtask_details: task.subtasks
            .filter(st => group.subtasks.includes(st.id))
            .map(st => ({ id: st.id, description: st.description })),
          predecessor_artifacts: input.predecessor_artifacts,
          context: task.context_summary
        }),
        activeForm: `Executing ${group.tdd_unit}`
      });
      groupTaskIds[groupKey] = sharedTask.id;
    }
    // Set blockedBy from group_waves: groups in wave 2 blocked by groups in wave 1
    if (task.subtask_execution?.group_waves) {
      for (const [waveNum, groupIds] of Object.entries(task.subtask_execution.group_waves)) {
        if (parseInt(waveNum) > 1) {
          const prevWaveGroupIds = task.subtask_execution.group_waves[String(parseInt(waveNum) - 1)] || [];
          for (const gid of groupIds) {
            const blockerIds = prevWaveGroupIds
              .map(pgid => groupTaskIds[`${task.id}-g${pgid}`])
              .filter(Boolean);
            if (blockerIds.length > 0) {
              TaskUpdate({ taskId: groupTaskIds[`${task.id}-g${gid}`], addBlockedBy: blockerIds });
            }
          }
        }
      }
    }
  }

} else {
  // -- HYBRID ---------------------------------------------------------------
  // Group-level for groupable tasks, task-level for the rest
  for (const task of input.tasks) {
    if (task.subtask_execution?.mode === "parallel_groups" && task.subtask_execution?.groups?.length > 1) {
      // Group-level (same as group_level above)
      for (const group of task.subtask_execution.groups) {
        TaskCreate({
          subject: `Group ${task.id}-g${group.group_id}: ${group.tdd_unit}`,
          description: JSON.stringify({
            task_id: task.id,
            task_description: task.description,
            group: group,
            subtask_details: task.subtasks
              .filter(st => group.subtasks.includes(st.id))
              .map(st => ({ id: st.id, description: st.description })),
            predecessor_artifacts: input.predecessor_artifacts,
            context: task.context_summary
          }),
          activeForm: `Executing ${group.tdd_unit}`
        });
      }
    } else {
      // Task-level (same as task_level above)
      TaskCreate({
        subject: `Task ${task.id}: ${task.description}`,
        description: JSON.stringify({
          task_id: task.id,
          subtasks: task.subtasks,
          context_summary: task.context_summary,
          predecessor_artifacts: input.predecessor_artifacts
        }),
        activeForm: `Implementing task ${task.id}`
      });
    }
  }
}
```

## T3: Spawn Teammates

Agent type and naming depend on the granularity chosen in T1.5:

```javascript
const teammates = [];
const num_teammates = cap; // Dynamic cap from T1.5 (replaces static Math.min(tasks.length, 3))

// Select agent type based on granularity
const agentType = (granularity === "task_level")
  ? "phase2-implementation"
  : "subtask-group-worker";  // group_level and hybrid use group workers

const namePrefix = (agentType === "phase2-implementation") ? "impl" : "group";

for (let i = 0; i < num_teammates; i++) {
  const teammate = Task({
    subagent_type: agentType,
    team_name: team_name,
    name: `${namePrefix}-${i}`,
    prompt: `You are a teammate in wave team "${team_name}".

INSTRUCTIONS:
1. Use TaskList to find available (unblocked, unowned) tasks
2. Claim a task with TaskUpdate (set owner to your name)
3. ${agentType === "phase2-implementation"
    ? "Implement it using TDD: RED -> GREEN -> REFACTOR"
    : "Parse the description JSON as SubtaskGroupContext and execute Gate 0 + Gate 1 + Steps 1-5 (TDD)"}
4. After each commit, broadcast artifacts via SendMessage:
   SendMessage({
     type: "message",
     recipient: "wave-orchestrator",
     content: JSON.stringify({
       event: "artifact_created",
       task_id: "...",
       ${agentType === "subtask-group-worker" ? 'group_id: "...",' : ''}
       files_created: [...],
       exports_added: [...],
       functions_created: [...]
     }),
     summary: "${agentType === "subtask-group-worker" ? "Group X" : "Task X"} artifacts ready"
   })
5. Mark task completed with TaskUpdate
6. Check TaskList for more available tasks
7. When no tasks remain, go idle

PREDECESSOR ARTIFACTS (VERIFIED):
${JSON.stringify(input.predecessor_artifacts)}

These exports/files are GUARANTEED to exist. Use them directly.
`
  });
  teammates.push(teammate);
}

// Spawn code-reviewer teammate (utility -- exempt from cap) (v5.4.0)
if (CODE_REVIEW_ENABLED) {
  const reviewer = Task({
    subagent_type: "code-reviewer",
    team_name: team_name,
    name: "code-reviewer",
    prompt: `You are the code-reviewer teammate in wave team "${team_name}".

INSTRUCTIONS:
1. Wait for artifact_for_review messages from the team lead
2. For each artifact: check for code smells, scan for secrets, basic spec check
3. Do NOT check for lint/type errors -- the pre-commit gate handles those
4. Send findings via SendMessage to the team lead
5. After each review, send review_done acknowledgment
6. Go idle between reviews
7. When you receive a shutdown_request, approve it

SPEC CONTEXT:
- Spec folder: ${input.spec_folder}
- Tasks JSON: ${input.spec_folder}/tasks.json

Use TaskGet to read full task descriptions when checking spec compliance.
`
  });
  // code-reviewer is not added to the teammates array (utility, not implementation)
}
```

## T4: Monitor and Validate (Incremental Verification)

```javascript
// Wait for messages from teammates
// When receiving artifact_created messages, run lightweight pre-check
function onArtifactMessage(message) {
  const artifact = JSON.parse(message.content);

  // Pre-check: verify files exist
  for (const file of artifact.files_created || []) {
    const exists = Bash(`[ -f "${file}" ] && echo "found" || echo "missing"`);
    if (exists.stdout?.trim() !== "found") {
      SendMessage({
        type: "message",
        recipient: message.sender,
        content: `Pre-check failed: File "${file}" not found. Fix before completing task.`,
        summary: `Fix missing file: ${file}`
      });
    }
  }

  // Pre-check: verify exports exist
  for (const exp of artifact.exports_added || []) {
    const exists = Bash(`grep -rq "export.*${exp}" src/ && echo "found" || echo "missing"`);
    if (exists.stdout?.trim() !== "found") {
      SendMessage({
        type: "message",
        recipient: message.sender,
        content: `Pre-check failed: Export "${exp}" not found. Fix before completing task.`,
        summary: `Fix missing export: ${exp}`
      });
    }
  }
}
```

## T4.5: Artifact Relay (v5.2.0)

After a successful pre-check, relay the artifact summary to all OTHER active teammates so they can consume sibling exports instead of re-implementing:

```javascript
function onArtifactPreCheckPassed(message, activeTeammates) {
  const artifact = JSON.parse(message.content);

  // Relay to all active teammates EXCEPT the originator
  for (const mate of activeTeammates) {
    if (mate.name === message.sender) continue;

    SendMessage({
      type: "message",
      recipient: mate.name,
      content: JSON.stringify({
        event: "sibling_artifact",
        source_task: artifact.task_id,
        source_group: artifact.group_id || null,
        files_created: artifact.files_created || [],
        exports_added: artifact.exports_added || []
      }),
      summary: `Sibling artifact from ${message.sender}`
    });
  }
}

// On FAILED pre-check: send fix request to originator only (no relay)
// On PASSED pre-check: relay to all other active teammates
```

## T4.75: Relay Artifacts to Code Reviewer (v5.4.0)

After the T4.5 sibling relay, forward artifacts to the code-reviewer for Tier 1 semantic review:

```javascript
function onArtifactPreCheckPassed(message, activeTeammates) {
  // ... existing T4.5 sibling relay (unchanged) ...

  // NEW: Relay to code-reviewer for Tier 1 review (if enabled)
  if (CODE_REVIEW_ENABLED) {
    SendMessage({
      type: "message",
      recipient: "code-reviewer",
      content: JSON.stringify({
        event: "artifact_for_review",
        source_task: artifact.task_id,
        source_teammate: message.sender,
        files_created: artifact.files_created || [],
        files_modified: artifact.files_modified || [],
        exports_added: artifact.exports_added || []
      }),
      summary: `Review artifact from ${message.sender}`
    });
  }
}
```

## T4.8: Handle Review Findings (v5.4.0)

When the code-reviewer sends findings, route blocking ones to the implementing teammate:

```javascript
const MAX_REVIEW_FIX_ATTEMPTS = 2;
const fixAttempts = {};  // "taskId-file" -> count
const SCRIPTS = `${CLAUDE_PROJECT_DIR}/.claude/scripts`;
const findingsFile = `.agent-os/scratch/code-review-findings.json`;

function onReviewFinding(message) {
  const finding = JSON.parse(message.content);

  // Accumulate finding via script
  Bash(`${SCRIPTS}/code-review-ops.sh accumulate ${findingsFile} '${JSON.stringify(finding)}'`);

  if (finding.severity === "CRITICAL" || finding.severity === "HIGH") {
    const taskKey = `${finding.task_id}-${finding.file}`;
    fixAttempts[taskKey] = (fixAttempts[taskKey] || 0) + 1;

    if (fixAttempts[taskKey] <= MAX_REVIEW_FIX_ATTEMPTS) {
      // Route fix request to implementing teammate
      SendMessage({
        type: "message",
        recipient: finding.source_teammate,
        content: `Code review finding (${finding.severity}): ${finding.description}\n` +
                 `File: ${finding.file}:${finding.line}\n` +
                 `Fix: ${finding.recommendation}\n` +
                 `Please fix and re-broadcast artifacts.`,
        summary: `${finding.severity} finding in ${finding.file}`
      });
    }
    // If > MAX_REVIEW_FIX_ATTEMPTS, finding stays unresolved for Tier 2 escalation
  }
}

function onReviewDone(message) {
  const ack = JSON.parse(message.content);
  // Log acknowledgment -- blocking findings already routed in onReviewFinding
  console.log(`[Wave] Code review done for task ${ack.task_id}: ${ack.findings_count} findings (${ack.blocking_count} blocking)`);
}
```

## T5: Collect Results, Code Review, and Cleanup

```javascript
// Wait for all shared tasks to be completed
// (Monitor TaskList until all tasks show status: completed)

// Run full Ralph verification (UNCHANGED from legacy mode)
// ... same verification logic as Step 3 below ...

// -- TWO-TIER CODE REVIEW HANDOFF (v5.4.0) ----------------------------

// 1. Shutdown code-reviewer teammate (Tier 1 complete)
if (CODE_REVIEW_ENABLED) {
  SendMessage({
    type: "shutdown_request",
    recipient: "code-reviewer",
    content: "All tasks complete, Tier 1 review done"
  });
}

// 2. Invoke code-validator subagent for deep Tier 2 review
if (CODE_REVIEW_ENABLED) {
  const changedFiles = Bash(`git diff --name-only ${baseBranch}...HEAD`).stdout.trim();

  // Read accumulated Tier 1 findings
  const tier1Findings = fs.existsSync(findingsFile)
    ? JSON.parse(fs.readFileSync(findingsFile, 'utf-8')).tier1_findings
    : [];

  const deepReview = Task({
    subagent_type: "code-validator",
    prompt: `Perform deep code review for wave ${input.wave_number} of ${input.spec_name}.

CHANGED FILES:
${changedFiles}

SPEC FOLDER: ${input.spec_folder}
STANDARDS: .agent-os/standards/ (if exists)
IS_STANDALONE: false

TIER 1 FINDINGS (already caught -- do NOT duplicate these):
${JSON.stringify(tier1Findings)}

Focus on what Tier 1 missed: design patterns, OWASP security, spec compliance, cross-task consistency.
Return structured findings JSON.`
  });

  // 3. Combine results via script
  const combined = Bash(
    `${SCRIPTS}/code-review-ops.sh combine ${findingsFile} '${JSON.stringify(deepReview)}'`
  );
  const combinedResult = JSON.parse(combined.stdout);

  if (combinedResult.has_unresolved_blocking) {
    return {
      status: "blocked",
      blocker: `Code review: ${combinedResult.unresolved_count} unresolved CRITICAL/HIGH findings`,
      code_review: combinedResult
    };
  }

  // 4. Pass -- include advisory findings in wave result
  waveResult.code_review = combinedResult;
}

// -- END CODE REVIEW -------------------------------------------------

// Shutdown implementation teammates
for (const teammate of teammates) {
  SendMessage({
    type: "shutdown_request",
    recipient: teammate.name,
    content: "All wave tasks complete"
  });
}

// Delete team
TeamDelete();
```

## T5 Legacy Mode: Standalone Review (v5.4.0)

When `AGENT_OS_TEAMS=false` and `AGENT_OS_CODE_REVIEW=true`, only Tier 2 runs (as a standalone review):

```javascript
if (!TEAMS_ENABLED && CODE_REVIEW_ENABLED) {
  const changedFiles = Bash(`git diff --name-only ${baseBranch}...HEAD`).stdout.trim();

  const reviewResult = Task({
    subagent_type: "code-validator",
    prompt: `Full code review for wave ${input.wave_number} of ${input.spec_name}.

CHANGED FILES: ${changedFiles}
SPEC FOLDER: ${input.spec_folder}
IS_STANDALONE: true

This is a standalone review (no Tier 1 ran). Check ALL scopes:
design patterns, OWASP security, spec compliance, cross-task consistency,
PLUS code smells and hardcoded secrets.
Return structured findings JSON.`
  });

  if (reviewResult.findings?.some(f => ["CRITICAL", "HIGH"].includes(f.severity))) {
    return { status: "blocked", blocker: "Code review findings", code_review: reviewResult };
  }
  waveResult.code_review = { tier2: reviewResult, combined_status: "pass" };
}
```

---

## Context Schema Reference

### PredecessorArtifacts

```typescript
interface PredecessorArtifacts {
  verified: boolean;  // MUST be true before use
  [wave_key: string]: {
    exports_added: string[];      // Named exports created
    files_created: string[];      // File paths created
    functions_created: string[];  // Function/method names
    commits: string[];            // Git commit hashes
  }
}
```

### VerificationResult

```typescript
interface VerificationResult {
  artifact_type: "export" | "file" | "function";
  claimed_name: string;
  exists: boolean;
  location?: string;  // Where found (if exists)
  reason?: string;    // Why not found (if !exists)
}
```

---

## Changelog

### v5.4.0 (2026-02-13)
- T3: Spawn code-reviewer Sonnet teammate (utility, exempt from cap) when AGENT_OS_CODE_REVIEW=true
- T4.75: Relay artifacts to code-reviewer for Tier 1 semantic review
- T4.8: Handle review findings -- route blocking CRITICAL/HIGH to implementer (max 2 fix attempts)
- T5: Two-tier handoff -- shutdown reviewer, invoke code-validator (Opus) via Task() for deep analysis
- T5 legacy: Standalone Tier 2 review when AGENT_OS_TEAMS=false and AGENT_OS_CODE_REVIEW=true
- Task spawn restrictions: added code-validator to Task(...)
- Teammate restrictions: added code-reviewer
- T1.5: Implementation teammate cap explicitly excludes utility teammates

### v5.2.0 (2026-02-12)
- T1.5: Teammate granularity selection (task_level / group_level / hybrid)
- Dynamic teammate cap based on isolation_score (replaces static cap of 3)
- AGENT_OS_MAX_TEAMMATES env var support (default: 5)
- T2: Group-level TaskCreate with SubtaskGroupContext JSON descriptions
- T3: Agent type routing -- subtask-group-worker for group-level, phase2-implementation for task-level
- T4.5: Artifact relay protocol -- relays verified artifacts to active sibling teammates
- Backward compatible: no parallel_groups -> task_level (v5.1 behavior)

### v5.1.0 (2026-02-09)
- Added Teams-based peer coordination mode (AGENT_OS_TEAMS=true)
- Dual-mode execution: Teams (TeamCreate/SendMessage) or Legacy (Task/TaskOutput)
- Artifact broadcast protocol for sibling task notification
- Incremental verification pre-check on artifact receipt
- Teammate restrictions convention (phase2-implementation, subtask-group-worker)
- Teams tools added to frontmatter
