#!/usr/bin/env ts-node
/**
 * Wave Parallel Execution System for Agent OS v4.9.0
 * 
 * Provides parallel wave identification and execution coordination
 * for the execute-spec-orchestrator.
 * 
 * Features:
 * - Dependency graph analysis
 * - Parallel wave identification
 * - Task grouping by isolation score
 * - Integration with ast-verify.ts for artifact verification
 */

import * as fs from 'fs';
import * as path from 'path';

// ============================================================================
// Types
// ============================================================================

export interface Task {
  id: string;
  type: 'parent' | 'subtask';
  description: string;
  status: 'pending' | 'in_progress' | 'pass' | 'blocked';
  parallelization?: {
    wave: number;
    blocked_by: string[];
    can_parallel_with: string[];
    isolation_score: number;
    shared_files: string[];
  };
  subtasks?: string[];
}

export interface WaveGroup {
  wave_id: number;
  tasks: string[];
  can_parallel: boolean;
  isolation_score: number;
  rationale: string;
  estimated_duration_minutes: number;
}

export interface ParallelWaveResult {
  waves: WaveGroup[];
  dependency_graph: Record<string, string[]>;
  max_concurrent_workers: number;
  estimated_speedup: number;
}

export interface TasksJson {
  tasks: Task[];
  execution_strategy?: {
    waves: WaveGroup[];
    dependency_graph: Record<string, string[]>;
  };
}

// ============================================================================
// Core Functions
// ============================================================================

/**
 * Identify parallel waves from a dependency graph
 * Groups tasks that can execute concurrently based on dependencies
 */
export function identifyParallelWaves(
  tasks: Task[],
  dependencyGraph: Record<string, string[]>
): WaveGroup[] {
  const waves: WaveGroup[] = [];
  const completed = new Set<string>();
  const parentTasks = tasks.filter(t => t.type === 'parent' && t.status !== 'pass');
  
  let waveId = 1;
  let remaining = new Set(parentTasks.map(t => t.id));
  
  while (remaining.size > 0) {
    // Find tasks whose dependencies are all completed
    const readyTasks: string[] = [];
    
    for (const taskId of remaining) {
      const deps = dependencyGraph[taskId] || [];
      const allDepsComplete = deps.every(d => completed.has(d) || !remaining.has(d));
      
      if (allDepsComplete) {
        readyTasks.push(taskId);
      }
    }
    
    if (readyTasks.length === 0) {
      // Circular dependency or all remaining tasks are blocked
      console.warn('No ready tasks found - possible circular dependency');
      break;
    }
    
    // Calculate isolation score for this wave
    const waveTasks = parentTasks.filter(t => readyTasks.includes(t.id));
    const avgIsolation = calculateWaveIsolation(waveTasks);
    
    // Create wave group
    const wave: WaveGroup = {
      wave_id: waveId,
      tasks: readyTasks,
      can_parallel: readyTasks.length > 1 && avgIsolation >= 0.8,
      isolation_score: avgIsolation,
      rationale: generateWaveRationale(waveTasks, waveId),
      estimated_duration_minutes: estimateWaveDuration(waveTasks)
    };
    
    waves.push(wave);
    
    // Mark as completed and remove from remaining
    readyTasks.forEach(id => {
      completed.add(id);
      remaining.delete(id);
    });
    
    waveId++;
  }
  
  return waves;
}

/**
 * Check if a task group has dependencies on another group
 */
export function hasDependencyOnGroup(
  groupA: string[],
  groupB: string[],
  dependencyGraph: Record<string, string[]>
): boolean {
  for (const taskId of groupA) {
    const deps = dependencyGraph[taskId] || [];
    for (const dep of deps) {
      if (groupB.includes(dep)) {
        return true;
      }
    }
  }
  return false;
}

/**
 * Build dependency graph from tasks.json structure
 */
export function buildDependencyGraph(tasks: Task[]): Record<string, string[]> {
  const graph: Record<string, string[]> = {};
  
  for (const task of tasks) {
    if (task.type === 'parent') {
      graph[task.id] = task.parallelization?.blocked_by || [];
    }
  }
  
  return graph;
}

/**
 * Calculate isolation score for a wave (how independent are the tasks)
 */
