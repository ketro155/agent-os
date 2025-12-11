# Parallel Execution Patterns

Patterns for executing multiple tasks concurrently using Claude Code's async agent capabilities. Enables significant speedup for independent tasks while maintaining safety for dependent tasks.

**Version**: 2.0 - Initial release with async agent support.

**Reference**: Leverages Claude Code's `run_in_background` Task parameter and `AgentOutputTool`.

---

## Core Principles

1. **Wave-Based Execution**: Tasks grouped into waves; all tasks in a wave can run in parallel
2. **Dependency Respect**: Never parallelize tasks with file conflicts or logical dependencies
3. **Fresh Context per Worker**: Each parallel worker starts with clean context (orchestrator pattern)
4. **Graceful Degradation**: Fall back to sequential execution if parallel fails
5. **Progress Visibility**: Track all concurrent workers and aggregate results

---

## Execution Modes

| Mode | When Used | Description |
|------|-----------|-------------|
| `sequential` | All tasks have dependencies | One task at a time |
| `parallel_waves` | Some tasks can parallelize | Groups of concurrent tasks |
| `fully_parallel` | All tasks independent | Maximum concurrency |

---

## Pattern: Spawn Parallel Workers

Launch multiple task workers concurrently using Claude Code's async agents.

```javascript
// SPAWN_PARALLEL_WORKERS_PATTERN
async function spawnParallelWorkers(wave, contextSummary, specFolder) {
  const agentIds = [];
  const taskResults = {};

  // 1. Spawn all workers in wave with run_in_background: true
  for (const taskId of wave.tasks) {
    const context = loadTaskContext(specFolder, taskId);
    const parallelContext = context.task.parallel_context;

    const workerPrompt = buildWorkerPrompt(taskId, context, parallelContext);

    // Use Task tool with run_in_background
    const result = await Task({
      description: `Execute task ${taskId}`,
      prompt: workerPrompt,
      subagent_type: 'task-worker',
      run_in_background: true
    });

    agentIds.push({
      taskId: taskId,
      agentId: result.agentId,
      startedAt: new Date().toISOString()
    });

    console.log(`Spawned worker for task ${taskId}: ${result.agentId}`);
  }

  // 2. Return agent tracking info
  return {
    wave_id: wave.wave_id,
    agents: agentIds,
    total_workers: agentIds.length,
    started_at: new Date().toISOString()
  };
}
```

---

## Pattern: Collect Worker Results

Wait for and collect results from all parallel workers.

```javascript
// COLLECT_WORKER_RESULTS_PATTERN
async function collectWorkerResults(waveAgents, timeout_seconds = 300) {
  const results = [];
  const startTime = Date.now();

  for (const agent of waveAgents.agents) {
    const elapsed = (Date.now() - startTime) / 1000;
    const remainingTimeout = Math.max(60, timeout_seconds - elapsed);

    try {
      // Use AgentOutputTool to wait for result
      const output = await AgentOutputTool({
        agentId: agent.agentId,
        block: true,
        wait_up_to: remainingTimeout
      });

      results.push({
        taskId: agent.taskId,
        agentId: agent.agentId,
        status: 'completed',
        result: parseWorkerResult(output),
        duration_ms: Date.now() - new Date(agent.startedAt).getTime()
      });

    } catch (error) {
      results.push({
        taskId: agent.taskId,
        agentId: agent.agentId,
        status: 'failed',
        error: error.message,
        duration_ms: Date.now() - new Date(agent.startedAt).getTime()
      });
    }
  }

  return {
    wave_id: waveAgents.wave_id,
    results: results,
    all_passed: results.every(r => r.status === 'completed' && r.result?.status === 'pass'),
    failed_tasks: results.filter(r => r.status === 'failed' || r.result?.status !== 'pass'),
    total_duration_ms: Date.now() - new Date(waveAgents.started_at).getTime()
  };
}

function parseWorkerResult(output) {
  // Parse structured result from worker
  // Workers should return JSON with status, files_modified, test_results
  try {
    const jsonMatch = output.match(/```json\n([\s\S]*?)\n```/);
    if (jsonMatch) {
      return JSON.parse(jsonMatch[1]);
    }
    // Fallback: look for status indicators
    return {
      status: output.includes('TASK COMPLETE') ? 'pass' : 'unknown',
      raw_output: output
    };
  } catch (e) {
    return { status: 'parse_error', raw_output: output };
  }
}
```

---

## Pattern: Monitor Worker Progress

Poll worker status without blocking (useful for progress updates).

