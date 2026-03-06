#!/usr/bin/env node

/**
 * Agent OS v5.0 - JSON to Markdown Generator
 *
 * Generates tasks.md from tasks.json (single-source architecture)
 * Supports both v3.0 and v4.0 task formats.
 * Called automatically by PostToolUse hook when tasks.json changes.
 *
 * Usage: node json-to-markdown.js <tasks.json path>
 */

const fs = require('fs');
const { getTaskStatusIcon, formatTimestamp, generateProgressBar, runCli } = require('./markdown-utils');

// ============================================================================
// Task type icons (v4.0)
// ============================================================================

const TYPE_ICONS = {
  'git-operation': '[G]',
  'verification': '[V]',
  'e2e-testing': '[E]',
  'discovery': '[D]',
  'pr-review': '[R]',
  'implementation': ''
};

function getTypeIcon(taskType) {
  return TYPE_ICONS[taskType] || '';
}

// ============================================================================
// v4.0 Renderer
// ============================================================================

function generateMarkdownV4(tasksJson) {
  const { spec, tasks, summary, computed, updated } = tasksJson;
  const lines = [];

  // Header
  lines.push(`# Tasks: ${spec}`);
  lines.push('');
  lines.push(`> **Auto-generated from tasks.json v4.0** - Do not edit directly`);
  lines.push(`> Last updated: ${updated}`);
  lines.push('');

  // Summary
  lines.push('## Summary');
  lines.push('');
  lines.push(`| Metric | Value |`);
  lines.push(`|--------|-------|`);
  lines.push(`| Total Tasks | ${summary.total_tasks} |`);
  lines.push(`| Implementation | ${summary.implementation_tasks} |`);
  lines.push(`| Infrastructure | ${summary.infrastructure_tasks} |`);
  lines.push(`| Completed | ${summary.completed} (${summary.overall_percent}%) |`);
  lines.push(`| In Progress | ${summary.in_progress || 0} |`);
  lines.push(`| Blocked | ${summary.blocked || 0} |`);
  lines.push(`| Pending | ${summary.pending} |`);
  lines.push('');

  // Execution Waves (computed from dependencies)
  if (computed && computed.waves && computed.waves.length > 0) {
    lines.push('## Execution Waves (Computed from Dependencies)');
    lines.push('');
    if (computed.estimated_parallel_speedup) {
      lines.push(`**Estimated Speedup**: ${computed.estimated_parallel_speedup}x | **Max Concurrent**: ${computed.max_concurrent_workers}`);
      lines.push('');
    }
    for (const wave of computed.waves) {
      const waveTasks = wave.tasks.map(id => {
        const t = tasks.find(tt => tt.id === id);
        if (!t) return id;
        const icon = getTypeIcon(t.task_type);
        const status = getTaskStatusIcon(t.status);
        return `${icon}${icon ? ' ' : ''}${id} ${status}`.trim();
      });
      const parallelTag = wave.parallel ? ' [parallel]' : '';
      lines.push(`**Depth ${wave.depth}**: ${waveTasks.join(', ')}${parallelTag}`);
      if (wave.label) {
        lines.push(`  _${wave.label}_`);
      }
    }
    lines.push('');
  }

  // Dependency Graph
  if (computed && computed.dependency_graph) {
    lines.push('## Dependency Graph');
    lines.push('');
    lines.push('```');
    const roots = Object.entries(computed.dependency_graph)
      .filter(([, deps]) => deps.length === 0)
      .map(([id]) => id);
    const printed = new Set();
    for (const root of roots) {
      printDepTree(root, computed.dependency_graph, tasks, lines, '', true, printed);
    }
    lines.push('```');
    lines.push('');
  }

  // Infrastructure Tasks
  const infraTasks = tasks.filter(t => t.task_type !== 'implementation' && !t.parent);
  if (infraTasks.length > 0) {
    lines.push('## Infrastructure Tasks');
    lines.push('');
    lines.push('| ID | Type | Description | Status | Depends On | Assigned |');
    lines.push('|----|------|-------------|--------|------------|----------|');
    for (const t of infraTasks) {
      const icon = getTypeIcon(t.task_type);
      const status = `${getTaskStatusIcon(t.status)} ${t.status}`;
      const deps = (t.depends_on || []).join(', ') || '-';
      const assign = t.auto_assign || '-';
      lines.push(`| ${icon} ${t.id} | ${t.task_type} | ${t.description} | ${status} | ${deps} | ${assign} |`);
    }
    lines.push('');
  }

  // Implementation Tasks
  const implParents = tasks.filter(t => t.task_type === 'implementation' && !t.parent && t.subtasks);
  const implStandalone = tasks.filter(t => t.task_type === 'implementation' && !t.parent && !t.subtasks);

  lines.push('## Implementation Tasks');
  lines.push('');

  for (const parent of [...implParents, ...implStandalone]) {
    const statusIcon = getTaskStatusIcon(parent.status);
    const progressBar = generateProgressBar(parent.progress_percent || 0);

    lines.push(`### Task ${parent.id}: ${parent.description}`);
    lines.push('');
    lines.push(`**Status**: ${statusIcon} ${parent.status} ${progressBar}`);

    if (parent.complexity) {
      lines.push(`**Complexity**: ${parent.complexity}${parent.complexity_reasoning ? ` — ${parent.complexity_reasoning}` : ''}`);
    }
    if (parent.isolation_score != null) {
      lines.push(`**Isolation**: ${parent.isolation_score}`);
    }
    if (parent.depends_on && parent.depends_on.length > 0) {
      lines.push(`**Depends On**: ${parent.depends_on.join(', ')}`);
    }
    if (parent.started_at) {
      lines.push(`**Started**: ${formatTimestamp(parent.started_at)}`);
    }
    if (parent.completed_at) {
      lines.push(`**Completed**: ${formatTimestamp(parent.completed_at)}${parent.duration_minutes ? ` (${parent.duration_minutes} min)` : ''}`);
    }
    if (parent.blocker) {
      lines.push(`**Blocker**: ${parent.blocker}`);
    }
    lines.push('');

    // Subtasks
    const subtasks = tasks.filter(t => t.parent === parent.id);
    if (subtasks.length > 0) {
      lines.push('#### Subtasks');
      lines.push('');
      for (const subtask of subtasks) {
        const checkbox = subtask.status === 'pass' ? '[x]' :
                        subtask.status === 'blocked' ? '[!]' : '[ ]';
        const tddTag = subtask.tdd_phase ? ` \`${subtask.tdd_phase}\`` : '';
        const blockerNote = subtask.blocker ? ` — ${subtask.blocker}` : '';
        lines.push(`- ${checkbox} **${subtask.id}** ${subtask.description}${tddTag}${blockerNote}`);
      }
      lines.push('');
    }

    // Predecessor artifacts
    if (parent.predecessor_artifacts && Object.keys(parent.predecessor_artifacts).length > 0) {
      lines.push('#### Predecessor Artifacts');
      lines.push('');
      for (const [depId, arts] of Object.entries(parent.predecessor_artifacts)) {
        const exports = arts.exports ? arts.exports.join(', ') : '';
        lines.push(`- Task ${depId}: ${exports}`);
      }
      lines.push('');
    }

    // Artifacts (if completed)
    if (parent.artifacts && Object.keys(parent.artifacts).length > 0) {
      lines.push('#### Artifacts');
      lines.push('');
      if (parent.artifacts.files_created?.length > 0) {
        lines.push(`**Files Created**: ${parent.artifacts.files_created.join(', ')}`);
      }
      if (parent.artifacts.files_modified?.length > 0) {
        lines.push(`**Files Modified**: ${parent.artifacts.files_modified.join(', ')}`);
      }
      if (parent.artifacts.exports_added?.length > 0) {
        lines.push(`**Exports Added**: \`${parent.artifacts.exports_added.join('`, `')}\``);
      }
      if (parent.artifacts.test_files?.length > 0) {
        lines.push(`**Test Files**: ${parent.artifacts.test_files.join(', ')}`);
      }
      lines.push('');
    }

    lines.push('---');
    lines.push('');
  }

  // Future tasks
  if (tasksJson.future_tasks && tasksJson.future_tasks.length > 0) {
    lines.push('## Future Tasks');
    lines.push('');
    for (const ft of tasksJson.future_tasks) {
      lines.push(`- **${ft.id}**: ${ft.description} (${ft.priority || 'medium'}) — _${ft.source}_`);
    }
    lines.push('');
  }

  // Footer
  lines.push('## Notes');
  lines.push('');
  lines.push('- This file is auto-generated from `tasks.json` v4.0');
  lines.push('- Dependencies are primary; waves are computed via topological sort');
  lines.push('- To modify tasks, edit `tasks.json` or use Agent OS commands');
  lines.push('- Regenerated automatically by PostToolUse hook');
  lines.push('');

  return lines.join('\n');
}

