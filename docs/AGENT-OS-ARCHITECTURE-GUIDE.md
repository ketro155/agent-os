# Agent OS: A Complete Guide to AI-Assisted Software Development

> **Version**: 4.5.0
> **Purpose**: Educational reference for understanding how Agent OS orchestrates AI agents, manages state, and maintains context efficiency in software development workflows.

---

## Table of Contents

1. [Philosophy & Design Principles](#1-philosophy--design-principles)
2. [Architecture Overview](#2-architecture-overview)
3. [The Feature Development Pipeline](#3-the-feature-development-pipeline)
4. [Commands: The User Interface](#4-commands-the-user-interface)
5. [Agents & Subagents: Execution Architecture](#5-agents--subagents-execution-architecture)
6. [Context Management & Efficiency](#6-context-management--efficiency)
7. [State Management & Recovery](#7-state-management--recovery)
8. [Git Integration & Branch Strategy](#8-git-integration--branch-strategy)
9. [Hooks: Deterministic Validation](#9-hooks-deterministic-validation)
10. [Practical Examples](#10-practical-examples)

---

## 1. Philosophy & Design Principles

### The Problem Agent OS Solves

Traditional AI-assisted coding suffers from several fundamental issues:

| Problem | Impact |
|---------|--------|
| **Context exhaustion** | Large features overflow the context window, causing lost instructions |
| **State drift** | Multiple files tracking the same state get out of sync |
| **Skippable validation** | Model-invoked checks can be bypassed or forgotten |
| **Hallucinated dependencies** | Agent claims to create exports that don't exist |
| **Lost progress** | Session interruptions lose work context |

### Core Design Principles

```
┌─────────────────────────────────────────────────────────────────────┐
│                     AGENT OS DESIGN PRINCIPLES                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  1. DETERMINISTIC OVER PROBABILISTIC                                │
│     • Hooks execute unconditionally (shell scripts)                 │
│     • Validation cannot be "forgotten" or skipped                   │
│     • System guarantees > model promises                            │
│                                                                      │
│  2. SINGLE SOURCE OF TRUTH                                          │
│     • One authoritative file per data type                          │
│     • Derived views auto-generated via hooks                        │
│     • No manual sync required                                       │
│                                                                      │
│  3. CONTEXT ISOLATION                                               │
│     • Fresh context per phase/wave/worker                           │
│     • Only verified artifacts cross boundaries                      │
│     • Scales to unlimited feature complexity                        │
│                                                                      │
│  4. VERIFICATION OVER TRUST                                         │
│     • Grep-verify exports before passing to next wave               │
│     • File existence checks before dependency claims                │
│     • System-level hallucination prevention                         │
│                                                                      │
│  5. RECOVERY BY DEFAULT                                             │
│     • Atomic writes with temp-then-rename pattern                   │
│     • Auto-backups before state changes                             │
│     • Cross-session progress persistence                            │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 2. Architecture Overview

### High-Level Component Map

```
┌─────────────────────────────────────────────────────────────────────┐
│                         AGENT OS v4.5.0                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   USER LAYER                                                        │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │  /plan-product  /create-spec  /create-tasks  /execute-tasks  │  │
│   │  /analyze-product  /shape-spec  /debug  /pr-review-cycle     │  │
│   └──────────────────────────────────────────────────────────────┘  │
│                              │                                       │
│                              ▼                                       │
│   ORCHESTRATION LAYER                                               │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │  Commands (.claude/commands/*.md)                            │  │
│   │  • Define workflow steps and user interactions               │  │
│   │  • Invoke agents via Task tool with subagent_type            │  │
│   │  • Maintain phase transitions and state updates              │  │
│   └──────────────────────────────────────────────────────────────┘  │
│                              │                                       │
│                              ▼                                       │
│   AGENT LAYER                                                       │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │  Agents (.claude/agents/*.md)                                │  │
│   │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐            │  │
│   │  │   Phase 1   │ │   Phase 2   │ │   Phase 3   │            │  │
│   │  │  Discovery  │ │Implementation│ │  Delivery   │            │  │
│   │  │   (haiku)   │ │  (sonnet)   │ │  (sonnet)   │            │  │
│   │  └─────────────┘ └─────────────┘ └─────────────┘            │  │
│   │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐            │  │
│   │  │ git-workflow│ │project-mgr  │ │subtask-group│            │  │
│   │  │   agent     │ │   agent     │ │   worker    │            │  │
│   │  └─────────────┘ └─────────────┘ └─────────────┘            │  │
│   └──────────────────────────────────────────────────────────────┘  │
│                              │                                       │
│                              ▼                                       │
│   VALIDATION LAYER (Deterministic)                                  │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │  Hooks (.claude/hooks/*.sh)                                  │  │
│   │  • session-start.sh    → Initialize context & env vars       │  │
│   │  • session-end.sh      → Log progress & cleanup              │  │
│   │  • post-file-change.sh → Sync tasks.json → tasks.md          │  │
│   │  • pre-commit-gate.sh  → Validate build/types/tests          │  │
│   └──────────────────────────────────────────────────────────────┘  │
│                              │                                       │
│                              ▼                                       │
│   STATE LAYER                                                       │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │  .agent-os/                                                  │  │
│   │  ├── product/          → mission.md, roadmap.md, vision.md   │  │
│   │  ├── specs/            → Feature specifications              │  │
│   │  │   └── [spec-name]/  → spec.md, tasks.json, tasks.md       │  │
│   │  ├── progress/         → progress.json (cross-session)       │  │
│   │  ├── state/            → session-cache.json, recovery/       │  │
│   │  └── schemas/          → JSON validation schemas             │  │
│   └──────────────────────────────────────────────────────────────┘  │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Directory Structure After Installation

```
your-project/
├── .claude/
│   ├── CLAUDE.md            # Core memory (always loaded by Claude Code)
│   ├── rules/               # Contextual rules (loaded when relevant)
│   ├── commands/            # User-invocable commands
│   │   ├── plan-product.md
│   │   ├── create-spec.md
│   │   ├── create-tasks.md
│   │   ├── execute-tasks.md
│   │   └── ...
│   ├── agents/              # Subagent definitions
│   │   ├── phase1-discovery.md
│   │   ├── phase2-implementation.md
│   │   ├── phase3-delivery.md
│   │   ├── git-workflow.md
│   │   └── ...
│   ├── hooks/               # Deterministic validation
│   │   ├── session-start.sh
│   │   ├── session-end.sh
│   │   ├── post-file-change.sh
│   │   └── pre-commit-gate.sh
│   ├── scripts/             # Utility scripts
│   │   ├── task-operations.sh
│   │   ├── branch-setup.sh
│   │   └── ...
│   └── settings.json        # Hook configuration
│
└── .agent-os/
    ├── product/             # Product-level documents
    ├── specs/               # Feature specifications
    ├── progress/            # Cross-session progress log
    ├── state/               # Session state & recovery
    └── schemas/             # JSON validation schemas
```

---

## 3. The Feature Development Pipeline

### Complete Workflow Visualization

```
┌─────────────────────────────────────────────────────────────────────┐
│                    FEATURE DEVELOPMENT PIPELINE                      │
└─────────────────────────────────────────────────────────────────────┘

  PRODUCT INITIALIZATION (One-time)
  ════════════════════════════════

  ┌─────────────────────┐
  │   /plan-product     │  Create product foundation
  │   or                │  • mission.md (purpose & goals)
  │   /analyze-product  │  • roadmap.md (feature backlog)
  └─────────────────────┘  • vision.md (long-term direction)
            │
            ▼

  FEATURE DEVELOPMENT (Per Feature)
  ═════════════════════════════════

  ┌─────────────────────┐
  │   /shape-spec       │  Optional: Explore & refine requirements
  │   (optional)        │  • Interview user for clarification
  └─────────────────────┘  • Research existing codebase patterns
            │
            ▼
  ┌─────────────────────┐
  │   /create-spec      │  Create detailed specification
  │                     │  • Functional requirements
  └─────────────────────┘  • Technical approach
            │              • API contracts
            │              • Test scenarios
            ▼

  Output: .agent-os/specs/[YYYY-MM-DD-feature-name]/spec.md

            │
            ▼
  ┌─────────────────────┐
  │   /create-tasks     │  Generate task breakdown
  │                     │  • Analyze spec for atomic tasks
  └─────────────────────┘  • Identify parallelization opportunities
            │              • Create wave execution strategy
            ▼

  Output: tasks.json (source) + tasks.md (auto-generated view)

            │
            ▼
  ┌─────────────────────┐
  │   /execute-tasks    │  TDD Implementation
  │                     │  • Phase 1: Discovery & setup
  └─────────────────────┘  • Phase 2: RED → GREEN → REFACTOR
            │              • Phase 3: Delivery & PR
            ▼

  Output: Working code + Tests + PR

            │
            ▼
  ┌─────────────────────┐
  │   /pr-review-cycle  │  Handle PR feedback
  │   (if needed)       │  • Parse review comments
  └─────────────────────┘  • Implement fixes
                           • Capture future_tasks for backlog
```

### Pipeline Data Flow

```
/create-spec                           /create-tasks
┌────────────────────┐                ┌────────────────────┐
│ Input:             │                │ Input:             │
│ • User requirements│                │ • spec.md          │
│ • Codebase patterns│      ──►       │ • Codebase context │
│                    │                │                    │
│ Output:            │                │ Output:            │
│ • spec.md          │                │ • tasks.json       │
│   (500-2000 lines) │                │   (structured)     │
└────────────────────┘                └────────────────────┘
                                               │
                                               ▼
                                      ┌────────────────────┐
                                      │ Auto-generated:    │
                                      │ • tasks.md         │
                                      │   (human-readable) │
                                      │ • context-summary  │
                                      │   .json (per task) │
                                      └────────────────────┘
                                               │
/execute-tasks                                 │
┌────────────────────┐                         │
│ Input:             │◄────────────────────────┘
│ • tasks.json       │
│ • spec.md          │
│ • context-summary  │
│                    │
│ Output:            │
│ • Implemented code │
│ • Test files       │
│ • Updated tasks    │
│ • Git commits      │
│ • Pull Request     │
└────────────────────┘
```

---

## 4. Commands: The User Interface

### What Commands Are

Commands are markdown files that define workflows for Claude Code. They serve as the **user interface** to Agent OS, providing:

- **Structured prompts** that guide the AI through complex multi-step processes
- **Invocation points** for specialized agents
- **State management** instructions for updating progress

### Command Structure Pattern

```markdown
# /command-name

## Purpose
Brief description of what this command does.

## Prerequisites
- Required files or state
- Previous commands that should have run

## Workflow

### Step 1: Context Gathering
[Instructions for gathering necessary context]

### Step 2: Core Processing
[Main logic of the command]
[May invoke agents via Task tool]

### Step 3: State Update
[Update tasks.json, progress.json, etc.]

### Step 4: Output
[What to show the user]
```

### Core Commands Reference

| Command | Purpose | Invokes Agents | Output |
|---------|---------|----------------|--------|
| `/plan-product` | Initialize product foundation | None | mission.md, roadmap.md, vision.md |
| `/analyze-product` | Analyze existing codebase | Explore | Product analysis |
| `/shape-spec` | Refine requirements interactively | None | Clarified requirements |
| `/create-spec` | Generate detailed specification | None | spec.md |
| `/create-tasks` | Break spec into tasks | None | tasks.json, tasks.md |
| `/execute-tasks` | TDD implementation | Phase 1, 2, 3 | Code, tests, PR |
| `/debug` | Context-aware debugging | Explore | Bug fix |
| `/pr-review-cycle` | Handle PR feedback | PR Review agents | Fixes, future_tasks |

### How Commands Invoke Agents

Commands use Claude Code's native `Task` tool to spawn subagents:

```markdown
## Step: Execute Phase 1 Discovery

Invoke the Phase 1 Discovery agent:

<task>
  subagent_type: phase1-discovery
  prompt: |
    Analyze the spec at: {spec_path}
    Tasks to consider: {task_ids}
    Current wave: {wave_number}

    Return execution configuration.
</task>
```

The `Task` tool creates a **fresh context** for the subagent, preventing context accumulation in the main conversation.

---

## 5. Agents & Subagents: Execution Architecture

### The Phase Model

Agent OS uses a **three-phase execution model** where each phase has:
- **Specific responsibilities**
- **Restricted tool access**
- **Fresh context isolation**

```
┌─────────────────────────────────────────────────────────────────────┐
│                      THREE-PHASE EXECUTION MODEL                     │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐
│     PHASE 1         │    │     PHASE 2         │    │     PHASE 3         │
│    Discovery        │───►│   Implementation    │───►│    Delivery         │
│                     │    │                     │    │                     │
│  Model: haiku       │    │  Model: sonnet      │    │  Model: sonnet      │
│  (fast, efficient)  │    │  (capable, precise) │    │  (capable, precise) │
└─────────────────────┘    └─────────────────────┘    └─────────────────────┘
         │                          │                          │
         ▼                          ▼                          ▼
┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐
│ TOOLS:              │    │ TOOLS:              │    │ TOOLS:              │
│ • Read              │    │ • Read              │    │ • Read              │
│ • Grep              │    │ • Edit              │    │ • Bash              │
│ • Glob              │    │ • Write             │    │ • Grep              │
│ • TodoWrite         │    │ • Bash              │    │ • Glob              │
│ • AskUserQuestion   │    │ • Grep              │    │ • TodoWrite         │
│ • Task (subagents)  │    │ • Glob              │    │ • Write             │
│                     │    │ • TodoWrite         │    │                     │
│ NO file modification│    │                     │    │ NO Edit tool        │
└─────────────────────┘    │ NO Task invocation  │    │ (read-only + bash)  │
                           └─────────────────────┘    └─────────────────────┘
         │                          │                          │
         ▼                          ▼                          ▼
┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐
│ RESPONSIBILITIES:   │    │ RESPONSIBILITIES:   │    │ RESPONSIBILITIES:   │
│                     │    │                     │    │                     │
│ • Load spec/tasks   │    │ • TDD cycle per     │    │ • Verify all tasks  │
│ • Validate git      │    │   subtask           │    │   complete          │
│   branch            │    │ • RED: Write test   │    │ • Run full test     │
│ • Set up wave       │    │ • GREEN: Implement  │    │   suite             │
│   branch            │    │ • REFACTOR: Clean   │    │ • Graduate backlog  │
│ • Select tasks      │    │ • Commit per        │    │ • Create PR         │
│ • Choose execution  │    │   subtask           │    │ • Update roadmap    │
│   mode              │    │ • Collect artifacts │    │                     │
│                     │    │                     │    │                     │
└─────────────────────┘    └─────────────────────┘    └─────────────────────┘

         │                          │                          │
         ▼                          ▼                          ▼

OUTPUT: Execution config    OUTPUT: Task artifacts      OUTPUT: PR URL
  • tasks_to_execute          • files_created             • tests_passed: true
  • execution_mode            • exports_added             • pr_url: "..."
  • git_branch                • functions_created         • roadmap_updated
  • wave_number               • test_files
```

### Why Tool Restrictions Matter

```
┌─────────────────────────────────────────────────────────────────────┐
│                    TOOL RESTRICTION RATIONALE                        │
└─────────────────────────────────────────────────────────────────────┘

PHASE 1 (Discovery)
├── Has: Read, Grep, Glob (exploration)
├── Has: Task (can spawn workers)
├── Missing: Edit, Write (no file changes)
└── Reason: Discovery phase should NEVER modify code.
           Prevents accidental changes during exploration.

PHASE 2 (Implementation)
├── Has: Edit, Write, Bash (full modification)
├── Missing: Task (cannot spawn subagents)
└── Reason: Focused implementation without orchestration.
           Prevents recursive agent spawning.
           All subtask parallelization handled by orchestrator.

PHASE 3 (Delivery)
├── Has: Bash, Write (for running tests, creating PR)
├── Missing: Edit (no code changes)
└── Reason: Delivery phase should VERIFY, not modify.
           If tests fail, return to Phase 2.
           Prevents last-minute code changes that bypass TDD.
```

### Agent Types Reference

| Agent | File | Model | Purpose |
|-------|------|-------|---------|
| `phase1-discovery` | phase1-discovery.md | haiku | Task discovery, branch setup, mode selection |
| `phase2-implementation` | phase2-implementation.md | sonnet | TDD implementation cycle |
| `phase3-delivery` | phase3-delivery.md | sonnet | Verification, PR creation |
| `subtask-group-worker` | subtask-group-worker.md | sonnet | Parallel subtask execution |
| `git-workflow` | git-workflow.md | sonnet | Branch/commit/PR operations |
| `project-manager` | project-manager.md | haiku | Task/roadmap state updates |
| `future-classifier` | future-classifier.md | haiku | Classify PR feedback items |
| `roadmap-integrator` | roadmap-integrator.md | haiku | Add items to roadmap |

### Context Passing Between Phases

```
┌─────────────────────────────────────────────────────────────────────┐
│                    INTER-PHASE CONTEXT FLOW                          │
└─────────────────────────────────────────────────────────────────────┘

/execute-tasks (Orchestrator)
        │
        │ Spawns Phase 1 with:
        │ • spec_path
        │ • available_tasks (from tasks.json)
        │
        ▼
┌───────────────────┐
│    Phase 1        │
│    Discovery      │
└───────────────────┘
        │
        │ Returns JSON:
        │ {
        │   "spec_name": "auth-feature",
        │   "tasks_to_execute": ["1", "2", "3"],
        │   "execution_mode": "parallel_waves",
        │   "wave_number": 1,
        │   "git_branch": "feature/auth-feature-wave-1"
        │ }
        │
        ▼
/execute-tasks receives config
        │
        │ For each task, spawns Phase 2 with:
        │ • task_id
        │ • task_description
        │ • subtasks
        │ • predecessor_artifacts (if wave > 1)
        │ • context_summary (pre-computed)
        │
        ▼
┌───────────────────┐
│    Phase 2        │
│  Implementation   │
└───────────────────┘
        │
        │ Returns JSON:
        │ {
        │   "task_id": "1",
        │   "status": "completed",
        │   "artifacts": {
        │     "files_created": ["src/auth/login.ts"],
        │     "exports_added": ["loginUser", "validateToken"],
        │     "test_files": ["tests/auth/login.test.ts"]
        │   }
        │ }
        │
        ▼
/execute-tasks collects artifacts
        │
        │ VERIFICATION STEP (Critical!)
        │ For each export claimed:
        │   grep -r "export.*loginUser" src/
        │   → If not found: HALT with error
        │   → If found: Add to verified_artifacts
        │
        │ For each file claimed:
        │   ls src/auth/login.ts
        │   → If not found: HALT with error
        │
        ▼
Wave 2 receives VERIFIED artifacts:
{
  "predecessor_artifacts": {
    "verified": true,
    "wave_1": {
      "exports_added": ["loginUser", "validateToken"],
      "files_created": ["src/auth/login.ts"]
    }
  }
}
        │
        │ After all waves complete
        │
        ▼
┌───────────────────┐
│    Phase 3        │
│    Delivery       │
└───────────────────┘
        │
        │ Returns:
        │ {
        │   "tests_passed": true,
        │   "pr_url": "https://github.com/...",
        │   "roadmap_updated": true
        │ }
        │
        ▼
Feature Complete!
```

### Artifact Verification: Preventing Hallucinations

```
┌─────────────────────────────────────────────────────────────────────┐
│              SYSTEM-LEVEL HALLUCINATION PREVENTION                   │
└─────────────────────────────────────────────────────────────────────┘

THE PROBLEM:
Phase 2 Agent claims: "I created loginUser export in src/auth/login.ts"
Wave 2 Task depends on: import { loginUser } from './auth/login'

If loginUser doesn't actually exist → Wave 2 fails with confusing error

THE SOLUTION:
Wave Orchestrator VERIFIES before passing to Wave 2:

┌────────────────────────────────────────────────────────────────────┐
│  for each claimed_export in task.artifacts.exports_added:          │
│    result = grep -r "export.*${claimed_export}" src/               │
│                                                                    │
│    if result.empty:                                                │
│      ⛔ HALT EXECUTION                                              │
│      Report: "Phase 2 claimed to create '${claimed_export}'        │
│               but it was not found in the codebase.                │
│               This is a critical error requiring investigation."   │
│                                                                    │
│    else:                                                           │
│      ✅ Add to verified_artifacts                                   │
│      Continue to next export                                       │
│                                                                    │
│  for each claimed_file in task.artifacts.files_created:            │
│    if not file_exists(claimed_file):                               │
│      ⛔ HALT EXECUTION                                              │
│      Report: "Phase 2 claimed to create '${claimed_file}'          │
│               but file does not exist."                            │
│                                                                    │
│    else:                                                           │
│      ✅ Add to verified_artifacts                                   │
└────────────────────────────────────────────────────────────────────┘

RESULT:
• Wave 2 receives ONLY grep-verified artifacts
• Import failures are caught at orchestration level
• Debugging is straightforward: "Export X missing from Wave 1"
• Hallucinations caught by SYSTEM, not relying on MODEL accuracy
```

---

## 6. Context Management & Efficiency

### The Context Problem

```
┌─────────────────────────────────────────────────────────────────────┐
│                     THE CONTEXT ACCUMULATION PROBLEM                 │
└─────────────────────────────────────────────────────────────────────┘

NAIVE APPROACH (What NOT to do):

Main Agent Context:
├── User request                                          ~500 tokens
├── Read spec.md                                        ~3,000 tokens
├── Read tasks.json                                     ~1,500 tokens
├── Task 1 implementation (TDD output)                 ~15,000 tokens
├── Task 2 implementation (TDD output)                 ~15,000 tokens
├── Task 3 implementation (TDD output)                 ~15,000 tokens
├── Task 4 implementation (TDD output)                 ~15,000 tokens
├── Task 5 implementation (TDD output)                 ~15,000 tokens
├── ...                                                        ...
└── TOTAL: 80,000+ tokens (CONTEXT OVERFLOW!)

Problems:
• Earlier instructions get pushed out of context
• Agent "forgets" spec requirements
• Quality degrades as tasks progress
• Large features impossible to complete
```

### Solution 1: Phase-Based Context Isolation

```
┌─────────────────────────────────────────────────────────────────────┐
│                 PHASE-BASED CONTEXT ISOLATION                        │
└─────────────────────────────────────────────────────────────────────┘

AGENT OS APPROACH:

Main Orchestrator Context:               Phase 2 Agent Context (Fresh!):
├── User request           ~500          ├── Agent instructions    ~2,000
├── Phase 1 config result  ~300          ├── Single task details   ~1,000
├── Phase 2 artifacts      ~500/task     ├── Context summary       ~800
├── Phase 3 result         ~200          └── TDD implementation   ~15,000
└── TOTAL: ~3,000 tokens                     TOTAL: ~19,000 tokens

Benefits:
• Each Phase 2 invocation: fresh 19K context (well under limits)
• Main orchestrator stays lean: ~3K tokens
• Phase 2 output (15K) discarded after artifacts extracted
• Can execute unlimited tasks without accumulation
```

### Solution 2: Wave Orchestration

```
┌─────────────────────────────────────────────────────────────────────┐
│                      WAVE ORCHESTRATION                              │
└─────────────────────────────────────────────────────────────────────┘

EXECUTION STRATEGY:

tasks.json defines waves:
{
  "execution_strategy": {
    "mode": "parallel_waves",
    "waves": [
      { "wave_id": 1, "tasks": ["1", "2", "3"] },  // Independent
      { "wave_id": 2, "tasks": ["4", "5"] },       // Depend on Wave 1
      { "wave_id": 3, "tasks": ["6"] }             // Depends on Wave 2
    ]
  }
}

Wave 1 Execution:
┌────────────────────────────────────────────────────────────────────┐
│                                                                    │
│  ┌─────────┐     ┌─────────┐     ┌─────────┐                      │
│  │ Task 1  │     │ Task 2  │     │ Task 3  │   Run in PARALLEL    │
│  │ Phase 2 │     │ Phase 2 │     │ Phase 2 │   (independent)      │
│  └────┬────┘     └────┬────┘     └────┬────┘                      │
│       │               │               │                           │
│       ▼               ▼               ▼                           │
│  artifacts       artifacts       artifacts                        │
│       │               │               │                           │
│       └───────────────┼───────────────┘                           │
│                       ▼                                           │
│              VERIFY ALL ARTIFACTS                                 │
│              (grep exports, check files)                          │
│                       │                                           │
│                       ▼                                           │
│         verified_context for Wave 2 (~500 bytes)                  │
│                                                                   │
└────────────────────────────────────────────────────────────────────┘
                        │
                        ▼
Wave 2 Execution:
┌────────────────────────────────────────────────────────────────────┐
│                                                                    │
│  Receives ONLY: verified exports/files from Wave 1 (~500 bytes)   │
│  NOT: Full TDD output from Wave 1 (~45,000 bytes)                 │
│                                                                    │
│  ┌─────────┐     ┌─────────┐                                      │
│  │ Task 4  │     │ Task 5  │   Can import Wave 1 exports          │
│  │ Phase 2 │     │ Phase 2 │   with confidence (verified!)        │
│  └─────────┘     └─────────┘                                      │
│                                                                   │
└────────────────────────────────────────────────────────────────────┘

Context Savings:
• Without orchestration: 45,000+ tokens passed to Wave 2
• With orchestration: ~500 tokens passed to Wave 2
• Reduction: 99% context savings between waves
```

### Solution 3: Pre-Computed Context Summaries

```
┌─────────────────────────────────────────────────────────────────────┐
│                  PRE-COMPUTED CONTEXT SUMMARIES                      │
└─────────────────────────────────────────────────────────────────────┘

Generated by /create-tasks alongside tasks.json:

.agent-os/specs/auth-feature/context-summary.json:
{
  "1": {
    "task_id": "1",
    "description": "Implement JWT token generation",
    "relevant_specs": ["Section 2.1: Token Format", "Section 3.2: Expiration"],
    "relevant_files": ["src/auth/", "src/utils/crypto.ts"],
    "context_summary": "Task implements JWT generation per RFC 7519.
                        Uses existing crypto utils. Must integrate with
                        user model for claims."
  },
  "2": {
    "task_id": "2",
    "description": "Implement token validation middleware",
    "relevant_specs": ["Section 2.3: Validation Rules"],
    "relevant_files": ["src/middleware/", "src/auth/token.ts"],
    "context_summary": "Middleware validates JWT on protected routes.
                        Depends on Task 1 for token format. Returns
                        401 on invalid/expired tokens."
  }
}

Usage in Phase 2:

WITHOUT pre-computed context:
├── Agent must: Read spec.md (3000 tokens)
├── Agent must: Search for relevant files (500 tokens)
├── Agent must: Analyze dependencies (1000 tokens)
└── Total context discovery: ~4500 tokens

WITH pre-computed context:
├── Read context_summary[task_id] (800 tokens)
├── Already knows: relevant_specs, relevant_files
└── Total context discovery: ~800 tokens

Savings: 82% reduction in context overhead per task
```

### Solution 4: Batched Subtask Protocol

```
┌─────────────────────────────────────────────────────────────────────┐
│                   BATCHED SUBTASK PROTOCOL                           │
└─────────────────────────────────────────────────────────────────────┘

For tasks with 5+ subtasks (common in complex features):

PROBLEM: Sequential TDD accumulates output

Task with 9 subtasks, sequential:
├── Subtask 1.1 TDD output    ~5,000 tokens
├── Subtask 1.2 TDD output    ~5,000 tokens
├── Subtask 1.3 TDD output    ~5,000 tokens
├── Subtask 1.4 TDD output    ~5,000 tokens
├── Subtask 1.5 TDD output    ~5,000 tokens
├── Subtask 1.6 TDD output    ~5,000 tokens
├── Subtask 1.7 TDD output    ~5,000 tokens
├── Subtask 1.8 TDD output    ~5,000 tokens
├── Subtask 1.9 TDD output    ~5,000 tokens
└── TOTAL: 45,000 tokens (context strain)

SOLUTION: Batched execution with fresh context per batch

Batch 1 Agent (fresh context):
├── Subtasks 1.1, 1.2, 1.3    ~15,000 tokens
├── Returns: artifacts
└── Context discarded

Batch 2 Agent (fresh context):
├── Subtasks 1.4, 1.5, 1.6    ~15,000 tokens
├── Receives: Batch 1 verified artifacts (~300 tokens)
├── Returns: artifacts
└── Context discarded

Batch 3 Agent (fresh context):
├── Subtasks 1.7, 1.8, 1.9    ~15,000 tokens
├── Receives: Batch 1+2 verified artifacts (~600 tokens)
├── Returns: artifacts
└── Context discarded

Each batch: ~15,600 tokens (comfortable)
Orchestrator total: ~3,000 tokens (artifacts only)
```

### Context Efficiency Summary

```
┌─────────────────────────────────────────────────────────────────────┐
│                   CONTEXT EFFICIENCY METRICS                         │
└─────────────────────────────────────────────────────────────────────┘

Strategy                        │ Context Reduction │ When Applied
────────────────────────────────┼───────────────────┼──────────────────
Phase isolation                 │ ~60% per phase    │ Always
Wave orchestration              │ ~99% between waves│ Multi-task specs
Pre-computed context            │ ~82% per task     │ Always
Batched subtasks                │ ~70% for large    │ 5+ subtasks
                                │     tasks         │

COMBINED EFFECT:
• Naive approach: 100K+ tokens for 10-task feature
• Agent OS approach: ~25K tokens peak, ~5K orchestrator steady-state
• Result: Can execute unlimited complexity features
```

---

## 7. State Management & Recovery

### Single-Source-of-Truth Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│               SINGLE-SOURCE-OF-TRUTH TASK FORMAT                     │
└─────────────────────────────────────────────────────────────────────┘

PROBLEM (v2.x architecture):
├── tasks.md (human-readable, editable)
├── tasks.json (machine-readable, editable)
└── Both files must stay in sync → Sync drift bugs!

SOLUTION (v3.0+ architecture):
├── tasks.json (SOURCE OF TRUTH - human-editable JSON)
└── tasks.md (AUTO-GENERATED via hook - read-only view)

┌────────────────────────────────────────────────────────────────────┐
│  Human edits tasks.json                                            │
│           │                                                        │
│           ▼                                                        │
│  Hook: post-file-change.sh detects write to tasks.json             │
│           │                                                        │
│           ▼                                                        │
│  Hook regenerates tasks.md from tasks.json                         │
│           │                                                        │
│           ▼                                                        │
│  tasks.md is ALWAYS in sync (guaranteed by hook)                   │
└────────────────────────────────────────────────────────────────────┘

Benefits:
• Edit one file, both stay in sync
• No manual sync commands needed
• Deterministic (hook always runs)
• Human can edit JSON directly for complex changes
```

### tasks.json Structure

```json
{
  "version": "3.0",
  "spec": "auth-feature",
  "spec_path": ".agent-os/specs/2025-01-15-auth-feature/spec.md",
  "created": "2025-01-15T10:00:00Z",
  "updated": "2025-01-15T14:30:00Z",
  "markdown_generated": "2025-01-15T14:30:00Z",

  "execution_strategy": {
    "mode": "parallel_waves",
    "waves": [
      {
        "wave_id": 1,
        "tasks": ["1", "2"],
        "rationale": "Independent foundational components",
        "estimated_duration_minutes": 30
      },
      {
        "wave_id": 2,
        "tasks": ["3"],
        "rationale": "Depends on Task 1 and 2 exports",
        "estimated_duration_minutes": 20
      }
    ],
    "estimated_parallel_speedup": 1.5,
    "max_concurrent_workers": 3
  },

  "tasks": [
    {
      "id": "1",
      "type": "parent",
      "description": "Implement JWT token generation",
      "status": "completed",
      "wave": 1,
      "subtasks": ["1.1", "1.2", "1.3"],
      "started_at": "2025-01-15T11:00:00Z",
      "completed_at": "2025-01-15T11:45:00Z",
      "artifacts": {
        "files_created": ["src/auth/jwt.ts", "tests/auth/jwt.test.ts"],
        "exports_added": ["generateToken", "TokenPayload"],
        "functions_created": ["generateToken", "createPayload"]
      }
    },
    {
      "id": "1.1",
      "type": "subtask",
      "parent": "1",
      "description": "Create token payload structure",
      "status": "completed"
    }
    // ... more tasks
  ],

  "future_tasks": [
    {
      "id": "ft-001",
      "type": "WAVE_TASK",
      "description": "Add refresh token support",
      "source": "PR review comment",
      "target_wave": 2,
      "needs_subtask_expansion": true
    }
  ],

  "summary": {
    "total_tasks": 6,
    "completed": 4,
    "pending": 2,
    "blocked": 0,
    "overall_percent": 66
  }
}
```

### Atomic State Operations

```bash
┌─────────────────────────────────────────────────────────────────────┐
│                    ATOMIC WRITE PATTERN                              │
└─────────────────────────────────────────────────────────────────────┘

# task-operations.sh implements atomic writes:

update_task_status() {
    local task_id="$1"
    local new_status="$2"
    local tasks_file="$3"

    # Step 1: Create recovery backup
    cp "$tasks_file" ".agent-os/state/recovery/tasks-$(date +%s).json"

    # Step 2: Write to temp file (not original)
    local temp_file=$(mktemp)
    jq ".tasks |= map(if .id == \"$task_id\" then .status = \"$new_status\" else . end)" \
       "$tasks_file" > "$temp_file"

    # Step 3: Validate schema (optional but recommended)
    if ! validate_schema "$temp_file"; then
        rm "$temp_file"
        echo "Schema validation failed"
        return 1
    fi

    # Step 4: Atomic rename (mv is atomic on POSIX)
    mv "$temp_file" "$tasks_file"

    # Step 5: Clean old recovery files (keep last 5)
    ls -t .agent-os/state/recovery/tasks-*.json | tail -n +6 | xargs rm -f

    # Step 6: Trigger hook to regenerate tasks.md
    # (Happens automatically via post-file-change hook)
}

WHY ATOMIC?
• Crash during write → original file intact
• Crash during mv → either old or new file (never corrupted)
• Recovery always available from backup
```

### Session State & Cross-Session Memory

```
┌─────────────────────────────────────────────────────────────────────┐
│                 SESSION STATE MANAGEMENT                             │
└─────────────────────────────────────────────────────────────────────┘

SESSION CACHE (Short-lived, 5-minute expiration):
.agent-os/state/session-cache.json
{
  "spec_cache": {
    "auth-spec.md": {
      "path": ".agent-os/specs/auth/spec.md",
      "sections": ["2.1 Token Format", "2.2 Validation"],
      "last_modified": "2025-01-15T10:00:00Z"
    }
  },
  "context_cache": {
    "current_wave": 1,
    "completed_tasks": ["1", "2"]
  },
  "metadata": {
    "expires": "2025-01-15T10:05:00Z",
    "auto_extend": true,
    "extension_count": 3,
    "max_extensions": 12  // 1 hour max
  }
}

PROGRESS LOG (Persistent, version-controlled):
.agent-os/progress/progress.json
{
  "version": "1.0",
  "entries": [
    {
      "id": "entry-20250115-110000-abc",
      "timestamp": "2025-01-15T11:00:00Z",
      "type": "task_completed",
      "spec": "auth-feature",
      "task_id": "1",
      "data": {
        "description": "Implement JWT token generation",
        "duration_minutes": 45,
        "notes": "Used jose library for JWT operations"
      }
    },
    {
      "id": "entry-20250115-114500-def",
      "timestamp": "2025-01-15T11:45:00Z",
      "type": "task_blocked",
      "spec": "auth-feature",
      "task_id": "3",
      "data": {
        "description": "Implement token validation middleware",
        "blocker": "Missing crypto.subtle in test environment",
        "next_steps": "Add polyfill for Node.js test runner"
      }
    }
  ]
}

USAGE:
• Session cache: Quick lookups within active session
• Progress log: Resume context after session restart
• Both: Survives Claude Code crashes/restarts
```

### Recovery Mechanisms

```
┌─────────────────────────────────────────────────────────────────────┐
│                    RECOVERY MECHANISMS                               │
└─────────────────────────────────────────────────────────────────────┘

AUTO-RECOVERY BACKUPS:
.agent-os/state/recovery/
├── tasks-1705312800.json    (5 minutes ago)
├── tasks-1705312500.json    (10 minutes ago)
├── tasks-1705312200.json    (15 minutes ago)
├── tasks-1705311900.json    (20 minutes ago)
└── tasks-1705311600.json    (25 minutes ago)
    ↑ Oldest kept (5 versions)

CORRUPTION DETECTION:
session-start.sh hook:
├── Load tasks.json
├── Validate JSON syntax
├── Validate against schema
├── If invalid → auto-restore from recovery/
└── Log recovery action to progress.json

PARTIAL FAILURE HANDLING:
Phase 2 crashes mid-task:
├── task.status = "in_progress"
├── task.started_at = timestamp
├── Artifacts from completed subtasks preserved
├── On restart: Phase 1 detects in_progress task
├── Option: Resume from last subtask OR restart task
└── User prompted for preference
```

---

## 8. Git Integration & Branch Strategy

### Wave-Aware Branch Structure

```
┌─────────────────────────────────────────────────────────────────────┐
│                  WAVE-AWARE BRANCH STRATEGY                          │
└─────────────────────────────────────────────────────────────────────┘

main (protected)
  │
  └── feature/auth-feature (base feature branch)
        │
        ├── feature/auth-feature-wave-1
        │     └── Wave 1 tasks implemented here
        │         PR: wave-1 → feature/auth-feature
        │
        ├── feature/auth-feature-wave-2
        │     └── Wave 2 tasks implemented here
        │         Created AFTER Wave 1 PR merged
        │         PR: wave-2 → feature/auth-feature
        │
        └── feature/auth-feature-wave-3
              └── Wave 3 tasks implemented here
                  Created AFTER Wave 2 PR merged
                  PR: wave-3 → feature/auth-feature

Final PR: feature/auth-feature → main
(After all waves merged to base)

WHY THIS STRUCTURE?

Problem with simple branching:
├── Wave 1 PR open, Wave 2 work begins
├── Wave 1 PR merges → main updated
├── Wave 2 branch now conflicts with main
└── Merge conflicts in tasks.json, artifacts

Wave-aware solution:
├── Each wave: fresh branch from base
├── Wave PRs target base branch (not main)
├── Base branch accumulates all waves
├── Final PR: base → main (single clean merge)
└── No cross-wave conflicts possible
```

### Branch Setup Script

```bash
# .claude/scripts/branch-setup.sh

# Called by Phase 1 to set up wave branch
bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/branch-setup.sh" setup auth-feature 1

# Returns:
{
  "status": "success",
  "branches": {
    "base": "feature/auth-feature",
    "wave": "feature/auth-feature-wave-1",
    "current": "feature/auth-feature-wave-1"
  },
  "pr_target": "feature/auth-feature",
  "wave_number": 1,
  "is_final_wave": false
}

# What it does:
1. Check if base branch exists
   └── If not: create from main
2. Check if wave branch exists
   └── If not: create from base
3. Checkout wave branch
4. Return configuration for Phase 2
```

### Commit Workflow

```
┌─────────────────────────────────────────────────────────────────────┐
│                      COMMIT WORKFLOW                                 │
└─────────────────────────────────────────────────────────────────────┘

Phase 1: Branch Validation Gate
┌────────────────────────────────────────────────────────────────────┐
│  current_branch=$(git branch --show-current)                       │
│                                                                    │
│  if [[ "$current_branch" == "main" || "$current_branch" == "master" ]]; then
│    ⛔ BLOCKING ERROR                                                │
│    "Cannot execute tasks on protected branch: $current_branch"     │
│    "Run branch-setup.sh first"                                     │
│    EXIT 1                                                          │
│  fi                                                                │
│                                                                    │
│  ✅ Continue to Phase 2                                             │
└────────────────────────────────────────────────────────────────────┘

Phase 2: Commit After Each Subtask
┌────────────────────────────────────────────────────────────────────┐
│  # After subtask 1.1 complete:                                     │
│  git add src/auth/jwt.ts tests/auth/jwt.test.ts                    │
│  git commit -m "feat(auth): implement token payload structure"     │
│                                                                    │
│  # Pre-commit hook (pre-commit-gate.sh) runs:                      │
│  ├── npm run build (or equivalent)                                 │
│  ├── npm run typecheck (if TypeScript)                             │
│  ├── npm run test (related tests only)                             │
│  │                                                                 │
│  │   If any fail: ⛔ COMMIT REJECTED                                │
│  │   Phase 2 must fix before continuing                            │
│  │                                                                 │
│  └── ✅ Commit succeeds                                             │
│                                                                    │
│  # After subtask 1.2 complete:                                     │
│  git add ...                                                       │
│  git commit -m "feat(auth): implement token signing"               │
│  ...                                                               │
└────────────────────────────────────────────────────────────────────┘

Phase 3: PR Creation
┌────────────────────────────────────────────────────────────────────┐
│  # Verify all tests pass                                           │
│  npm test                                                          │
│  npm run build                                                     │
│                                                                    │
│  # Push to remote                                                  │
│  git push -u origin feature/auth-feature-wave-1                    │
│                                                                    │
│  # Create PR via git-workflow agent                                │
│  gh pr create \                                                    │
│    --base feature/auth-feature \                                   │
│    --title "feat(auth): Wave 1 - JWT token generation" \           │
│    --body "## Summary                                              │
│    - Implements JWT token generation per spec section 2.1          │
│    - Adds token payload structure and signing                      │
│                                                                    │
│    ## Test Coverage                                                │
│    - Unit tests for token generation                               │
│    - Integration tests for payload validation                      │
│                                                                    │
│    ## Spec Reference                                               │
│    .agent-os/specs/2025-01-15-auth-feature/spec.md"                │
└────────────────────────────────────────────────────────────────────┘
```

### Git-Workflow Agent

```
┌─────────────────────────────────────────────────────────────────────┐
│                    GIT-WORKFLOW AGENT                                │
└─────────────────────────────────────────────────────────────────────┘

Purpose: Specialized agent for all git operations

Invoked by:
├── Phase 1 (branch setup validation)
├── Phase 2 (subtask commits)
├── Phase 3 (PR creation)
└── /debug (fix commits)

Capabilities:
├── Branch creation and checkout
├── Staging and committing with conventional commits
├── Conflict detection and resolution guidance
├── PR creation with comprehensive descriptions
├── Status checking and remote sync

Example invocation from Phase 3:
┌────────────────────────────────────────────────────────────────────┐
│  Task tool:                                                        │
│    subagent_type: git-workflow                                     │
│    prompt: |                                                       │
│      Create PR for wave 1 completion:                              │
│      - Base branch: feature/auth-feature                           │
│      - Current branch: feature/auth-feature-wave-1                 │
│      - Completed tasks: 1, 2                                       │
│      - Spec: auth-feature                                          │
│      - All tests passing: true                                     │
│                                                                    │
│      Include in PR body:                                           │
│      - Summary of changes                                          │
│      - Test coverage status                                        │
│      - Link to spec                                                │
└────────────────────────────────────────────────────────────────────┘
```

---

## 9. Hooks: Deterministic Validation

### Why Hooks Instead of Skills

```
┌─────────────────────────────────────────────────────────────────────┐
│                 HOOKS VS SKILLS COMPARISON                           │
└─────────────────────────────────────────────────────────────────────┘

SKILLS (v2.x approach):
├── Invoked by: Model decides to call them
├── Problem: Model can "forget" or choose not to call
├── Example: "Validate before commit" skill might be skipped
└── Result: Inconsistent validation, bugs slip through

HOOKS (v3.0+ approach):
├── Invoked by: Claude Code runtime (deterministic)
├── Trigger: Specific events (file change, commit, session start)
├── Cannot be skipped: Shell script executes regardless of model
└── Result: Guaranteed validation, consistent behavior

┌────────────────────────────────────────────────────────────────────┐
│                                                                    │
│   Model says: "I'll commit this code"                              │
│                     │                                              │
│                     ▼                                              │
│   Claude Code: Detects git commit command                          │
│                     │                                              │
│                     ▼                                              │
│   Hook system: Runs pre-commit-gate.sh BEFORE commit               │
│                     │                                              │
│         ┌───────────┴───────────┐                                  │
│         ▼                       ▼                                  │
│   Tests pass?              Tests fail?                             │
│         │                       │                                  │
│         ▼                       ▼                                  │
│   Commit proceeds        ⛔ Commit BLOCKED                          │
│                          Error shown to model                      │
│                          Model must fix before retry               │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘

KEY INSIGHT: The model cannot bypass the hook.
Even if it "forgets" to validate, the hook runs anyway.
```

### Hook Configuration

```json
// .claude/settings.json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash(git commit*)",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PROJECT_DIR}/.claude/hooks/pre-commit-gate.sh\""
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PROJECT_DIR}/.claude/hooks/post-file-change.sh\" \"$TOOL_INPUT_PATH\""
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "type": "command",
        "command": "bash \"${CLAUDE_PROJECT_DIR}/.claude/hooks/session-start.sh\""
      }
    ],
    "SessionEnd": [
      {
        "type": "command",
        "command": "bash \"${CLAUDE_PROJECT_DIR}/.claude/hooks/session-end.sh\""
      }
    ]
  }
}
```

### Hook Reference

| Hook | Trigger | Purpose | Blocking? |
|------|---------|---------|-----------|
| `session-start.sh` | Session begins | Load context, set `CLAUDE_PROJECT_DIR` env var | No |
| `session-end.sh` | Session ends | Log progress, cleanup temp files | No |
| `post-file-change.sh` | After Write/Edit to tasks.json | Regenerate tasks.md, auto-promote future_tasks | No |
| `pre-commit-gate.sh` | Before `git commit` | Validate build, types, tests | **Yes** |

### Pre-Commit Gate Deep Dive

```bash
#!/bin/bash
# .claude/hooks/pre-commit-gate.sh

set -e  # Exit on any error

echo "🔍 Pre-commit validation starting..."

# Step 1: Check for staged changes
if ! git diff --cached --quiet; then

    # Step 2: Run build
    echo "📦 Running build..."
    if ! npm run build; then
        echo "❌ Build failed. Commit blocked."
        exit 1
    fi

    # Step 3: Run type check (if TypeScript)
    if [ -f "tsconfig.json" ]; then
        echo "🔷 Running type check..."
        if ! npm run typecheck; then
            echo "❌ Type check failed. Commit blocked."
            exit 1
        fi
    fi

    # Step 4: Run tests
    echo "🧪 Running tests..."
    if ! npm test; then
        echo "❌ Tests failed. Commit blocked."
        exit 1
    fi

    # Step 5: Check tasks.json validity (if exists)
    TASKS_FILE=$(find .agent-os/specs -name "tasks.json" 2>/dev/null | head -1)
    if [ -n "$TASKS_FILE" ]; then
        echo "📋 Validating tasks.json..."
        if ! jq empty "$TASKS_FILE" 2>/dev/null; then
            echo "❌ tasks.json is invalid JSON. Commit blocked."
            exit 1
        fi

        # Check for orphaned future_tasks (warning only)
        FUTURE_COUNT=$(jq '.future_tasks | length' "$TASKS_FILE")
        if [ "$FUTURE_COUNT" -gt 0 ]; then
            echo "⚠️  Warning: $FUTURE_COUNT future_tasks not yet triaged"
        fi
    fi

    echo "✅ All validations passed. Commit proceeding."
else
    echo "ℹ️  No staged changes to validate."
fi

exit 0
```

### Future Tasks Auto-Promotion (v4.5.0)

```
┌─────────────────────────────────────────────────────────────────────┐
│              FUTURE TASKS AUTO-PROMOTION FLOW                        │
└─────────────────────────────────────────────────────────────────────┘

PR Review captures deferred items:
┌────────────────────────────────────────────────────────────────────┐
│  tasks.json:                                                       │
│  {                                                                 │
│    "future_tasks": [                                               │
│      {                                                             │
│        "id": "ft-001",                                             │
│        "type": "ROADMAP_ITEM",                                     │
│        "description": "Add OAuth2 support",                        │
│        "source": "PR #42 review comment"                           │
│      },                                                            │
│      {                                                             │
│        "id": "ft-002",                                             │
│        "type": "WAVE_TASK",                                        │
│        "description": "Add rate limiting to auth endpoints",       │
│        "target_wave": 2,                                           │
│        "needs_subtask_expansion": true                             │
│      }                                                             │
│    ]                                                               │
│  }                                                                 │
└────────────────────────────────────────────────────────────────────┘
                            │
                            ▼
post-file-change.sh hook triggers auto-promotion:
┌────────────────────────────────────────────────────────────────────┐
│                                                                    │
│  For type: "ROADMAP_ITEM"                                          │
│  ──────────────────────────                                        │
│  → Append to .agent-os/product/roadmap.md                          │
│  → Remove from future_tasks                                        │
│                                                                    │
│  For type: "WAVE_TASK"                                             │
│  ─────────────────────                                             │
│  → Add to tasks array with:                                        │
│    • status: "pending"                                             │
│    • wave: target_wave                                             │
│    • needs_subtask_expansion: true                                 │
│  → Remove from future_tasks                                        │
│  → Subtasks generated on next /execute-tasks run                   │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘

Result: No orphaned backlog items
• ROADMAP_ITEM → lives in roadmap.md (product backlog)
• WAVE_TASK → becomes real task (implementation backlog)
• Both tracked, neither lost
```

---

## 10. Practical Examples

### Example 1: Simple Feature Implementation

```
USER: I want to add a "forgot password" feature to our auth system.

WORKFLOW:

1. /create-spec
   └── Creates: .agent-os/specs/2025-01-15-forgot-password/spec.md
       • Describes email flow, token generation, password reset
       • Defines API endpoints, UI components
       • Lists test scenarios

2. /create-tasks
   └── Creates: tasks.json with:
       Task 1: Implement password reset token generation
       Task 2: Create password reset email sender
       Task 3: Build password reset form component
       Task 4: Implement reset password API endpoint

       Waves: [[1, 2], [3, 4]]  (1&2 parallel, then 3&4 parallel)

3. /execute-tasks
   └── Phase 1: Sets up branch, selects tasks
   └── Phase 2 (Wave 1):
       • Task 1 & 2 execute in parallel
       • TDD for each: test → implement → refactor
       • Commits after each subtask
   └── Phase 2 (Wave 2):
       • Task 3 & 4 execute in parallel
       • Receive verified artifacts from Wave 1
   └── Phase 3: Run full tests, create PR

4. PR merged → Feature complete!
```

### Example 2: Handling a Large Complex Feature

```
USER: Implement a complete multi-tenant system with tenant isolation,
      billing integration, and admin dashboard.

WORKFLOW:

1. /create-spec (may take 30+ minutes of refinement)
   └── Large spec covering all aspects

2. /create-tasks
   └── Generates 15 tasks across 5 waves:
       Wave 1: [Core tenant model, Database schema]
       Wave 2: [Tenant context middleware, Data isolation layer]
       Wave 3: [Billing models, Stripe integration]
       Wave 4: [Admin API endpoints, Dashboard components]
       Wave 5: [Integration tests, Documentation]

3. /execute-tasks
   └── Context efficiency kicks in:
       • Each wave: fresh context
       • Each task: isolated Phase 2 agent
       • Artifacts verified between waves
       • Total context never exceeds 30K tokens

   └── If blocker found:
       • Task marked blocked
       • Progress logged
       • User prompted for resolution
       • Can continue with independent tasks

4. Multiple PRs created (one per wave or aggregate)
```

### Example 3: PR Review Feedback Loop

```
USER: Got feedback on my auth PR, please handle it.

WORKFLOW:

1. /pr-review-cycle
   └── Reads PR comments
   └── Classifies each comment:
       • FIX_NOW: Add to current wave
       • FUTURE_TASK: Add to future_tasks
       • QUESTION: Prompt user for response
       • NITPICK: Apply if trivial

2. For FIX_NOW items:
   └── Creates tasks for fixes
   └── Runs Phase 2 for each fix
   └── Commits and pushes

3. For FUTURE_TASK items:
   └── Added to future_tasks in tasks.json
   └── Hook auto-promotes:
       • ROADMAP_ITEM → roadmap.md
       • WAVE_TASK → next wave

4. PR updated with fixes
   └── User reviews and merges
```

---

## Summary: Agent OS Key Innovations

```
┌─────────────────────────────────────────────────────────────────────┐
│                     KEY ARCHITECTURAL INNOVATIONS                    │
└─────────────────────────────────────────────────────────────────────┘

1. DETERMINISTIC VALIDATION
   Problem: Model-invoked checks can be skipped
   Solution: Shell hooks execute unconditionally
   Result: Guaranteed validation before every commit

2. CONTEXT ISOLATION
   Problem: Large features overflow context
   Solution: Phase/wave/worker isolation, verified artifact passing
   Result: Unlimited feature complexity without context degradation

3. SINGLE SOURCE OF TRUTH
   Problem: Multiple state files drift out of sync
   Solution: JSON source + auto-generated views via hooks
   Result: Zero sync bugs, easy human editing

4. ARTIFACT VERIFICATION
   Problem: Agent claims exports that don't exist (hallucination)
   Solution: Grep-verify all artifacts before passing to next wave
   Result: System-level hallucination prevention

5. WAVE-AWARE GIT
   Problem: Parallel work causes merge conflicts
   Solution: Wave-specific branches, incremental PRs to base
   Result: Clean parallel execution without conflicts

6. RECOVERY BY DEFAULT
   Problem: Crashes lose progress
   Solution: Atomic writes, auto-backups, cross-session progress log
   Result: Resume from any failure point

7. FUTURE TASK LIFECYCLE
   Problem: PR feedback items get lost
   Solution: Auto-promotion hooks graduate items to roadmap/waves
   Result: Zero orphaned backlog items
```

---

## Further Reading

- **SYSTEM-OVERVIEW.md**: Comprehensive technical documentation
- **CHANGELOG.md**: Version history and migration guides
- **v3/commands/**: Command source files
- **v3/agents/**: Agent definitions
- **v3/hooks/**: Hook implementations
- **https://buildermethods.com/agent-os**: Official documentation site

---

*This guide reflects Agent OS v4.5.0. For the latest updates, check CHANGELOG.md.*