function calculateWaveIsolation(tasks: Task[]): number {
  if (tasks.length === 0) return 1.0;
  if (tasks.length === 1) return 1.0;
  
  // Check for shared files between tasks
  const allSharedFiles = new Set<string>();
  let overlapCount = 0;
  
  for (const task of tasks) {
    const sharedFiles = task.parallelization?.shared_files || [];
    for (const file of sharedFiles) {
      if (allSharedFiles.has(file)) {
        overlapCount++;
      }
      allSharedFiles.add(file);
    }
  }
  
  // Average isolation from task metadata
  const avgTaskIsolation = tasks.reduce(
    (sum, t) => sum + (t.parallelization?.isolation_score || 1.0),
    0
  ) / tasks.length;
  
  // Penalize for file overlaps
  const overlapPenalty = overlapCount * 0.1;
  
  return Math.max(0, Math.min(1, avgTaskIsolation - overlapPenalty));
}

/**
 * Generate rationale string for a wave
 */
function generateWaveRationale(tasks: Task[], waveId: number): string {
  if (tasks.length === 0) return 'Empty wave';
  
  const descriptions = tasks.map(t => t.description.substring(0, 30));
  const canParallel = tasks.every(t => 
    (t.parallelization?.isolation_score || 0) >= 0.8
  );
  
  if (waveId === 1) {
    return `Foundation wave - ${descriptions.join(', ')}. ${canParallel ? 'Independent tasks.' : 'Sequential dependencies.'}`;
  }
  
  return `Wave ${waveId} - ${tasks.length} task(s). ${canParallel ? 'Can run in parallel.' : 'Sequential execution recommended.'}`;
}

/**
 * Estimate duration for a wave based on task complexity
 */
function estimateWaveDuration(tasks: Task[]): number {
  // Base estimate: 15 minutes per task, reduced for parallel execution
  const baseMinutes = 15;
  const parallelFactor = 0.6; // Parallel tasks take ~60% of sequential time
  
  const canParallel = tasks.every(t => 
    (t.parallelization?.isolation_score || 0) >= 0.8
  );
  
  if (canParallel && tasks.length > 1) {
    return Math.ceil(baseMinutes * parallelFactor * Math.sqrt(tasks.length));
  }
  
  return tasks.length * baseMinutes;
}

/**
 * Load tasks.json and analyze for parallel execution
 */
export function analyzeTasksForParallelization(tasksJsonPath: string): ParallelWaveResult {
  if (!fs.existsSync(tasksJsonPath)) {
    throw new Error(`Tasks file not found: ${tasksJsonPath}`);
  }
  
  const content = fs.readFileSync(tasksJsonPath, 'utf-8');
  const tasksJson: TasksJson = JSON.parse(content);
  
  const tasks = tasksJson.tasks;
  const dependencyGraph = tasksJson.execution_strategy?.dependency_graph || 
                          buildDependencyGraph(tasks);
  
  const waves = identifyParallelWaves(tasks, dependencyGraph);
  
  // Calculate max concurrent workers
  const maxConcurrent = Math.max(...waves.map(w => w.can_parallel ? w.tasks.length : 1));
  
  // Calculate estimated speedup
  const sequentialTime = waves.reduce((sum, w) => sum + w.estimated_duration_minutes * w.tasks.length / (w.can_parallel ? w.tasks.length : 1), 0);
  const parallelTime = waves.reduce((sum, w) => sum + w.estimated_duration_minutes, 0);
  const speedup = sequentialTime / parallelTime;
  
  return {
    waves,
    dependency_graph: dependencyGraph,
    max_concurrent_workers: maxConcurrent,
    estimated_speedup: Math.round(speedup * 100) / 100
  };
}

// ============================================================================
// CLI Interface
// ============================================================================

