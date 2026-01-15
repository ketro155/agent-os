#!/usr/bin/env npx tsx
/**
 * E2E Test Utilities (v4.11.0)
 *
 * Provides utility functions for E2E test execution and failure analysis.
 * Used by phase3-delivery agent for automatic E2E failure remediation.
 *
 * @see rules/e2e-integration.md
 */

// ═══════════════════════════════════════════════════════════════════════════
// Types
// ═══════════════════════════════════════════════════════════════════════════

export interface E2EFailure {
  scenario: string;
  step: string;
  error: string;
  screenshot?: string;
  element?: string;
  selector?: string;
}

export interface FixabilityResult {
  fixable: boolean;
  reason: string;
  suggestedFix?: string;
  confidence: 'HIGH' | 'MEDIUM' | 'LOW';
  fixType?: FixType;
}

export type FixType =
  | 'MISSING_DATA_TESTID'
  | 'TIMING_ISSUE'
  | 'SELECTOR_OUTDATED'
  | 'MISSING_ARIA_LABEL'
  | 'ELEMENT_NOT_VISIBLE'
  | 'NETWORK_TIMEOUT'
  | 'UNKNOWN';

// ═══════════════════════════════════════════════════════════════════════════
// Auto-Fix Patterns
// ═══════════════════════════════════════════════════════════════════════════

/**
 * Pattern definitions for auto-fixable E2E failures.
 * Each pattern includes detection regex and fix suggestion.
 */
const AUTO_FIX_PATTERNS: Array<{
  type: FixType;
  patterns: RegExp[];
  confidence: 'HIGH' | 'MEDIUM' | 'LOW';
  suggestFix: (failure: E2EFailure, match: RegExpMatchArray | null) => string;
}> = [
  {
    type: 'MISSING_DATA_TESTID',
    patterns: [
      /Element not found:.*\[data-testid=['"]([^'"]+)['"]\]/i,
      /Unable to find.*data-testid.*['"]([^'"]+)['"]/i,
      /No element matching.*data-testid=['"]([^'"]+)['"]/i,
    ],
    confidence: 'HIGH',
    suggestFix: (failure, match) => {
      const testId = match?.[1] || 'unknown-id';
      return `Add data-testid="${testId}" to the target element in the component`;
    },
  },
  {
    type: 'TIMING_ISSUE',
    patterns: [
      /timeout.*waiting.*element/i,
      /element.*not.*visible.*timeout/i,
      /timed out.*appear/i,
      /waiting for.*exceeded/i,
    ],
    confidence: 'MEDIUM',
    suggestFix: (failure) => {
      return `Increase wait timeout or add explicit wait for element: "${failure.element || failure.selector}"`;
    },
  },
  {
    type: 'SELECTOR_OUTDATED',
    patterns: [
      /Unable to find element.*class=['"]([^'"]+)['"]/i,
      /No element matching.*\.([a-zA-Z-_]+)/i,
      /Element.*#([a-zA-Z-_]+).*not found/i,
    ],
    confidence: 'MEDIUM',
    suggestFix: (failure) => {
      return `Update selector to use data-testid instead of CSS class/id. Current failing selector: "${failure.selector}"`;
    },
  },
  {
    type: 'MISSING_ARIA_LABEL',
    patterns: [
      /Unable to find.*role=['"]([^'"]+)['"].*name=['"]([^'"]+)['"]/i,
      /No accessible.*aria-label/i,
      /Element with role.*not found/i,
    ],
    confidence: 'HIGH',
    suggestFix: (failure, match) => {
      const role = match?.[1] || 'button';
      const name = match?.[2] || 'label';
      return `Add aria-label="${name}" to the ${role} element`;
    },
  },
  {
    type: 'ELEMENT_NOT_VISIBLE',
    patterns: [
      /element.*not.*visible/i,
      /element.*obscured/i,
      /element.*covered.*another/i,
      /element.*off.*screen/i,
    ],
    confidence: 'LOW',
    suggestFix: (failure) => {
      return `Check if element is rendered but hidden. May need scroll or visibility fix for: "${failure.element}"`;
    },
  },
  {
    type: 'NETWORK_TIMEOUT',
    patterns: [
      /network.*timeout/i,
      /fetch.*failed/i,
      /request.*aborted/i,
      /ERR_CONNECTION/i,
    ],
    confidence: 'LOW',
    suggestFix: () => {
      return `Network-related failure - may be transient. Consider increasing network timeout or adding retry logic`;
    },
  },
];

