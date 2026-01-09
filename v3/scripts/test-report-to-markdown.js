#!/usr/bin/env node

/**
 * Agent OS v4.6 - Test Report to Markdown Generator
 *
 * Generates test-report.md from test-report.json
 * Called automatically by PostToolUse hook when test-report.json changes
 *
 * Usage: node test-report-to-markdown.js <test-report.json path>
 */

const fs = require('fs');
const path = require('path');

function generateMarkdown(reportJson) {
  const {
    plan_name,
    executed_at,
    completed_at,
    duration_seconds,
    environment,
    summary,
    failures,
    skipped,
    scenarios,
    evidence_summary
  } = reportJson;

  const lines = [];

  // Header
  lines.push(`# Test Report: ${plan_name}`);
  lines.push('');
  lines.push(`> **Auto-generated from test-report.json** - Do not edit directly`);
  lines.push(`> Executed: ${formatDateTime(executed_at)}`);
  if (completed_at) {
    lines.push(`> Completed: ${formatDateTime(completed_at)}`);
  }
  lines.push('');

  // Quick Status Banner
  const statusBanner = getStatusBanner(summary);
  lines.push(statusBanner);
  lines.push('');

  // Summary
  lines.push('## Summary');
  lines.push('');
  lines.push('| Metric | Value |');
  lines.push('|--------|-------|');
  lines.push(`| Total Scenarios | ${summary.total_scenarios} |`);
  lines.push(`| Passed | ${summary.passed} ✅ |`);
  lines.push(`| Failed | ${summary.failed} ${summary.failed > 0 ? '❌' : ''} |`);
  lines.push(`| Skipped | ${summary.skipped} ${summary.skipped > 0 ? '⏭️' : ''} |`);
  lines.push(`| Pass Rate | ${summary.pass_rate}% |`);
  if (summary.effective_pass_rate !== undefined && summary.skipped > 0) {
    lines.push(`| Effective Pass Rate | ${summary.effective_pass_rate}% (excludes skipped) |`);
  }
  lines.push(`| Duration | ${formatDuration(duration_seconds)} |`);
  lines.push('');

  // Environment
  if (environment) {
    lines.push('### Environment');
    lines.push('');
    lines.push(`- **Base URL**: \`${environment.base_url}\``);
    lines.push(`- **Browser**: ${environment.browser}`);
    if (environment.viewport) {
      lines.push(`- **Viewport**: ${environment.viewport}`);
    }
    lines.push('');
  }

  // Failures Section (prominent)
  if (failures && failures.length > 0) {
    lines.push('## ❌ Failures');
    lines.push('');
    lines.push('> These scenarios need attention. Review the evidence and fix the issues.');
    lines.push('');

    for (const failure of failures) {
      lines.push(`### ${failure.scenario_id}: ${failure.scenario_name}`);
      lines.push('');

      const prereqBadge = failure.is_prerequisite ? ' 🔑 **PREREQUISITE**' : '';
      lines.push(`**Status**: Failed at step ${failure.failure_step}${prereqBadge}`);
      lines.push('');
      lines.push('**Error:**');
      lines.push('```');
      lines.push(failure.failure_message);
      lines.push('```');
      lines.push('');

      // Blocked scenarios
      if (failure.blocked_scenarios && failure.blocked_scenarios.length > 0) {
        lines.push(`**⚠️ Blocked Scenarios**: ${failure.blocked_scenarios.join(', ')}`);
        lines.push('');
        lines.push(`> Because this prerequisite failed, ${failure.blocked_scenarios.length} scenario(s) were skipped.`);
        lines.push('');
      }

      // Evidence links
      if (failure.evidence) {
        lines.push('**Evidence:**');
        if (failure.evidence.screenshot) {
          lines.push(`- [Screenshot](${failure.evidence.screenshot})`);
        }
        if (failure.evidence.console_logs) {
          lines.push(`- [Console Logs](${failure.evidence.console_logs})`);
        }
        if (failure.evidence.network_logs) {
          lines.push(`- [Network Logs](${failure.evidence.network_logs})`);
        }
        if (failure.evidence.gif) {
          lines.push(`- [GIF Recording](${failure.evidence.gif})`);
        }
        lines.push('');
      }

      lines.push('---');
      lines.push('');
    }
  }

  // Skipped Section
  if (skipped && skipped.length > 0) {
    lines.push('## ⏭️ Skipped Scenarios');
    lines.push('');
    lines.push('> These scenarios were skipped because a prerequisite failed.');
    lines.push('');

    lines.push('| Scenario | Name | Reason |');
    lines.push('|----------|------|--------|');
    for (const skip of skipped) {
      lines.push(`| ${skip.scenario_id} | ${skip.scenario_name} | ${skip.skip_reason} |`);
    }
    lines.push('');
  }

  // All Scenarios
  lines.push('## All Scenarios');
  lines.push('');

  // Group by status
  const passed = scenarios.filter(s => s.status === 'passed');
  const failed = scenarios.filter(s => s.status === 'failed' || s.status === 'error');
  const skippedScenarios = scenarios.filter(s => s.status === 'skipped');
  const pending = scenarios.filter(s => s.status === 'pending');

  if (passed.length > 0) {
    lines.push('### ✅ Passed');
    lines.push('');
    for (const s of passed) {
      const prereqBadge = s.is_prerequisite ? ' 🔑' : '';
      const duration = s.duration_ms ? ` (${formatMilliseconds(s.duration_ms)})` : '';
      lines.push(`- [x] **${s.id}**: ${s.name}${prereqBadge}${duration}`);
    }
    lines.push('');
  }

  if (failed.length > 0) {
    lines.push('### ❌ Failed');
    lines.push('');
    for (const s of failed) {
      const prereqBadge = s.is_prerequisite ? ' 🔑' : '';
      const failureNote = s.failure_message ? ` - ${truncate(s.failure_message, 60)}` : '';
      lines.push(`- [ ] **${s.id}**: ${s.name}${prereqBadge}${failureNote}`);
    }
    lines.push('');
  }

  if (skippedScenarios.length > 0) {
    lines.push('### ⏭️ Skipped');
    lines.push('');
    for (const s of skippedScenarios) {
      const reason = s.skip_reason ? ` - ${s.skip_reason}` : '';
      lines.push(`- [ ] **${s.id}**: ${s.name}${reason}`);
    }
    lines.push('');
  }

  if (pending.length > 0) {
    lines.push('### ⏳ Not Executed');
    lines.push('');
    for (const s of pending) {
      lines.push(`- [ ] **${s.id}**: ${s.name}`);
    }
    lines.push('');
  }

  // Evidence Summary
  if (evidence_summary) {
    lines.push('## Evidence Summary');
    lines.push('');
    lines.push('| Type | Count |');
    lines.push('|------|-------|');
    if (evidence_summary.screenshots_captured !== undefined) {
      lines.push(`| Screenshots | ${evidence_summary.screenshots_captured} |`);
    }
    if (evidence_summary.console_logs_captured !== undefined) {
      lines.push(`| Console Logs | ${evidence_summary.console_logs_captured} |`);
    }
    if (evidence_summary.network_logs_captured !== undefined) {
      lines.push(`| Network Logs | ${evidence_summary.network_logs_captured} |`);
    }
    if (evidence_summary.gifs_recorded !== undefined) {
      lines.push(`| GIF Recordings | ${evidence_summary.gifs_recorded} |`);
    }
    if (evidence_summary.total_size_mb !== undefined) {
      lines.push(`| Total Size | ${evidence_summary.total_size_mb} MB |`);
    }
    lines.push('');
  }

  // Evidence Index Table
  const scenariosWithEvidence = scenarios.filter(s => s.evidence_folder);
  if (scenariosWithEvidence.length > 0) {
    lines.push('### Evidence Index');
    lines.push('');
    lines.push('| Scenario | Status | Evidence Folder |');
    lines.push('|----------|--------|-----------------|');
    for (const s of scenariosWithEvidence) {
      const statusIcon = getStatusIcon(s.status);
      lines.push(`| ${s.id} | ${statusIcon} ${s.status} | [${s.evidence_folder}](${s.evidence_folder}) |`);
    }
    lines.push('');
  }

  // Footer with actionable next steps
  if (summary.failed > 0 || summary.skipped > 0) {
    lines.push('## Next Steps');
    lines.push('');
    if (summary.failed > 0) {
      lines.push('1. **Review failures above** - Check screenshots and logs for each failed scenario');
      lines.push('2. **Create specifications** - Use `/create-spec` to document fixes needed');
      lines.push('3. **Re-run tests** - After fixes, run `/run-tests ' + plan_name + '` again');
    } else if (summary.skipped > 0) {
      lines.push('1. **Fix prerequisite failures** - Skipped tests cannot pass until prerequisites work');
      lines.push('2. **Re-run tests** - Once prerequisites pass, skipped scenarios will execute');
    }
    lines.push('');
  }

  lines.push('---');
  lines.push('*Generated by Agent OS Browser Testing*');

  return lines.join('\n');
}

