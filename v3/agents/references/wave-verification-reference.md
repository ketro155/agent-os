# Wave Verification Reference

> Reference document for wave-orchestrator. Loaded on demand when working in `.claude/agents/`.
> See the main agent definition for core execution logic.

## AST-Based Verification (v4.9.0)

> **PREFERRED** over grep patterns for TypeScript/JavaScript files

### Step 3 Alternative: AST Verification

For accurate verification of exports and functions, use the AST verification system:

```javascript
// Import AST verification functions
const { verifyWithCache, batchVerifyExports, verifyFunctionExists } = require('./.claude/scripts/ast-verify.ts');

// For each task result
for (const result of results) {
  const verifiedArtifacts = {
    exports_added: [],
    files_created: [],
    functions_created: []
  };
  const unverifiedClaims = [];

  // Verify files exist (simple check)
  for (const file of result.files_created || []) {
    if (fs.existsSync(file)) {
      verifiedArtifacts.files_created.push(file);
    } else {
      unverifiedClaims.push({
        type: 'file',
        claimed: file,
        reason: 'File does not exist'
      });
    }
  }

  // Verify exports using AST (accurate)
  for (const exportName of result.exports_added || []) {
    let found = false;
    for (const file of result.files_created || []) {
      if (file.match(/\.(ts|tsx|js|jsx)$/)) {
        const verification = verifyWithCache(file);
        if (verification.exports.includes(exportName)) {
          verifiedArtifacts.exports_added.push(exportName);
          found = true;
          break;
        }
      }
    }
    if (!found) {
      unverifiedClaims.push({
        type: 'export',
        claimed: exportName,
        reason: 'Not found in any created files via AST analysis'
      });
    }
  }

  // Verify functions using AST
  for (const funcName of result.functions_created || []) {
    let found = false;
    for (const file of result.files_created || []) {
      if (file.match(/\.(ts|tsx|js|jsx)$/)) {
        if (verifyFunctionExists(file, funcName)) {
          verifiedArtifacts.functions_created.push(funcName);
          found = true;
          break;
        }
      }
    }
    if (!found) {
      unverifiedClaims.push({
        type: 'function',
        claimed: funcName,
        reason: 'Not found in any created files via AST analysis'
      });
    }
  }

  result.verified_artifacts = verifiedArtifacts;
  result.unverified_claims = unverifiedClaims;
}
```

### Batch Verification Pattern

For verifying multiple claims efficiently:

```javascript
const claims = results.flatMap(result =>
  (result.exports_added || []).map(exportName => ({
    file: result.files_created?.[0] || '',
    exportName
  }))
);

const batchResults = batchVerifyExports(claims);
const verified = batchResults.filter(r => r.exists);
const unverified = batchResults.filter(r => !r.exists);
```

### Cache Management

Verification results are cached in `.agent-os/cache/verification/`:

```javascript
// Clear cache for a specific file after modifications
clearCache('/path/to/modified/file.ts');

// Clear all verification cache
clearCache();
```

### Fallback to Grep

For non-TypeScript files (markdown, JSON, etc.), fall back to grep patterns:

```bash
# For markdown files
grep -l "pattern" *.md

# For JSON files
jq 'has("key")' file.json
```

---

## Ralph Verification Loop (v4.9.0)

### Verification Module Reference

The verification logic is **centralized** in `.claude/scripts/verification-loop.ts`. Invoke via CLI:

```bash
# Verify task completion
npx tsx .claude/scripts/verification-loop.ts verify '<result-json>' '<tasks-json-path>'

# Generate feedback for re-invocation
npx tsx .claude/scripts/verification-loop.ts feedback '<verification-json>' '<result-json>' <attempt>
```

**Exported Functions:**

| Function | Purpose | Returns |
|----------|---------|---------|
| `verifyTaskCompletion(result, options)` | Check all claimed artifacts exist | `VerificationResult` |
| `generateVerificationFeedback(verification, result, attempt)` | Create feedback for retry | `VerificationFeedback` |
| `shouldContinueLoop(attempt, verification)` | Check if retry allowed | `boolean` |

See `rules/verification-loop.md` for full documentation.

### Configuration

```javascript
const MAX_VERIFICATION_ATTEMPTS = 3;  // Max re-invocations per task
```

### executeWithVerification Function (Core Ralph Loop)

```javascript
/**
 * Execute a task with Ralph Wiggum verification loop.
 * Uses centralized verification from .claude/scripts/verification-loop.ts
 */
async function executeWithVerification(task, predecessorArtifacts, specFolder) {
  let attempt = 0;
  let lastResult = null;
  let verificationFeedback = null;

  while (attempt < MAX_VERIFICATION_ATTEMPTS) {
    attempt++;

    // Build prompt with optional verification feedback
    let prompt = `
Execute task: ${JSON.stringify(task)}

PREDECESSOR ARTIFACTS (VERIFIED):
${JSON.stringify(predecessorArtifacts)}

These exports/files are GUARANTEED to exist. Use them directly.

