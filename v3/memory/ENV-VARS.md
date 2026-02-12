# Agent OS Environment Variables (v5.2.0)

> Centralized documentation for all environment variables used by Agent OS.
> See individual components for detailed usage.

## Overview

Agent OS uses environment variables for:
- **Configuration**: Threshold values, retention periods
- **Paths**: Project directories, tool locations
- **Feature flags**: Enable/disable optional features
- **Integration**: External service configuration

---

## Core Variables

### CLAUDE_PROJECT_DIR

**Purpose**: Root directory of the project being worked on.

| Key | Value |
|-----|-------|
| Default | Current working directory |
| Required | No (auto-detected) |
| Used By | All agents, hooks, scripts |

```bash
export CLAUDE_PROJECT_DIR="/path/to/project"
```

---

## Context Offloading (v4.10.0)

These variables control the FewWord-inspired context offloading system.

### AGENT_OS_INLINE_MAX

**Purpose**: Maximum output size (bytes) to display inline.

| Key | Value |
|-----|-------|
| Default | `512` |
| Type | Integer (bytes) |
| Used By | `subagent-stop.sh` hook |

Outputs smaller than this threshold are displayed directly. Larger outputs are offloaded.

```bash
export AGENT_OS_INLINE_MAX=512
```

### AGENT_OS_PREVIEW_MIN

**Purpose**: Minimum output size to include failure preview.

| Key | Value |
|-----|-------|
| Default | `4096` |
| Type | Integer (bytes) |
| Used By | `subagent-stop.sh` hook |

For failed operations with outputs larger than this, a preview of the failure is included.

```bash
export AGENT_OS_PREVIEW_MIN=4096
```

### AGENT_OS_SUCCESS_RETENTION

**Purpose**: How long to keep successful output files.

| Key | Value |
|-----|-------|
| Default | `24` |
| Type | Integer (hours) |
| Used By | Scratch directory cleanup |

```bash
export AGENT_OS_SUCCESS_RETENTION=24
```

### AGENT_OS_FAILURE_RETENTION

**Purpose**: How long to keep failed output files.

| Key | Value |
|-----|-------|
| Default | `48` |
| Type | Integer (hours) |
| Used By | Scratch directory cleanup |

Failures are kept longer for debugging purposes.

```bash
export AGENT_OS_FAILURE_RETENTION=48
```

### AGENT_OS_SCRATCH_MAX_MB

**Purpose**: Maximum size of scratch directory before LRU eviction.

| Key | Value |
|-----|-------|
| Default | `250` |
| Type | Integer (megabytes) |
| Used By | Scratch directory cleanup |

When the scratch directory exceeds this size, oldest files are removed.

```bash
export AGENT_OS_SCRATCH_MAX_MB=250
```

---

## Teams (v5.2.0)

These variables control Teams-based wave coordination.

### AGENT_OS_MAX_TEAMMATES

**Purpose**: Maximum concurrent teammates per wave team.

| Key | Value |
|-----|-------|
| Default | `5` |
| Type | Integer |
| Used By | `wave-orchestrator` (dynamic cap formula) |

The actual teammate count is capped by both this value and the `isolation_score`-based formula:

```
avgIsolation >= 0.95 → cap = min(workUnits, MAX, 5)
avgIsolation >= 0.80 → cap = min(workUnits, MAX, 3)
avgIsolation >= 0.60 → cap = min(workUnits, MAX, 2)
avgIsolation <  0.60 → cap = 1
```

```bash
export AGENT_OS_MAX_TEAMMATES=5
```

---

## Task Execution

These variables control task batching and execution thresholds.

### BATCH_THRESHOLD

**Purpose**: Number of subtasks that triggers batched execution.

| Key | Value |
|-----|-------|
| Default | `4` |
| Type | Integer |
| Used By | `phase2-implementation` |

Tasks with more subtasks than this threshold use batched execution to prevent context overflow.

```bash
export BATCH_THRESHOLD=4
```

### SUBTASKS_PER_BATCH

**Purpose**: Maximum subtasks per batch agent.

| Key | Value |
|-----|-------|
| Default | `3` |
| Type | Integer |
| Used By | `phase2-implementation` |

When batching is triggered, subtasks are grouped into batches of this size.

```bash
export SUBTASKS_PER_BATCH=3
```

---

## Verification (v4.9.0)

### MAX_VERIFICATION_ATTEMPTS

**Purpose**: Maximum re-invocations for Ralph verification loop.

