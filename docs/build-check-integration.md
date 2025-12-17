# Build Check Integration

## Overview

The `/execute-tasks` and `/debug` commands include intelligent build verification before commits. This prevents build failures from reaching CI/CD by catching type and lint errors early, while smartly distinguishing between "must fix now" and "acceptable for future tasks" issues.

## Architecture (v3.0+)

### v3 Implementation: Hooks + Skills

In v3.0, build checking uses a **hybrid approach** combining mandatory hooks and model-invoked skills:

| Component | Type | Location | Purpose |
|-----------|------|----------|---------|
| `pre-commit-gate.sh` | Hook | `.claude/hooks/` | **Mandatory** validation before any commit |
| `build-check` skill | Skill | `.claude/skills/` | **Auto-invoked** for intelligent error classification |

**Key Difference from v2.x**: Hooks are **deterministic**—they cannot be skipped by the model. This ensures build validation always runs before commits.

### How It Works

1. **Hook Trigger**: When `git commit` is invoked, `pre-commit-gate.sh` runs automatically
2. **Skill Invocation**: The `build-check` skill is auto-invoked to classify any errors
3. **Decision**: Based on classification, commit proceeds or blocks

### Integration Points

#### `/execute-tasks` (Phase 3)
- **Pre-commit gate** runs before git workflow
- Validates build, tests, and types
- Blocks commit if critical errors found

#### `/debug`
- Same pre-commit validation
- Context-aware error classification based on fix scope

## Build Check Workflow

```
┌─────────────────────────────────────┐
│  Step 1: Pre-Commit Hook Triggers   │
│  (git commit attempted)             │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│  Step 2: Run Build Command          │
│  (if package.json has build script) │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│  Step 3: Get IDE Diagnostics        │
│  (mcp__ide__getDiagnostics)         │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│  Step 4: Analyze Modified Files     │
│  - Errors in modified files         │
│  - Type/lint issues in our code     │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│  Step 5: Analyze Other Files        │
│  - Breaking changes we caused       │
│  - Errors future tasks will fix     │
│  - Pre-existing unrelated errors    │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│  Step 6: Smart Classification       │
│  (build-check skill)                │
│  - MUST_FIX                         │
│  - ACCEPTABLE_FOR_NOW               │
│  - INVESTIGATE                      │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│  Step 7: Return Decision            │
│  - FIX_REQUIRED (block commit)      │
│  - DOCUMENT_AND_COMMIT              │
│  - COMMIT (proceed)                 │
└─────────────────────────────────────┘
```

### Decision Types

#### 1. COMMIT ✅
**When:** No errors found, all checks pass
**Action:** Proceed with git commit immediately

#### 2. FIX_REQUIRED ❌
**When:** Critical errors that must be fixed now
**Examples:**
- Type errors in files modified by current task
- Breaking changes affecting other parts of codebase
- Import errors for existing code
- Syntax errors or critical type mismatches

**Action:**
- Display errors to user
- Fix each error
- Re-run build-checker until COMMIT decision
- Then proceed to git workflow

#### 3. DOCUMENT_AND_COMMIT ⚠️
**When:** Errors exist but are acceptable for now
**Examples:**
- Errors in unmodified files about interfaces/types that future tasks will implement
- Type errors about incomplete features in remaining tasks
- Dependencies explicitly mentioned in task breakdown

**Action:**
- Display acceptable errors with reasoning
- Add commit message addendum documenting the errors
- Note which future tasks will resolve them
- Proceed to git commit with enhanced message

## Smart Failure Classification

### MUST_FIX Criteria
```typescript
// Errors that BLOCK commits
- Type/lint errors in modified files
- Breaking changes affecting other code
- Errors preventing core functionality
- Syntax errors or critical type mismatches
- Import errors for existing code
```

### ACCEPTABLE_FOR_NOW Criteria
```typescript
// Errors that can be DOCUMENTED and committed
- Errors in unmodified files about missing interfaces future tasks will add
- Type errors about incomplete features in remaining tasks
- Circular dependencies that resolve when all tasks complete
- Errors explicitly mentioned as "to be implemented" in task dependencies
```

