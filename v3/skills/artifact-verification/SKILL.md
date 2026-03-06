---
name: artifact-verification
description: Verifies that predecessor task artifacts (files, exports, APIs) exist before dependent tasks begin. Use before starting tasks with dependencies or at wave boundaries in multi-wave execution. Use when user says "verify artifacts", "check dependencies", "are predecessors done", or "validate task outputs". NOT for verifying test results (use /test-guardian).
version: 3.1.0
metadata:
  author: Agent OS
  category: workflow-automation
---

# Artifact Verification Skill

> **Note**: This skill is auto-invoked by `/execute-tasks` Step 6a at wave boundaries. It can also be invoked manually via `/artifact-verification`.

Verify that predecessor task artifacts actually exist before proceeding with dependent work. This prevents hallucination of non-existent exports, files, or APIs.

## When to Use

- Before starting any task that has dependencies
- When a task description references "using X from task Y"
- **Before wave execution in multi-wave specs** (auto-invoked)
- **At wave boundaries when entering a new wave** (auto-invoked)
- When implementing code that imports from other modules

## Auto-Invocation

This skill is automatically invoked in two scenarios:

1. **Wave Boundary** — when `/execute-tasks` transitions between waves (TeamDelete → TeamCreate cycles), it runs before creating the next team.
2. **Task Start** — when phase2-implementation (teammate mode) starts a task with dependencies.

See `references/ast-verification-api.md` for the integration code examples.

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

Use AST-based verification (recommended) or legacy grep (fallback):

```bash
# AST verification (recommended)
npx tsx .claude/scripts/ast-verify.ts check-export [file-path] [export-name]
npx tsx .claude/scripts/ast-verify.ts check-function [file-path] [function-name]

# Legacy grep (fallback when AST unavailable)
grep -n "export.*[function-name]" [file-path]
```

For full AST API details and programmatic usage, see `references/ast-verification-api.md`.

### Step 3: Document Findings

Create verification report:

```
ARTIFACT VERIFICATION REPORT
============================
Task: [task-id]
Timestamp: [datetime]

VERIFIED (exist and correct):
- [artifact-1]: Found at [location]

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

| Type | AST Method | Legacy Method | Example |
|------|-----------|---------------|---------|
| TypeScript file | `verifyExports(path)` | `ls` + `grep export` | `src/utils/auth.ts` |
| Export (any) | `verifyExportExists(path, name)` | `grep "export.*name"` | `validateEmail` |
| Function export | `verifyFunctionExists(path, name)` | `grep "export.*function"` | `createUser()` |
| Interface/Type | `verifyExportTypes(path, [{name, kind}])` | `grep "interface\|type"` | `User`, `ApiResponse` |
| Class export | `verifyExportTypes(path, [{name, kind:'class'}])` | `grep "export.*class"` | `UserService` |
| React component | `verifyExportExists` + file check | `grep "export.*function\|default"` | `Button.tsx` |
| API route | `grep "router\.\|app\."` | Same | `/api/users` |
| Config / Test file | `ls` | Same | `config.json`, `auth.test.ts` |

## Anti-Patterns to Avoid

1. **Assuming existence** - Never start coding imports without verification
2. **Partial verification** - Check ALL dependencies, not just obvious ones
3. **Skipping on "obvious" tasks** - Even simple tasks can have hidden dependencies
4. **Trusting task descriptions** - Verify actual filesystem, not just documentation

## Changelog

### v3.1.0 (2026-03-06)
- Extracted AST API examples to references/ast-verification-api.md for context efficiency
- Reduced SKILL.md from 310 to ~120 lines

### v3.0.0 (2026-03-06)
- Updated for v5.5.0 flat team orchestration; removed deprecated agent references

### v2.0.0 (2026-01-10)
- Added auto-invocation at wave boundaries, AST-based type verification, verifyExportTypes

### v1.0.0 (2026-01-09)
- Initial implementation with grep-based verification
