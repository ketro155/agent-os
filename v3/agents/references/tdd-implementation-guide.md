# TDD Implementation Guide

> Reference document for phase2-implementation. Loaded on demand when working in `.claude/agents/`.
> See the main agent definition for core execution logic.

## Subtask Execution Mode Decision Tree (v4.3)

```
                                    |
                                    v
                    +-------------------------------+
                    | Does task have                 |
                    | subtask_execution.mode config? |
                    +-------------------------------+
                           |              |
                      YES  |              |  NO
                           v              |
              +--------------------+      |
              | mode ==            |      |
              | "parallel_groups"? |      |
              +--------------------+      |
                 |            |           |
            YES  |            | NO        |
                 v            |           |
    +---------------------+   |           |
    | PARALLEL GROUPS     |   |           |
    | (Step 0.6)          |   |           |
    |                     |   |           |
    | - Executes groups   |   |           |
    |   in wave order     |   |           |
    | - Groups within     |   |           |
    |   wave run parallel |   |           |
    | - Best for complex  |   |           |
    |   file dependencies |   |           |
    +---------------------+   |           |
                              |           |
                              v           v
                    +---------------------------+
                    | How many subtasks?         |
                    | subtasks.length            |
                    +---------------------------+
                       |              |
                  > 4  |              |  <= 4
                       v              v
        +---------------------+  +---------------------+
        | BATCHED EXECUTION   |  | SEQUENTIAL          |
        | (Step 0.7)          |  | (For Each Subtask)  |
        |                     |  |                     |
        | - Splits into       |  | - Direct execution  |
        |   batches of 3      |  |   in current agent  |
        | - Each batch in     |  | - No sub-agents     |
        |   separate agent    |  | - Simple and fast   |
        | - Prevents context  |  | - Best for small    |
        |   overflow          |  |   tasks             |
        +---------------------+  +---------------------+
```

### Mode Comparison Table

| Mode | When Used | Agents Spawned | Best For |
|------|-----------|----------------|----------|
| **Sequential** | <= 4 subtasks, no config | 0 | Simple tasks, quick fixes |
| **Batched** | > 4 subtasks, no config | N/3 (rounded up) | Medium complexity, prevents overflow |
| **Parallel Groups** | `subtask_execution.mode` set | Group count | Complex features with file deps |

### Configuration Sources

The `subtask_execution` config comes from **tasks.json**, populated by `/create-tasks`:

```json
{
  "id": "3",
  "subtask_execution": {
    "mode": "parallel_groups",
    "groups": [
      { "group_id": "G1", "subtasks": ["3.1", "3.2"], "files_affected": ["src/api/"] },
      { "group_id": "G2", "subtasks": ["3.3", "3.4"], "files_affected": ["src/utils/"] }
    ],
    "group_waves": [
      { "wave_id": 1, "groups": ["G1", "G2"] }
    ]
  }
}
```

**Default Behavior (No Config):**
- If `subtask_execution` is not set, mode is determined by subtask count
- <= 4 subtasks: Sequential (simple, no overhead)
- > 4 subtasks: Batched (prevents context overflow)

### Implementation Code

```javascript
// Configuration
const BATCH_THRESHOLD = 4;  // Batch if more than 4 subtasks
const SUBTASKS_PER_BATCH = 3;  // Process 3 subtasks per batch agent

// Check for explicit parallelization configuration
const subtaskExecution = task.subtask_execution;
const subtaskCount = task.subtasks?.length || 0;

if (subtaskExecution?.mode === "parallel_groups") {
  // Use Parallel Group Protocol (Step 0.6)
  EXECUTE: Parallel Group Protocol
} else if (subtaskCount > BATCH_THRESHOLD) {
  // Use Batched Execution Protocol (Step 0.7) - prevents context overflow
  EXECUTE: Batched Subtask Protocol
} else {
  // Use Sequential Protocol (existing "For Each Subtask" flow)
  // Safe for small number of subtasks
  EXECUTE: Sequential Subtask Protocol
}
```

**Why Batching Exists (v4.3):**
- Tasks with 5+ subtasks accumulate ~40-60KB of context (test output, implementations, commits)
- This causes context overflow in the Phase 2 agent
- Batching splits work across multiple agents, each with fresh context
- Each batch agent handles 3 subtasks, returns minimal artifact summary
- Parent agent only holds artifact names, not full TDD output

---

## Step 0.6: Parallel Group Protocol (v4.2)

> **For tasks with `subtask_execution.mode: "parallel_groups"` only**

