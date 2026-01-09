#!/usr/bin/env node

/**
 * Agent OS v4.6 - Test Plan to Markdown Generator
 *
 * Generates test-plan.md from test-plan.json
 * Called automatically by PostToolUse hook when test-plan.json changes
 *
 * Usage: node test-plan-to-markdown.js <test-plan.json path>
 */

const fs = require('fs');
const path = require('path');

function generateMarkdown(planJson) {
  const {
    name,
    description,
    base_url,
    source,
    fixtures,
    scenarios,
    summary,
    default_evidence,
    updated,
    created
  } = planJson;

  const lines = [];

  // Header
  lines.push(`# Test Plan: ${name}`);
  lines.push('');
  lines.push(`> **Auto-generated from test-plan.json** - Do not edit directly`);
  lines.push(`> Last updated: ${updated || created}`);
  lines.push('');

  // Overview
  lines.push('## Overview');
  lines.push('');
  if (description) {
    lines.push(description);
    lines.push('');
  }
  lines.push(`**Base URL**: \`${base_url}\``);
  if (source) {
    lines.push(`**Source**: ${source.type} - ${source.value || 'N/A'}`);
    lines.push(`**Scope**: ${source.scope}`);
  }
  lines.push('');

  // Summary
  lines.push('## Summary');
  lines.push('');
  lines.push('| Metric | Value |');
  lines.push('|--------|-------|');
  lines.push(`| Total Scenarios | ${summary?.total_scenarios || scenarios.length} |`);
  lines.push(`| Critical | ${summary?.by_priority?.critical || countByPriority(scenarios, 'critical')} |`);
  lines.push(`| High | ${summary?.by_priority?.high || countByPriority(scenarios, 'high')} |`);
  lines.push(`| Medium | ${summary?.by_priority?.medium || countByPriority(scenarios, 'medium')} |`);
  lines.push(`| Low | ${summary?.by_priority?.low || countByPriority(scenarios, 'low')} |`);
  if (summary?.estimated_duration_seconds) {
    lines.push(`| Est. Duration | ${formatDuration(summary.estimated_duration_seconds)} |`);
  }
  lines.push('');

  // Default Evidence Configuration
  if (default_evidence) {
    lines.push('## Default Evidence Configuration');
    lines.push('');
    const evidenceItems = [];
    if (default_evidence.screenshots) evidenceItems.push('Screenshots');
    if (default_evidence.console_logs) evidenceItems.push('Console Logs');
    if (default_evidence.network_requests) evidenceItems.push('Network Requests');
    if (default_evidence.gif_recording) evidenceItems.push('GIF Recording');
    lines.push(evidenceItems.join(' | ') || 'None configured');
    lines.push('');
  }

  // Fixtures
  if (fixtures && Object.keys(fixtures).length > 0) {
    lines.push('## Fixtures');
    lines.push('');
    lines.push('Reusable setup sequences that run before scenarios.');
    lines.push('');

    for (const [fixtureName, fixture] of Object.entries(fixtures)) {
      lines.push(`### \`${fixtureName}\``);
      lines.push('');
      if (fixture.description) {
        lines.push(fixture.description);
        lines.push('');
      }
      lines.push('**Steps:**');
      for (let i = 0; i < fixture.steps.length; i++) {
        const step = fixture.steps[i];
        lines.push(`${i + 1}. **${step.action}**: ${stepToDescription(step)}`);
      }
      lines.push('');
      if (fixture.success_indicator) {
        lines.push(`**Success Indicator**: ${fixture.success_indicator}`);
        lines.push('');
      }
    }
  }

  // Execution Order
  const prerequisites = scenarios.filter(s => s.is_prerequisite);
  if (prerequisites.length > 0) {
    lines.push('## Execution Order');
    lines.push('');
    lines.push('Scenarios with dependencies execute in this order:');
    lines.push('');
    lines.push('```');
    lines.push('1. Prerequisites (run first):');
    for (const prereq of prerequisites) {
      lines.push(`   └── ${prereq.id}: ${prereq.name}`);
    }
    lines.push('');
    lines.push('2. Dependent Scenarios (run after prerequisites pass)');
    lines.push('```');
    lines.push('');
  }

  // Scenarios
  lines.push('## Scenarios');
  lines.push('');

  for (const scenario of scenarios) {
    const priorityIcon = getPriorityIcon(scenario.priority);
    const prereqBadge = scenario.is_prerequisite ? ' 🔑 **PREREQUISITE**' : '';

    lines.push(`### ${scenario.id}: ${scenario.name} ${priorityIcon}${prereqBadge}`);
    lines.push('');

    if (scenario.description) {
      lines.push(scenario.description);
      lines.push('');
    }

    // Metadata table
    lines.push(`| Property | Value |`);
    lines.push(`|----------|-------|`);
    lines.push(`| Category | ${scenario.category || 'General'} |`);
    lines.push(`| Priority | ${scenario.priority} |`);
    if (scenario.estimated_duration_seconds) {
      lines.push(`| Est. Duration | ${formatDuration(scenario.estimated_duration_seconds)} |`);
    }
    lines.push('');

    // Entry Criteria
    if (scenario.entry_criteria) {
      const ec = scenario.entry_criteria;
      lines.push('#### Entry Criteria');
      lines.push('');
      if (ec.description) {
        lines.push(`> ${ec.description}`);
        lines.push('');
      }
      if (ec.depends_on && ec.depends_on.length > 0) {
        lines.push(`**Depends On**: ${ec.depends_on.join(', ')}`);
      }
      if (ec.required_fixtures && ec.required_fixtures.length > 0) {
        lines.push(`**Required Fixtures**: ${ec.required_fixtures.map(f => `\`${f}\``).join(', ')}`);
      }
      lines.push('');
    }

    // Steps
    lines.push('#### Steps');
    lines.push('');
    for (const step of scenario.steps) {
      const criticalMark = step.critical ? ' **🔴 CRITICAL**' : '';
      const stepDesc = stepToDescription(step);
      lines.push(`${step.step_id}. **${step.action}**: ${step.description || stepDesc}${criticalMark}`);

      // Step details as sub-items
      const details = [];
      if (step.target) details.push(`Target: \`${step.target}\``);
      if (step.selector) details.push(`Selector: "${step.selector}"`);
      if (step.value !== undefined) details.push(`Value: \`${step.value}\``);
      if (step.expected) details.push(`Expected: ${step.expected}`);
      if (step.duration) details.push(`Wait: ${step.duration}s`);

      if (details.length > 0) {
        for (const detail of details) {
          lines.push(`    - ${detail}`);
        }
      }
    }
    lines.push('');

    // Expected Outcome
    lines.push('#### Expected Outcome');
    lines.push('');
    lines.push(scenario.expected_outcome);
    lines.push('');

    // Evidence Configuration (if different from default)
    if (scenario.evidence) {
      const ev = scenario.evidence;
      const evidenceItems = [];
      if (ev.screenshots) evidenceItems.push('Screenshots');
      if (ev.console_logs) evidenceItems.push('Console Logs');
      if (ev.network_requests) evidenceItems.push('Network Requests');
      if (ev.gif_recording) evidenceItems.push('GIF Recording');

      if (evidenceItems.length > 0) {
        lines.push('#### Evidence');
        lines.push('');
        lines.push(evidenceItems.join(' | '));
        lines.push('');
      }
    }

    lines.push('---');
    lines.push('');
  }

  // Usage
  lines.push('## Usage');
  lines.push('');
  lines.push(`Run \`/run-tests ${name}\` to execute this test plan.`);
  lines.push('');

  return lines.join('\n');
}

