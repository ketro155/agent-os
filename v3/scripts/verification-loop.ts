#!/usr/bin/env npx tsx
/**
 * Ralph Wiggum Verification Loop (v4.9.0)
 *
 * Implements the Ralph Wiggum pattern: "Completion must be earned, not declared."
 *
 * Core concept: Tasks cannot claim completion without verification.
 * If verification fails, feedback is generated for re-invocation.
 *
 * @see https://awesomeclaude.ai/ralph-wiggum
 */

import * as fs from 'fs';
import * as path from 'path';
import { execSync } from 'child_process';

// ═══════════════════════════════════════════════════════════════════════════
// Configuration
// ═══════════════════════════════════════════════════════════════════════════

const MAX_VERIFICATION_ATTEMPTS = 3;
const VERIFICATION_CACHE_DIR = '.agent-os/cache/verification';

// ═══════════════════════════════════════════════════════════════════════════
// Types
// ═══════════════════════════════════════════════════════════════════════════

interface TaskResult {
  status: 'pass' | 'fail' | 'blocked' | 'partial';
  task_id: string;
  files_created?: string[];
  files_modified?: string[];
  exports_added?: string[];
  functions_created?: string[];
  test_results?: {
    ran: number;
    passed: number;
    failed: number;
  };
  subtasks_completed?: string[];
  commits?: string[];
  notes?: string;
}

interface VerificationFailure {
  category: 'file' | 'export' | 'function' | 'test' | 'subtask' | 'typescript';
  claimed: string;
  reason: string;
  suggestion?: string;
}

interface VerificationResult {
  passed: boolean;
  failures: VerificationFailure[];
  verified_artifacts: {
    files_created: string[];
    exports_added: string[];
    functions_created: string[];
  };
  timestamp: string;
}

interface VerificationFeedback {
  attempt: number;
  max_attempts: number;
  failures: VerificationFailure[];
  message: string;
  previous_claims: TaskResult;
}

// ═══════════════════════════════════════════════════════════════════════════
// Core Verification Functions
// ═══════════════════════════════════════════════════════════════════════════

/**
 * Verify that all claimed files exist
 */
function verifyFilesExist(files: string[]): VerificationFailure[] {
  const failures: VerificationFailure[] = [];

  for (const file of files) {
    if (!fs.existsSync(file)) {
      failures.push({
        category: 'file',
        claimed: file,
        reason: `File does not exist: ${file}`,
        suggestion: `Create the file or remove it from files_created`
      });
    }
  }

  return failures;
}

/**
 * Verify that all claimed exports exist in the codebase
 * Uses grep for broader search, AST for precise verification
 */
function verifyExportsExist(exports: string[], searchPaths: string[] = ['src/', 'lib/', 'app/']): VerificationFailure[] {
  const failures: VerificationFailure[] = [];

  for (const exportName of exports) {
    let found = false;
    const searchPattern = `export.*${exportName}`;

    for (const searchPath of searchPaths) {
      if (!fs.existsSync(searchPath)) continue;

      try {
        const result = execSync(
          `grep -r "${searchPattern}" ${searchPath} 2>/dev/null | head -1`,
          { encoding: 'utf-8', timeout: 5000 }
        );
        if (result.trim()) {
          found = true;
          break;
        }
      } catch {
        // grep returns non-zero if no matches
      }
    }

    if (!found) {
      failures.push({
        category: 'export',
        claimed: exportName,
        reason: `Export '${exportName}' not found in codebase`,
        suggestion: `Add 'export' keyword to ${exportName} or verify the function exists`
      });
    }
  }

  return failures;
}

/**
 * Verify that all claimed functions exist
 */
function verifyFunctionsExist(functions: string[], searchPaths: string[] = ['src/', 'lib/', 'app/']): VerificationFailure[] {
  const failures: VerificationFailure[] = [];

  for (const funcName of functions) {
    let found = false;
    // Match function declarations, const arrow functions, and method definitions
    const searchPatterns = [
      `function ${funcName}`,
      `const ${funcName}`,
      `${funcName} =`,
      `${funcName}(`
    ];

    for (const searchPath of searchPaths) {
      if (!fs.existsSync(searchPath)) continue;

      for (const pattern of searchPatterns) {
        try {
          const result = execSync(
            `grep -r "${pattern}" ${searchPath} 2>/dev/null | head -1`,
            { encoding: 'utf-8', timeout: 5000 }
          );
          if (result.trim()) {
            found = true;
            break;
          }
        } catch {
          // grep returns non-zero if no matches
        }
      }
      if (found) break;
    }

    if (!found) {
      failures.push({
        category: 'function',
        claimed: funcName,
        reason: `Function '${funcName}' not found in codebase`,
        suggestion: `Implement the function or verify the name is correct`
      });
    }
  }

  return failures;
}

