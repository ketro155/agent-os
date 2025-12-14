#!/usr/bin/env node

/**
 * Agent OS v3.0 - JSON to Markdown Generator
 *
 * Generates tasks.md from tasks.json (single-source architecture)
 * Called automatically by PostToolUse hook when tasks.json changes
 *
 * Usage: node json-to-markdown.js <tasks.json path>
 */

const fs = require('fs');
const path = require('path');

function generateMarkdown(tasksJson) {
  const { spec, tasks, summary, execution_strategy, updated } = tasksJson;

  const lines = [];

  // Header
  lines.push(`# Tasks: ${spec}`);
  lines.push('');
  lines.push(`> **Auto-generated from tasks.json** - Do not edit directly`);
  lines.push(`> Last updated: ${updated}`);
  lines.push('');

  // Summary section
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

  // Parallel execution info
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

  // Tasks section
  lines.push('## Tasks');
  lines.push('');

  // Group by parent tasks
  const parentTasks = tasks.filter(t => t.type === 'parent');

  for (const parent of parentTasks) {
    const statusIcon = getStatusIcon(parent.status);
    const progressBar = generateProgressBar(parent.progress_percent || 0);

    lines.push(`### Task ${parent.id}: ${parent.description}`);
    lines.push('');
    lines.push(`**Status**: ${statusIcon} ${parent.status} ${progressBar}`);

    if (parent.started_at) {
      lines.push(`**Started**: ${formatDate(parent.started_at)}`);
    }
    if (parent.completed_at) {
      lines.push(`**Completed**: ${formatDate(parent.completed_at)} (${parent.duration_minutes} min)`);
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
        const blockerNote = subtask.blocker ? ` ⚠️ ${subtask.blocker}` : '';
        lines.push(`- ${checkbox} **${subtask.id}** ${subtask.description}${blockerNote}`);
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

  // Footer
  lines.push('## Notes');
  lines.push('');
  lines.push('- This file is auto-generated from `tasks.json`');
  lines.push('- To modify tasks, edit `tasks.json` or use Agent OS commands');
  lines.push('- Regenerated automatically by PostToolUse hook');
  lines.push('');

  return lines.join('\n');
}

function getStatusIcon(status) {
  const icons = {
    'pending': '⏳',
    'in_progress': '🔄',
    'pass': '✅',
    'blocked': '🚫',
    'skipped': '⏭️'
  };
  return icons[status] || '❓';
}

function generateProgressBar(percent) {
  const filled = Math.round(percent / 10);
  const empty = 10 - filled;
  return `[${'█'.repeat(filled)}${'░'.repeat(empty)}] ${percent}%`;
}

function formatDate(isoDate) {
  if (!isoDate) return 'N/A';
  const date = new Date(isoDate);
  return date.toLocaleString();
}

function getWaveStatus(taskIds, tasks) {
  const waveTasks = tasks.filter(t => taskIds.includes(t.id));
  const completed = waveTasks.filter(t => t.status === 'pass').length;
  const total = waveTasks.length;

  if (completed === total) return '✅ Complete';
  if (completed > 0) return '🔄 In Progress';
  return '⏳ Pending';
}

// Main execution
function main() {
  const args = process.argv.slice(2);

  if (args.length === 0) {
    console.error('Usage: json-to-markdown.js <tasks.json path>');
    process.exit(1);
  }

  const jsonPath = args[0];

  if (!fs.existsSync(jsonPath)) {
    console.error(`File not found: ${jsonPath}`);
    process.exit(1);
  }

  try {
    const jsonContent = fs.readFileSync(jsonPath, 'utf8');
    const tasksJson = JSON.parse(jsonContent);

    // Validate version
    if (!tasksJson.version || !tasksJson.version.startsWith('3')) {
      console.log('Skipping: Not a v3.0 tasks.json file');
      process.exit(0);
    }

    const markdown = generateMarkdown(tasksJson);

    // Write to tasks.md in same directory
    const mdPath = jsonPath.replace('.json', '.md');
    fs.writeFileSync(mdPath, markdown);

    // Update markdown_generated timestamp in JSON
    tasksJson.markdown_generated = new Date().toISOString();
    fs.writeFileSync(jsonPath, JSON.stringify(tasksJson, null, 2));

    console.log(`Generated: ${mdPath}`);

  } catch (error) {
    console.error(`Error processing ${jsonPath}: ${error.message}`);
    process.exit(1);
  }
}

main();
