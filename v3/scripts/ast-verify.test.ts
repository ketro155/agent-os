#!/usr/bin/env ts-node
/**
 * Tests for AST Verification System - verifyExportTypes
 *
 * TDD RED Phase: These tests define the expected behavior for type verification
 * that uses the existing AST verification infrastructure from Task 3.
 *
 * @since v4.9.0
 */

import * as assert from 'assert';
import * as fs from 'fs';
import * as path from 'path';

// Import existing functions from ast-verify.ts (Task 3 artifacts)
import {
  verifyExports,
  verifyWithCache,
  verifyExportExists,
  verifyFunctionExists,
  VerificationResult
} from './ast-verify';

// ============================================================================
// Test Fixtures
// ============================================================================

const TEST_FIXTURES_DIR = path.join(__dirname, '__test_fixtures__');

const SAMPLE_TS_FILE = `
export interface User {
  id: string;
  name: string;
  email: string;
}

export type UserId = string;

export interface ApiResponse<T> {
  data: T;
  error?: string;
}

export function createUser(name: string): User {
  return { id: '1', name, email: 'test@test.com' };
}

export const validateEmail = (email: string): boolean => {
  return email.includes('@');
};

export class UserService {
  getUser(id: string): User | null {
    return null;
  }
}

export enum UserRole {
  Admin = 'admin',
  User = 'user'
}
`;

// ============================================================================
// Setup / Teardown
// ============================================================================

function setupFixtures(): void {
  if (!fs.existsSync(TEST_FIXTURES_DIR)) {
    fs.mkdirSync(TEST_FIXTURES_DIR, { recursive: true });
  }
  fs.writeFileSync(
    path.join(TEST_FIXTURES_DIR, 'sample.ts'),
    SAMPLE_TS_FILE
  );
}

function cleanupFixtures(): void {
  if (fs.existsSync(TEST_FIXTURES_DIR)) {
    fs.rmSync(TEST_FIXTURES_DIR, { recursive: true, force: true });
  }
}

// ============================================================================
// Tests: Existing Task 3 Functions (Sanity Check)
// ============================================================================

function testTask3ArtifactsExist(): void {
  console.log('TEST: Task 3 artifacts exist and work...');

  setupFixtures();
  const samplePath = path.join(TEST_FIXTURES_DIR, 'sample.ts');

  // Verify Task 3's verifyExports works
  const result = verifyExports(samplePath);

  assert.ok(result.verified, 'verifyExports should return verified: true');
  assert.ok(result.exports.includes('User'), 'Should detect User interface export');
  assert.ok(result.exports.includes('createUser'), 'Should detect createUser function export');
  assert.ok(result.types.includes('User'), 'Should detect User as type');
  assert.ok(result.functions.includes('createUser'), 'Should detect createUser as function');

  console.log('  PASS: Task 3 artifacts verified');
  cleanupFixtures();
}

// ============================================================================
// Tests: verifyExportTypes (NEW - To Be Implemented)
// ============================================================================

/**
 * Import the new function that will be added
 * This will fail until verifyExportTypes is implemented
 */
let verifyExportTypes: (
  filePath: string,
  expectedTypes: Array<{ name: string; kind: 'interface' | 'type' | 'enum' | 'class' }>
) => ExportTypeVerificationResult;

interface ExportTypeVerificationResult {
  verified: boolean;
  matches: Array<{ name: string; kind: string; found: boolean }>;
  missingTypes: string[];
  extraTypes: string[];
  errors: string[];
}