```javascript
// MONITOR_WORKERS_PATTERN
async function monitorWorkerProgress(waveAgents, updateCallback) {
  const status = {};

  for (const agent of waveAgents.agents) {
    status[agent.taskId] = { agentId: agent.agentId, status: 'running' };
  }

  // Poll every 30 seconds
  const pollInterval = 30000;
  let allComplete = false;

  while (!allComplete) {
    await sleep(pollInterval);

    for (const agent of waveAgents.agents) {
      if (status[agent.taskId].status === 'running') {
        // Non-blocking check
        const check = await AgentOutputTool({
          agentId: agent.agentId,
          block: false
        });

        if (check.status === 'completed') {
          status[agent.taskId].status = 'completed';
          status[agent.taskId].result = check.output;
        } else if (check.status === 'failed') {
          status[agent.taskId].status = 'failed';
          status[agent.taskId].error = check.error;
        }
        // else still running
      }
    }

    // Update callback for UI/logging
    if (updateCallback) {
      updateCallback(status);
    }

    // Check if all complete
    allComplete = Object.values(status).every(s =>
      s.status === 'completed' || s.status === 'failed'
    );
  }

  return status;
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}
```

---

## Pattern: Execute Wave with Retry

Execute a wave of parallel tasks with retry logic for failures.

```javascript
// EXECUTE_WAVE_WITH_RETRY_PATTERN
async function executeWaveWithRetry(wave, contextSummary, specFolder, maxRetries = 1) {
  let attempt = 0;
  let waveResult = null;

  while (attempt <= maxRetries) {
    attempt++;
    console.log(`Wave ${wave.wave_id} - Attempt ${attempt}`);

    // 1. Spawn workers
    const waveAgents = await spawnParallelWorkers(wave, contextSummary, specFolder);

    // 2. Collect results
    waveResult = await collectWorkerResults(waveAgents);

    // 3. Check for success
    if (waveResult.all_passed) {
      console.log(`Wave ${wave.wave_id} completed successfully`);
      return waveResult;
    }

    // 4. Handle failures
    if (attempt <= maxRetries && waveResult.failed_tasks.length > 0) {
      console.log(`Wave ${wave.wave_id} had ${waveResult.failed_tasks.length} failures, retrying...`);

      // Only retry failed tasks
      wave = {
        ...wave,
        tasks: waveResult.failed_tasks.map(t => t.taskId)
      };
    }
  }

  // Return final result (may include failures)
  return waveResult;
}
```

---

## Pattern: Orchestrate All Waves

Full orchestration of parallel execution across all waves.

```javascript
// ORCHESTRATE_PARALLEL_EXECUTION_PATTERN
async function orchestrateParallelExecution(specFolder) {
  // 1. Load execution strategy
  const tasksJson = JSON.parse(
    readFileSync(`${specFolder}/tasks.json`, 'utf8')
  );
  const contextSummary = JSON.parse(
    readFileSync(`${specFolder}/context-summary.json`, 'utf8')
  );

  const { execution_strategy } = tasksJson;

  if (execution_strategy.mode === 'sequential') {
    console.log('Sequential mode - no parallel execution');
    return { mode: 'sequential', waves_executed: 0 };
  }

  // 2. Execute each wave
  const waveResults = [];

  for (const wave of execution_strategy.waves) {
    console.log(`\n=== Executing Wave ${wave.wave_id} ===`);
    console.log(`Tasks: ${wave.tasks.join(', ')}`);
    console.log(`Rationale: ${wave.rationale}`);

    // Execute wave with parallel workers
    const result = await executeWaveWithRetry(
      wave,
      contextSummary,
      specFolder
    );

    waveResults.push(result);

    // Update tasks.json with results
    updateTasksWithResults(specFolder, result);

    // Check for blocking failures
    if (!result.all_passed) {
      const criticalFailures = result.failed_tasks.filter(t =>
        // Check if any later waves depend on failed tasks
        execution_strategy.waves.some(w =>
          w.wave_id > wave.wave_id &&
          w.tasks.some(wt =>
            tasksJson.tasks.find(task =>
              task.id === wt &&
              task.parallelization?.blocked_by?.includes(t.taskId)
            )
          )
        )
      );

      if (criticalFailures.length > 0) {
        console.log(`Critical failures block later waves: ${criticalFailures.map(t => t.taskId).join(', ')}`);
        return {
          mode: 'parallel_waves',
          status: 'blocked',
          waves_executed: waveResults.length,
          wave_results: waveResults,
          blocking_failures: criticalFailures
        };
      }
    }
  }

  // 3. Return aggregate results
  const allPassed = waveResults.every(w => w.all_passed);

  return {
    mode: 'parallel_waves',
    status: allPassed ? 'success' : 'partial',
    waves_executed: waveResults.length,
    wave_results: waveResults,
    total_tasks: execution_strategy.waves.reduce((sum, w) => sum + w.tasks.length, 0),
    passed_tasks: waveResults.reduce((sum, w) =>
      sum + w.results.filter(r => r.result?.status === 'pass').length, 0
    ),
    estimated_sequential_time: execution_strategy.total_sequential_minutes,
    actual_parallel_time: waveResults.reduce((sum, w) => sum + w.total_duration_ms, 0) / 60000,
    speedup_achieved: execution_strategy.total_sequential_minutes /
      (waveResults.reduce((sum, w) => sum + w.total_duration_ms, 0) / 60000)
  };
}

function updateTasksWithResults(specFolder, waveResult) {
  const jsonPath = `${specFolder}/tasks.json`;
  const tasksJson = JSON.parse(readFileSync(jsonPath, 'utf8'));

  for (const taskResult of waveResult.results) {
    const task = tasksJson.tasks.find(t => t.id === taskResult.taskId);
    if (task) {
      task.status = taskResult.result?.status === 'pass' ? 'pass' : 'blocked';
      task.completed_at = taskResult.result?.status === 'pass'
        ? new Date().toISOString()
        : null;
      task.duration_minutes = Math.round(taskResult.duration_ms / 60000);
      if (taskResult.error) {
        task.blocker = taskResult.error;
      }
    }
  }

  // Atomic write
  const tempPath = `${jsonPath}.tmp`;
  writeFileSync(tempPath, JSON.stringify(tasksJson, null, 2));
  renameSync(tempPath, jsonPath);
}
```

