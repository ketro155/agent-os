---
name: codebase-names
description: "Validate function, variable, and component names using live codebase search and task artifacts before writing code. Auto-invoke this skill when referencing existing functions, importing components, or modifying files with existing code."
allowed-tools: Read, Grep, Glob
---

# Codebase Names Validation Skill (v2.1)

Automatically validate exact names using **live Grep searches** and **task artifacts** to prevent naming errors when writing code that integrates with existing functions, components, or variables.

**Version 2.1 Change**: Replaces static codebase index with live search + task artifact verification.

## When to Use This Skill

Claude should automatically invoke this skill:
- **Before calling existing functions** in new code
- **Before importing existing components/utilities**
- **Before modifying existing files** with function references
- **When referencing existing variables/classes/types**
- **When using database table or API endpoint names**
- **When a task depends on outputs from a previous task**

## Data Sources (Priority Order)

### 1. Task Artifacts (Most Reliable for Recent Tasks)

Check `tasks.json` for artifacts from completed predecessor tasks:

```bash
# Read task artifacts from tasks.json
grep -A 20 '"artifacts"' .agent-os/specs/[spec-name]/tasks.json
```

Task artifacts contain:
- `exports_added`: Functions/classes created by predecessor tasks
- `files_created`: New files that can be imported from
- `functions_created`: Function names available for calling

**Why artifacts are reliable**: They record actual outputs from just-completed tasks, not predictions.

### 2. Live Codebase Search (Always Fresh)

Use Grep to search the actual codebase:

```bash
# Find function definition
grep -r "export.*functionName" src/

# Find component export
grep -r "export.*ComponentName" --include="*.tsx" --include="*.ts" src/

# Find class definition
grep -r "class ClassName" --include="*.ts" --include="*.py" src/

# Find type/interface
grep -r "export type\|export interface" --include="*.ts" src/types/
```

### 3. Static Index (Optional Fallback - May Be Stale)

If `.agent-os/codebase/` exists, it can serve as a hint but **should be verified**:
- `functions.md` - May have outdated line numbers
- `imports.md` - May miss recent additions
- `schemas.md` - Database/API definitions

**Warning**: Static index may be outdated. Always verify critical names with live search.

## Workflow

### Step 1: Check Task Dependencies

If working on a task with dependencies:

```
READ: tasks.json for current spec
FIND: Current task's parallelization.blocked_by list
FOR each predecessor task:
  EXTRACT: artifacts.exports_added, artifacts.files_created
  ADD: To verified names list
```

### Step 2: Live Search for Other Names

For names not from predecessor artifacts:

```bash
# Search for function
grep -rn "export function ${name}\|export const ${name}" src/

# Search for component
grep -rn "export default.*${name}\|export { ${name}" src/

# Search for type
grep -rn "export type ${name}\|export interface ${name}" src/
```

### Step 3: Verify and Format

Build reference sheet with verified names only.

## Output Format

```markdown
📚 Verified Names Reference

### From Predecessor Tasks (Task 1 artifacts):
✓ validateUser - from src/auth/validate.ts (Task 1)
✓ hashPassword - from src/auth/validate.ts (Task 1)
✓ AuthError - from src/auth/errors.ts (Task 1)

### From Live Codebase Search:
✓ UserService (grep: src/services/user.ts:15)
✓ DatabaseConnection (grep: src/lib/database.ts:8)

### Import Paths (verified):
import { validateUser, hashPassword } from '@/auth/validate'
import { UserService } from '@/services/user'

⚠️  USE THESE EXACT NAMES - VERIFIED VIA ARTIFACTS OR LIVE SEARCH
```

## Smart Search Patterns

Based on task context, use targeted searches:

**Auth-related tasks:**
```bash
grep -rn "export.*auth\|export.*token\|export.*session" src/
```

**Component tasks:**
```bash
grep -rn "export default\|export function" --include="*.tsx" src/components/
```

**API/Backend tasks:**
```bash
grep -rn "export.*router\|export.*handler\|export.*controller" src/
```

**Database tasks:**
```bash
grep -rn "schema\|model\|table" --include="*.ts" --include="*.py" src/
```

## Missing Names Protocol

If requested names are not found:

```markdown
❌ Name Not Found

Could not locate: [function/component/variable name]

Searched:
1. ✗ Task artifacts (no predecessor with this export)
2. ✗ Live grep: grep -r "export.*${name}" src/
3. ✗ Static index (if exists): .agent-os/codebase/

Possible reasons:
1. Name doesn't exist yet - needs to be created
2. Name uses different casing or spelling
3. Name is in unexpected location

DO NOT proceed with guessed names.
ACTION: Create the function/component, or clarify with user.
```

## Key Principles

1. **Live Search First**: Always use Grep for verification - it's always current
2. **Trust Task Artifacts**: Predecessor task artifacts are reliable (just created)
3. **Verify Static Index**: If using .agent-os/codebase/, verify critical names
4. **Exact Names Only**: Never guess or approximate - search and confirm
5. **Copy-Paste Ready**: Format names for easy use in code
6. **Clear Sources**: Always indicate where the name was found

## Migration from Static Index

The static codebase index (`.agent-os/codebase/`) is deprecated in v2.1:
- **Before**: Search static index files → risk of stale data
- **After**: Live Grep + task artifacts → always current

If the static index exists, it can still be used as a hint, but live verification is required for critical names.
