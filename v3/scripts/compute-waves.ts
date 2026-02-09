#!/usr/bin/env ts-node
/**
 * Agent OS v5.0 - Compute Waves via Topological Sort
 *
 * Computes execution waves from task depends_on fields using Kahn's algorithm.
 * Produces the `computed` section for tasks.json v4.0.
 *
 * Usage:
 *   ts-node compute-waves.ts <tasks.json>       Print computed section
 *   ts-node compute-waves.ts apply <tasks.json>  Write computed section into file
 *   ts-node compute-waves.ts test                Run inline tests
 */

import * as fs from 'fs';

// ============================================================================
// Types
// ============================================================================

interface TaskV4 {
  id: string;
  task_type: string;
  description: string;
  status: string;
  depends_on: string[];
  isolation_score?: number;
  shared_files?: string[];
  subtasks?: string[];
  parent?: string;
}

interface ComputedWave {
  depth: number;
  tasks: string[];
  label: string;
  parallel: boolean;
}

interface ComputedSection {
  waves: ComputedWave[];
  dependency_graph: Record<string, string[]>;
  max_concurrent_workers: number;
  estimated_parallel_speedup: number;
  total_implementation_tasks: number;
  total_infrastructure_tasks: number;
}

// ============================================================================
// Core: Kahn's Algorithm Topological Sort
// ============================================================================

export function computeWaves(tasks: TaskV4[]): ComputedSection {
  // Filter to top-level tasks (exclude subtasks)
  const topLevel = tasks.filter(t => !t.parent);

  // Build dependency graph and in-degree map
  const graph: Record<string, string[]> = {};
  const inDegree: Record<string, number> = {};
  const taskMap = new Map(topLevel.map(t => [t.id, t]));

  for (const task of topLevel) {
    graph[task.id] = task.depends_on.filter(d => taskMap.has(d));
    inDegree[task.id] = graph[task.id].length;
  }

  // Kahn's algorithm: assign depth to each task
  const depth: Record<string, number> = {};
  const queue: string[] = [];

  // Seed queue with zero in-degree tasks
  for (const task of topLevel) {
    if (inDegree[task.id] === 0) {
      queue.push(task.id);
      depth[task.id] = 0;
    }
  }

  let processed = 0;
  while (queue.length > 0) {
    const current = queue.shift()!;
    processed++;

    // Find tasks that depend on current
    for (const task of topLevel) {
      if (graph[task.id].includes(current)) {
        // Update depth: max of current depth + 1
        depth[task.id] = Math.max(depth[task.id] || 0, depth[current] + 1);
        inDegree[task.id]--;
        if (inDegree[task.id] === 0) {
          queue.push(task.id);
        }
      }
    }
  }

  // Check for cycles
  if (processed < topLevel.length) {
    const unprocessed = topLevel.filter(t => depth[t.id] === undefined).map(t => t.id);
    console.warn(`Circular dependency detected. Unprocessed tasks: ${unprocessed.join(', ')}`);
    // Assign max depth + 1 to unprocessed
    const maxDepth = Math.max(0, ...Object.values(depth));
    for (const id of unprocessed) {
      depth[id] = maxDepth + 1;
    }
  }

  // Group by depth → waves
  const waveMap = new Map<number, string[]>();
  for (const [id, d] of Object.entries(depth)) {
    if (!waveMap.has(d)) waveMap.set(d, []);
    waveMap.get(d)!.push(id);
  }

  const waves: ComputedWave[] = Array.from(waveMap.entries())
    .sort(([a], [b]) => a - b)
    .map(([d, taskIds]) => {
      const waveTasks = taskIds.map(id => taskMap.get(id)!);
      const implTasks = waveTasks.filter(t => t.task_type === 'implementation');
      const canParallel = taskIds.length > 1 && implTasks.every(t => (t.isolation_score ?? 1.0) >= 0.8);

      return {
        depth: d,
        tasks: taskIds,
        label: inferWaveLabel(waveTasks),
        parallel: canParallel
      };
    });

  // Compute statistics
  const implCount = topLevel.filter(t => t.task_type === 'implementation').length;
  const infraCount = topLevel.filter(t => t.task_type !== 'implementation').length;
  const maxConcurrent = Math.max(1, ...waves.map(w => w.parallel ? w.tasks.length : 1));

  // Estimate speedup
  const totalTasks = topLevel.length;
  const totalDepths = waves.length;
  const speedup = totalDepths > 0 ? Math.round((totalTasks / totalDepths) * 100) / 100 : 1;

  return {
    waves,
    dependency_graph: graph,
    max_concurrent_workers: maxConcurrent,
    estimated_parallel_speedup: speedup,
    total_implementation_tasks: implCount,
    total_infrastructure_tasks: infraCount
  };
}

function inferWaveLabel(tasks: TaskV4[]): string {
  const types = new Set(tasks.map(t => t.task_type));

  if (types.has('git-operation') && tasks.length === 1) {
    const op = tasks[0].description.toLowerCase();
    if (op.includes('branch')) return 'Branch setup';
    if (op.includes('pr') || op.includes('pull request')) return 'PR creation';
    if (op.includes('merge')) return 'Merge';
    if (op.includes('deliver')) return 'Final delivery';
    return 'Git operation';
  }
  if (types.has('pr-review')) return 'PR review';
  if (types.has('verification')) return 'Verification';
  if (types.has('e2e-testing')) return 'E2E validation';
  if (types.has('implementation')) {
    const descs = tasks.map(t => t.description.substring(0, 30)).join(', ');
    return `Implementation: ${descs}`;
  }
  return `Depth ${tasks[0] ? '' : 'empty'}`;
}

