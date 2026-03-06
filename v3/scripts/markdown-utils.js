#!/usr/bin/env node

/**
 * Agent OS - Shared Markdown Generation Utilities
 *
 * Common formatting functions and CLI boilerplate used by
 * json-to-markdown.js, test-plan-to-markdown.js, and test-report-to-markdown.js
 */

const fs = require('fs');

// ============================================================================
// Status Icons
// ============================================================================

const TASK_STATUS_ICONS = {
  'pending': '\u23F3',
  'in_progress': '\uD83D\uDD04',
  'pass': '\u2705',
  'blocked': '\uD83D\uDEAB',
  'skipped': '\u23ED\uFE0F'
};

const TEST_STATUS_ICONS = {
  'passed': '\u2705',
  'failed': '\u274C',
  'error': '\uD83D\uDCA5',
  'skipped': '\u23ED\uFE0F',
  'pending': '\u23F3'
};

function getTaskStatusIcon(status) {
  return TASK_STATUS_ICONS[status] || '\u2753';
}

function getTestStatusIcon(status) {
  return TEST_STATUS_ICONS[status] || '\u2753';
}

// ============================================================================
// Formatting
// ============================================================================

function formatTimestamp(isoString) {
  if (!isoString) return 'N/A';
  return new Date(isoString).toLocaleString();
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
  return `${(ms / 1000).toFixed(1)}s`;
}

function generateProgressBar(percent) {
  const filled = Math.round(percent / 10);
  const empty = 10 - filled;
  return `[${'█'.repeat(filled)}${'░'.repeat(empty)}] ${percent}%`;
}

function truncate(str, maxLength) {
  if (!str) return '';
  if (str.length <= maxLength) return str;
  return str.substring(0, maxLength - 3) + '...';
}

// ============================================================================
// CLI Runner
// ============================================================================

/**
 * Standard CLI runner for JSON-to-Markdown converters.
 * Handles arg parsing, file reading, JSON parsing, markdown writing.
 *
 * @param {string} label - Script name for error messages (e.g., "json-to-markdown.js")
 * @param {Function} generateFn - (parsedJson) => markdownString
 * @param {Object} [opts] - Options
 * @param {Function} [opts.postWrite] - (jsonPath, parsedJson) => void - called after .md write
 */
function runCli(label, generateFn, opts = {}) {
  const jsonPath = process.argv[2];

  if (!jsonPath) {
    console.error(`Usage: ${label} <json path>`);
    process.exit(1);
  }

  if (!fs.existsSync(jsonPath)) {
    console.error(`File not found: ${jsonPath}`);
    process.exit(1);
  }

  try {
    const json = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
    const markdown = generateFn(json);
    const mdPath = jsonPath.replace('.json', '.md');
    fs.writeFileSync(mdPath, markdown);
    console.log(`Generated: ${mdPath}`);

    if (opts.postWrite) {
      opts.postWrite(jsonPath, json);
    }
  } catch (error) {
    console.error(`Error processing ${jsonPath}: ${error.message}`);
    process.exit(1);
  }
}

module.exports = {
  getTaskStatusIcon,
  getTestStatusIcon,
  formatTimestamp,
  formatDuration,
  formatMilliseconds,
  generateProgressBar,
  truncate,
  runCli
};