Execute subtask groups in parallel waves, with sequential TDD execution within each group.

### 0.6.1: Initialize Group Tracking

```javascript
TodoWrite([
  {
    content: `Task ${task.id}: Parallel group execution (${task.subtask_execution.groups.length} groups)`,
    status: "in_progress",
    activeForm: `Executing ${task.subtask_execution.groups.length} parallel groups`
  }
])
```

### 0.6.2: Execute Group Waves

```javascript
// Track artifacts from completed groups
let predecessorGroupArtifacts = {
  exports_added: [],
  files_created: [],
  functions_created: []
};

// Process each wave of groups
for (const wave of task.subtask_execution.group_waves) {
  console.log(`Executing Wave ${wave.wave_id}: Groups [${wave.groups.join(', ')}]`);

  // Spawn parallel workers for all groups in this wave
  const groupWorkers = [];

  for (const groupId of wave.groups) {
    const group = task.subtask_execution.groups.find(g => g.group_id === groupId);
    const subtaskDetails = group.subtasks.map(subId =>
      task.subtasks_full.find(s => s.id === subId)
    );

    // Build context for this group worker
    const groupContext = {
      task_id: task.id,
      task_description: task.description,
      group: group,
      subtask_details: subtaskDetails,
      predecessor_artifacts: predecessorGroupArtifacts,
      context: {
        spec_summary: context.spec_summary,
        relevant_files: group.files_affected,
        standards: context.standards
      }
    };

    // Spawn worker in background
    const workerId = Task({
      subagent_type: "subtask-group-worker",
      run_in_background: true,
      prompt: `Execute subtask group for task ${task.id}:

GROUP CONTEXT:
${JSON.stringify(groupContext, null, 2)}

Execute all subtasks in this group sequentially using TDD.
Commit once after all subtasks complete.
Return structured artifacts.`
    });

    groupWorkers.push({ groupId, workerId, group });
  }

  // Collect results from all workers (blocking)
  const groupResults = [];
  for (const worker of groupWorkers) {
    const result = TaskOutput({
      task_id: worker.workerId,
      block: true,
      timeout: 300000  // 5 minutes per group
    });

    groupResults.push({
      groupId: worker.groupId,
      group: worker.group,
      result: result
    });
  }

  // Verify and merge artifacts from this wave
  for (const { groupId, group, result } of groupResults) {
    if (result.status === "pass") {
      // Verify artifacts exist via grep
      for (const exportName of result.exports_added || []) {
        const found = await Bash(`grep -r "export.*${exportName}" src/ | head -1`);
        if (found.stdout.trim()) {
          predecessorGroupArtifacts.exports_added.push(exportName);
        } else {
          console.warn(`Unverified export claim: ${exportName} from group ${groupId}`);
        }
      }

      // Verify files exist
      for (const file of result.files_created || []) {
        if (await fileExists(file)) {
          predecessorGroupArtifacts.files_created.push(file);
        }
      }

      // Merge functions
      predecessorGroupArtifacts.functions_created.push(...(result.functions_created || []));

      // Update subtask statuses in tasks.json
      for (const subtaskId of result.subtasks_completed || []) {
        await Bash(`bash .claude/scripts/task-operations.sh update "${subtaskId}" "pass"`);
      }
    } else if (result.status === "blocked" || result.status === "fail") {
      // Log blocker but continue with other groups in wave
      console.error(`Group ${groupId} ${result.status}: ${result.blocker || 'Unknown error'}`);

      // Mark failed subtasks
      for (const subtaskId of result.subtasks_failed || []) {
        await Bash(`bash .claude/scripts/task-operations.sh update "${subtaskId}" "blocked"`);
      }
    }
  }

  // Check if all groups in wave passed before proceeding to next wave
  const allPassed = groupResults.every(r => r.result.status === "pass");
  if (!allPassed) {
    const failedGroups = groupResults.filter(r => r.result.status !== "pass");
    console.warn(`Wave ${wave.wave_id} had ${failedGroups.length} failed/blocked groups`);
    // Continue to next wave anyway - partial success is acceptable
  }
}
```

### 0.6.3: Aggregate Task Results

After all group waves complete:

