# Debug

Unified debugging command with automatic context detection and Explore agent integration for root cause analysis.

## Usage

```
/debug [issue_description] [--scope=task|spec|general]
```

## Parameters

- `issue_description` (optional): Description of the issue to debug
- `--scope` (optional): Hint for debugging scope - auto-detected if not provided

## Native Integration

| Feature | Tool | Purpose |
|---------|------|---------|
| **Explore Agent** | `Task` with `subagent_type='Explore'` | Comprehensive root cause investigation |
| **systematic-debugging** | skill (auto-invokes) | 4-phase root cause analysis |
| **pre-commit-gate** | hook | Validates fix before commit |

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

### 5. Implement Fix

```
TDD APPROACH:
1. Write test that reproduces bug
2. Verify test fails
3. Implement fix
4. Verify test passes
5. Check for regressions
```

### 6. Verification

pre-commit-gate hook validates:
- All tests pass
- Build succeeds
- No type errors

### 7. Git Workflow

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

### 8. Documentation

```
WRITE: .agent-os/debugging/[DATE]-[issue].md

TEMPLATE:
# Debug Report
**Scope**: [task/spec/general]
**Date**: [DATE]

## Issue
## Root Cause
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
- Git commits with root cause analysis
- Pull request (if general scope)

## Debug Contexts

| Scope | When | Git Strategy |
|-------|------|--------------|
| `task` | Issue in single task | Commit to feature branch |
| `spec` | Integration issue | Commit to feature branch |
| `general` | System-wide bug | Create fix branch + PR |