Return structured result with artifacts.
`;

    // Add verification feedback if this is a retry
    if (verificationFeedback) {
      prompt += `

===================================================================
VERIFICATION FEEDBACK (Attempt ${attempt}/${MAX_VERIFICATION_ATTEMPTS})
===================================================================

${verificationFeedback.message}

PREVIOUS CLAIMS THAT FAILED VERIFICATION:
${JSON.stringify(verificationFeedback.previous_claims, null, 2)}

IMPORTANT: Address ALL verification failures before returning "pass" status.
The same verification will run again after you complete.
===================================================================
`;
    }

    // Invoke phase2-implementation
    lastResult = Task({
      subagent_type: "phase2-implementation",
      prompt: prompt
    });

    // If agent already returned blocked/fail, don't verify - pass through
    if (lastResult.status === "blocked" || lastResult.status === "fail") {
      return lastResult;
    }

    // VERIFICATION STEP - Use centralized verification-loop.ts
    const verification = invokeVerification(lastResult, specFolder);

    if (verification.passed) {
      // Verification passed! Return with verified flag
      return {
        ...lastResult,
        verified: true,
        verification_attempts: attempt
      };
    }

    // Verification failed - generate feedback for next iteration
    console.warn(`[Wave] Task ${task.id} verification failed (attempt ${attempt}/${MAX_VERIFICATION_ATTEMPTS})`);
    for (const failure of verification.failures) {
      console.warn(`  - ${failure.category}: ${failure.claimed} - ${failure.reason}`);
    }

    // Generate feedback for re-invocation using centralized script
    verificationFeedback = invokeGenerateFeedback(verification, lastResult, attempt);

    // If max attempts reached, return with verification failure
    if (attempt >= MAX_VERIFICATION_ATTEMPTS) {
      return {
        status: "blocked",
        task_id: task.id,
        blocker: `Verification failed after ${MAX_VERIFICATION_ATTEMPTS} attempts`,
        verification_failures: verification.failures,
        last_result: lastResult
      };
    }

    console.log(`[Wave] Re-invoking task ${task.id} with verification feedback...`);
  }

  return lastResult;
}

/**
 * Invoke centralized verification script
 * @see .claude/scripts/verification-loop.ts
 */
function invokeVerification(result, specFolder) {
  const resultJson = JSON.stringify(result).replace(/'/g, "'\\''");
  const tasksPath = `${specFolder}/tasks.json`;

  const output = Bash(`npx tsx "${CLAUDE_PROJECT_DIR}/.claude/scripts/verification-loop.ts" verify '${resultJson}' "${tasksPath}"`);

  return JSON.parse(output.stdout || '{"passed": false, "failures": []}');
}

/**
 * Invoke centralized feedback generation
 * @see .claude/scripts/verification-loop.ts
 */
function invokeGenerateFeedback(verification, result, attempt) {
  const verificationJson = JSON.stringify(verification).replace(/'/g, "'\\''");
  const resultJson = JSON.stringify(result).replace(/'/g, "'\\''");

  const output = Bash(`npx tsx "${CLAUDE_PROJECT_DIR}/.claude/scripts/verification-loop.ts" feedback '${verificationJson}' '${resultJson}' ${attempt}`);

  return JSON.parse(output.stdout || '{}');
}
```

### Parallel Mode (with Verification Loop)

```javascript
// Spawn all task agents in parallel
const taskAgents = [];

for (task of input.tasks) {
  const agentId = Task({
    subagent_type: "phase2-implementation",
    run_in_background: true,
    prompt: `
      Execute task: ${JSON.stringify(task)}

      PREDECESSOR ARTIFACTS (VERIFIED):
      ${JSON.stringify(input.predecessor_artifacts)}

      These exports/files are GUARANTEED to exist. Use them directly.

      Return structured result with artifacts.
    `
  });
  taskAgents.push({ task_id: task.id, agent_id: agentId, task: task });
}

// Collect ALL results (blocking)
const results = [];
for (agent of taskAgents) {
  let result = TaskOutput({ task_id: agent.agent_id, block: true });

  // Apply Ralph verification loop to each result
  if (result.status === "pass") {
    result = await executeWithVerification(agent.task, input.predecessor_artifacts, input.spec_folder);
  }

  results.push({ task_id: agent.task_id, result });
}
```

### Sequential Mode (with Verification Loop)

```javascript
for (task of input.tasks) {
  // Use verification loop instead of direct invocation
  const result = executeWithVerification(task, predecessor_artifacts, input.spec_folder);
  results.push({ task_id: task.id, result });

  // Update predecessor context for next task in wave
  if (result.status === "pass" && result.verified) {
    predecessor_artifacts = mergeArtifacts(predecessor_artifacts, result);
  }
}
```

---

## Changelog

### v4.9.0-pre (2026-01-09)
- Added AST-based verification using TypeScript compiler API
- Added verification caching with file hash invalidation
- Improved accuracy over grep patterns for export/function detection
- Added batch verification support for performance
