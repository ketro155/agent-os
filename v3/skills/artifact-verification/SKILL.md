---
name: artifact-verification
description: When you need to verify that predecessor task artifacts exist before starting a dependent task. Use when task dependencies reference files, exports, or APIs that should already exist.
version: 1.0.0
---

# Artifact Verification Skill

Verify that predecessor task artifacts actually exist before proceeding with dependent work. This prevents hallucination of non-existent exports, files, or APIs.

## When to Use

- Before starting any task that has dependencies
- When a task description references "using X from task Y"
- Before wave execution in multi-wave specs
- When implementing code that imports from other modules

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

For each artifact, run appropriate verification:

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

| Type | Verification Method | Example |
|------|---------------------|---------|
| TypeScript file | `ls` + `grep export` | `src/utils/auth.ts` |
| React component | `grep "export.*function\|export default"` | `Button.tsx` |
| API route | `grep "router\.\|app\."` | `/api/users` |
| Database model | `grep "interface\|type\|schema"` | `User` model |
| Config | `ls` + `cat` | `config.json` |
| Test file | `ls` | `auth.test.ts` |

## Anti-Patterns to Avoid

1. **Assuming existence** - Never start coding imports without verification
2. **Partial verification** - Check ALL dependencies, not just obvious ones
3. **Skipping on "obvious" tasks** - Even simple tasks can have hidden dependencies
4. **Trusting task descriptions** - Verify actual filesystem, not just documentation

## Example Invocation

When you see a task like:

> Task 2.3: Add validation to user form using the validateEmail helper from task 2.1

Run verification:

```bash
# Verify validateEmail exists
grep -n "export.*validateEmail" src/utils/validation.ts

# If not found, check alternate locations
grep -rn "validateEmail" src/ --include="*.ts"
```

Only proceed if verification passes.