```javascript
// Collect all group results
const allGroupResults = /* collected from waves above */;

// Build aggregated task result
const taskResult = {
  status: allGroupResults.every(r => r.status === "pass") ? "pass" : "partial",
  task_id: task.id,
  groups_completed: allGroupResults.filter(r => r.status === "pass").length,
  groups_total: task.subtask_execution.groups.length,
  files_created: predecessorGroupArtifacts.files_created,
  exports_added: predecessorGroupArtifacts.exports_added,
  functions_created: predecessorGroupArtifacts.functions_created,
  commits: allGroupResults.map(r => r.commit).filter(Boolean),
  notes: `Parallel execution: ${taskResult.groups_completed}/${taskResult.groups_total} groups completed`
};

// Update parent task status
if (taskResult.status === "pass") {
  await Bash(`bash .claude/scripts/task-operations.sh update "${task.id}" "pass"`);
} else {
  await Bash(`bash .claude/scripts/task-operations.sh update "${task.id}" "in_progress"`);
}

// Return aggregated result
return taskResult;
```

### 0.6.4: Skip Sequential Flow

After completing parallel group execution, **SKIP** the "For Each Subtask" section and proceed directly to the Output Format section.

---

## Step 0.7: Batched Subtask Protocol (v4.3)

> **For tasks with more than 4 subtasks that don't have parallel_groups configured**

This protocol prevents context overflow by splitting subtasks into batches, each executed by a separate sub-agent.

### 0.7.1: Calculate Batches

```javascript
const SUBTASKS_PER_BATCH = 3;

// Get subtask details
const subtaskDetails = task.subtasks.map(subtaskId => {
  // If we have full subtask objects, use them
  // Otherwise, create minimal structure from IDs
  return task.subtasks_full?.find(s => s.id === subtaskId) || {
    id: subtaskId,
    description: `Subtask ${subtaskId}`
  };
});

// Split into batches of 3
const batches = [];
for (let i = 0; i < subtaskDetails.length; i += SUBTASKS_PER_BATCH) {
  batches.push({
    batch_number: Math.floor(i / SUBTASKS_PER_BATCH) + 1,
    subtasks: subtaskDetails.slice(i, i + SUBTASKS_PER_BATCH)
  });
}

console.log(`Task ${task.id}: Splitting ${subtaskDetails.length} subtasks into ${batches.length} batches`);
```

**Example for Task with 8 subtasks:**
```
Batch 1: [4.1, 4.2, 4.3]
Batch 2: [4.4, 4.5, 4.6]
Batch 3: [4.7, 4.8]
```

### 0.7.2: Initialize Batch Tracking

```javascript
TodoWrite([
  {
    content: `Task ${task.id}: Batched execution (${batches.length} batches of ${SUBTASKS_PER_BATCH})`,
    status: "in_progress",
    activeForm: `Executing ${batches.length} batches`
  }
]);

// Track artifacts across all batches
let aggregatedArtifacts = {
  exports_added: [],
  files_created: [],
  files_modified: [],
  functions_created: [],
  commits: [],
  subtasks_completed: []
};

// Track batch statuses for reporting
const batchStatuses = [];
```

### 0.7.3: Execute Batches Sequentially

> **IMPORTANT**: Batches execute SEQUENTIALLY (not in parallel) because later subtasks may depend on earlier ones within the same task.

```javascript
for (const batch of batches) {
  console.log(`Executing Batch ${batch.batch_number}/${batches.length}: Subtasks [${batch.subtasks.map(s => s.id).join(', ')}]`);

  // Build context for batch worker
  const batchContext = {
    task_id: task.id,
    task_description: task.description,
    batch_number: batch.batch_number,
    total_batches: batches.length,
    subtasks: batch.subtasks,
    predecessor_artifacts: {
      // Artifacts from predecessor tasks (from context)
      ...context.predecessor_artifacts,
      // PLUS artifacts from previous batches in this task
      exports_added: [
        ...(context.predecessor_artifacts?.exports_added || []),
        ...aggregatedArtifacts.exports_added
      ],
      files_created: [
        ...(context.predecessor_artifacts?.files_created || []),
        ...aggregatedArtifacts.files_created
      ]
    },
    spec_summary: context.spec_summary,
    relevant_files: context.relevant_files,
    standards: context.standards
  };

  // Spawn batch worker agent
  const batchResult = Task({
    subagent_type: "phase2-implementation",  // Reuses this same agent type
    prompt: `
Execute batch ${batch.batch_number} of ${batches.length} for task ${task.id}.

## Batch Context
- Task: ${task.description}
- Subtasks in this batch: ${batch.subtasks.map(s => `${s.id}: ${s.description}`).join('\n  - ')}

## Predecessor Artifacts (verified, safe to import)
${JSON.stringify(batchContext.predecessor_artifacts, null, 2)}