/**
 * Print a dependency tree recursively
 */
function printDepTree(id, graph, tasks, lines, prefix, isLast, printed) {
  if (printed.has(id)) {
    lines.push(`${prefix}${isLast ? '└── ' : '├── '}${id} (see above)`);
    return;
  }
  printed.add(id);

  const task = tasks.find(t => t.id === id);
  const icon = task ? getTypeIcon(task.task_type) : '';
  const desc = task ? ` (${task.description.substring(0, 40)})` : '';
  lines.push(`${prefix}${isLast ? '└── ' : '├── '}${icon}${icon ? ' ' : ''}${id}${desc}`);

  // Find children (tasks that depend on this one)
  const children = Object.entries(graph)
    .filter(([, deps]) => deps.includes(id))
    .map(([childId]) => childId);

  for (let i = 0; i < children.length; i++) {
    const childPrefix = prefix + (isLast ? '    ' : '│   ');
    printDepTree(children[i], graph, tasks, lines, childPrefix, i === children.length - 1, printed);
  }
}

// ============================================================================
// v3.0 Renderer (preserved for backward compatibility)
// ============================================================================

function generateMarkdownV3(tasksJson) {
  const { spec, tasks, summary, execution_strategy, updated } = tasksJson;
  const lines = [];

  lines.push(`# Tasks: ${spec}`);
  lines.push('');
  lines.push(`> **Auto-generated from tasks.json** - Do not edit directly`);
  lines.push(`> Last updated: ${updated}`);
  lines.push('');

  lines.push('## Summary');
  lines.push('');
  lines.push(`| Metric | Value |`);
  lines.push(`|--------|-------|`);
  lines.push(`| Total Tasks | ${summary.total_tasks} |`);
  lines.push(`| Completed | ${summary.completed} (${summary.overall_percent}%) |`);
  lines.push(`| In Progress | ${summary.in_progress} |`);
  lines.push(`| Blocked | ${summary.blocked} |`);
  lines.push(`| Pending | ${summary.pending} |`);
  lines.push('');

  if (execution_strategy && execution_strategy.mode === 'parallel_waves') {
    lines.push('## Execution Strategy');
    lines.push('');
    lines.push(`**Mode**: ${execution_strategy.mode}`);
    lines.push(`**Estimated Speedup**: ${execution_strategy.estimated_parallel_speedup}x`);
    lines.push('');
    lines.push('### Waves');
    lines.push('');
    for (const wave of execution_strategy.waves) {
      const waveStatus = getWaveStatus(wave.tasks, tasks);
      lines.push(`- **Wave ${wave.wave_id}** [${waveStatus}]: Tasks ${wave.tasks.join(', ')}`);
      if (wave.rationale) {
        lines.push(`  - _${wave.rationale}_`);
      }
    }
    lines.push('');
  }

  lines.push('## Tasks');
  lines.push('');

  const parentTasks = tasks.filter(t => t.type === 'parent');

  for (const parent of parentTasks) {
    const statusIcon = getTaskStatusIcon(parent.status);
    const progressBar = generateProgressBar(parent.progress_percent || 0);

    lines.push(`### Task ${parent.id}: ${parent.description}`);
    lines.push('');
    lines.push(`**Status**: ${statusIcon} ${parent.status} ${progressBar}`);

    if (parent.started_at) {
      lines.push(`**Started**: ${formatTimestamp(parent.started_at)}`);
    }
    if (parent.completed_at) {
      lines.push(`**Completed**: ${formatTimestamp(parent.completed_at)} (${parent.duration_minutes} min)`);
    }
    if (parent.blocker) {
      lines.push(`**Blocker**: ${parent.blocker}`);
    }
    lines.push('');

    const subtasks = tasks.filter(t => t.parent === parent.id);
    if (subtasks.length > 0) {
      lines.push('#### Subtasks');
      lines.push('');
      for (const subtask of subtasks) {
        const checkbox = subtask.status === 'pass' ? '[x]' :
                        subtask.status === 'blocked' ? '[!]' : '[ ]';
        const blockerNote = subtask.blocker ? ` ${subtask.blocker}` : '';
        lines.push(`- ${checkbox} **${subtask.id}** ${subtask.description}${blockerNote}`);
      }
      lines.push('');
    }

    if (parent.artifacts && Object.keys(parent.artifacts).length > 0) {
      lines.push('#### Artifacts');
      lines.push('');
      if (parent.artifacts.files_created?.length > 0) {
        lines.push(`**Files Created**: ${parent.artifacts.files_created.join(', ')}`);
      }
      if (parent.artifacts.files_modified?.length > 0) {
        lines.push(`**Files Modified**: ${parent.artifacts.files_modified.join(', ')}`);
      }
      if (parent.artifacts.exports_added?.length > 0) {
        lines.push(`**Exports Added**: \`${parent.artifacts.exports_added.join('`, `')}\``);
      }
      if (parent.artifacts.test_files?.length > 0) {
        lines.push(`**Test Files**: ${parent.artifacts.test_files.join(', ')}`);
      }
      lines.push('');
    }

    lines.push('---');
    lines.push('');
  }

  lines.push('## Notes');
  lines.push('');
  lines.push('- This file is auto-generated from `tasks.json`');
  lines.push('- To modify tasks, edit `tasks.json` or use Agent OS commands');
  lines.push('- Regenerated automatically by PostToolUse hook');
  lines.push('');

  return lines.join('\n');
}

function getWaveStatus(taskIds, tasks) {
  const waveTasks = tasks.filter(t => taskIds.includes(t.id));
  const completed = waveTasks.filter(t => t.status === 'pass').length;
  const total = waveTasks.length;

  if (completed === total) return '\u2705 Complete';
  if (completed > 0) return '\uD83D\uDD04 In Progress';
  return '\u23F3 Pending';
}

// ============================================================================
// Main
// ============================================================================

// Route to correct renderer based on version
function generate(tasksJson) {
  if (tasksJson.version && tasksJson.version.startsWith('4')) {
    return generateMarkdownV4(tasksJson);
  } else if (tasksJson.version && tasksJson.version.startsWith('3')) {
    return generateMarkdownV3(tasksJson);
  }
  console.log(`Skipping: Unsupported version ${tasksJson.version || 'unknown'}`);
  process.exit(0);
}

runCli('json-to-markdown.js', generate, {
  postWrite: (jsonPath, json) => {
    json.markdown_generated = new Date().toISOString();
    fs.writeFileSync(jsonPath, JSON.stringify(json, null, 2));
  }
});