function getStatusBanner(summary) {
  if (summary.failed === 0 && summary.skipped === 0) {
    return '## ✅ All Tests Passed!';
  } else if (summary.failed > 0) {
    return `## ❌ ${summary.failed} Test(s) Failed`;
  } else if (summary.skipped > 0) {
    return `## ⚠️ ${summary.skipped} Test(s) Skipped (prerequisite failure)`;
  }
  return '## ⏳ Tests In Progress';
}

function getStatusIcon(status) {
  const icons = {
    passed: '✅',
    failed: '❌',
    error: '💥',
    skipped: '⏭️',
    pending: '⏳'
  };
  return icons[status] || '❓';
}

function formatDateTime(isoString) {
  if (!isoString) return 'N/A';
  const date = new Date(isoString);
  return date.toLocaleString();
}

function formatDuration(seconds) {
  if (!seconds) return 'N/A';
  if (seconds < 60) return `${seconds}s`;
  const mins = Math.floor(seconds / 60);
  const secs = seconds % 60;
  return secs > 0 ? `${mins}m ${secs}s` : `${mins}m`;
}

function formatMilliseconds(ms) {
  if (!ms) return 'N/A';
  if (ms < 1000) return `${ms}ms`;
  const seconds = (ms / 1000).toFixed(1);
  return `${seconds}s`;
}

function truncate(str, maxLength) {
  if (!str) return '';
  if (str.length <= maxLength) return str;
  return str.substring(0, maxLength - 3) + '...';
}

// Main execution
function main() {
  const jsonPath = process.argv[2];

  if (!jsonPath) {
    console.error('Usage: test-report-to-markdown.js <test-report.json path>');
    process.exit(1);
  }

  if (!fs.existsSync(jsonPath)) {
    console.error(`File not found: ${jsonPath}`);
    process.exit(1);
  }

  try {
    const reportJson = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
    const markdown = generateMarkdown(reportJson);
    const mdPath = jsonPath.replace('.json', '.md');
    fs.writeFileSync(mdPath, markdown);
    console.log(`Generated: ${mdPath}`);
  } catch (error) {
    console.error(`Error: ${error.message}`);
    process.exit(1);
  }
}

main();