function testVerifyExportTypesDetectsInterfaces(): void {
  console.log('TEST: verifyExportTypes detects interface exports...');

  setupFixtures();
  const samplePath = path.join(TEST_FIXTURES_DIR, 'sample.ts');

  try {
    // Dynamic import to get the new function
    const astVerify = require('./ast-verify');
    verifyExportTypes = astVerify.verifyExportTypes;

    if (!verifyExportTypes) {
      throw new Error('verifyExportTypes not yet implemented');
    }

    const result = verifyExportTypes(samplePath, [
      { name: 'User', kind: 'interface' },
      { name: 'ApiResponse', kind: 'interface' }
    ]);

    assert.ok(result.verified, 'Should verify when all expected interfaces exist');
    assert.strictEqual(result.missingTypes.length, 0, 'No types should be missing');
    assert.ok(
      result.matches.some(m => m.name === 'User' && m.kind === 'interface' && m.found),
      'User interface should be found'
    );

    console.log('  PASS: Interface detection works');
  } catch (err) {
    console.log(`  FAIL: ${(err as Error).message}`);
    throw err;
  } finally {
    cleanupFixtures();
  }
}

function testVerifyExportTypesDetectsTypeAliases(): void {
  console.log('TEST: verifyExportTypes detects type alias exports...');

  setupFixtures();
  const samplePath = path.join(TEST_FIXTURES_DIR, 'sample.ts');

  try {
    const astVerify = require('./ast-verify');
    verifyExportTypes = astVerify.verifyExportTypes;

    if (!verifyExportTypes) {
      throw new Error('verifyExportTypes not yet implemented');
    }

    const result = verifyExportTypes(samplePath, [
      { name: 'UserId', kind: 'type' }
    ]);

    assert.ok(result.verified, 'Should verify when type alias exists');
    assert.ok(
      result.matches.some(m => m.name === 'UserId' && m.kind === 'type' && m.found),
      'UserId type alias should be found'
    );

    console.log('  PASS: Type alias detection works');
  } catch (err) {
    console.log(`  FAIL: ${(err as Error).message}`);
    throw err;
  } finally {
    cleanupFixtures();
  }
}

function testVerifyExportTypesDetectsEnums(): void {
  console.log('TEST: verifyExportTypes detects enum exports...');

  setupFixtures();
  const samplePath = path.join(TEST_FIXTURES_DIR, 'sample.ts');

  try {
    const astVerify = require('./ast-verify');
    verifyExportTypes = astVerify.verifyExportTypes;

    if (!verifyExportTypes) {
      throw new Error('verifyExportTypes not yet implemented');
    }

    const result = verifyExportTypes(samplePath, [
      { name: 'UserRole', kind: 'enum' }
    ]);

    assert.ok(result.verified, 'Should verify when enum exists');
    assert.ok(
      result.matches.some(m => m.name === 'UserRole' && m.kind === 'enum' && m.found),
      'UserRole enum should be found'
    );

    console.log('  PASS: Enum detection works');
  } catch (err) {
    console.log(`  FAIL: ${(err as Error).message}`);
    throw err;
  } finally {
    cleanupFixtures();
  }
}

function testVerifyExportTypesDetectsClasses(): void {
  console.log('TEST: verifyExportTypes detects class exports...');

  setupFixtures();
  const samplePath = path.join(TEST_FIXTURES_DIR, 'sample.ts');

  try {
    const astVerify = require('./ast-verify');
    verifyExportTypes = astVerify.verifyExportTypes;

    if (!verifyExportTypes) {
      throw new Error('verifyExportTypes not yet implemented');
    }

    const result = verifyExportTypes(samplePath, [
      { name: 'UserService', kind: 'class' }
    ]);

    assert.ok(result.verified, 'Should verify when class exists');
    assert.ok(
      result.matches.some(m => m.name === 'UserService' && m.kind === 'class' && m.found),
      'UserService class should be found'
    );

    console.log('  PASS: Class detection works');
  } catch (err) {
    console.log(`  FAIL: ${(err as Error).message}`);
    throw err;
  } finally {
    cleanupFixtures();
  }
}