// ═══════════════════════════════════════════════════════════════════════════
// Core Functions
// ═══════════════════════════════════════════════════════════════════════════

/**
 * Determine if an E2E failure can be automatically fixed.
 *
 * A failure is considered auto-fixable if:
 * 1. It matches a known pattern (high confidence)
 * 2. The fix is straightforward (e.g., add attribute, increase timeout)
 * 3. The fix doesn't require architectural changes
 *
 * @param failure - The E2E test failure to analyze
 * @returns Fixability result with confidence and suggestion
 *
 * @example
 * ```typescript
 * const result = canAutoFix({
 *   scenario: "User can checkout",
 *   step: "Click Place Order",
 *   error: "Element not found: [data-testid='place-order-btn']"
 * });
 * // result.fixable === true
 * // result.fixType === 'MISSING_DATA_TESTID'
 * ```
 */
export function canAutoFix(failure: E2EFailure): FixabilityResult {
  const errorText = failure.error.toLowerCase();

  for (const pattern of AUTO_FIX_PATTERNS) {
    for (const regex of pattern.patterns) {
      const match = failure.error.match(regex);
      if (match) {
        return {
          fixable: pattern.confidence !== 'LOW',
          reason: `Matched pattern: ${pattern.type}`,
          suggestedFix: pattern.suggestFix(failure, match),
          confidence: pattern.confidence,
          fixType: pattern.type,
        };
      }
    }
  }

  // No pattern matched - not auto-fixable
  return {
    fixable: false,
    reason: 'No auto-fix pattern matched. Manual investigation required.',
    confidence: 'LOW',
    fixType: 'UNKNOWN',
  };
}

/**
 * Analyze multiple failures and determine overall fixability.
 *
 * Rules:
 * - If ANY failure is not fixable → overall not fixable
 * - If > 3 failures → not fixable (too complex)
 * - If all fixable with HIGH/MEDIUM confidence → fixable
 *
 * @param failures - Array of E2E failures to analyze
 * @returns Aggregate fixability assessment
 */
export function canAutoFixAll(failures: E2EFailure[]): {
  fixable: boolean;
  reason: string;
  fixes: Array<{ failure: E2EFailure; result: FixabilityResult }>;
} {
  // Rule 1: More than 3 failures is too complex
  if (failures.length > 3) {
    return {
      fixable: false,
      reason: `Too many failures (${failures.length}) for auto-fix. Maximum is 3.`,
      fixes: [],
    };
  }

  // Analyze each failure
  const fixes = failures.map((failure) => ({
    failure,
    result: canAutoFix(failure),
  }));

  // Rule 2: All must be fixable
  const unfixable = fixes.filter((f) => !f.result.fixable);
  if (unfixable.length > 0) {
    return {
      fixable: false,
      reason: `${unfixable.length} failure(s) cannot be auto-fixed: ${unfixable.map((f) => f.result.fixType).join(', ')}`,
      fixes,
    };
  }

  // Rule 3: No LOW confidence fixes
  const lowConfidence = fixes.filter((f) => f.result.confidence === 'LOW');
  if (lowConfidence.length > 0) {
    return {
      fixable: false,
      reason: `${lowConfidence.length} failure(s) have LOW confidence fixes`,
      fixes,
    };
  }

  return {
    fixable: true,
    reason: `All ${failures.length} failure(s) can be auto-fixed`,
    fixes,
  };
}

/**
 * Generate remediation instructions for a set of fixable failures.
 *
 * @param failures - Failures that have been determined fixable
 * @returns Structured remediation plan
 */