### INVESTIGATE Criteria
```typescript
// Errors needing HUMAN JUDGMENT
- Errors in unmodified files unrelated to current task
- Pre-existing errors not documented in tasks
- Ambiguous type errors without clear resolution path
```

## Example Scenarios

### Scenario 1: Clean Build ✅
```
Task: Implement user login (Task 2.1)
Modified: src/auth/login.ts, src/auth/login.test.ts

Build Check Result:
✓ Build: passed
✓ Diagnostics: 0 errors, 2 warnings (unused imports - acceptable)
✓ Decision: COMMIT
→ Action: Proceed with commit
```

### Scenario 2: Errors in Modified Files ❌
```
Task: Add logout functionality (Task 2.2)
Modified: src/auth/logout.ts

Build Check Result:
✗ Build: failed
✗ Must Fix Error:
  - src/auth/logout.ts:34 - Type 'undefined' not assignable to 'User'
  - Reason: Type error in file modified by current task
✗ Decision: FIX_REQUIRED
→ Action: Fix type error before committing
```

### Scenario 3: Acceptable Future Task Errors ⚠️
```
Task: Define auth types (Task 2.1)
Modified: src/types/auth.ts
Future Tasks: 2.2 (implement login), 2.3 (implement logout)

Build Check Result:
⚠ Build: failed (expected)
⚠ External Errors: 5 in src/auth/login.ts, src/auth/logout.ts
  - Using newly defined User type
  - Will be implemented in tasks 2.2, 2.3
⚠ Acceptable Errors:
  - src/auth/login.ts:12 - Cannot find name 'validateUser'
    → Will be fixed by Task 2.2
  - src/auth/logout.ts:8 - Cannot find name 'clearSession'
    → Will be fixed by Task 2.3
⚠ Decision: DOCUMENT_AND_COMMIT
⚠ Commit Addendum: "Note: 5 expected errors in auth files will be resolved by tasks 2.2-2.3"
→ Action: Add note to commit message and proceed
```

### Scenario 4: Breaking Change ❌
```
Task: Refactor User interface
Modified: src/types/user.ts (changed User interface)

Build Check Result:
✗ Build: failed
✗ Must Fix Error:
  - src/profile/display.ts:45 - Property 'email' does not exist on type 'User'
  - Reason: Breaking change in User interface affects existing code
✗ Decision: FIX_REQUIRED
→ Action: Update all files using User.email to use new structure
```

## Integration Details

### v3.0 Hook Configuration

The `pre-commit-gate.sh` hook is configured in `.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "git commit",
        "hooks": [".claude/hooks/pre-commit-gate.sh"]
      }
    ]
  }
}
```

### Build-Check Skill Context

When the `build-check` skill is auto-invoked, it receives context about:
- Modified files from current task/fix
- Current task or fix description
- Future tasks (if within active spec)
- Spec path for dependency analysis

### Classification Output

The skill classifies errors and returns a decision:

```javascript
// Example classification result
{
  decision: "DOCUMENT_AND_COMMIT",
  buildStatus: "failed",
  diagnosticsSummary: {
    totalErrors: 5,
    modifiedFileErrors: 0,
    externalFileErrors: 5,
    warnings: 2
  },
  mustFixErrors: [],
  acceptableErrors: [
    {
      file: "src/auth/login.ts",
      line: 12,
      message: "Cannot find name 'validateUser'",
      reason: "Function will be implemented in Task 2.2",
      futureTask: "Task 2.2 - Implement login"
    }
  ],
  commitMessageAddendum: "\n\nNote: 5 expected errors...",
  recommendedAction: "Document acceptable errors and proceed"
}
```

## Benefits

### 1. Early Error Detection
- Catches type/lint errors before they reach CI/CD
- Prevents broken builds from being committed
- Reduces debugging time in code review

### 2. Context-Aware Decisions
- Understands task dependencies and future work
- Distinguishes between critical and temporary errors
- Provides clear reasoning for each decision

### 3. Documentation
- Documents expected build issues in commit messages
- Links errors to future tasks that will fix them
- Creates audit trail of intentional incomplete states

