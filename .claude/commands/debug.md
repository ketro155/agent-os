# Debug (v4.9.0)

Unified debugging command with automatic context detection and Explore agent integration for root cause analysis.

**v4.9.0 Enhancements:**
- generateReproScript for creating reproducible test scripts
- Enhanced debugging documentation
- Automated reproduction test generation

## Usage

```
/debug [issue_description] [--scope=task|spec|general] [--repro]
```

## Parameters

- `issue_description` (optional): Description of the issue to debug
- `--scope` (optional): Hint for debugging scope - auto-detected if not provided
- `--repro` (optional): Generate reproduction script (v4.9.0)

## Native Integration

| Feature | Tool | Purpose |
|---------|------|---------|
| **Explore Agent** | `Task` with `subagent_type='Explore'` | Comprehensive root cause investigation |
| **systematic-debugging** | skill (auto-invokes) | 4-phase root cause analysis |
| **pre-commit-gate** | hook | Validates fix before commit |
| **generateReproScript** | function (v4.9.0) | Creates reproducible test scripts |

## Workflow

### 1. Context Detection

```
CHECK: .agent-os/specs/ for active specs
DETERMINE:
  - task: Issue affects single task
  - spec: Issue affects multiple tasks/integration
  - general: System-wide or standalone issue
```

### 2. Issue Gathering

```
GATHER:
  - Error messages
  - Steps to reproduce
  - Expected vs actual behavior
  - Recent changes
```

### 3. Codebase Exploration (Explore Agent)

```
ACTION: Task tool with subagent_type='Explore'
THOROUGHNESS: "very thorough" (debugging requires comprehensive analysis)

PROMPT: "Investigate issue in codebase:
        Issue: [DESCRIPTION]
        Location: [FILE/FUNCTION if known]

        Explore:
        1. Error propagation path
        2. Related working code
        3. Recent changes
        4. Dependencies
        5. Test coverage

        Return:
        - Root cause candidates
        - Working examples for comparison
        - Files to investigate
        - Investigation priorities"
```

### 4. Systematic Investigation

systematic-debugging skill auto-invokes with Explore results:

**Phase 1: Root Cause Investigation**
- Read error messages and stack traces
- Use Explore agent's "error propagation" results
- Trace data flow

**Phase 2: Pattern Analysis**
- Use Explore agent's "working code" results
- Compare working vs broken code
- Identify differences

**Phase 3: Hypothesis Formation**
- Form: "The error occurs because [X] which leads to [Y]"
- Test hypothesis with single-variable changes

**Phase 4: Verification**
- Confirm root cause before fixing

### 5. Generate Reproduction Script (v4.9.0)

> **NEW in v4.9.0**: Automatically generate a reproduction script for the issue

```javascript
/**
 * Generate a reproducible script for the debugging issue
 * Creates a self-contained test that demonstrates the bug
 */
export function generateReproScript(
  issueContext: IssueContext
): ReproScript {
  const script: ReproScript = {
    filename: `repro-${issueContext.id || Date.now()}.ts`,
    type: determineScriptType(issueContext),
    content: '',
    instructions: [],
    dependencies: []
  };
  
  // Determine script type based on issue context
  if (issueContext.type === 'api') {
    script.content = generateApiReproScript(issueContext);
    script.dependencies = ['fetch', 'node-fetch'];
    script.instructions = [
      'Run with: npx ts-node repro-*.ts',
      'Observe the error output',
      'Expected vs actual behavior documented in script'
    ];
  } else if (issueContext.type === 'ui') {
    script.content = generateUIReproScript(issueContext);
    script.dependencies = ['playwright', '@playwright/test'];
    script.instructions = [
      'Run with: npx playwright test repro-*.ts',
      'Screenshot captured on failure',
      'Browser opens to show issue'
    ];
  } else if (issueContext.type === 'unit') {
    script.content = generateUnitReproScript(issueContext);
    script.dependencies = ['jest', 'vitest'];
    script.instructions = [
      'Run with: npx jest repro-*.ts or npx vitest repro-*.ts',
      'Test should fail demonstrating the bug',
      'After fix, test should pass'
    ];
  } else {
    script.content = generateGenericReproScript(issueContext);
    script.instructions = [
      'Run with: npx ts-node repro-*.ts',
      'Follow console output for reproduction steps'
    ];
  }
  
  return script;
}

/**
 * Generate API reproduction script
 */
function generateApiReproScript(context: IssueContext): string {
  return `#!/usr/bin/env ts-node