export function generateRemediationPlan(
  failures: E2EFailure[]
): {
  steps: Array<{
    order: number;
    action: string;
    file?: string;
    suggestion: string;
  }>;
  estimatedEffort: 'TRIVIAL' | 'SIMPLE' | 'MODERATE';
} {
  const analysis = canAutoFixAll(failures);

  if (!analysis.fixable) {
    return {
      steps: [],
      estimatedEffort: 'MODERATE',
    };
  }

  const steps = analysis.fixes.map((fix, index) => ({
    order: index + 1,
    action: `Fix: ${fix.result.fixType}`,
    file: extractFileFromError(fix.failure.error),
    suggestion: fix.result.suggestedFix || 'Manual investigation required',
  }));

  // Estimate effort based on fix types
  const hasTimingFix = analysis.fixes.some((f) => f.result.fixType === 'TIMING_ISSUE');
  const hasNetworkFix = analysis.fixes.some((f) => f.result.fixType === 'NETWORK_TIMEOUT');

  let effort: 'TRIVIAL' | 'SIMPLE' | 'MODERATE' = 'TRIVIAL';
  if (hasTimingFix || hasNetworkFix) {
    effort = 'MODERATE';
  } else if (failures.length > 1) {
    effort = 'SIMPLE';
  }

  return { steps, estimatedEffort: effort };
}

// ═══════════════════════════════════════════════════════════════════════════
// Helper Functions
// ═══════════════════════════════════════════════════════════════════════════

function extractFileFromError(error: string): string | undefined {
  // Try to extract file path from common error formats
  const patterns = [
    /at\s+([^\s]+\.(?:tsx?|jsx?))/i,
    /in\s+([^\s]+\.(?:tsx?|jsx?))/i,
    /file:\s*([^\s]+\.(?:tsx?|jsx?))/i,
  ];

  for (const pattern of patterns) {
    const match = error.match(pattern);
    if (match) {
      return match[1];
    }
  }

  return undefined;
}

// ═══════════════════════════════════════════════════════════════════════════
// CLI Interface
// ═══════════════════════════════════════════════════════════════════════════

const command = process.argv[2];

if (command === 'analyze') {
  // Usage: npx tsx e2e-utils.ts analyze '{"scenario": "...", "step": "...", "error": "..."}'
  const failureJson = process.argv[3];

  if (!failureJson) {
    console.error('Usage: e2e-utils.ts analyze <failure-json>');
    process.exit(1);
  }

  try {
    const failure = JSON.parse(failureJson) as E2EFailure;
    const result = canAutoFix(failure);
    console.log(JSON.stringify(result, null, 2));
    process.exit(result.fixable ? 0 : 1);
  } catch (error: any) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

if (command === 'analyze-all') {
  // Usage: npx tsx e2e-utils.ts analyze-all '[{...}, {...}]'
  const failuresJson = process.argv[3];

  if (!failuresJson) {
    console.error('Usage: e2e-utils.ts analyze-all <failures-json-array>');
    process.exit(1);
  }

  try {
    const failures = JSON.parse(failuresJson) as E2EFailure[];
    const result = canAutoFixAll(failures);
    console.log(JSON.stringify(result, null, 2));
    process.exit(result.fixable ? 0 : 1);
  } catch (error: any) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

if (command === 'plan') {
  // Usage: npx tsx e2e-utils.ts plan '[{...}, {...}]'
  const failuresJson = process.argv[3];

  if (!failuresJson) {
    console.error('Usage: e2e-utils.ts plan <failures-json-array>');
    process.exit(1);
  }

  try {
    const failures = JSON.parse(failuresJson) as E2EFailure[];
    const plan = generateRemediationPlan(failures);
    console.log(JSON.stringify(plan, null, 2));
  } catch (error: any) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

if (command === 'help' || !command) {
  console.log(`
E2E Test Utilities (v4.11.0)

Commands:
  analyze <failure-json>
    Analyze a single E2E failure for auto-fixability.
    Returns: { fixable, reason, suggestedFix, confidence, fixType }
    Exit code: 0 = fixable, 1 = not fixable

  analyze-all <failures-json-array>
    Analyze multiple E2E failures.
    Returns: { fixable, reason, fixes[] }
    Exit code: 0 = all fixable, 1 = some not fixable

  plan <failures-json-array>
    Generate remediation plan for fixable failures.
    Returns: { steps[], estimatedEffort }

  help
    Show this help message.

Examples:
  npx tsx e2e-utils.ts analyze '{"scenario":"Login","step":"Click","error":"Element not found: [data-testid=\\"btn\\"]"}'
  npx tsx e2e-utils.ts analyze-all '[{"scenario":"A","step":"B","error":"timeout waiting"}]'
  npx tsx e2e-utils.ts plan '[{"scenario":"A","step":"B","error":"Element not found: [data-testid=\\"x\\"]"}]'
`);
}
