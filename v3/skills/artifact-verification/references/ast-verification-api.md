# AST Verification API Reference

> Detailed code examples for `.claude/scripts/ast-verify.ts`.
> Read this when you need programmatic verification or wave boundary type checking.

## CLI Usage

```bash
# Verify file exports (all exports, functions, types)
npx tsx .claude/scripts/ast-verify.ts verify [file-path]

# Check specific export exists
npx tsx .claude/scripts/ast-verify.ts check-export [file-path] [export-name]

# Check specific function exists
npx tsx .claude/scripts/ast-verify.ts check-function [file-path] [function-name]
```

## Programmatic Usage

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

## Example: Verifying Task Artifacts

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

## Type Verification (v2.0.0)

For tasks that depend on specific types (interfaces, type aliases, enums, classes):

```javascript
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
  return { status: 'blocked', blocker: `Missing artifacts: ${result.missingTypes.join(', ')}` };
}
```

## Wave Boundary Type Verification

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

## Auto-Invocation Integration Code

### Wave Boundary (in /execute-tasks Step 6a)

```javascript
if (waveN.tasks.some(task => task.blocked_by.length > 0)) {
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

### Task Start (in phase2-implementation teammate)

```javascript
if (task.blocked_by && task.blocked_by.length > 0) {
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