function countByPriority(scenarios, priority) {
  return scenarios.filter(s => s.priority === priority).length;
}

function getPriorityIcon(priority) {
  const icons = {
    critical: '🔴',
    high: '🟠',
    medium: '🟡',
    low: '🟢'
  };
  return icons[priority] || '⚪';
}

function formatDuration(seconds) {
  if (!seconds) return 'N/A';
  if (seconds < 60) return `${seconds}s`;
  const mins = Math.floor(seconds / 60);
  const secs = seconds % 60;
  return secs > 0 ? `${mins}m ${secs}s` : `${mins}m`;
}

function stepToDescription(step) {
  switch (step.action) {
    case 'navigate':
      return `Go to ${step.target}`;
    case 'click':
      return `Click on "${step.selector}"`;
    case 'type':
      return `Type "${step.value}" into "${step.selector}"`;
    case 'select':
      return `Select "${step.value}" from "${step.selector}"`;
    case 'verify':
      return `Verify "${step.expected}" is visible`;
    case 'wait':
      return `Wait ${step.duration || 2} seconds`;
    case 'scroll':
      return `Scroll ${step.direction || 'down'}`;
    case 'custom':
      return step.description || 'Custom action';
    default:
      return step.description || step.action;
  }
}

// Main execution
function main() {
  const jsonPath = process.argv[2];

  if (!jsonPath) {
    console.error('Usage: test-plan-to-markdown.js <test-plan.json path>');
    process.exit(1);
  }

  if (!fs.existsSync(jsonPath)) {
    console.error(`File not found: ${jsonPath}`);
    process.exit(1);
  }

  try {
    const planJson = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
    const markdown = generateMarkdown(planJson);
    const mdPath = jsonPath.replace('.json', '.md');
    fs.writeFileSync(mdPath, markdown);
    console.log(`Generated: ${mdPath}`);
  } catch (error) {
    console.error(`Error: ${error.message}`);
    process.exit(1);
  }
}

main();
