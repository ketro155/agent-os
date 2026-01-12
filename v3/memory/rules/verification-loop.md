---
paths:
  - ".claude/agents/**"
  - ".agent-os/specs/**"
---

# Ralph Wiggum Verification Loop (v4.9.0)

> **"Completion must be earned, not declared."**
>
> This rule implements the Ralph Wiggum pattern for task verification.
> Tasks cannot claim completion without passing verification. If verification
> fails, the task is re-invoked with feedback until it passes or max attempts reached.

## Origin

The Ralph Wiggum technique is an iterative AI development methodology named after
Geoffrey Huntley's technique. It prioritizes **iteration over perfection** and
forces verification through a simple loop mechanism.

**Reference:** https://awesomeclaude.ai/ralph-wiggum

## Core Principle

```
Traditional:  Agent says "done" → Trust → Proceed
Ralph:        Agent says "done" → Verify → If fail → Re-invoke → Loop
```

The key insight: **Single-shot completion is unreliable**. Forcing verification
through iteration catches errors that would otherwise propagate.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  Orchestration Layer (wave-orchestrator)                        │
│                                                                 │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  VERIFICATION LOOP                                         │ │
│  │                                                            │ │
│  │  1. Invoke phase2-implementation                           │ │
│  │  2. Agent returns result with status: "pass"               │ │
│  │  3. Run verifyTaskCompletion()                             │ │
│  │  4. If verification FAILS:                                 │ │
│  │     a. Generate feedback with specific failures            │ │
│  │     b. Re-invoke agent with feedback appended              │ │
│  │     c. Loop continues (max 3 attempts)                     │ │
│  │  5. If verification PASSES:                                │ │
│  │     a. Mark result as verified                             │ │
│  │     b. Proceed to next task                                │ │
│  │                                                            │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Verification Criteria

When a task claims `status: "pass"`, the following are verified:

| Criterion | Verification Method | Failure Handling |
|-----------|---------------------|------------------|
| **Files Created** | `fs.existsSync(file)` | List missing files |
| **Exports Added** | `grep -r "export.*name"` | List missing exports |
| **Functions Created** | `grep -r "function name\|const name"` | List missing functions |
| **Tests Pass** | `npm test` exit code | Include test output |
| **TypeScript Clean** | `tsc --noEmit` exit code | Include first 5 errors |
| **Subtasks Complete** | Check tasks.json status | List incomplete subtasks |

## Configuration

```javascript
// Maximum verification attempts before blocking
const MAX_VERIFICATION_ATTEMPTS = 3;

// Verification options
const verificationOptions = {
  tasksJsonPath: '.agent-os/specs/[spec]/tasks.json',
  skipTests: false,        // Set true for partial verification
  skipTypeScript: false,   // Set true if no tsconfig.json
  searchPaths: ['src/', 'lib/', 'app/']  // Where to search for exports
};
```

## Feedback Format

When verification fails, feedback is generated:

```
═══════════════════════════════════════════════════════════════════════════
VERIFICATION FEEDBACK (Attempt 2/3)
═══════════════════════════════════════════════════════════════════════════

⚠️ VERIFICATION FAILED (Attempt 2/3)

Your task completion claim could not be verified. Please address the following issues:

### FILE Issues (1):
- ❌ File does not exist: src/auth/validator.ts
  💡 Create the file or remove it from files_created

### EXPORT Issues (2):
- ❌ Export 'validateToken' not found in codebase
  💡 Add 'export' keyword to validateToken or verify the function exists
- ❌ Export 'hashPassword' not found in codebase
  💡 Add 'export' keyword to hashPassword or verify the function exists

### TEST Issues (1):
- ❌ Tests are failing
  💡 Fix the failing tests:
    FAIL src/auth/validator.test.ts
    ✕ should validate token format (15ms)

---
After fixing these issues, the verification will run again automatically.
If verification passes, your task will be marked as complete.
═══════════════════════════════════════════════════════════════════════════
```

## Agent Response to Feedback

When an agent receives verification feedback, it should:

1. **Parse the failures** - Extract specific issues from feedback
2. **Focus on remediation** - Don't repeat all work, just fix failures
3. **Verify locally** - Run tests/tsc before claiming complete again
4. **Return same format** - Use identical output structure

### Remediation Actions

| Failure Type | Remediation |
|--------------|-------------|
| `file` | Create missing file with correct content |
| `export` | Add `export` keyword to function/const |
| `function` | Implement the missing function |
| `test` | Fix failing tests, verify with `npm test` |
| `typescript` | Fix type errors, verify with `tsc --noEmit` |
| `subtask` | Update subtask status in tasks.json |

## Integration Points

### wave-orchestrator.md

The `executeWithVerification()` function wraps all task invocations:

```javascript
const result = executeWithVerification(task, predecessorArtifacts, specFolder);
```

### phase2-implementation.md

Handles verification feedback at Step 0:

```javascript
if (input.includes("VERIFICATION FEEDBACK")) {
  // Focus on fixing failures, not repeating work
}
```

### verification-loop.ts

Provides verification and feedback generation:

```bash
# Verify a task result
npx tsx .claude/scripts/verification-loop.ts verify '<result-json>'

# Generate feedback
npx tsx .claude/scripts/verification-loop.ts feedback '<verification>' '<result>' <attempt>
```

## Error Handling

### Verification Script Errors

If the verification script itself fails:

```javascript
return {
  passed: false,
  failures: [{
    category: 'system',
    claimed: 'verification',
    reason: 'Verification script error: [error message]'
  }]
};
```

### Max Attempts Exceeded

If verification fails after MAX_VERIFICATION_ATTEMPTS:

```javascript
return {
  status: "blocked",
  task_id: task.id,
  blocker: "Verification failed after 3 attempts",
  verification_failures: [...],
  last_result: lastResult
};
```

The task is marked as blocked, not failed, allowing manual intervention.

## Comparison to Traditional Approach

### Without Ralph Pattern

```
1. Agent implements task
2. Agent claims "pass"
3. Orchestrator trusts claim
4. Proceed to next task
5. Errors discovered later (or never)
```

### With Ralph Pattern

```
1. Agent implements task
2. Agent claims "pass"
3. Orchestrator verifies claim
4. Verification finds missing export
5. Agent re-invoked with feedback
6. Agent fixes export
7. Verification passes
8. Proceed with verified result
```

## Performance Considerations

- **Verification overhead**: ~5-10 seconds per task (tests + tsc)
- **Re-invocation cost**: Full agent context for retry
- **Typical pass rate**: 85%+ on first attempt with good prompts

The overhead is justified by catching errors early rather than debugging
cascading failures later.

## Best Practices

1. **Don't over-claim** - Only list artifacts you actually created
2. **Verify locally first** - Run tests before claiming pass
3. **Be specific** - Use exact function/export names
4. **Handle failures gracefully** - Focus on fixing, not restarting

## Changelog

### v4.9.0 (2026-01-11)
- Initial implementation of Ralph Wiggum verification loop
- Added verification-loop.ts script
- Integrated with wave-orchestrator
- Added phase2-implementation feedback handling
- Documented verification criteria and feedback format