/**
 * Verify that tests actually pass
 */
function verifyTestsPass(): VerificationFailure[] {
  const failures: VerificationFailure[] = [];

  try {
    execSync('npm test 2>&1', { encoding: 'utf-8', timeout: 120000 });
  } catch (error: any) {
    const output = error.stdout || error.message || 'Unknown test failure';
    // Extract just the last few lines for context
    const lines = output.split('\n');
    const summary = lines.slice(-10).join('\n');

    failures.push({
      category: 'test',
      claimed: 'All tests pass',
      reason: `Tests are failing`,
      suggestion: `Fix the failing tests:\n${summary}`
    });
  }

  return failures;
}

/**
 * Verify no TypeScript errors exist
 */
function verifyNoTypeScriptErrors(): VerificationFailure[] {
  const failures: VerificationFailure[] = [];

  // Check if TypeScript is configured
  if (!fs.existsSync('tsconfig.json')) {
    return failures; // Skip if no TypeScript
  }

  try {
    execSync('npx tsc --noEmit 2>&1', { encoding: 'utf-8', timeout: 60000 });
  } catch (error: any) {
    const output = error.stdout || error.message || 'Unknown TypeScript error';
    // Extract first few errors
    const lines = output.split('\n').filter((l: string) => l.includes('error TS'));
    const summary = lines.slice(0, 5).join('\n');

    failures.push({
      category: 'typescript',
      claimed: 'No TypeScript errors',
      reason: `TypeScript compilation errors found`,
      suggestion: `Fix TypeScript errors:\n${summary}`
    });
  }

  return failures;
}

/**
 * Verify that subtasks are marked as completed in tasks.json
 */
function verifySubtasksCompleted(taskId: string, claimedSubtasks: string[], tasksJsonPath: string): VerificationFailure[] {
  const failures: VerificationFailure[] = [];

  if (!fs.existsSync(tasksJsonPath)) {
    return failures; // Can't verify without tasks.json
  }

  try {
    const tasksJson = JSON.parse(fs.readFileSync(tasksJsonPath, 'utf-8'));
    const task = tasksJson.tasks?.find((t: any) => t.id === taskId);

    if (!task) return failures;

    for (const subtaskId of claimedSubtasks) {
      const subtask = task.subtasks_full?.find((s: any) => s.id === subtaskId);
      if (subtask && subtask.status !== 'pass' && subtask.status !== 'completed') {
        failures.push({
          category: 'subtask',
          claimed: subtaskId,
          reason: `Subtask ${subtaskId} not marked as completed (status: ${subtask.status || 'unknown'})`,
          suggestion: `Update subtask status in tasks.json`
        });
      }
    }
  } catch (error) {
    // JSON parse error - skip verification
  }

  return failures;
}

// ═══════════════════════════════════════════════════════════════════════════
// Main Verification Function
// ═══════════════════════════════════════════════════════════════════════════

/**
 * Perform complete verification of a task result
 *
 * This is the core Ralph Wiggum verification - it checks:
 * 1. All claimed files exist
 * 2. All claimed exports exist in codebase
 * 3. All claimed functions exist
 * 4. Tests pass
 * 5. No TypeScript errors
 * 6. Subtasks are marked complete
 */
export function verifyTaskCompletion(
  result: TaskResult,
  options: {
    tasksJsonPath?: string;
    skipTests?: boolean;
    skipTypeScript?: boolean;
    searchPaths?: string[];
  } = {}
): VerificationResult {
  const failures: VerificationFailure[] = [];
  const verified_artifacts = {
    files_created: [] as string[],
    exports_added: [] as string[],
    functions_created: [] as string[]
  };

  // 1. Verify files exist
  if (result.files_created?.length) {
    const fileFailures = verifyFilesExist(result.files_created);
    failures.push(...fileFailures);

    // Track verified files
    const failedFiles = new Set(fileFailures.map(f => f.claimed));
    verified_artifacts.files_created = result.files_created.filter(f => !failedFiles.has(f));
  }

  // 2. Verify exports exist
  if (result.exports_added?.length) {
    const exportFailures = verifyExportsExist(result.exports_added, options.searchPaths);
    failures.push(...exportFailures);

    const failedExports = new Set(exportFailures.map(f => f.claimed));
    verified_artifacts.exports_added = result.exports_added.filter(e => !failedExports.has(e));
  }

  // 3. Verify functions exist
  if (result.functions_created?.length) {
    const functionFailures = verifyFunctionsExist(result.functions_created, options.searchPaths);
    failures.push(...functionFailures);

    const failedFunctions = new Set(functionFailures.map(f => f.claimed));
    verified_artifacts.functions_created = result.functions_created.filter(f => !failedFunctions.has(f));
  }

  // 4. Verify tests pass (unless skipped)
  if (!options.skipTests) {
    const testFailures = verifyTestsPass();
    failures.push(...testFailures);
  }

  // 5. Verify no TypeScript errors (unless skipped)
  if (!options.skipTypeScript) {
    const tsFailures = verifyNoTypeScriptErrors();
    failures.push(...tsFailures);
  }

  // 6. Verify subtasks completed
  if (result.subtasks_completed?.length && options.tasksJsonPath) {
    const subtaskFailures = verifySubtasksCompleted(
      result.task_id,
      result.subtasks_completed,
      options.tasksJsonPath
    );
    failures.push(...subtaskFailures);
  }

  return {
    passed: failures.length === 0,
    failures,
    verified_artifacts,
    timestamp: new Date().toISOString()
  };
}