## Instructions
1. Execute each subtask using TDD: RED -> GREEN -> REFACTOR
2. Commit after each subtask
3. Return structured result with artifacts

## Spec Context
${context.spec_summary || 'See spec files'}

Return JSON result with: status, subtasks_completed, exports_added, files_created, commits
    `
  });

  // ===================================================================
  // Process batch result immediately (don't accumulate full objects)
  // ===================================================================

  if (batchResult.status === "pass" || batchResult.status === "partial") {
    // Verify and merge artifacts using exit codes only (minimal context)
    for (const exportName of batchResult.exports_added || []) {
      const check = Bash(`grep -rq "export.*${exportName}" . && echo "found" || echo "missing"`);
      if (check.stdout?.trim() === "found") {
        aggregatedArtifacts.exports_added.push(exportName);
      } else {
        console.warn(`Unverified export: ${exportName} from batch ${batch.batch_number}`);
      }
    }

    for (const file of batchResult.files_created || []) {
      const check = Bash(`[ -f "${file}" ] && echo "found" || echo "missing"`);
      if (check.stdout?.trim() === "found") {
        aggregatedArtifacts.files_created.push(file);
      }
    }

    // Merge other artifacts (simple arrays of strings)
    aggregatedArtifacts.files_modified.push(...(batchResult.files_modified || []));
    aggregatedArtifacts.functions_created.push(...(batchResult.functions_created || []));
    aggregatedArtifacts.commits.push(...(batchResult.commits || []));
    aggregatedArtifacts.subtasks_completed.push(...(batchResult.subtasks_completed || []));

    // Update subtask statuses immediately
    for (const subtaskId of batchResult.subtasks_completed || []) {
      Bash(`bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/task-operations.sh" update "${subtaskId}" "pass"`);
    }

    batchStatuses.push({
      batch_number: batch.batch_number,
      status: batchResult.status,
      subtasks_completed: batchResult.subtasks_completed?.length || 0
    });

    console.log(`Batch ${batch.batch_number}: ${batchResult.subtasks_completed?.length || 0} subtasks completed`);

  } else {
    // Batch failed or blocked
    console.error(`Batch ${batch.batch_number} ${batchResult.status}: ${batchResult.blocker || 'Unknown error'}`);

    batchStatuses.push({
      batch_number: batch.batch_number,
      status: batchResult.status,
      blocker: batchResult.blocker,
      subtasks_affected: batch.subtasks.map(s => s.id)
    });

    // Mark affected subtasks as blocked
    for (const subtask of batch.subtasks) {
      Bash(`bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/task-operations.sh" update "${subtask.id}" "blocked"`);
    }

    // Decision: Continue with remaining batches or halt?
    // Default: Continue to attempt remaining batches (partial progress is better than none)
    console.log(`Continuing with remaining batches despite batch ${batch.batch_number} failure...`);
  }

  // batchResult goes out of scope here - context stays bounded
}
```

### 0.7.4: Aggregate Task Results

```javascript
// Calculate overall status
const passedBatches = batchStatuses.filter(b => b.status === "pass").length;
const totalBatches = batches.length;
const allPassed = passedBatches === totalBatches;

const taskResult = {
  status: allPassed ? "pass" : (passedBatches > 0 ? "partial" : "blocked"),
  task_id: task.id,
  execution_mode: "batched",
  batches_completed: passedBatches,
  batches_total: totalBatches,
  subtasks_completed: aggregatedArtifacts.subtasks_completed,
  files_created: aggregatedArtifacts.files_created,
  files_modified: aggregatedArtifacts.files_modified,
  exports_added: aggregatedArtifacts.exports_added,
  functions_created: aggregatedArtifacts.functions_created,
  commits: aggregatedArtifacts.commits,
  notes: `Batched execution: ${passedBatches}/${totalBatches} batches, ${aggregatedArtifacts.subtasks_completed.length} subtasks completed`
};

// Update parent task status
if (taskResult.status === "pass") {
  Bash(`bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/task-operations.sh" update "${task.id}" "pass"`);
} else if (taskResult.status === "partial") {
  Bash(`bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/task-operations.sh" update "${task.id}" "in_progress"`);
} else {
  Bash(`bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/task-operations.sh" update "${task.id}" "blocked"`);
}

