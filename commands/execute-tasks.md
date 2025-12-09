# Execute Tasks

## Quick Navigation
- [Description](#description)
- [Parameters](#parameters)
- [Dependencies](#dependencies)
- [Task Tracking](#task-tracking)
- [Execution Modes](#execution-modes)
- [Core Instructions](#core-instructions)
- [State Management](#state-management)
- [Error Handling](#error-handling)

## Description
Execute one or more tasks from a specification with context-efficient architecture. This command uses **phase-based instruction loading** and supports an **orchestrator pattern** for multi-task sessions.

**Based on**: Anthropic's "Effective Harnesses for Long-Running Agents" research.

## Parameters
- `spec_srd_reference` (required): Path to the specification file or folder
- `specific_tasks` (optional): Array of specific task IDs to execute (defaults to next uncompleted task)

## Dependencies
**Required State Files:**
- `.agent-os/state/workflow.json` (read/write)
- `.agent-os/state/session-cache.json` (read/write for cache persistence)

**Expected Directories:**
- `.agent-os/specs/` (specifications)
- `.agent-os/tasks/` (task definitions - uses tasks.json)
- `.agent-os/standards/` (coding standards)
- `.agent-os/codebase/` (optional - codebase references)

**Creates Directories:**
- `.agent-os/state/recovery/` (state backups)
- `.agent-os/recaps/` (completion summaries)

## Task Tracking
**IMPORTANT: Use Claude's TodoWrite tool throughout execution:**
```javascript
// Minimal orchestrator-level todos (phases handle details)
const todos = [
  { content: "Run session startup protocol", status: "pending", activeForm: "Running session startup protocol" },
  { content: "Load task and determine execution mode", status: "pending", activeForm: "Loading task and determining execution mode" },
  { content: "Execute task(s)", status: "pending", activeForm: "Executing task(s)" },
  { content: "Complete delivery workflow", status: "pending", activeForm: "Completing delivery workflow" }
];
```

## Execution Modes

This command supports three execution modes based on Anthropic's research:

### Mode 1: Direct Single-Task (DEFAULT, RECOMMENDED)
```
Tasks: 1 parent task
Context: Full instructions loaded
Benefits: Simplest, full context available
Use when: Most sessions (1-2 tasks)
```

### Mode 2: Orchestrated Multi-Task
```
Tasks: 2+ parent tasks
Context: Orchestrator spawns workers per task
Benefits: Fresh context per task, scalable
Use when: Long sessions, many tasks
```

### Mode 3: Direct Multi-Task (NOT RECOMMENDED)
```
Tasks: 2+ parent tasks
Context: All in current session
Risks: Context bloat, lower quality
Use when: User explicitly overrides
```

**Mode Selection Flow:**
```
IF 1 task selected:
  USE: Direct Single-Task (Mode 1)

IF 2+ tasks selected:
  DISPLAY: Warning about research findings
  OFFER:
    1. Single task focus (Mode 1) - RECOMMENDED
    2. Orchestrated execution (Mode 2)
    3. Direct multi-task (Mode 3) - override only
```

## For Claude Code
When executing this command:
1. **Initialize TodoWrite** with the workflow phases
2. **Load phases on-demand** to minimize context:
   - Phase 0: Session startup (always)
   - Phase 1: Task discovery (always)
   - Phase 2: Task execution (only during implementation)
   - Phase 3: Completion (only after all tasks done)
3. Use atomic operations for all state reads/writes
4. Use **tasks.json** (not tasks.md) for task status
5. Use **context-summary.json** for pre-computed context
6. **Delegate to orchestrator** if multi-task mode selected

---

## SECTION: Core Instructions
<!-- BEGIN EMBEDDED CONTENT - LIGHTWEIGHT ORCHESTRATION SHELL -->

# Task Execution - Orchestration Shell

This is the lightweight shell that coordinates phases. Full instructions are loaded per-phase to conserve context.

## Workflow Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    EXECUTE-TASKS WORKFLOW                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Phase 0: Session Startup                                        │
│  ├── session-startup skill auto-invokes                          │
│  └── Environment verified, progress loaded                       │
│       ↓                                                          │
│  Phase 1: Task Discovery                                         │
│  ├── Load tasks.json                                             │
│  ├── Determine execution mode (single/orchestrated/multi)        │
│  ├── Load context-summary.json (or generate)                     │
│  └── Git branch setup                                            │
│       ↓                                                          │
│  [MODE BRANCH]                                                   │
│  ├── IF orchestrated → task-orchestrator subagent handles all    │
│  └── IF direct → Continue to Phase 2                             │
│       ↓                                                          │
│  Phase 2: Task Execution (per task)                              │
│  ├── Load task context from summary                              │
│  ├── TDD implementation cycle                                    │
│  ├── Test verification                                           │
│  └── Update tasks.json                                           │
│       ↓                                                          │
│  Phase 3: Completion                                             │
│  ├── Full test suite                                             │
│  ├── Build verification                                          │
│  ├── Git workflow (commit, PR)                                   │
│  └── Documentation and notification                              │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Phase Loading Protocol

Load phase instructions on-demand to conserve context:

```
PHASE_INSTRUCTIONS = {
  "phase0": "@commands/phases/execute-phase0.md",
  "phase1": "@commands/phases/execute-phase1.md",
  "phase2": "@commands/phases/execute-phase2.md",
  "phase3": "@commands/phases/execute-phase3.md"
}

FOR each phase needed:
  READ: Phase instruction file
  EXECUTE: Instructions in that phase
  RELEASE: Phase context when complete (conceptually)
  PROCEED: To next phase
```

## Quick Reference: Key Changes from v1.7

| Aspect | Before (v1.7) | After (v1.8+) |
|--------|---------------|---------------|
| Task format | tasks.md only | tasks.json primary + tasks.md sync |
| Context | Full spec discovery | Pre-computed context-summary.json |
| Multi-task | Direct execution | Orchestrator pattern available |
| Single-task | Warning only | Strict default, requires override |
| Instructions | All embedded (636 lines) | Phase-based loading (~150 lines each) |

## Execution Entry Point

### Step 0: Load and Execute Phase 0
```
ACTION: Read @commands/phases/execute-phase0.md
EXECUTE: Session startup protocol
OUTPUT: Environment verified, task suggestion ready
```

### Step 1: Load and Execute Phase 1
```
ACTION: Read @commands/phases/execute-phase1.md
EXECUTE: Task discovery and mode selection
OUTPUT: execution_mode determined (direct/orchestrated)
```

### Step 2: Mode Branch

```
IF execution_mode == "orchestrated":
  ACTION: Invoke task-orchestrator subagent via Task tool
  REQUEST: "Orchestrate task execution for spec:
            Spec: [SPEC_FOLDER_PATH]
            Mode: orchestrated
            Tasks: [TASK_IDS_TO_EXECUTE]
            Context: Use context-summary.json"
  WAIT: For orchestrator completion
  SKIP: To Phase 3 completion steps (Step 10+)

ELSE (direct modes):
  ACTION: Read @commands/phases/execute-phase2.md
  EXECUTE: Task execution loop
  OUTPUT: All tasks completed
```

### Step 3: Load and Execute Phase 3
```
ACTION: Read @commands/phases/execute-phase3.md
EXECUTE: Completion and delivery workflow
OUTPUT: PR created, documentation done
```

## Skills Auto-Invoked

These skills trigger automatically at appropriate points:

| Skill | Trigger Point | Purpose |
|-------|---------------|---------|
| session-startup | Phase 0 start | Environment verification |
| tdd | Phase 2 implementation | Test-driven development |
| test-check | Phase 2 verification | Test execution |
| build-check | Phase 3 pre-commit | Build verification |
| verification | Phase 2 completion | Evidence-based claims |

## Subagents Used

| Subagent | Purpose | Phase |
|----------|---------|-------|
| task-orchestrator | Multi-task coordination | Phase 1 (if orchestrated) |
| git-workflow | Branch and commit management | Phase 1, 3 |
| codebase-indexer | Code reference updates | Phase 2 |
| project-manager | Documentation and notification | Phase 3 |

## Context Efficiency

### Token Budget (Approximate)

| Component | Direct Mode | Orchestrated Mode |
|-----------|-------------|-------------------|
| Shell instructions | ~800 | ~800 |
| Phase 0-1 | ~600 | ~600 |
| Phase 2 (per task) | ~1500 | Delegated to worker |
| Phase 3 | ~800 | ~800 |
| Context summary | ~800/task | ~800/worker |
| **Total for 5 tasks** | ~10,000 | ~4,500 (orchestrator) |

### Why Orchestrated Mode Helps

```
Direct Mode (5 tasks):
├── All context accumulates
├── By task 5: ~15,000 tokens of context
└── Risk: Context overflow, quality degradation

Orchestrated Mode (5 tasks):
├── Orchestrator holds ~2,000 tokens
├── Each worker starts fresh (~3,000 tokens)
├── Workers terminate after task
└── Result: Consistent quality throughout
```

<!-- END EMBEDDED CONTENT -->

---

## SECTION: State Management

Use patterns from @shared/state-patterns.md:
- State writes: ATOMIC_WRITE_PATTERN
- State loads: STATE_LOAD_PATTERN
- Cache validation: CACHE_VALIDATION_PATTERN (5-min expiry, mtime-based)
- Locking: LOCK_PATTERN

Use patterns from @shared/progress-log.md:
- Append entries: PROGRESS_APPEND_PATTERN
- Load progress: PROGRESS_LOAD_PATTERN
- Read recent: PROGRESS_READ_RECENT_PATTERN

Use patterns from @shared/task-json.md:
- Parse tasks: MARKDOWN_TO_JSON_PATTERN
- Sync tasks: SYNC_TASKS_PATTERN
- Update metadata: UPDATE_TASK_METADATA_PATTERN

Use patterns from @shared/context-summary.md:
- Load context: LOAD_TASK_CONTEXT_PATTERN
- Format for worker: FORMAT_WORKER_CONTEXT_PATTERN

**Progress logging events:**
- `session_started`: After Phase 1 completes
- `task_completed`: After each parent task (Phase 2)
- `session_ended`: At Phase 3 completion

**Execute-tasks specific state:**
```json
{
  "task_iteration": {
    "current_task": "1.2",
    "subtask_index": 0,
    "tdd_phase": "RED|GREEN|REFACTOR"
  },
  "execution_mode": "direct|orchestrated|direct_multi",
  "phases_completed": ["phase0", "phase1"]
}
```

---

## SECTION: Error Handling

**Recovery Philosophy**: Save state early, save often. Every step should be resumable.

See @shared/error-recovery.md for detailed recovery procedures covering:
- State corruption recovery
- Git workflow failures
- Test failures during execution
- Build failures
- Subagent/skill invocation failures
- Cache expiration recovery
- Partial task failure (resume protocol)
- Development server conflicts

### Quick Reference: Error → Recovery

| Error Type | First Action | Escalation |
|------------|--------------|------------|
| State corruption | Load from recovery/ | Reinitialize |
| Git checkout fails | Stash changes | Manual resolution |
| Tests fail | Analyze output, fix | Skip with documentation |
| Build errors (own files) | Fix immediately | - |
| Build errors (other files) | DOCUMENT_AND_COMMIT | Create new task |
| Subagent timeout | Retry once | Manual fallback |
| Cache expired | Rebuild from source | Full context reload |
| Partial execution | Check tasks.json, resume | Restart with context |
| Port conflict | Kill process | Use alternate port |
| Orchestrator failure | Retry, then direct mode | Manual task execution |
| Context overflow | Switch to orchestrated mode | Split into sessions |

### Execute-tasks Specific

- **Phase loading failure**: Fall back to full embedded instructions
- **Context summary missing**: Generate on-the-fly
- **Orchestrator timeout**: Continue in direct mode with single task

## Subagent Integration
When the instructions mention agents, use the Task tool to invoke these subagents:
- `task-orchestrator` for multi-task coordination (new)
- `git-workflow` for branch and commit management
- `codebase-indexer` for code reference updates
- `project-manager` for documentation and notifications

Skills (auto-invoked):
- `session-startup` for environment verification
- `tdd` for test-driven development
- `test-check` for test execution
- `build-check` for build verification
- `verification` for evidence-based completion claims
- `codebase-names` for validating function/variable names