if (require.main === module) {
  const args = process.argv.slice(2);
  const command = args[0];
  
  if (command === 'analyze' && args[1]) {
    const result = analyzeTasksForParallelization(args[1]);
    console.log(JSON.stringify(result, null, 2));
    process.exit(0);
  }
  
  if (command === 'waves' && args[1]) {
    const result = analyzeTasksForParallelization(args[1]);
    console.log(`Found ${result.waves.length} waves:`);
    result.waves.forEach(w => {
      console.log(`  Wave ${w.wave_id}: ${w.tasks.join(', ')} (parallel: ${w.can_parallel})`);
    });
    process.exit(0);
  }
  
  if (command === 'test') {
    // Run inline tests
    runTests();
    process.exit(0);
  }
  
  console.log(`
Wave Parallel Execution System v4.9.0

Usage:
  ts-node wave-parallel.ts analyze <tasks.json>   Analyze tasks for parallel execution
  ts-node wave-parallel.ts waves <tasks.json>     Show wave breakdown
  ts-node wave-parallel.ts test                   Run inline tests
`);
  process.exit(1);
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
      console.log(`✓ ${name}`);
      passed++;
    } catch (e) {
      console.log(`✗ ${name}`);
      console.log(`  Error: ${e}`);
      failed++;
    }
  }
  
  function assertEqual<T>(actual: T, expected: T, msg?: string) {
    if (JSON.stringify(actual) !== JSON.stringify(expected)) {
      throw new Error(`${msg || 'Assertion failed'}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
    }
  }
  
  console.log('\n=== Wave Parallel Tests ===\n');
  
  // Test 1: Basic wave identification
  test('identifyParallelWaves - independent tasks form single wave', () => {
    const tasks: Task[] = [
      { id: '1', type: 'parent', description: 'Task 1', status: 'pending', parallelization: { wave: 1, blocked_by: [], can_parallel_with: ['2'], isolation_score: 1.0, shared_files: [] } },
      { id: '2', type: 'parent', description: 'Task 2', status: 'pending', parallelization: { wave: 1, blocked_by: [], can_parallel_with: ['1'], isolation_score: 1.0, shared_files: [] } },
    ];
    const depGraph = { '1': [], '2': [] };
    
    const waves = identifyParallelWaves(tasks, depGraph);
    
    assertEqual(waves.length, 1, 'Should have 1 wave');
    assertEqual(waves[0].tasks.sort(), ['1', '2'], 'Wave should contain both tasks');
    assertEqual(waves[0].can_parallel, true, 'Wave should be parallelizable');
  });
  
  // Test 2: Sequential dependency creates multiple waves
  test('identifyParallelWaves - sequential deps create multiple waves', () => {
    const tasks: Task[] = [
      { id: '1', type: 'parent', description: 'Task 1', status: 'pending', parallelization: { wave: 1, blocked_by: [], can_parallel_with: [], isolation_score: 1.0, shared_files: [] } },
      { id: '2', type: 'parent', description: 'Task 2', status: 'pending', parallelization: { wave: 2, blocked_by: ['1'], can_parallel_with: [], isolation_score: 1.0, shared_files: [] } },
      { id: '3', type: 'parent', description: 'Task 3', status: 'pending', parallelization: { wave: 3, blocked_by: ['2'], can_parallel_with: [], isolation_score: 1.0, shared_files: [] } },
    ];
    const depGraph = { '1': [], '2': ['1'], '3': ['2'] };
    
    const waves = identifyParallelWaves(tasks, depGraph);
    
    assertEqual(waves.length, 3, 'Should have 3 waves');
    assertEqual(waves[0].tasks, ['1'], 'Wave 1 should have task 1');
    assertEqual(waves[1].tasks, ['2'], 'Wave 2 should have task 2');
    assertEqual(waves[2].tasks, ['3'], 'Wave 3 should have task 3');
  });
  
  // Test 3: Mixed parallel and sequential
  test('identifyParallelWaves - mixed parallel and sequential', () => {
    const tasks: Task[] = [
      { id: '1', type: 'parent', description: 'Task 1', status: 'pending', parallelization: { wave: 1, blocked_by: [], can_parallel_with: ['2'], isolation_score: 1.0, shared_files: [] } },
      { id: '2', type: 'parent', description: 'Task 2', status: 'pending', parallelization: { wave: 1, blocked_by: [], can_parallel_with: ['1'], isolation_score: 1.0, shared_files: [] } },
      { id: '3', type: 'parent', description: 'Task 3', status: 'pending', parallelization: { wave: 2, blocked_by: ['1', '2'], can_parallel_with: [], isolation_score: 1.0, shared_files: [] } },
    ];
    const depGraph = { '1': [], '2': [], '3': ['1', '2'] };
    
    const waves = identifyParallelWaves(tasks, depGraph);
    
    assertEqual(waves.length, 2, 'Should have 2 waves');
    assertEqual(waves[0].tasks.sort(), ['1', '2'], 'Wave 1 should have tasks 1 and 2');
    assertEqual(waves[1].tasks, ['3'], 'Wave 2 should have task 3');
  });
  
  // Test 4: hasDependencyOnGroup
  test('hasDependencyOnGroup - detects cross-group dependency', () => {
    const depGraph = { 'A': ['X', 'Y'], 'B': [], 'X': [], 'Y': [] };
    
    const result = hasDependencyOnGroup(['A', 'B'], ['X', 'Y'], depGraph);
    assertEqual(result, true, 'Group A depends on X which is in group B');
  });
  
  test('hasDependencyOnGroup - no dependency returns false', () => {
    const depGraph = { 'A': [], 'B': [], 'X': [], 'Y': [] };
    
    const result = hasDependencyOnGroup(['A', 'B'], ['X', 'Y'], depGraph);
    assertEqual(result, false, 'No cross-group dependencies');
  });
  
  // Test 5: buildDependencyGraph
  test('buildDependencyGraph - extracts from parallelization field', () => {
    const tasks: Task[] = [
      { id: '1', type: 'parent', description: 'Task 1', status: 'pending', parallelization: { wave: 1, blocked_by: [], can_parallel_with: [], isolation_score: 1.0, shared_files: [] } },
      { id: '2', type: 'parent', description: 'Task 2', status: 'pending', parallelization: { wave: 2, blocked_by: ['1'], can_parallel_with: [], isolation_score: 1.0, shared_files: [] } },
      { id: '1.1', type: 'subtask', description: 'Subtask 1.1', status: 'pending' },
    ];
    
    const graph = buildDependencyGraph(tasks);
    
    assertEqual(graph['1'], [], 'Task 1 has no deps');
    assertEqual(graph['2'], ['1'], 'Task 2 depends on 1');
    assertEqual(graph['1.1'], undefined, 'Subtasks are not included');
  });
  
  // Test 6: Skip completed tasks
  test('identifyParallelWaves - skips completed tasks', () => {
    const tasks: Task[] = [
      { id: '1', type: 'parent', description: 'Task 1', status: 'pass', parallelization: { wave: 1, blocked_by: [], can_parallel_with: [], isolation_score: 1.0, shared_files: [] } },
      { id: '2', type: 'parent', description: 'Task 2', status: 'pending', parallelization: { wave: 2, blocked_by: ['1'], can_parallel_with: [], isolation_score: 1.0, shared_files: [] } },
    ];
    const depGraph = { '1': [], '2': ['1'] };
    
    const waves = identifyParallelWaves(tasks, depGraph);
    
    assertEqual(waves.length, 1, 'Should have 1 wave (task 1 is completed)');
    assertEqual(waves[0].tasks, ['2'], 'Only task 2 should be in wave');
  });
  
  // Test 7: Low isolation score prevents parallelization
  test('identifyParallelWaves - low isolation prevents parallel', () => {
    const tasks: Task[] = [
      { id: '1', type: 'parent', description: 'Task 1', status: 'pending', parallelization: { wave: 1, blocked_by: [], can_parallel_with: ['2'], isolation_score: 0.5, shared_files: ['shared.ts'] } },
      { id: '2', type: 'parent', description: 'Task 2', status: 'pending', parallelization: { wave: 1, blocked_by: [], can_parallel_with: ['1'], isolation_score: 0.5, shared_files: ['shared.ts'] } },
    ];
    const depGraph = { '1': [], '2': [] };
    
    const waves = identifyParallelWaves(tasks, depGraph);
    
    assertEqual(waves[0].can_parallel, false, 'Low isolation should prevent parallel execution');
  });
  
  console.log(`\n=== Results: ${passed} passed, ${failed} failed ===\n`);
  
  if (failed > 0) {
    process.exit(1);
  }
}