### 4. Developer Experience
- Clear actionable feedback (commit/fix/document)
- No false positives blocking legitimate work
- Transparent reasoning for all decisions

### 5. Build Confidence
- Know exactly what errors exist and why
- Understand which tasks will resolve issues
- Commit with confidence even with "acceptable" errors

## Configuration

### Build Command Detection
The build-checker automatically detects build commands from `package.json`:
```json
{
  "scripts": {
    "build": "tsc && vite build"  // ← Automatically used
  }
}
```

If no build script exists, the checker skips build execution and relies solely on IDE diagnostics.

### Diagnostics Source
Uses `mcp__ide__getDiagnostics` tool which provides:
- TypeScript type errors
- ESLint/Prettier lint errors
- IDE-detected issues
- All severity levels (error, warning, info)

## File Locations (v3.0+)

```
agent-os/
├── v3/
│   ├── hooks/
│   │   └── pre-commit-gate.sh      # Mandatory pre-commit validation
│   └── agents/
│       └── phase3-delivery.md      # Includes build check before commit
├── claude-code/skills/
│   └── build-check.md              # Smart error classification skill
├── commands/
│   ├── execute-tasks.md            # Orchestrates phases including build check
│   └── debug.md                    # Same pre-commit validation
└── docs/
    └── build-check-integration.md  # This document
```

**When installed to a project:**
```
.claude/
├── hooks/
│   └── pre-commit-gate.sh          # Hook (deterministic)
├── skills/
│   └── build-check.md              # Skill (model-invoked)
└── settings.json                   # Hook configuration
```

## Installation

Build checking is automatically included with v3 installation:

```bash
# Fresh installation (v3 is default)
./setup/project.sh --claude-code

# Upgrade from v2.x
./setup/project.sh --claude-code --upgrade
```

No additional configuration needed—hooks are automatically configured in `settings.json`.

## Troubleshooting

### Issue: Build check takes too long
**Solution:** Build timeout is 5 minutes. If exceeds, skip build and rely on diagnostics.

### Issue: Too many "acceptable" errors flagged as must-fix
**Solution:** Ensure future tasks are properly passed to build-checker. Check Step 9.5/10.5 context gathering.

### Issue: Pre-existing errors blocking commits
**Solution:** Build-checker only flags errors in modified files as must-fix. Pre-existing errors in other files are classified as "investigate" and don't block.

### Issue: Build command not found
**Solution:** Add "build" script to package.json, or rely on diagnostics-only checking.

## Migration Notes

### From v2.x to v3.0
When upgrading, build checking transitions from skill-only to hook+skill:

| v2.x | v3.0+ |
|------|-------|
| `build-check` skill (can be skipped) | `pre-commit-gate.sh` hook (mandatory) + `build-check` skill |
| Model decides when to invoke | Hook always runs before commit |

Run the upgrade command:
```bash
./setup/project.sh --claude-code --upgrade
```

### For Active Specs
Build checks intelligently handle incomplete work:
- Tasks in progress: Errors in other files are acceptable
- Final task: All errors must be fixed before commit
- Breaking changes: Always flagged as must-fix

### v3.0 Benefits Over v2.x
- **Hooks cannot be bypassed** - validation is deterministic
- **Consistent behavior** - same validation every time
- **Better audit trail** - hook execution is logged

## Future Enhancements

### Potential Improvements
1. **Custom Severity Rules:** Allow projects to define which error types are acceptable
2. **Build Cache:** Cache build results to avoid redundant builds
3. **Auto-Fix:** Suggest or apply fixes for common type errors
4. **Integration Tests:** Run integration tests as part of build check
5. **Performance Metrics:** Track build check performance and optimization opportunities

## Summary

The build check integration (v3.0+) provides:
- ✅ **Mandatory validation** via pre-commit hook (cannot be skipped)
- ✅ **Intelligent classification** via build-check skill
- ✅ Context-aware handling of future task errors
- ✅ Clear documentation of acceptable errors in commit messages
- ✅ Confidence in commit quality
- ✅ Reduced CI/CD failures
- ✅ Better developer experience

**Key v3.0 Improvement**: The hook+skill hybrid ensures validation **always runs** while maintaining smart error classification for multi-task workflows.