function testVerifyExportTypesReportsMissingTypes(): void {
  console.log('TEST: verifyExportTypes reports missing types...');

  setupFixtures();
  const samplePath = path.join(TEST_FIXTURES_DIR, 'sample.ts');

  try {
    const astVerify = require('./ast-verify');
    verifyExportTypes = astVerify.verifyExportTypes;

    if (!verifyExportTypes) {
      throw new Error('verifyExportTypes not yet implemented');
    }

    const result = verifyExportTypes(samplePath, [
      { name: 'User', kind: 'interface' },
      { name: 'NonExistentType', kind: 'interface' }
    ]);

    assert.ok(!result.verified, 'Should fail verification when type is missing');
    assert.ok(
      result.missingTypes.includes('NonExistentType'),
      'Should report NonExistentType as missing'
    );

    console.log('  PASS: Missing type detection works');
  } catch (err) {
    console.log(`  FAIL: ${(err as Error).message}`);
    throw err;
  } finally {
    cleanupFixtures();
  }
}

function testVerifyExportTypesHandlesKindMismatch(): void {
  console.log('TEST: verifyExportTypes detects kind mismatch...');

  setupFixtures();
  const samplePath = path.join(TEST_FIXTURES_DIR, 'sample.ts');

  try {
    const astVerify = require('./ast-verify');
    verifyExportTypes = astVerify.verifyExportTypes;

    if (!verifyExportTypes) {
      throw new Error('verifyExportTypes not yet implemented');
    }

    // User is an interface, not a type alias
    const result = verifyExportTypes(samplePath, [
      { name: 'User', kind: 'type' }  // Wrong kind!
    ]);

    assert.ok(!result.verified, 'Should fail when kind does not match');
    assert.ok(
      result.matches.some(m => m.name === 'User' && !m.found),
      'User with wrong kind should not be found'
    );

    console.log('  PASS: Kind mismatch detection works');
  } catch (err) {
    console.log(`  FAIL: ${(err as Error).message}`);
    throw err;
  } finally {
    cleanupFixtures();
  }
}

function testVerifyExportTypesFileNotFound(): void {
  console.log('TEST: verifyExportTypes handles file not found...');

  try {
    const astVerify = require('./ast-verify');
    verifyExportTypes = astVerify.verifyExportTypes;

    if (!verifyExportTypes) {
      throw new Error('verifyExportTypes not yet implemented');
    }

    const result = verifyExportTypes('/non/existent/file.ts', [
      { name: 'User', kind: 'interface' }
    ]);

    assert.ok(!result.verified, 'Should fail for non-existent file');
    assert.ok(result.errors.length > 0, 'Should have error message');

    console.log('  PASS: File not found handling works');
  } catch (err) {
    console.log(`  FAIL: ${(err as Error).message}`);
    throw err;
  }
}

// ============================================================================
// Test Runner
// ============================================================================

async function runTests(): Promise<void> {
  console.log('\n===========================================');
  console.log('AST Verify Tests - verifyExportTypes');
  console.log('===========================================\n');

  const tests = [
    // Sanity check - Task 3 artifacts
    testTask3ArtifactsExist,

    // New verifyExportTypes tests
    testVerifyExportTypesDetectsInterfaces,
    testVerifyExportTypesDetectsTypeAliases,
    testVerifyExportTypesDetectsEnums,
    testVerifyExportTypesDetectsClasses,
    testVerifyExportTypesReportsMissingTypes,
    testVerifyExportTypesHandlesKindMismatch,
    testVerifyExportTypesFileNotFound,
  ];

  let passed = 0;
  let failed = 0;

  for (const test of tests) {
    try {
      test();
      passed++;
    } catch (err) {
      failed++;
      console.error(`  Error: ${(err as Error).message}`);
    }
  }

  console.log('\n===========================================');
  console.log(`Results: ${passed} passed, ${failed} failed`);
  console.log('===========================================\n');

  if (failed > 0) {
    process.exit(1);
  }
}

runTests().catch(err => {
  console.error('Test runner error:', err);
  process.exit(1);
});
