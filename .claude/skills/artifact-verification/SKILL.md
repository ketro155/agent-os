---
name: artifact-verification
description: When you need to verify that predecessor task artifacts exist before starting a dependent task. Use when task dependencies reference files, exports, or APIs that should already exist.
version: 2.0.0
auto_invoke:
  - trigger: wave_boundary
    condition: "new_wave_has_dependencies"
  - trigger: task_start
    condition: "task.blocked_by.length > 0"
---

# Artifact Verification Skill

Verify that predecessor task artifacts actually exist before proceeding with dependent work. This prevents hallucination of non-existent exports, files, or APIs.

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 2.0.0 | 2026-01-10 | Added auto-invocation at wave boundaries, AST-based type verification, verifyExportTypes |
| 1.0.0 | 2026-01-09 | Initial implementation with grep-based verification |

## When to Use

- Before starting any task that has dependencies
- When a task description references "using X from task Y"
- **Before wave execution in multi-wave specs** (auto-invoked)
- **At wave boundaries when entering a new wave** (auto-invoked)
- When implementing code that imports from other modules

## Auto-Invocation (v2.0.0)

This skill is automatically invoked in two scenarios:

### 1. Wave Boundary Auto-Invocation

When the execute-spec-orchestrator transitions between waves, this skill runs automatically:

```javascript
// In wave-orchestrator.md / execute-spec-orchestrator.md
// Before spawning workers for wave N:
if (waveN.tasks.some(task => task.blocked_by.length > 0)) {
  // Auto-invoke artifact-verification
  const verificationResult = await invokeSkill('artifact-verification', {
    wave_id: waveN.wave_id,
    predecessor_waves: waves.filter(w => w.wave_id < waveN.wave_id),
    expected_artifacts: collectExpectedArtifacts(waveN.tasks)
  });

  if (!verificationResult.verified) {
    console.error('Wave blocked: missing predecessor artifacts');
    return { status: 'blocked', missing: verificationResult.missing };
  }
}
```

### 2. Task Start Auto-Invocation

When phase2-implementation starts a task with dependencies:

```javascript
// In phase2-implementation.md
// At task start:
if (task.blocked_by && task.blocked_by.length > 0) {
  // Auto-invoke artifact-verification
  const artifacts = context.predecessor_artifacts;
  const verificationResult = await invokeSkill('artifact-verification', {
    task_id: task.id,
    predecessor_artifacts: artifacts
  });

  if (!verificationResult.verified) {
    return {
      status: 'blocked',
      blocker: `Missing artifacts: ${verificationResult.missing.join(', ')}`
    };
  }
}
```

## Verification Process

### Step 1: Identify Required Artifacts

From the task description and dependencies, list what should exist:

```
Required artifacts for task [ID]:
- [ ] File: src/utils/helper.ts (from task 1.1)
- [ ] Export: calculateMetrics function (from task 1.2)
- [ ] API: /api/v1/users endpoint (from task 2.1)
```

### Step 2: Verify Each Artifact

For each artifact, run appropriate verification.

#### AST-Based Verification (Recommended - v2.0.0)

Use the AST verification system from `.claude/scripts/ast-verify.ts` for accurate TypeScript/JavaScript verification:

```bash
# Verify file exports (all exports, functions, types)
npx tsx .claude/scripts/ast-verify.ts verify [file-path]

# Check specific export exists
npx tsx .claude/scripts/ast-verify.ts check-export [file-path] [export-name]

# Check specific function exists
npx tsx .claude/scripts/ast-verify.ts check-function [file-path] [function-name]
```

**Programmatic usage:**

```typescript
import { verifyExports, verifyExportExists, verifyExportTypes } from '.claude/scripts/ast-verify';

// Full file verification
const result = verifyExports('src/auth/token.ts');
console.log(result.exports);    // ['validateToken', 'TokenError', ...]
console.log(result.functions);  // ['validateToken', 'hashToken', ...]
console.log(result.types);      // ['Token', 'TokenConfig', ...]

// Quick export check
const exists = verifyExportExists('src/auth/token.ts', 'validateToken');

// Type verification with kind checking (v2.0.0)
const typeResult = verifyExportTypes('src/auth/token.ts', [
  { name: 'Token', kind: 'interface' },
  { name: 'TokenConfig', kind: 'type' },
  { name: 'TokenError', kind: 'class' }
]);
console.log(typeResult.verified);      // true if all match
console.log(typeResult.missingTypes);  // ['MissingType', ...]
```

#### Legacy Grep-Based Verification (Fallback)

Use when AST verification is unavailable:

**Files:**
```bash
ls -la [expected-path]
```

**Exports:**
```bash
grep -n "export.*[function-name]" [file-path]
```

**API Endpoints:**
```bash
grep -rn "router\.\|app\." --include="*.ts" | grep "[endpoint]"
```

### Step 3: Document Findings

Create verification report:

```
ARTIFACT VERIFICATION REPORT
============================
Task: [task-id]
Timestamp: [datetime]

VERIFIED (exist and correct):
- [artifact-1]: Found at [location]
- [artifact-2]: Found at [location]

MISSING (required but not found):
- [artifact-3]: Expected at [location], NOT FOUND

MISMATCHED (exists but different):
- [artifact-4]: Expected [X], found [Y]
```

### Step 4: Decision

- **All verified**: Proceed with task
- **Missing artifacts**: STOP and report blocker
- **Mismatched**: Clarify with user before proceeding

## Common Artifact Types

| Type | AST Method (v2.0.0) | Legacy Method | Example |
|------|---------------------|---------------|---------|
| TypeScript file | `verifyExports(path)` | `ls` + `grep export` | `src/utils/auth.ts` |
| Export (any) | `verifyExportExists(path, name)` | `grep "export.*name"` | `validateEmail` |
| Function export | `verifyFunctionExists(path, name)` | `grep "export.*function"` | `createUser()` |
| Interface/Type | `verifyExportTypes(path, [{name, kind}])` | `grep "interface\|type"` | `User`, `ApiResponse` |
| Class export | `verifyExportTypes(path, [{name, kind:'class'}])` | `grep "export.*class"` | `UserService` |
| Enum export | `verifyExportTypes(path, [{name, kind:'enum'}])` | `grep "export.*enum"` | `UserRole` |
| React component | `verifyExportExists` + file check | `grep "export.*function\|default"` | `Button.tsx` |
| API route | `grep "router\.\|app\."` | Same | `/api/users` |
| Config | `ls` + `cat` | Same | `config.json` |
| Test file | `ls` | Same | `auth.test.ts` |

## Anti-Patterns to Avoid

1. **Assuming existence** - Never start coding imports without verification
2. **Partial verification** - Check ALL dependencies, not just obvious ones
3. **Skipping on "obvious" tasks** - Even simple tasks can have hidden dependencies
4. **Trusting task descriptions** - Verify actual filesystem, not just documentation

## Example Invocation

When you see a task like:

> Task 2.3: Add validation to user form using the validateEmail helper from task 2.1

Run verification:

### Using AST Verification (Recommended)

```bash
# Verify validateEmail exists as an export
npx tsx .claude/scripts/ast-verify.ts check-export src/utils/validation.ts validateEmail

# Or verify it's specifically a function
npx tsx .claude/scripts/ast-verify.ts check-function src/utils/validation.ts validateEmail
```

**Programmatic (in agent code):**

```javascript
const { verifyExportExists, verifyFunctionExists } = require('.claude/scripts/ast-verify');

// Check export exists
if (!verifyExportExists('src/utils/validation.ts', 'validateEmail')) {
  return { status: 'blocked', blocker: 'Missing export: validateEmail' };
}

// Check it's actually a function (not just a type or constant)
if (!verifyFunctionExists('src/utils/validation.ts', 'validateEmail')) {
  return { status: 'blocked', blocker: 'validateEmail exists but is not a function' };
}
```

### Using Legacy Grep (Fallback)

```bash
# Verify validateEmail exists
grep -n "export.*validateEmail" src/utils/validation.ts

# If not found, check alternate locations
grep -rn "validateEmail" src/ --include="*.ts"
```

Only proceed if verification passes.

## Type Verification (v2.0.0)

For tasks that depend on specific types (interfaces, type aliases, enums, classes), use `verifyExportTypes`:

### Example: Verifying Task 3 Artifacts

```javascript
// Task 10 depends on Task 3's AST verification exports
const { verifyExportTypes } = require('.claude/scripts/ast-verify');

const result = verifyExportTypes('.claude/scripts/ast-verify.ts', [
  { name: 'VerificationResult', kind: 'interface' },
  { name: 'CachedVerification', kind: 'interface' },
  { name: 'VerifyOptions', kind: 'interface' },
  { name: 'verifyExports', kind: 'function' },
  { name: 'verifyWithCache', kind: 'function' }
]);

if (!result.verified) {
  console.error('Missing types:', result.missingTypes);
  return { status: 'blocked', blocker: `Missing Task 3 artifacts: ${result.missingTypes.join(', ')}` };
}
```

### Wave Boundary Type Verification

At wave transitions, collect all expected types from predecessor tasks:

```javascript
function collectExpectedTypes(waveNTasks, predecessorArtifacts) {
  const expectedTypes = [];

  for (const artifact of predecessorArtifacts) {
    if (artifact.types) {
      for (const type of artifact.types) {
        expectedTypes.push({
          file: artifact.file,
          name: type.name,
          kind: type.kind
        });
      }
    }
  }

  return expectedTypes;
}

// Verify all at wave boundary
const allTypes = collectExpectedTypes(wave4Tasks, predecessorArtifacts);
for (const typeSpec of allTypes) {
  const result = verifyExportTypes(typeSpec.file, [
    { name: typeSpec.name, kind: typeSpec.kind }
  ]);

  if (!result.verified) {
    return { status: 'blocked', missing: typeSpec.name };
  }
}
```
