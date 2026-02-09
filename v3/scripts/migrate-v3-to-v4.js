#!/usr/bin/env node

/**
 * Agent OS v5.0 - Migrate tasks.json from v3.0 to v4.0
 *
 * Converts existing tasks.json files in-place:
 * 1. Extracts depends_on from parallelization.blocked_by
 * 2. Promotes isolation_score and shared_files to top level
 * 3. Adds task_type field to all tasks
 * 4. Generates infrastructure tasks (branch, verify, PR, merge, deliver)
 * 5. Computes waves via topological sort
 * 6. Backs up original as tasks.v3-backup.json
 *
 * Usage: node migrate-v3-to-v4.js <tasks.json> [--dry-run]
 */

const fs = require('fs');
const path = require('path');

function migrate(inputPath, dryRun = false) {
  if (!fs.existsSync(inputPath)) {
    console.error(`File not found: ${inputPath}`);
    process.exit(1);
  }

  const raw = fs.readFileSync(inputPath, 'utf-8');
  const v3 = JSON.parse(raw);

  if (!v3.version || !v3.version.startsWith('3')) {
    console.error(`Expected version 3.x, got ${v3.version || 'none'}`);
    process.exit(1);
  }

  console.log(`Migrating ${inputPath} from v${v3.version} to v4.0...`);

  // ── Step 1: Backup ──
  if (!dryRun) {
    const backupPath = inputPath.replace('.json', '.v3-backup.json');
    fs.writeFileSync(backupPath, raw);
    console.log(`  Backup: ${backupPath}`);
  }

  // ── Step 2: Convert tasks ──
  const waves = v3.execution_strategy?.waves || [];
  const v4Tasks = [];
  const parentTasks = v3.tasks.filter(t => t.type === 'parent');
  const subtasks = v3.tasks.filter(t => t.type === 'subtask');

  // Determine which wave each parent task belongs to
  const taskWaveMap = {};
  for (const wave of waves) {
    for (const taskId of wave.tasks) {
      taskWaveMap[taskId] = wave.wave_id;
    }
  }

  // Group parent tasks by wave
  const tasksByWave = {};
  for (const task of parentTasks) {
    const waveId = taskWaveMap[task.id] || task.parallelization?.wave || 1;
    if (!tasksByWave[waveId]) tasksByWave[waveId] = [];
    tasksByWave[waveId].push(task);
  }

  const actualWaveCount = Math.max(1, ...Object.keys(tasksByWave).map(Number));
  const specName = v3.spec || 'unknown';

  // ── Step 3: Generate infrastructure + convert implementation tasks per wave ──
  for (let w = 1; w <= actualWaveCount; w++) {
    const waveTasks = tasksByWave[w] || [];
    const prevMerge = w > 1 ? `W${w - 1}-MERGE` : null;

    // Branch setup task
    const branchTask = {
      id: `W${w}-BRANCH`,
      task_type: 'git-operation',
      description: `Create wave-${w} branch${w === 1 ? ' and feature branch' : ' from feature branch'}`,
      status: 'pending',
      depends_on: prevMerge ? [prevMerge] : [],
      auto_assign: 'git-ops',
      config: {
        operation: 'branch-setup',
        ...(w === 1 ? {
          base_branch: 'main',
          feature_branch: `feature/${specName}`,
          wave_branch: `feature/${specName}-wave-${w}`
        } : {
          wave_branch: `feature/${specName}-wave-${w}`
        })
      }
    };
    v4Tasks.push(branchTask);

    // Convert implementation tasks
    for (const task of waveTasks) {
      const converted = {
        id: task.id,
        task_type: 'implementation',
        description: task.description,
        status: task.status,
        depends_on: [`W${w}-BRANCH`],
      };

      // Promote fields from parallelization to top level
      if (task.parallelization) {
        converted.isolation_score = task.parallelization.isolation_score ?? 1.0;
        converted.shared_files = task.parallelization.shared_files || [];
        // Cross-wave deps are handled by W-BRANCH depending on W-1-MERGE, no need to duplicate
      }

      // Keep existing fields
      if (task.subtasks) converted.subtasks = task.subtasks;
      if (task.subtask_execution) converted.subtask_execution = task.subtask_execution;
      if (task.complexity) converted.complexity = task.complexity;
      if (task.complexity_reasoning) converted.complexity_reasoning = task.complexity_reasoning;
      if (task.artifacts) converted.artifacts = task.artifacts;
      if (task.checkpoint) converted.checkpoint = task.checkpoint;
      if (task.progress_percent != null) converted.progress_percent = task.progress_percent;
      if (task.attempts != null) converted.attempts = task.attempts;
      if (task.started_at) converted.started_at = task.started_at;
      if (task.completed_at) converted.completed_at = task.completed_at;
      if (task.duration_minutes != null) converted.duration_minutes = task.duration_minutes;
      if (task.notes) converted.notes = task.notes;
      if (task.blocker) converted.blocker = task.blocker;

      // Add predecessor_artifacts for tasks that depend on previous wave outputs
      if (w > 1 && task.parallelization?.blocked_by?.length > 0) {
        const predArtifacts = {};
        for (const depId of task.parallelization.blocked_by) {
          const depTask = parentTasks.find(t => t.id === depId);
          if (depTask && depTask.artifacts?.exports_added?.length > 0) {
            predArtifacts[depId] = { exports: depTask.artifacts.exports_added };
          }
        }
        if (Object.keys(predArtifacts).length > 0) {
          converted.predecessor_artifacts = predArtifacts;
        }
      }

      v4Tasks.push(converted);
    }

    // Convert subtasks for this wave's parent tasks
    const waveTaskIds = new Set(waveTasks.map(t => t.id));
    for (const sub of subtasks) {
      if (waveTaskIds.has(sub.parent)) {
        v4Tasks.push({
          id: sub.id,
          task_type: 'implementation',
          parent: sub.parent,
          description: sub.description,
          status: sub.status,
          depends_on: [],
          ...(sub.tdd_phase && { tdd_phase: sub.tdd_phase }),
          ...(sub.started_at && { started_at: sub.started_at }),
          ...(sub.completed_at && { completed_at: sub.completed_at }),
          ...(sub.blocker && { blocker: sub.blocker }),
          ...(sub.notes && { notes: sub.notes }),
        });
      }
    }

    // Verify task
    const verifyExports = waveTasks
      .flatMap(t => t.artifacts?.exports_added || []);
    const verifyFiles = waveTasks
      .flatMap(t => [...(t.artifacts?.files_created || []), ...(t.artifacts?.files_modified || [])]);

    v4Tasks.push({
      id: `W${w}-VERIFY`,
      task_type: 'verification',
      description: `Verify wave-${w} exports, run tests and type check`,
      status: 'pending',
      depends_on: waveTasks.map(t => t.id),
      auto_assign: 'verifier',
      config: {
        verify_exports: verifyExports,
        verify_files: verifyFiles,
        run_tests: true,
        run_tsc: true
      }
    });

    // PR task
    v4Tasks.push({
      id: `W${w}-PR`,
      task_type: 'git-operation',
      description: `Create wave-${w} PR to feature branch`,
      status: 'pending',
      depends_on: [`W${w}-VERIFY`],
      auto_assign: 'git-ops',
      config: {
        operation: 'create-pr',
        source: `feature/${specName}-wave-${w}`,
        target: `feature/${specName}`
      }
    });

    // Merge task
    v4Tasks.push({
      id: `W${w}-MERGE`,
      task_type: 'git-operation',
      description: `Merge wave-${w} PR${w === actualWaveCount ? ' (final wave)' : ''}`,
      status: 'pending',
      depends_on: [`W${w}-PR`],
      auto_assign: 'git-ops',
      config: {
        operation: 'merge-pr',
        requires_approval: w === actualWaveCount
      }
    });
  }

  // ── Step 4: E2E and Deliver tasks ──
  const lastMerge = `W${actualWaveCount}-MERGE`;

  // Check if E2E test plan exists
  const specDir = path.dirname(inputPath);
  const testPlanDir = specDir.replace('/specs/', '/test-plans/');
  const testPlanPath = path.join(testPlanDir, 'test-plan.json');
  const hasE2E = fs.existsSync(testPlanPath);

  if (hasE2E) {
    v4Tasks.push({
      id: 'E2E',
      task_type: 'e2e-testing',
      description: 'Run full E2E test plan',
      status: 'pending',
      depends_on: [lastMerge],
      auto_assign: 'test-runner',
      config: {
        scope: 'full',
        test_plan: testPlanPath
      }
    });
  }

  v4Tasks.push({
    id: 'DELIVER',
    task_type: 'git-operation',
    description: 'Create final PR to main',
    status: 'pending',
    depends_on: hasE2E ? ['E2E'] : [lastMerge],
    auto_assign: 'git-ops'
  });

  // ── Step 5: Compute waves ──
  const computed = computeWavesSimple(v4Tasks);

  // ── Step 6: Build v4 output ──
  const implTasks = v4Tasks.filter(t => t.task_type === 'implementation' && !t.parent);
  const infraTasks = v4Tasks.filter(t => t.task_type !== 'implementation');

  const v4 = {
    version: '4.0',
    spec: v3.spec,
    spec_path: v3.spec_path,
    created: v3.created,
    updated: new Date().toISOString(),
    tasks: v4Tasks,
    future_tasks: v3.future_tasks || [],
    computed,
    summary: {
      total_tasks: v4Tasks.filter(t => !t.parent).length,
      implementation_tasks: implTasks.length,
      infrastructure_tasks: infraTasks.length,
      completed: v4Tasks.filter(t => t.status === 'pass' && !t.parent).length,
      in_progress: v4Tasks.filter(t => t.status === 'in_progress' && !t.parent).length,
      blocked: v4Tasks.filter(t => t.status === 'blocked' && !t.parent).length,
      pending: v4Tasks.filter(t => t.status === 'pending' && !t.parent).length,
      overall_percent: 0
    }
  };

  const total = v4.summary.total_tasks;
  if (total > 0) {
    v4.summary.overall_percent = Math.floor((v4.summary.completed / total) * 100);
  }

  if (dryRun) {
    console.log(JSON.stringify(v4, null, 2));
  } else {
    fs.writeFileSync(inputPath, JSON.stringify(v4, null, 2));
    console.log(`  Migrated: ${v4Tasks.length} tasks (${implTasks.length} impl + ${infraTasks.length} infra)`);
    console.log(`  Waves: ${computed.waves.length}`);
    console.log(`  Done: ${inputPath}`);
  }
}

