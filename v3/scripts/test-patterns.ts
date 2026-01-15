#!/usr/bin/env npx tsx
/**
 * Test Pattern Discovery (v4.9.0)
 *
 * Automatically discovers test configuration from Jest, Vitest, or other frameworks.
 * Used by phase2-implementation for running tests with correct patterns.
 *
 * @see phase2-implementation.md Section "Test Pattern Discovery"
 */

import * as fs from 'fs';
import * as path from 'path';

// ═══════════════════════════════════════════════════════════════════════════
// Types
// ═══════════════════════════════════════════════════════════════════════════

export interface TestPatterns {
  testMatch: string[];
  testPathIgnorePatterns: string[];
  moduleFileExtensions: string[];
  framework: 'jest' | 'vitest' | 'mocha' | 'unknown';
  setupFiles: string[];
  testEnvironment: string;
  testCommand: string;
  watchCommand?: string;
}

// ═══════════════════════════════════════════════════════════════════════════
// Pattern Extraction Helpers
// ═══════════════════════════════════════════════════════════════════════════

function extractArrayValues(arrayContent: string): string[] {
  const matches = arrayContent.match(/['"`](.*?)['"`]/g) || [];
  return matches.map((m) => m.slice(1, -1));
}

function safeJsonParse<T>(content: string, fallback: T): T {
  try {
    return JSON.parse(content);
  } catch {
    return fallback;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Framework Detection
// ═══════════════════════════════════════════════════════════════════════════

/**
 * Discover test patterns from project configuration.
 *
 * Searches for configuration in this order:
 * 1. Jest configuration (jest.config.js/ts/json, package.json)
 * 2. Vitest configuration (vitest.config.ts/js, vite.config.ts)
 * 3. Mocha configuration (.mocharc.json, package.json)
 * 4. Falls back to common defaults
 *
 * @param projectRoot - Root directory of the project (default: current directory)
 * @returns Discovered test patterns and configuration
 */
export function discoverTestPatterns(projectRoot: string = '.'): TestPatterns {
  const patterns: TestPatterns = {
    testMatch: [],
    testPathIgnorePatterns: [],
    moduleFileExtensions: [],
    framework: 'unknown',
    setupFiles: [],
    testEnvironment: 'node',
    testCommand: 'npm test',
    watchCommand: undefined,
  };

  // ─────────────────────────────────────────────────────────────────────────
  // Check for Jest configuration
  // ─────────────────────────────────────────────────────────────────────────

  const jestConfigPaths = [
    path.join(projectRoot, 'jest.config.js'),
    path.join(projectRoot, 'jest.config.ts'),
    path.join(projectRoot, 'jest.config.json'),
    path.join(projectRoot, 'jest.config.mjs'),
    path.join(projectRoot, 'package.json'), // jest config in package.json
  ];

  for (const configPath of jestConfigPaths) {
    if (!fs.existsSync(configPath)) continue;

    try {
      let config: any;

      if (configPath.endsWith('package.json')) {
        const pkg = JSON.parse(fs.readFileSync(configPath, 'utf-8'));
        config = pkg.jest;
        if (!config) continue;
      } else if (configPath.endsWith('.json')) {
        config = JSON.parse(fs.readFileSync(configPath, 'utf-8'));
      } else {
        // For .js/.ts/.mjs, try to extract patterns with regex
        const content = fs.readFileSync(configPath, 'utf-8');

        // Extract testMatch
        const testMatchMatch = content.match(/testMatch:\s*\[([\s\S]*?)\]/);
        if (testMatchMatch) {
          patterns.testMatch = extractArrayValues(testMatchMatch[1]);
        }

        // Extract testPathIgnorePatterns
        const ignoreMatch = content.match(
          /testPathIgnorePatterns:\s*\[([\s\S]*?)\]/
        );
        if (ignoreMatch) {
          patterns.testPathIgnorePatterns = extractArrayValues(ignoreMatch[1]);
        }

        // Check if it looks like Jest config
        if (content.includes('testMatch') || content.includes('jest')) {
          patterns.framework = 'jest';
          patterns.testCommand = 'npm test';
          patterns.watchCommand = 'npm test -- --watch';
        }

        // If we found patterns, we're done
        if (patterns.testMatch.length > 0) {
          break;
        }

        continue;
      }

      // Process parsed JSON config
      if (config) {
        patterns.framework = 'jest';
        patterns.testMatch = config.testMatch || [
          '**/__tests__/**/*.[jt]s?(x)',
          '**/?(*.)+(spec|test).[jt]s?(x)',
        ];
        patterns.testPathIgnorePatterns = config.testPathIgnorePatterns || [
          '/node_modules/',
        ];
        patterns.moduleFileExtensions = config.moduleFileExtensions || [
          'js',
          'jsx',
          'ts',
          'tsx',
        ];
        patterns.testEnvironment = config.testEnvironment || 'node';
        patterns.setupFiles =
          config.setupFilesAfterEnv || config.setupFiles || [];
        patterns.testCommand = 'npm test';
        patterns.watchCommand = 'npm test -- --watch';
      }

      break;
    } catch (e) {
      // Continue to next config file
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Check for Vitest configuration
  // ─────────────────────────────────────────────────────────────────────────

  if (patterns.framework === 'unknown') {
    const vitestConfigPaths = [
      path.join(projectRoot, 'vitest.config.ts'),
      path.join(projectRoot, 'vitest.config.js'),
      path.join(projectRoot, 'vitest.config.mjs'),
      path.join(projectRoot, 'vite.config.ts'), // vitest can be in vite.config
      path.join(projectRoot, 'vite.config.js'),
    ];

    for (const configPath of vitestConfigPaths) {
      if (!fs.existsSync(configPath)) continue;

      try {
        const content = fs.readFileSync(configPath, 'utf-8');

        if (content.includes('vitest') || content.includes('test:')) {
          patterns.framework = 'vitest';

          // Extract include patterns
          const includeMatch = content.match(/include:\s*\[([\s\S]*?)\]/);
          if (includeMatch) {
            patterns.testMatch = extractArrayValues(includeMatch[1]);
          } else {
            patterns.testMatch = [
              '**/*.{test,spec}.{js,mjs,cjs,ts,mts,cts,jsx,tsx}',
            ];
          }

          // Extract exclude patterns
          const excludeMatch = content.match(/exclude:\s*\[([\s\S]*?)\]/);
          if (excludeMatch) {
            patterns.testPathIgnorePatterns = extractArrayValues(
              excludeMatch[1]
            );
          } else {
            patterns.testPathIgnorePatterns = ['**/node_modules/**'];
          }

          patterns.testCommand = 'npm run test';
          patterns.watchCommand = 'npm run test -- --watch';

          break;
        }
      } catch (e) {
        // Continue to next config file
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Check for Mocha configuration
  // ─────────────────────────────────────────────────────────────────────────

  if (patterns.framework === 'unknown') {
    const mochaConfigPaths = [
      path.join(projectRoot, '.mocharc.json'),
      path.join(projectRoot, '.mocharc.js'),
      path.join(projectRoot, '.mocharc.yaml'),
    ];

    for (const configPath of mochaConfigPaths) {
      if (!fs.existsSync(configPath)) continue;

      try {
        if (configPath.endsWith('.json')) {
          const config = JSON.parse(fs.readFileSync(configPath, 'utf-8'));
          patterns.framework = 'mocha';
          patterns.testMatch = config.spec
            ? [config.spec]
            : ['test/**/*.js', 'test/**/*.ts'];
          patterns.testCommand = 'npm test';
          patterns.watchCommand = 'npm test -- --watch';
          break;
        }
      } catch (e) {
        // Continue
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Check package.json for test scripts
  // ─────────────────────────────────────────────────────────────────────────

  const packageJsonPath = path.join(projectRoot, 'package.json');
  if (fs.existsSync(packageJsonPath)) {
    try {
      const pkg = JSON.parse(fs.readFileSync(packageJsonPath, 'utf-8'));

      // Detect framework from scripts if not already detected
      if (patterns.framework === 'unknown') {
        if (pkg.scripts?.test?.includes('vitest')) {
          patterns.framework = 'vitest';
        } else if (pkg.scripts?.test?.includes('jest')) {
          patterns.framework = 'jest';
        } else if (pkg.scripts?.test?.includes('mocha')) {
          patterns.framework = 'mocha';
        }
      }

      // Get test commands from scripts
      if (pkg.scripts?.test) {
        patterns.testCommand = 'npm test';
      }
      if (pkg.scripts?.['test:watch']) {
        patterns.watchCommand = 'npm run test:watch';
      }
    } catch (e) {
      // Continue with defaults
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Apply defaults if nothing found
  // ─────────────────────────────────────────────────────────────────────────

  if (patterns.testMatch.length === 0) {
    patterns.testMatch = [
      '**/__tests__/**/*.[jt]s?(x)',
      '**/?(*.)+(spec|test).[jt]s?(x)',
      '**/tests/**/*.[jt]s?(x)',
    ];
  }

  if (patterns.testPathIgnorePatterns.length === 0) {
    patterns.testPathIgnorePatterns = ['/node_modules/', '/dist/', '/build/'];
  }

  if (patterns.moduleFileExtensions.length === 0) {
    patterns.moduleFileExtensions = ['js', 'jsx', 'ts', 'tsx', 'json'];
  }

  return patterns;
}

/**
 * Get the command to run a specific test file.
 *
 * @param testFile - Path to the test file
 * @param patterns - Discovered test patterns
 * @returns Command string to run the test
 */
export function getTestCommand(
  testFile: string,
  patterns: TestPatterns
): string {
  switch (patterns.framework) {
    case 'jest':
      return `npm test -- --testPathPattern="${testFile}"`;
    case 'vitest':
      return `npm run test -- ${testFile}`;
    case 'mocha':
      return `npm test -- ${testFile}`;
    default:
      return `npm test -- ${testFile}`;
  }
}

/**
 * Get the command to run tests matching a pattern.
 *
 * @param grepPattern - Pattern to match test names
 * @param patterns - Discovered test patterns
 * @returns Command string to run matching tests
 */
export function getGrepCommand(
  grepPattern: string,
  patterns: TestPatterns
): string {
  switch (patterns.framework) {
    case 'jest':
      return `npm test -- --testNamePattern="${grepPattern}"`;
    case 'vitest':
      return `npm run test -- --grep "${grepPattern}"`;
    case 'mocha':
      return `npm test -- --grep "${grepPattern}"`;
    default:
      return `npm test -- --grep "${grepPattern}"`;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CLI Interface
// ═══════════════════════════════════════════════════════════════════════════

const command = process.argv[2];

if (command === 'discover') {
  // Usage: npx tsx test-patterns.ts discover [project-root]
  const projectRoot = process.argv[3] || '.';
  const patterns = discoverTestPatterns(projectRoot);
  console.log(JSON.stringify(patterns, null, 2));
}

if (command === 'test-cmd') {
  // Usage: npx tsx test-patterns.ts test-cmd <test-file> [project-root]
  const testFile = process.argv[3];
  const projectRoot = process.argv[4] || '.';

  if (!testFile) {
    console.error('Usage: test-patterns.ts test-cmd <test-file> [project-root]');
    process.exit(1);
  }

  const patterns = discoverTestPatterns(projectRoot);
  console.log(getTestCommand(testFile, patterns));
}

if (command === 'grep-cmd') {
  // Usage: npx tsx test-patterns.ts grep-cmd <pattern> [project-root]
  const grepPattern = process.argv[3];
  const projectRoot = process.argv[4] || '.';

  if (!grepPattern) {
    console.error('Usage: test-patterns.ts grep-cmd <pattern> [project-root]');
    process.exit(1);
  }

  const patterns = discoverTestPatterns(projectRoot);
  console.log(getGrepCommand(grepPattern, patterns));
}

if (command === 'help' || !command) {
  console.log(`
Test Pattern Discovery (v4.9.0)

Commands:
  discover [project-root]
    Discover test configuration from project.
    Returns: { framework, testMatch, testCommand, ... }

  test-cmd <test-file> [project-root]
    Get command to run a specific test file.
    Returns: Command string

  grep-cmd <pattern> [project-root]
    Get command to run tests matching a name pattern.
    Returns: Command string

  help
    Show this help message.

Examples:
  npx tsx test-patterns.ts discover
  npx tsx test-patterns.ts discover ./my-project
  npx tsx test-patterns.ts test-cmd tests/auth.test.ts
  npx tsx test-patterns.ts grep-cmd "should login"
`);
}
