/**
 * Agent OS - Shared Graph Utilities
 *
 * Reusable dependency-graph algorithms used by compute-waves.ts and
 * wave-parallel.ts.  Extracted to eliminate duplication of Kahn's
 * algorithm and related helpers.
 */

// ============================================================================
// Types
// ============================================================================

/** Minimal interface for graph operations */
export interface GraphNode {
  id: string;
  depends_on: string[];
  parent?: string;
}

export interface DepthAssignment {
  depths: Record<string, number>;
  graph: Record<string, string[]>;
  unprocessed: string[]; // IDs with circular deps
}

// ============================================================================
// Core Algorithms
// ============================================================================

/**
 * Kahn's algorithm topological sort.
 * Returns depth assignments for top-level nodes (excludes nodes with parent).
 * Handles cycles by tracking unprocessed nodes.
 */
export function kahnTopologicalSort(nodes: GraphNode[]): DepthAssignment {
  const topLevel = nodes.filter(n => !n.parent);
  const nodeIds = new Set(topLevel.map(n => n.id));

  // Build dependency graph filtered to existing nodes
  const graph: Record<string, string[]> = {};
  const inDegree: Record<string, number> = {};

  for (const node of topLevel) {
    graph[node.id] = (node.depends_on || []).filter(d => nodeIds.has(d));
    inDegree[node.id] = graph[node.id].length;
  }

  // Assign depths
  const depths: Record<string, number> = {};
  const queue: string[] = [];

  for (const node of topLevel) {
    if (inDegree[node.id] === 0) {
      queue.push(node.id);
      depths[node.id] = 0;
    }
  }

  let processed = 0;
  while (queue.length > 0) {
    const current = queue.shift()!;
    processed++;

    for (const node of topLevel) {
      if (graph[node.id].includes(current)) {
        depths[node.id] = Math.max(depths[node.id] || 0, depths[current] + 1);
        inDegree[node.id]--;
        if (inDegree[node.id] === 0) {
          queue.push(node.id);
        }
      }
    }
  }

  // Track unprocessed (circular dependency) nodes
  const unprocessed: string[] = [];
  if (processed < topLevel.length) {
    const maxDepth = Math.max(0, ...Object.values(depths));
    for (const node of topLevel) {
      if (depths[node.id] === undefined) {
        depths[node.id] = maxDepth + 1;
        unprocessed.push(node.id);
      }
    }
  }

  return { depths, graph, unprocessed };
}

/**
 * Group depth assignments into waves (sorted by depth).
 */
export function groupByDepth(depths: Record<string, number>): Array<{ depth: number; tasks: string[] }> {
  const waveMap = new Map<number, string[]>();
  for (const [id, d] of Object.entries(depths)) {
    if (!waveMap.has(d)) waveMap.set(d, []);
    waveMap.get(d)!.push(id);
  }
  return Array.from(waveMap.entries())
    .sort(([a], [b]) => a - b)
    .map(([d, tasks]) => ({ depth: d, tasks }));
}

/**
 * Build dependency graph from tasks, supporting v3 (parallelization.blocked_by)
 * and v4 (depends_on).
 */
export function buildDependencyGraph(tasks: any[], version?: string): Record<string, string[]> {
  const graph: Record<string, string[]> = {};

  if (version && version.startsWith('4')) {
    for (const task of tasks) {
      if (!task.parent) {
        graph[task.id] = task.depends_on || [];
      }
    }
  } else {
    for (const task of tasks) {
      if (task.type === 'parent') {
        graph[task.id] = task.parallelization?.blocked_by || [];
      }
    }
  }

  return graph;
}

/**
 * Check if any task in groupA depends on a task in groupB.
 */
export function hasCrossDependency(
  groupA: string[],
  groupB: string[],
  graph: Record<string, string[]>
): boolean {
  for (const taskId of groupA) {
    const deps = graph[taskId] || [];
    if (deps.some(d => groupB.includes(d))) return true;
  }
  return false;
}
