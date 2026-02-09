# E2E Batch Checkpointing (v5.0.1)

> Checkpoint after each E2E scenario to enable resume on interruption.
> Prevents losing all progress when long E2E batches are interrupted.

## Overview

When running E2E test batches (smoke or full), the test executor writes a checkpoint file after each scenario completes. If the batch is interrupted, the next run can resume from where it left off.

```
┌─────────────────────────────────────────────────────────────────────┐
│                    CHECKPOINT LIFECYCLE                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Start batch                                                        │
│    │                                                                │
│    ├── Check for existing checkpoint                                │
│    │   ├── Fresh (< 2 hours old) → Resume from checkpoint           │
│    │   └── Stale (> 2 hours old) → Start fresh                     │
│    │                                                                │
│    ├── Execute scenario S1 → Write checkpoint                       │
│    ├── Execute scenario S2 → Write checkpoint                       │
│    ├── ⚡ INTERRUPTED ⚡                                             │
│    │                                                                │
│    ├── (Re-run) → Load checkpoint → Skip S1, S2                    │
│    ├── Execute scenario S3 → Write checkpoint                       │
│    ├── Execute scenario S4 → Write checkpoint                       │
│    │                                                                │
│    └── All done → Merge into results.json → Delete checkpoint       │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Checkpoint Schema

```json
{
  "version": "1.0",
  "spec_name": "feature-auth",
  "scope": "smoke|full",
  "started_at": "2026-02-09T10:00:00Z",
  "updated_at": "2026-02-09T10:05:00Z",
  "stale_threshold_hours": 2,
  "completed": [
    {
      "scenario_id": "S1",
      "status": "passed",
      "duration_ms": 5234,
      "completed_at": "2026-02-09T10:01:00Z"
    },
    {
      "scenario_id": "S2",
      "status": "failed",
      "duration_ms": 3456,
      "error": "Element not found: [data-testid='submit-btn']",
      "completed_at": "2026-02-09T10:02:30Z"
    }
  ],
  "pending": ["S3", "S4", "S5"],
  "resume_from": "S3",
  "summary": {
    "total": 5,
    "completed": 2,
    "passed": 1,
    "failed": 1,
    "remaining": 3
  }
}
```

## Checkpoint Location

```
.agent-os/test-results/${SPEC_NAME}/checkpoint.json
```

## Protocol

### Write Checkpoint (After Each Scenario)

```javascript
function writeCheckpoint(specName, scenarioResult, remainingScenarios) {
  const checkpointPath = `.agent-os/test-results/${specName}/checkpoint.json`;

  let checkpoint;
  if (fs.existsSync(checkpointPath)) {
    checkpoint = JSON.parse(fs.readFileSync(checkpointPath, 'utf-8'));
  } else {
    checkpoint = {
      version: "1.0",
      spec_name: specName,
      scope: scenarioResult.scope || "full",
      started_at: new Date().toISOString(),
      stale_threshold_hours: 2,
      completed: [],
      pending: remainingScenarios.map(s => s.id),
      summary: { total: 0, completed: 0, passed: 0, failed: 0, remaining: 0 }
    };
  }

  // Add completed scenario
  checkpoint.completed.push({
    scenario_id: scenarioResult.scenario_id,
    status: scenarioResult.status,
    duration_ms: scenarioResult.duration_ms,
    error: scenarioResult.failure_message || undefined,
    completed_at: new Date().toISOString()
  });

  // Update pending
  checkpoint.pending = remainingScenarios
    .filter(s => !checkpoint.completed.some(c => c.scenario_id === s.id))
    .map(s => s.id);

  checkpoint.resume_from = checkpoint.pending[0] || null;
  checkpoint.updated_at = new Date().toISOString();

  // Update summary
  checkpoint.summary = {
    total: checkpoint.completed.length + checkpoint.pending.length,
    completed: checkpoint.completed.length,
    passed: checkpoint.completed.filter(c => c.status === 'passed').length,
    failed: checkpoint.completed.filter(c => c.status === 'failed').length,
    remaining: checkpoint.pending.length
  };

  // Atomic write
  const tmpPath = checkpointPath + '.tmp';
  fs.writeFileSync(tmpPath, JSON.stringify(checkpoint, null, 2));
  fs.renameSync(tmpPath, checkpointPath);
}
```

### Read Checkpoint (At Batch Start)

```javascript
function readCheckpoint(specName) {
  const checkpointPath = `.agent-os/test-results/${specName}/checkpoint.json`;

  if (!fs.existsSync(checkpointPath)) {
    return null;  // No checkpoint — start fresh
  }

  const checkpoint = JSON.parse(fs.readFileSync(checkpointPath, 'utf-8'));

  // Check staleness
  const updatedAt = new Date(checkpoint.updated_at);
  const hoursOld = (Date.now() - updatedAt.getTime()) / (1000 * 60 * 60);

  if (hoursOld > (checkpoint.stale_threshold_hours || 2)) {
    console.log(`Checkpoint is ${hoursOld.toFixed(1)}h old (threshold: ${checkpoint.stale_threshold_hours}h) — starting fresh`);
    fs.unlinkSync(checkpointPath);
    return null;
  }

  console.log(`Resuming from checkpoint: ${checkpoint.summary.completed}/${checkpoint.summary.total} scenarios completed`);
  return checkpoint;
}
```

### Resume Protocol

```javascript
function getResumeScenarios(allScenarios, checkpoint) {
  if (!checkpoint) {
    return allScenarios;  // Run all
  }

  // Filter out already-completed scenarios
  const completedIds = new Set(checkpoint.completed.map(c => c.scenario_id));
  return allScenarios.filter(s => !completedIds.has(s.id));
}
```

### Cleanup (After Batch Complete)

```javascript
function finalizeCheckpoint(specName) {
  const checkpointPath = `.agent-os/test-results/${specName}/checkpoint.json`;
  const resultsPath = `.agent-os/test-results/${specName}/results.json`;

  if (!fs.existsSync(checkpointPath)) return;

  const checkpoint = JSON.parse(fs.readFileSync(checkpointPath, 'utf-8'));

  // Merge checkpoint results into results.json
  let results = {};
  if (fs.existsSync(resultsPath)) {
    results = JSON.parse(fs.readFileSync(resultsPath, 'utf-8'));
  }

  results.scenarios = (results.scenarios || []).concat(
    checkpoint.completed.map(c => ({
      scenario_id: c.scenario_id,
      status: c.status,
      duration_ms: c.duration_ms,
      error: c.error
    }))
  );
  results.checkpoint_resumed = true;
  results.total_checkpoint_scenarios = checkpoint.completed.length;

  fs.writeFileSync(resultsPath, JSON.stringify(results, null, 2));

  // Delete checkpoint
  fs.unlinkSync(checkpointPath);
  console.log(`Checkpoint merged into results.json and cleaned up`);
}
```

## Integration Points

### wave-lifecycle-agent (Step 3.5)

Before running smoke E2E, check for existing checkpoint:

```javascript
const checkpoint = readCheckpoint(spec_name);
const scenarios = getResumeScenarios(allSmokeScenarios, checkpoint);

if (checkpoint) {
  INFORM: `Resuming from checkpoint: ${checkpoint.summary.completed} scenarios already complete`;
}
```

### test-executor

After each scenario, write checkpoint:

```javascript
writeCheckpoint(spec_name, scenarioResult, remainingScenarios);
```

### phase3-delivery

Same pattern as wave-lifecycle-agent for full E2E runs.

## Best Practices

- **Always use atomic writes** (write to .tmp then rename)
- **Check staleness** before resuming (default: 2 hours)
- **Clean up** after batch completes
- **Don't checkpoint** in parallel execution — only sequential batches

---

## Changelog

### v5.0.1 (2026-02-09)
- Initial E2E batch checkpointing system
- Checkpoint schema with staleness detection
- Write/read/resume/cleanup protocol
- Integration with wave-lifecycle and phase3-delivery