// Log summary
console.log(`Task ${task.id} complete: ${taskResult.status}`);
console.log(`  Batches: ${passedBatches}/${totalBatches}`);
console.log(`  Subtasks: ${aggregatedArtifacts.subtasks_completed.length}/${subtaskDetails.length}`);
console.log(`  Files created: ${aggregatedArtifacts.files_created.length}`);
console.log(`  Exports added: ${aggregatedArtifacts.exports_added.length}`);

return taskResult;
```

### 0.7.5: Skip Sequential Flow

After completing batched execution, **SKIP** the "For Each Subtask" section and proceed directly to the Output Format section.

---

## Context Management (v4.9.0)

### Context Compression Between Subtasks

After completing each subtask, compress context to prevent overflow on tasks with many subtasks.

**Invoke Context-Summary Skill:**

```javascript
// After each subtask completion
const executeSubtask = async (subtask, context) => {
  // ... existing subtask execution ...

  // After TDD phases complete
  const subtaskResult = {
    status: 'pass',
    files_modified: [...],
    exports_added: [...],
    test_results: {...}
  };

  // Compress context for next subtask
  const compressedContext = await invokeContextSummary({
    scope: `subtask-${subtask.id}`,
    currentState: {
      task: context.task,
      subtask: subtask,
      completedSubtasks: context.completedSubtasks,
      remainingSubtasks: context.remainingSubtasks
    },
    keyDecisions: extractKeyDecisions(),
    filesModified: subtaskResult.files_modified,
    criticalContext: [
      `Completed: ${subtask.description}`,
      `Next: ${context.remainingSubtasks[0]?.description || 'Final verification'}`
    ]
  });

  return {
    ...subtaskResult,
    compressedContext
  };
};

const invokeContextSummary = async (params) => {
  // Use the context-summary skill
  return Skill({
    skill: 'context-summary',
    args: JSON.stringify({
      scope: params.scope,
      currentState: params.currentState,
      keyDecisions: params.keyDecisions,
      filesModified: params.filesModified,
      criticalContext: params.criticalContext
    })
  });
};
```

### Test Pattern Discovery

Automatically discover test patterns from project configuration.

**discoverTestPatterns Function:**

```javascript
const discoverTestPatterns = async (projectRoot = '.') => {
  const patterns = {
    testMatch: [],
    testPathIgnorePatterns: [],
    moduleFileExtensions: [],
    framework: null,
    setupFiles: [],
    testEnvironment: 'node'
  };

  // Check for Jest configuration
  const jestConfigPaths = [
    `${projectRoot}/jest.config.js`,
    `${projectRoot}/jest.config.ts`,
    `${projectRoot}/jest.config.json`,
    `${projectRoot}/package.json` // jestconfig in package.json
  ];

  for (const configPath of jestConfigPaths) {
    if (fs.existsSync(configPath)) {
      try {
        let config;
        if (configPath.endsWith('package.json')) {
          const pkg = JSON.parse(fs.readFileSync(configPath, 'utf-8'));
          config = pkg.jest;
          if (!config) continue;
        } else if (configPath.endsWith('.json')) {
          config = JSON.parse(fs.readFileSync(configPath, 'utf-8'));
        } else {
          // For .js/.ts, try to extract patterns with regex
          const content = fs.readFileSync(configPath, 'utf-8');
          const testMatchMatch = content.match(/testMatch:\s*\[([\s\S]*?)\]/);
          if (testMatchMatch) {
            patterns.testMatch = extractArrayValues(testMatchMatch[1]);
          }
        }

        if (config) {
          patterns.framework = 'jest';
          patterns.testMatch = config.testMatch || ['**/__tests__/**/*.[jt]s?(x)', '**/?(*.)+(spec|test).[jt]s?(x)'];
          patterns.testPathIgnorePatterns = config.testPathIgnorePatterns || ['/node_modules/'];
          patterns.moduleFileExtensions = config.moduleFileExtensions || ['js', 'jsx', 'ts', 'tsx'];
          patterns.testEnvironment = config.testEnvironment || 'node';
          patterns.setupFiles = config.setupFilesAfterEnv || config.setupFiles || [];
        }
        break;
      } catch (e) {
        console.warn(`Failed to parse Jest config at ${configPath}: ${e}`);
      }
    }
  }

  // Check for Vitest configuration
  const vitestConfigPaths = [
    `${projectRoot}/vitest.config.ts`,
    `${projectRoot}/vitest.config.js`,
    `${projectRoot}/vite.config.ts` // vitest can be in vite.config
  ];

  for (const configPath of vitestConfigPaths) {
    if (fs.existsSync(configPath)) {
      try {
        const content = fs.readFileSync(configPath, 'utf-8');
        if (content.includes('vitest') || content.includes('test:')) {
          patterns.framework = 'vitest';

          // Extract include patterns
          const includeMatch = content.match(/include:\s*\[([\s\S]*?)\]/);
          if (includeMatch) {
            patterns.testMatch = extractArrayValues(includeMatch[1]);
          } else {
            patterns.testMatch = ['**/*.{test,spec}.{js,mjs,cjs,ts,mts,cts,jsx,tsx}'];
          }

          // Extract exclude patterns
          const excludeMatch = content.match(/exclude:\s*\[([\s\S]*?)\]/);
          if (excludeMatch) {
            patterns.testPathIgnorePatterns = extractArrayValues(excludeMatch[1]);
          }

          break;
        }
      } catch (e) {
        console.warn(`Failed to parse Vitest config at ${configPath}: ${e}`);
      }
    }
  }

  // Default patterns if nothing found
  if (!patterns.framework) {
    patterns.framework = 'unknown';
    patterns.testMatch = [
      '**/__tests__/**/*.[jt]s?(x)',
      '**/?(*.)+(spec|test).[jt]s?(x)',
      '**/tests/**/*.[jt]s?(x)'
    ];
  }

  return patterns;
};