// ============================================================================
// CLI
// ============================================================================

if (require.main === module) {
  const args = process.argv.slice(2);

  if (args[0] === 'test') {
    runTests();
    process.exit(0);
  }

  const filePath = args[0] === 'apply' ? args[1] : args[0];
  const shouldApply = args[0] === 'apply';

  if (!filePath) {
    console.log(`
Compute Waves v5.0 — Topological sort for tasks.json v4.0

Usage:
  ts-node compute-waves.ts <tasks.json>        Print computed section
  ts-node compute-waves.ts apply <tasks.json>   Write computed into file
  ts-node compute-waves.ts test                 Run inline tests
`);
    process.exit(1);
  }

  if (!fs.existsSync(filePath)) {
    console.error(`File not found: ${filePath}`);
    process.exit(1);
  }

  const content = JSON.parse(fs.readFileSync(filePath, 'utf-8'));

  if (content.version !== '4.0') {
    console.error(`Expected version 4.0, got ${content.version}`);
    process.exit(1);
  }

  const computed = computeWaves(content.tasks);

  if (shouldApply) {
    content.computed = computed;
    content.updated = new Date().toISOString();
    fs.writeFileSync(filePath, JSON.stringify(content, null, 2));
    console.log(`Computed ${computed.waves.length} waves, written to ${filePath}`);
  } else {
    console.log(JSON.stringify(computed, null, 2));
  }
}

// ============================================================================
// Inline Tests
// ============================================================================

function runTests() {
  let passed = 0;
  let failed = 0;

  function test(name: string, fn: () => void) {
    try {
      fn();
      console.log(`  ✓ ${name}`);
      passed++;
    } catch (e) {
      console.log(`  ✗ ${name}: ${e}`);
      failed++;
    }
  }

  function assertEqual<T>(actual: T, expected: T) {
    if (JSON.stringify(actual) !== JSON.stringify(expected)) {
      throw new Error(`expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
    }
  }

  console.log('\n=== Compute Waves Tests ===\n');

  test('independent tasks → single depth', () => {
    const tasks: TaskV4[] = [
      { id: '1', task_type: 'implementation', description: 'A', status: 'pending', depends_on: [] },
      { id: '2', task_type: 'implementation', description: 'B', status: 'pending', depends_on: [] },
    ];
    const result = computeWaves(tasks);
    assertEqual(result.waves.length, 1);
    assertEqual(result.waves[0].depth, 0);
    assertEqual(result.waves[0].tasks.sort(), ['1', '2']);
  });

  test('sequential chain → one task per depth', () => {
    const tasks: TaskV4[] = [
      { id: 'A', task_type: 'git-operation', description: 'Branch', status: 'pending', depends_on: [] },
      { id: '1', task_type: 'implementation', description: 'Impl', status: 'pending', depends_on: ['A'] },
      { id: 'V', task_type: 'verification', description: 'Verify', status: 'pending', depends_on: ['1'] },
    ];
    const result = computeWaves(tasks);
    assertEqual(result.waves.length, 3);
    assertEqual(result.waves[0].tasks, ['A']);
    assertEqual(result.waves[1].tasks, ['1']);
    assertEqual(result.waves[2].tasks, ['V']);
  });

  test('diamond dependency → correct depth', () => {
    const tasks: TaskV4[] = [
      { id: 'B', task_type: 'git-operation', description: 'Branch', status: 'pending', depends_on: [] },
      { id: '1', task_type: 'implementation', description: 'A', status: 'pending', depends_on: ['B'] },
      { id: '2', task_type: 'implementation', description: 'B', status: 'pending', depends_on: ['B'] },
      { id: 'V', task_type: 'verification', description: 'Verify', status: 'pending', depends_on: ['1', '2'] },
    ];
    const result = computeWaves(tasks);
    assertEqual(result.waves.length, 3);
    assertEqual(result.waves[1].tasks.sort(), ['1', '2']);
    assertEqual(result.waves[1].parallel, true);
    assertEqual(result.waves[2].tasks, ['V']);
  });

  test('subtasks excluded from wave computation', () => {
    const tasks: TaskV4[] = [
      { id: '1', task_type: 'implementation', description: 'Parent', status: 'pending', depends_on: [], subtasks: ['1.1'] },
      { id: '1.1', task_type: 'implementation', description: 'Sub', status: 'pending', depends_on: [], parent: '1' },
    ];
    const result = computeWaves(tasks);
    assertEqual(result.waves.length, 1);
    assertEqual(result.waves[0].tasks, ['1']);
  });

  test('infrastructure vs implementation counts', () => {
    const tasks: TaskV4[] = [
      { id: 'W1-BRANCH', task_type: 'git-operation', description: 'Branch', status: 'pending', depends_on: [] },
      { id: '1', task_type: 'implementation', description: 'Impl', status: 'pending', depends_on: ['W1-BRANCH'] },
      { id: 'W1-VERIFY', task_type: 'verification', description: 'Verify', status: 'pending', depends_on: ['1'] },
      { id: 'E2E', task_type: 'e2e-testing', description: 'E2E', status: 'pending', depends_on: ['W1-VERIFY'] },
    ];
    const result = computeWaves(tasks);
    assertEqual(result.total_implementation_tasks, 1);
    assertEqual(result.total_infrastructure_tasks, 3);
  });

  console.log(`\n=== Results: ${passed} passed, ${failed} failed ===\n`);
  if (failed > 0) process.exit(1);
}