/**
 * Simplified Kahn's algorithm for the migration script (no ts-node dependency).
 */
function computeWavesSimple(tasks) {
  const topLevel = tasks.filter(t => !t.parent);
  const ids = new Set(topLevel.map(t => t.id));
  const depth = {};
  const inDeg = {};
  const depMap = {};

  for (const t of topLevel) {
    depMap[t.id] = (t.depends_on || []).filter(d => ids.has(d));
    inDeg[t.id] = depMap[t.id].length;
  }

  const queue = [];
  for (const t of topLevel) {
    if (inDeg[t.id] === 0) {
      queue.push(t.id);
      depth[t.id] = 0;
    }
  }

  while (queue.length > 0) {
    const cur = queue.shift();
    for (const t of topLevel) {
      if (depMap[t.id].includes(cur)) {
        depth[t.id] = Math.max(depth[t.id] || 0, depth[cur] + 1);
        inDeg[t.id]--;
        if (inDeg[t.id] === 0) queue.push(t.id);
      }
    }
  }

  // Handle unprocessed (cycle)
  const maxD = Math.max(0, ...Object.values(depth));
  for (const t of topLevel) {
    if (depth[t.id] === undefined) depth[t.id] = maxD + 1;
  }

  const waveMap = {};
  for (const [id, d] of Object.entries(depth)) {
    if (!waveMap[d]) waveMap[d] = [];
    waveMap[d].push(id);
  }

  const waves = Object.entries(waveMap)
    .sort(([a], [b]) => Number(a) - Number(b))
    .map(([d, taskIds]) => ({
      depth: Number(d),
      tasks: taskIds,
      label: `Depth ${d}`,
      parallel: taskIds.length > 1
    }));

  const graph = {};
  for (const t of topLevel) {
    graph[t.id] = depMap[t.id];
  }

  return {
    waves,
    dependency_graph: graph,
    max_concurrent_workers: Math.max(1, ...waves.map(w => w.tasks.length)),
    estimated_parallel_speedup: Math.round((topLevel.length / Math.max(1, waves.length)) * 100) / 100,
    total_implementation_tasks: topLevel.filter(t => t.task_type === 'implementation').length,
    total_infrastructure_tasks: topLevel.filter(t => t.task_type !== 'implementation').length
  };
}

// ── CLI ──
const args = process.argv.slice(2);
const dryRun = args.includes('--dry-run');
const filePaths = args.filter(a => !a.startsWith('--'));

if (filePaths.length === 0) {
  console.log(`
Agent OS v5.0 — Migrate tasks.json v3.0 → v4.0

Usage:
  node migrate-v3-to-v4.js <tasks.json> [--dry-run]
  node migrate-v3-to-v4.js .agent-os/specs/*/tasks.json

Options:
  --dry-run   Print converted output without writing

Backs up original as tasks.v3-backup.json
`);
  process.exit(1);
}

for (const fp of filePaths) {
  try {
    migrate(fp, dryRun);
  } catch (e) {
    console.error(`Error migrating ${fp}: ${e.message}`);
  }
}