const extractArrayValues = (arrayContent) => {
  const matches = arrayContent.match(/['"`](.*?)['"`]/g) || [];
  return matches.map(m => m.slice(1, -1));
};
```

### Usage in Phase 2 Implementation

```javascript
// At task start, discover test patterns
const testPatterns = await discoverTestPatterns(projectRoot);

// When running tests, use discovered patterns
const runTests = async (testFile) => {
  if (testPatterns.framework === 'jest') {
    return Bash(`npm test -- --testPathPattern="${testFile}"`);
  } else if (testPatterns.framework === 'vitest') {
    return Bash(`npm run test -- ${testFile}`);
  } else {
    // Fallback
    return Bash(`npm test -- ${testFile}`);
  }
};
```

---

## Automatic Context Pressure Response (v5.0.1)

When the subagent-stop hook reports `[Context Pressure: HIGH]` or `[Context Pressure: MODERATE]` in the system message, respond as follows:

### HIGH Pressure (> 100KB offloaded)

**MUST** invoke `/context-summary` before spawning the next subagent:

```javascript
// Mandatory before next Task() call
if (systemMessage.includes('[Context Pressure: HIGH]')) {
  INFORM: `Context pressure HIGH -- compressing context before next operation`;

  // Invoke context-summary skill
  await Skill({
    skill: 'context-summary',
    args: JSON.stringify({
      scope: `task-${task.id}-pressure-relief`,
      currentState: { task, completedSubtasks, remainingSubtasks },
      criticalContext: ['Preserve: current task state, artifacts, test results']
    })
  });
}
```

### MODERATE Pressure (> 50KB offloaded)

**SHOULD** invoke `/context-summary` if more than 2 subtasks remain:

```javascript
if (systemMessage.includes('[Context Pressure: MODERATE]') && remainingSubtasks.length > 2) {
  INFORM: `Context pressure MODERATE with ${remainingSubtasks.length} subtasks remaining -- compressing`;

  await Skill({ skill: 'context-summary', args: '...' });
}
```

### Why This Matters

Context overflow is the #1 cause of failed long-running tasks. By detecting pressure automatically via the subagent-stop hook and responding proactively, agents can complete complex tasks that would otherwise exhaust context.

---

## Changelog

### v5.1.0 (2026-02-09)
- Added teammate mode for Teams-based wave coordination (AGENT_OS_TEAMS=true)
- Teams tools added to frontmatter (SendMessage, TaskUpdate, TaskList, TaskGet)
- Artifact broadcast protocol -- notify siblings when creating exports/files
- Sibling artifact consumption -- check broadcasts before re-implementing utilities
- Fix request handling -- respond to team lead pre-check failure messages
- Dual-mode detection: teammate vs standalone based on spawn context

### v4.9.0 (2026-01-10)
- Standardized error handling with error-handling.md rule
- Use handleError() with ERROR_CATALOG codes
- Use mapErrorToCode() for error classification

### v4.9.0-pre (2026-01-09)
- Added context compression between subtasks using context-summary skill
- Added discoverTestPatterns function for Jest/Vitest configuration detection
- Added executeSubtask wrapper with automatic context management
- Improved test file discovery from project configuration