---

## Pattern: Build Worker Prompt

Construct the prompt for a parallel worker agent.

```javascript
// BUILD_WORKER_PROMPT_PATTERN
function buildWorkerPrompt(taskId, context, parallelContext) {
  const { global, task } = context;

  let prompt = `# Task Worker: Execute Task ${taskId}

You are a task worker agent executing a single task. Complete this task and return a structured result.

## Task Details
- **ID**: ${taskId}
- **Description**: ${task.summary}

## Project Context
- **Product**: ${global.product_pitch}
- **Tech Stack**: ${global.tech_stack.join(', ')}
- **Branch**: ${global.branch_name}

## Spec Sections to Reference
${task.spec_sections.map(s => `- ${s}`).join('\n')}

## Files to Modify
${task.relevant_files.map(f => `- ${f}`).join('\n')}

`;

  // Add codebase references
  if (task.codebase_refs?.functions?.length > 0) {
    prompt += `## Existing Functions (USE EXACT NAMES)
\`\`\`
${task.codebase_refs.functions.join('\n')}
\`\`\`

`;
  }

  // Add parallel context
  if (parallelContext) {
    prompt += `## Parallel Execution Context
- **Wave**: ${parallelContext.wave}
- **Conflict Risk**: ${parallelContext.conflict_risk}
${parallelContext.concurrent_tasks.length > 0
  ? `- **Concurrent With**: Tasks ${parallelContext.concurrent_tasks.join(', ')}`
  : '- **Sequential Execution**'}

### Worker Instructions
${parallelContext.worker_instructions}

`;
  }

  // Add standards
  if (task.standards?.patterns?.length > 0) {
    prompt += `## Patterns to Follow
${task.standards.patterns.map(p => `- ${p}`).join('\n')}

`;
  }

  // Add expected output format
  prompt += `## Expected Output

Complete the task following TDD (test first, then implement). When done, output your result as:

\`\`\`json
{
  "status": "pass|fail|blocked",
  "files_modified": ["path/to/file.ts"],
  "files_created": ["path/to/new.ts"],
  "test_results": {
    "ran": 5,
    "passed": 5,
    "failed": 0
  },
  "blocker": null,
  "notes": "Implementation summary",
  "duration_minutes": 15
}
\`\`\`

Then state: **TASK COMPLETE**
`;

  return prompt;
}
```

---

## Error Handling

| Error | Recovery |
|-------|----------|
| Worker timeout | Retry once with extended timeout, then mark blocked |
| Worker crash | Log error, mark task blocked, continue wave |
| All workers fail | Abort wave, fall back to sequential for remaining |
| Partial wave failure | Complete wave, log failures, continue if non-blocking |
| AgentOutputTool error | Retry with block: false polling, then timeout |

---

## Performance Metrics

Track these metrics for parallel execution:

```javascript
// PARALLEL_METRICS
const metrics = {
  // Time metrics
  total_sequential_estimate: 150, // minutes (from execution_strategy)
  total_parallel_actual: 105,     // minutes (measured)
  speedup_factor: 1.43,           // sequential / parallel

  // Task metrics
  total_tasks: 5,
  parallelized_tasks: 3,
  sequential_tasks: 2,

  // Wave metrics
  total_waves: 2,
  max_concurrent: 2,
  avg_wave_time: 52.5,            // minutes

  // Worker metrics
  workers_spawned: 5,
  workers_succeeded: 5,
  workers_failed: 0,
  workers_retried: 0
};
```

---

## Usage in Commands

Reference these patterns:

```markdown
## Parallel Execution

Use patterns from @shared/parallel-execution.md:
- Spawn workers: SPAWN_PARALLEL_WORKERS_PATTERN
- Collect results: COLLECT_WORKER_RESULTS_PATTERN
- Monitor progress: MONITOR_WORKERS_PATTERN
- Execute wave: EXECUTE_WAVE_WITH_RETRY_PATTERN
- Full orchestration: ORCHESTRATE_PARALLEL_EXECUTION_PATTERN
- Build prompt: BUILD_WORKER_PROMPT_PATTERN

Use in execute-tasks when execution_strategy.mode is 'parallel_waves'.
```