| Key | Value |
|-----|-------|
| Default | `3` |
| Type | Integer |
| Used By | `wave-orchestrator`, `verification-loop.ts` |

After this many attempts, verification failure becomes permanent.

```bash
export MAX_VERIFICATION_ATTEMPTS=3
```

---

## Hooks

### Hook Environment Variables

These are set automatically by Claude Code hooks.

| Variable | Set By | Purpose |
|----------|--------|---------|
| `HOOK_EVENT` | Claude Code | Type of hook event |
| `HOOK_TOOL_NAME` | Claude Code | Tool that triggered the hook |
| `HOOK_SESSION_ID` | Claude Code | Current session identifier |
| `AGENT_TYPE` | SubagentStop hook | Type of completed agent |
| `EXIT_CODE` | SubagentStop hook | Agent exit status |

---

## Comment Classification (v4.9.0)

### BATCH_SIZE

**Purpose**: Number of comments to process per batch.

| Key | Value |
|-----|-------|
| Default | `10` |
| Type | Integer |
| Used By | `comment-classifier` |

```bash
export BATCH_SIZE=10
```

### BATCH_THRESHOLD (Classifier)

**Purpose**: Comment count that triggers batching.

| Key | Value |
|-----|-------|
| Default | `20` |
| Type | Integer |
| Used By | `comment-classifier` |

```bash
export BATCH_THRESHOLD=20
```

### MAX_PARALLEL_BATCHES

**Purpose**: Maximum concurrent batch processing.

| Key | Value |
|-----|-------|
| Default | `3` |
| Type | Integer |
| Used By | `comment-classifier` |

```bash
export MAX_PARALLEL_BATCHES=3
```

---

## Directory Paths

### Standard Directories

These directories are used by Agent OS (relative to project root):

| Directory | Purpose | Gitignored |
|-----------|---------|------------|
| `.agent-os/` | Runtime state and artifacts | Partially |
| `.agent-os/specs/` | Feature specifications | No |
| `.agent-os/progress/` | Cross-session memory | Yes |
| `.agent-os/scratch/` | Ephemeral offloaded outputs | Yes |
| `.agent-os/metrics/` | Agent lifecycle tracking | Yes |
| `.agent-os/logs/` | Semantic memory logs | No |
| `.agent-os/cache/` | Verification cache | Yes |
| `.agent-os/test-plans/` | E2E test plans | No |
| `.agent-os/test-results/` | E2E test results | Yes |
| `.claude/` | Agent definitions and scripts | No |

---

## Configuration Examples

### Minimal Configuration

No environment variables required for default behavior.

### Performance Optimization

```bash
# Increase inline threshold for faster context
export AGENT_OS_INLINE_MAX=1024

# Reduce batch size for less context per agent
export SUBTASKS_PER_BATCH=2
export BATCH_THRESHOLD=3
```

### Extended Retention

```bash
# Keep outputs longer for debugging
export AGENT_OS_SUCCESS_RETENTION=72
export AGENT_OS_FAILURE_RETENTION=168  # 1 week
export AGENT_OS_SCRATCH_MAX_MB=500
```

### CI/CD Environment

```bash
# Strict verification, minimal retention
export MAX_VERIFICATION_ATTEMPTS=1
export AGENT_OS_SUCCESS_RETENTION=1
export AGENT_OS_FAILURE_RETENTION=4
```

---

## Troubleshooting

### Variable Not Taking Effect

1. Verify the variable is exported: `echo $VARIABLE_NAME`
2. Check for typos in variable name
3. Restart Claude Code session after setting

### Finding Variable Usage

```bash
# Search for variable usage in scripts
grep -r "AGENT_OS_" .claude/
grep -r "BATCH_THRESHOLD" .claude/
```

### Default Value Reference

All default values are defined in:
- `.claude/CLAUDE.md` (documented defaults)
- `.claude/hooks/*.sh` (implemented defaults)
- `.claude/scripts/*.ts` (implemented defaults)

---

## Changelog

### v5.2.0 (2026-02-12)
- Added Teams section with `AGENT_OS_MAX_TEAMMATES` variable
- Documented dynamic teammate cap formula

### v4.11.0 (2026-01-15)
- Initial centralized documentation
- Documented all context offloading variables
- Documented task execution thresholds
- Added configuration examples

### v4.10.0 (2026-01-12)
- Added context offloading variables (AGENT_OS_*)

### v4.9.0 (2026-01-10)
- Added verification variables
- Added classification batch variables