/**
 * Reproduction Script for: ${context.description}
 * Generated: ${new Date().toISOString()}
 * 
 * Issue: ${context.description}
 * Expected: ${context.expected || 'See description'}
 * Actual: ${context.actual || 'See description'}
 */

import fetch from 'node-fetch';

const BASE_URL = process.env.BASE_URL || '${context.baseUrl || 'http://localhost:3000'}';

async function reproduce() {
  console.log('=== Reproduction Script ===');
  console.log('Issue: ${context.description}');
  console.log('');
  
  try {
    // Setup
    ${context.setupCode || '// No setup required'}
    
    // Trigger the issue
    console.log('Step 1: Making request...');
    const response = await fetch(\`\${BASE_URL}${context.endpoint || '/api/test'}\`, {
      method: '${context.method || 'GET'}',
      headers: {
        'Content-Type': 'application/json',
        ${context.headers ? Object.entries(context.headers).map(([k, v]) => `'${k}': '${v}'`).join(',\n        ') : ''}
      },
      ${context.body ? `body: JSON.stringify(${JSON.stringify(context.body)})` : ''}
    });
    
    const data = await response.json();
    
    console.log('Response status:', response.status);
    console.log('Response body:', JSON.stringify(data, null, 2));
    
    // Verify the issue
    console.log('');
    console.log('Expected: ${context.expected || 'Success'}');
    console.log('Actual:', data);
    
    // Check if issue is reproduced
    ${context.assertionCode || `
    if (response.status !== 200) {
      console.log('\\n❌ ISSUE REPRODUCED: Unexpected status code');
      process.exit(1);
    }
    `}
    
    console.log('\\n✅ No issue detected (fix may already be applied)');
    
  } catch (error) {
    console.log('\\n❌ ISSUE REPRODUCED: Error occurred');
    console.error(error);
    process.exit(1);
  }
}

reproduce();
`;
}

/**
 * Generate UI reproduction script using Playwright
 */
function generateUIReproScript(context: IssueContext): string {
  return `#!/usr/bin/env ts-node
/**
 * UI Reproduction Script for: ${context.description}
 * Generated: ${new Date().toISOString()}
 * 
 * Run with: npx playwright test repro-*.ts
 */

import { test, expect } from '@playwright/test';

test.describe('Bug Reproduction', () => {
  test('${context.description}', async ({ page }) => {
    // Navigate to the page
    await page.goto('${context.baseUrl || 'http://localhost:3000'}${context.path || '/'}');
    
    // Setup steps
    ${context.setupSteps?.map(step => `
    // ${step.description}
    await page.${step.action}('${step.selector}'${step.value ? `, '${step.value}'` : ''});
    `).join('\n') || '// No setup steps'}
    
    // Trigger the issue
    ${context.triggerSteps?.map(step => `
    // ${step.description}
    await page.${step.action}('${step.selector}'${step.value ? `, '${step.value}'` : ''});
    `).join('\n') || '// Click to trigger issue\n    // await page.click(\\'selector\\');'}
    
    // Capture screenshot before assertion
    await page.screenshot({ path: 'repro-screenshot.png' });
    
    // Verify the issue
    ${context.assertion || `
    // Uncomment and modify this assertion to verify the bug
    // await expect(page.locator('.error')).toBeVisible();
    `}
    
    console.log('Expected: ${context.expected || 'See description'}');
    console.log('Actual behavior captured in screenshot');
  });
});
`;
}

/**
 * Generate unit test reproduction script
 */
function generateUnitReproScript(context: IssueContext): string {
  return `#!/usr/bin/env ts-node
/**
 * Unit Test Reproduction for: ${context.description}
 * Generated: ${new Date().toISOString()}
 * 
 * Run with: npx jest repro-*.ts or npx vitest repro-*.ts
 */

import { describe, it, expect } from 'vitest'; // or 'jest'

${context.imports?.map(i => `import { ${i.exports.join(', ')} } from '${i.from}';`).join('\n') || '// Import the module under test\n// import { functionToTest } from \'./module\';'}

describe('Bug Reproduction: ${context.description}', () => {
  it('should demonstrate the issue', () => {
    // Setup
    ${context.setupCode || '// const input = {...};'}
    
    // Execute
    ${context.executeCode || '// const result = functionToTest(input);'}
    
    // This test should FAIL to demonstrate the bug
    // After the fix is applied, it should PASS
    ${context.assertionCode || `
    // Uncomment and modify:
    // expect(result).toEqual(expectedValue);
    `}
  });
  
  it('should work correctly after fix', () => {
    // This documents the expected behavior
    ${context.expectedBehaviorCode || `
    // const input = {...};
    // const result = functionToTest(input);
    // expect(result).toEqual(correctValue);
    `}
  });
});
`;
}

/**
 * Generate generic reproduction script
 */
function generateGenericReproScript(context: IssueContext): string {
  return `#!/usr/bin/env ts-node
/**
 * Reproduction Script for: ${context.description}
 * Generated: ${new Date().toISOString()}
 * 
 * Instructions:
 * 1. Run this script: npx ts-node repro-*.ts
 * 2. Follow the output steps
 * 3. Observe the error or unexpected behavior
 */

console.log('=== Reproduction Steps ===');
console.log('');
console.log('Issue: ${context.description}');
console.log('');

${context.steps?.map((step, i) => `
console.log('Step ${i + 1}: ${step}');
// ${step}
`).join('\n') || `
console.log('Step 1: [Describe first step]');
console.log('Step 2: [Describe second step]');
console.log('Step 3: [Observe the issue]');
`}

console.log('');
console.log('Expected: ${context.expected || '[Expected behavior]'}');
console.log('Actual: ${context.actual || '[Actual behavior]'}');
console.log('');
console.log('Root cause (if known): ${context.rootCause || 'Under investigation'}');
`;
}
```

### 6. Implement Fix

```
TDD APPROACH:
1. Write test that reproduces bug (can use generateReproScript output)
2. Verify test fails
3. Implement fix
4. Verify test passes
5. Check for regressions
```

### 7. Verification

pre-commit-gate hook validates:
- All tests pass
- Build succeeds
- No type errors

### 8. Git Workflow

```
IF scope == "general":
  CREATE: fix/[issue-description] branch
  COMMIT: Fix with root cause in message
  PUSH: To remote
  PR: Create pull request (mandatory)

ELSE (task/spec):
  COMMIT: To current feature branch
  PUSH: To feature branch
```

### 9. Documentation

```
WRITE: .agent-os/debugging/[DATE]-[issue].md

TEMPLATE:
# Debug Report
**Scope**: [task/spec/general]
**Date**: [DATE]

## Issue
## Root Cause
## Reproduction Script
\`\`\`
[Generated reproduction script or path to it]
\`\`\`
## Fix Applied
## Verification
## Prevention
```

## Explore Agent Benefits for Debugging

- **Broader context** than manual file reading
- **Pattern discovery** - finds similar working code
- **Dependency tracing** - identifies related modules
- **Faster root cause** - prioritized investigation paths

## Creates

- `.agent-os/debugging/[DATE]-[issue].md` (debug report)
- `repro-[timestamp].ts` (reproduction script, v4.9.0)
- Git commits with root cause analysis
- Pull request (if general scope)

## Debug Contexts

| Scope | When | Git Strategy |
|-------|------|--------------|
| `task` | Issue in single task | Commit to feature branch |
| `spec` | Integration issue | Commit to feature branch |
| `general` | System-wide bug | Create fix branch + PR |

---

## Changelog

### v4.9.0
- Added generateReproScript function for automatic reproduction script creation
- Added --repro flag to generate reproduction scripts
- Added script types: api, ui, unit, generic
- Added reproduction script to debug report template

### v4.8.0
- Initial debug command