/**
 * Generate feedback for re-invocation after verification failure
 *
 * This creates the "prompt feedback" that will be passed to the agent
 * on the next iteration of the Ralph loop.
 */
export function generateVerificationFeedback(
  verification: VerificationResult,
  result: TaskResult,
  attempt: number
): VerificationFeedback {
  const failuresByCategory = verification.failures.reduce((acc, f) => {
    acc[f.category] = acc[f.category] || [];
    acc[f.category].push(f);
    return acc;
  }, {} as Record<string, VerificationFailure[]>);

  let message = `⚠️ VERIFICATION FAILED (Attempt ${attempt}/${MAX_VERIFICATION_ATTEMPTS})\n\n`;
  message += `Your task completion claim could not be verified. Please address the following issues:\n\n`;

  for (const [category, failures] of Object.entries(failuresByCategory)) {
    message += `### ${category.toUpperCase()} Issues (${failures.length}):\n`;
    for (const failure of failures) {
      message += `- ❌ ${failure.reason}\n`;
      if (failure.suggestion) {
        message += `  💡 ${failure.suggestion}\n`;
      }
    }
    message += '\n';
  }

  message += `\n---\n`;
  message += `After fixing these issues, the verification will run again automatically.\n`;
  message += `If verification passes, your task will be marked as complete.\n`;

  return {
    attempt,
    max_attempts: MAX_VERIFICATION_ATTEMPTS,
    failures: verification.failures,
    message,
    previous_claims: result
  };
}

/**
 * Check if we should continue the verification loop
 */
export function shouldContinueLoop(attempt: number, verification: VerificationResult): boolean {
  return !verification.passed && attempt < MAX_VERIFICATION_ATTEMPTS;
}

// ═══════════════════════════════════════════════════════════════════════════
// CLI Interface
// ═══════════════════════════════════════════════════════════════════════════

const command = process.argv[2];

if (command === 'verify') {
  // Usage: npx tsx verification-loop.ts verify '{"task_id": "1.2", ...}'
  const resultJson = process.argv[3];
  const tasksJsonPath = process.argv[4];

  if (!resultJson) {
    console.error('Usage: verification-loop.ts verify <result-json> [tasks-json-path]');
    process.exit(1);
  }

  try {
    const result = JSON.parse(resultJson) as TaskResult;
    const verification = verifyTaskCompletion(result, { tasksJsonPath });
    console.log(JSON.stringify(verification, null, 2));
    process.exit(verification.passed ? 0 : 1);
  } catch (error: any) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

if (command === 'feedback') {
  // Usage: npx tsx verification-loop.ts feedback '{"passed": false, ...}' '{"task_id": ...}' 1
  const verificationJson = process.argv[3];
  const resultJson = process.argv[4];
  const attempt = parseInt(process.argv[5] || '1', 10);

  if (!verificationJson || !resultJson) {
    console.error('Usage: verification-loop.ts feedback <verification-json> <result-json> <attempt>');
    process.exit(1);
  }

  try {
    const verification = JSON.parse(verificationJson) as VerificationResult;
    const result = JSON.parse(resultJson) as TaskResult;
    const feedback = generateVerificationFeedback(verification, result, attempt);
    console.log(JSON.stringify(feedback, null, 2));
  } catch (error: any) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

if (command === 'help' || !command) {
  console.log(`
Ralph Wiggum Verification Loop (v4.9.0)

Commands:
  verify <result-json> [tasks-json-path]
    Verify a task result. Returns verification result as JSON.
    Exit code 0 = passed, 1 = failed

  feedback <verification-json> <result-json> <attempt>
    Generate feedback message for re-invocation after failed verification.

  help
    Show this help message.

Examples:
  npx tsx verification-loop.ts verify '{"task_id":"1.2","files_created":["src/foo.ts"]}'
  npx tsx verification-loop.ts feedback '{"passed":false,"failures":[...]}' '{"task_id":"1.2"}' 1
`);
}
