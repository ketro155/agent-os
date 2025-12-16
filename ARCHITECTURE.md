# Agent OS Architecture Guide

> A comprehensive guide to understanding, designing, and building applications with Agent OS

## Table of Contents

- [Philosophy & Approach](#philosophy--approach)
- [Core Concepts](#core-concepts)
- [Workflow Pipeline](#workflow-pipeline)
- [Component Architecture](#component-architecture)
- [State Management](#state-management)
- [Design Patterns](#design-patterns)
- [Adoption Guide](#adoption-guide)
- [Architecture Decisions](#architecture-decisions)

---

## Philosophy & Approach

### The Problem

AI-assisted development often fails because:

1. **Unreliable Instruction Following**: AI doesn't consistently follow external documentation references
2. **Context Loss**: Long sessions lose track of goals and progress
3. **Unstructured Output**: Code quality varies without systematic processes
4. **No State Persistence**: AI forgets what happened in previous sessions
5. **Lack of Verification**: No systematic way to verify implementation correctness

### The Solution: Spec-Driven Development

Agent OS implements a **spec-driven development** approach where:

```
Specification → Tasks → Implementation → Verification
```

Every feature begins with a clear specification, gets broken into atomic tasks, implemented with TDD, and verified against the original spec.

### Core Principles

| Principle | Description |
|-----------|-------------|
| **Embedded Instructions** | All critical instructions embedded directly in files (99% reliability vs 60% with external refs) |
| **Single Source of Truth** | `tasks.json` is authoritative; derived files auto-generated |
| **Deterministic Gates** | Hooks that ALWAYS run, cannot be skipped |
| **Progressive Disclosure** | Load only needed context per phase/task |
| **Atomic State Operations** | Write to temp file, then atomic rename |
| **TDD-First** | Every task implements RED → GREEN → REFACTOR |

---

## Core Concepts

### 1. Commands

Commands are self-contained workflow definitions that orchestrate complex tasks. Each command file (~100-550 lines) contains:

```markdown
# Command Structure

## Quick Navigation
[Links to sections]

## Description
What this command does

## Parameters
Required and optional inputs

## Dependencies
State files needed

## Core Instructions
Complete embedded workflow (the key innovation)

## State Management
How state is saved/loaded

## Error Handling
Recovery patterns
```

**Why Embedded Instructions?**

```
External Reference Approach:
  Command: "Follow instructions in /docs/workflow.md"
  Result: 60% success rate - AI often ignores or misinterprets

Embedded Approach:
  Command: Contains all 50 steps directly
  Result: 99% success rate - AI executes each step
```

### 2. Phases

Complex workflows split into **phases** with different optimization profiles:

| Phase | Model | Tools | Duration | Purpose |
|-------|-------|-------|----------|---------|
| **Discovery** | Haiku (fast) | Read-only | <30s | Understand task scope |
| **Implementation** | Sonnet (capable) | Full edit | Variable | Build the feature |
| **Delivery** | Sonnet | Git, Test | 5-15min | Ship and verify |

**Phase Isolation Benefits:**
- Each phase loads only its needed context
- Faster phases use cheaper/faster models
- Failures isolated to single phase
- Clear handoff points for debugging

### 3. Subagents

Subagents are **specialized workers** with tool restrictions:

```yaml
# Phase 2 Implementation Agent
model: sonnet
tools: [Read, Edit, Write, Bash, Grep, Glob, TodoWrite]
responsibility: TDD implementation of tasks
```

**Tool Restriction Benefits:**
- Prevents scope creep (Discovery can't edit files)
- Reduces error surface area
- Clear separation of concerns
- Enables parallel execution

### 4. Skills

Skills are **model-invoked capabilities** that auto-trigger based on context:

```yaml
---
name: build-check
description: "Verify build passes before commits. Auto-invoke before any git commit."
allowed-tools: Bash, Read, Grep
---

# Build Check Skill

When invoked, this skill:
1. Runs the build command
2. Classifies any errors
3. Blocks commit if build fails
4. Suggests fixes for common issues
```

**Skill vs Command:**
- **Command**: User-invoked (`/execute-tasks`)
- **Skill**: Model-invoked automatically based on description

### 5. Hooks (v3.0+)

Hooks are **deterministic shell scripts** that ALWAYS execute:

```bash
# .claude/hooks/pre-commit-gate.sh
# ALWAYS runs before any commit - cannot be skipped

current_branch=$(git branch --show-current)
if [[ "$current_branch" == "main" || "$current_branch" == "master" ]]; then
    echo "ERROR: Cannot commit directly to $current_branch"
    exit 1
fi
```

**Hook vs Skill:**
- **Hook**: Deterministic, always runs, shell-based
- **Skill**: Probabilistic, model decides when to invoke

---

## Workflow Pipeline

### Standard Feature Development

```
┌─────────────────────────────────────────────────────────────────┐
│                    FEATURE DEVELOPMENT PIPELINE                  │
└─────────────────────────────────────────────────────────────────┘

┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│ /plan-product│    │ /shape-spec  │    │ /create-spec │
│              │───►│              │───►│              │
│ Mission &    │    │ Explore      │    │ Full spec    │
│ Roadmap      │    │ feasibility  │    │ documents    │
└──────────────┘    └──────────────┘    └──────────────┘
                                               │
                                               ▼
┌──────────────┐    ┌──────────────────────────────────┐
│ /execute-    │    │ /create-tasks                    │
│ tasks        │◄───│                                  │
│              │    │ tasks.md + tasks.json +          │
│ Implement    │    │ context-summary.json             │
│ with TDD     │    └──────────────────────────────────┘
└──────────────┘
       │
       ▼
┌──────────────────────────────────────────────────────┐
│                 PHASE EXECUTION                       │
├──────────────┬──────────────┬───────────────────────┤
│   Phase 1    │   Phase 2    │       Phase 3         │
│   Discovery  │   Implement  │       Delivery        │
│   (Haiku)    │   (Sonnet)   │       (Sonnet)        │
│              │              │                       │
│ • Load tasks │ • TDD cycle  │ • Run all tests       │
│ • Check git  │ • Per task:  │ • Create PR           │
│ • Plan mode  │   RED-GREEN  │ • Update roadmap      │
│              │   REFACTOR   │ • Notify complete     │
└──────────────┴──────────────┴───────────────────────┘
```

### Phase Execution Detail

```
EXECUTE-TASKS ORCHESTRATOR
│
├─► PHASE 1: Discovery
│   │
│   ├── Step 0: MANDATORY Git Branch Gate ⚠️
│   │   └── BLOCK if on main/master
│   │
│   ├── Step 1: Load tasks.json
│   │
│   ├── Step 2: Analyze dependencies
│   │
│   └── Step 3: Select execution mode
│       ├── direct_single (1 task)
│       ├── parallel_waves (independent tasks)
│       └── orchestrated_sequential (dependent tasks)
│
├─► PHASE 2: Implementation (per task)
│   │
│   ├── Defense-in-depth branch validation
│   │
│   ├── Load pre-computed context
│   │
│   ├── TDD Cycle:
│   │   ├── RED: Write failing test
│   │   ├── GREEN: Minimal implementation
│   │   └── REFACTOR: Clean up
│   │
│   ├── Record artifacts (files, exports)
│   │
│   └── Commit changes
│
└─► PHASE 3: Delivery
    │
    ├── Run full test suite
    │
    ├── Verify spec compliance
    │
    ├── Push and create PR
    │
    └── Update project documentation
```

### Execution Modes

```
┌─────────────────────────────────────────────────────────────────┐
│                      EXECUTION MODES                             │
└─────────────────────────────────────────────────────────────────┘

MODE 1: Direct Single-Task (DEFAULT)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• 1 task in current session
• Simplest, most reliable
• Full context available

    [Orchestrator] ──► [Task 1] ──► [Done]


MODE 2: Parallel Waves (RECOMMENDED for 2+ independent tasks)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Groups independent tasks into waves
• 1.5-3x speedup

    Wave 1:  [Task A] ─┬─► [Collect Results]
             [Task B] ─┤        │
             [Task C] ─┘        ▼
    Wave 2:              [Task D] ─► [Task E] ─► [Done]


MODE 3: Orchestrated Sequential
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Tasks with dependencies
• Respects blocking relationships

    [Task 1] ──► [Task 2] ──► [Task 3] ──► [Done]
         │           │
         └─depends───┘
```

---

## Component Architecture

### Directory Structure

```
project/
├── .claude/                    # Claude Code configuration
│   ├── CLAUDE.md              # Core instructions (auto-loaded)
│   ├── settings.json          # Hook configuration
│   │
│   ├── commands/              # User-invoked workflows
│   │   ├── plan-product.md
│   │   ├── shape-spec.md
│   │   ├── create-spec.md
│   │   ├── create-tasks.md
│   │   ├── execute-tasks.md
│   │   ├── debug.md
│   │   └── pr-review-cycle.md
│   │
│   ├── agents/                # Specialized subagents
│   │   ├── phase1-discovery.md
│   │   ├── phase2-implementation.md
│   │   ├── phase3-delivery.md
│   │   └── git-workflow.md
│   │
│   ├── hooks/                 # Deterministic hooks
│   │   ├── session-start.sh
│   │   ├── session-end.sh
│   │   ├── post-file-change.sh
│   │   └── pre-commit-gate.sh
│   │
│   ├── skills/                # Model-invoked capabilities
│   │   └── [skill-name].md
│   │
│   ├── scripts/               # Shell utilities
│   │   ├── task-operations.sh
│   │   └── json-to-markdown.js
│   │
│   └── rules/                 # Path-specific rules
│       └── [pattern].md
│
├── .agent-os/                  # Agent OS state & config
│   ├── product/               # Product definition
│   │   ├── mission.md
│   │   ├── mission-lite.md
│   │   ├── tech-stack.md
│   │   └── roadmap.md
│   │
│   ├── specs/                 # Feature specifications
│   │   ├── shaped/            # Exploration specs
│   │   └── [feature]/         # Full feature specs
│   │       ├── spec.md
│   │       ├── spec-lite.md
│   │       ├── tasks.md       # Human-readable
│   │       ├── tasks.json     # SOURCE OF TRUTH
│   │       └── context-summary.json
│   │
│   ├── state/                 # Runtime state
│   │   ├── session.json
│   │   ├── session-cache.json
│   │   ├── workflow.json
│   │   ├── recovery/          # Backups
│   │   └── checkpoints/       # Save points
│   │
│   ├── progress/              # Permanent memory
│   │   ├── progress.json
│   │   ├── progress.md        # Auto-generated
│   │   └── archive/           # Old entries
│   │
│   ├── standards/             # Development standards
│   │   ├── global/
│   │   ├── frontend/
│   │   ├── backend/
│   │   └── testing/
│   │
│   └── schemas/               # Validation schemas
│       └── tasks-v3.json
│
└── [project files...]
```

### Component Interactions

```
┌─────────────────────────────────────────────────────────────────┐
│                    COMPONENT INTERACTION MAP                     │
└─────────────────────────────────────────────────────────────────┘

                         USER INPUT
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        COMMAND LAYER                             │
│  /plan-product  /create-spec  /create-tasks  /execute-tasks     │
└─────────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┼───────────────┐
              │               │               │
              ▼               ▼               ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│   SUBAGENTS     │  │    SKILLS       │  │     HOOKS       │
│                 │  │                 │  │                 │
│ • Discovery     │  │ • build-check   │  │ • pre-commit    │
│ • Implementation│  │ • test-check    │  │ • session-start │
│ • Delivery      │  │ • tdd           │  │ • file-change   │
│ • Git workflow  │  │ • codebase-names│  │ • session-end   │
└────────┬────────┘  └────────┬────────┘  └────────┬────────┘
         │                    │                    │
         └────────────────────┼────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        STATE LAYER                               │
├─────────────────┬─────────────────┬─────────────────────────────┤
│ Session Cache   │ Progress Log    │ Task State (tasks.json)     │
│ (5min TTL)      │ (permanent)     │ (source of truth)           │
└─────────────────┴─────────────────┴─────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        FILE SYSTEM                               │
│  .agent-os/state/  .agent-os/progress/  .agent-os/specs/        │
└─────────────────────────────────────────────────────────────────┘
```

---

## State Management

### Two-Tier Memory Architecture

Agent OS uses complementary memory systems:

```
┌─────────────────────────────────────────────────────────────────┐
│                    MEMORY ARCHITECTURE                           │
└─────────────────────────────────────────────────────────────────┘

SESSION CACHE (Short-Term)          PROGRESS LOG (Long-Term)
━━━━━━━━━━━━━━━━━━━━━━━━━          ━━━━━━━━━━━━━━━━━━━━━━━━
Location: state/session-cache.json  Location: progress/progress.json
Lifespan: 5 minutes (auto-extend)   Lifespan: Never expires
Git: .gitignore (not tracked)       Git: Tracked (version controlled)
Purpose: Performance optimization   Purpose: Cross-session continuity

Contents:                           Contents:
• Spec file locations               • Completed tasks
• Context cache                     • Blockers encountered
• Test result cache                 • Session summaries
• File path cache                   • Decision rationale
```

### When to Use Which

| Question | Answer From |
|----------|-------------|
| "Where is the auth spec?" | Session Cache |
| "What tests passed recently?" | Session Cache |
| "What did we accomplish yesterday?" | **Progress Log** |
| "Why was Task 1.2 blocked?" | **Progress Log** |
| "What's the next step to resume?" | **Progress Log** |

### Atomic Write Pattern

All state operations use this pattern:

```javascript
async function atomicWrite(filepath, data) {
  // 1. Create recovery backup
  const backup = `${filepath}.backup.${Date.now()}`;
  await fs.copyFile(filepath, backup);

  // 2. Validate data schema
  validateSchema(data);

  // 3. Write to temp file
  const temp = `${filepath}.tmp`;
  await fs.writeFile(temp, JSON.stringify(data, null, 2));

  // 4. Atomic rename (cannot be interrupted mid-write)
  await fs.rename(temp, filepath);

  // 5. Cleanup old backups (keep last 5)
  await cleanOldBackups(filepath);
}
```

### Task State (Source of Truth)

```json
// .agent-os/specs/[feature]/tasks.json
{
  "version": "3.0",
  "spec_name": "user-authentication",
  "tasks": [
    {
      "id": "1",
      "title": "Create user model",
      "description": "Define User schema with validation",
      "status": "completed",
      "dependencies": [],
      "artifacts": {
        "files_created": ["src/models/User.ts"],
        "exports": ["User", "UserSchema"]
      }
    },
    {
      "id": "2",
      "title": "Implement login endpoint",
      "status": "in_progress",
      "dependencies": ["1"],
      "context": {
        "relevant_files": ["src/models/User.ts"],
        "test_patterns": ["src/**/*.test.ts"]
      }
    }
  ]
}
```

---

## Design Patterns

### 1. Embedded Instructions Pattern

**Problem**: AI doesn't reliably follow external documentation

**Solution**: Embed all instructions directly in command files

```markdown
# command.md

## Core Instructions

### Step 1: Initialize
1. Create todo list with workflow steps
2. Validate required parameters exist
3. Check for dependency files

### Step 2: Execute
[Complete instructions here - not "see docs/workflow.md"]

### Step 3: Verify
[Complete verification steps]
```

**Result**: 99% reliability vs 60% with external references

### 2. Progressive Context Loading

**Problem**: Large context windows slow processing and increase costs

**Solution**: Load only what's needed per phase

```javascript
// Phase 1: Minimal context
const discovery_context = {
  task_list: await read('tasks.json'),
  git_status: await exec('git status')
};

// Phase 2: Task-specific context
const implementation_context = {
  task: current_task,
  relevant_files: task.context.relevant_files,
  test_patterns: task.context.test_patterns
  // NOT: entire codebase
};
```

**Result**: 50-60% faster, 73% token reduction per task

### 3. Two-Gate Validation

**Problem**: Single validation points can be bypassed

**Solution**: Defense-in-depth with multiple gates

```
PHASE 1 ─────────────────────────── PHASE 2
    │                                   │
    ▼                                   ▼
┌─────────┐                       ┌─────────┐
│ Gate 1  │                       │ Gate 2  │
│ Check   │                       │ Check   │
│ branch  │                       │ branch  │
│ (early  │                       │ (before │
│ fail)   │                       │ edit)   │
└─────────┘                       └─────────┘
    │                                   │
    │ PASS                              │ PASS
    ▼                                   ▼
  Continue                           Continue
```

### 4. TDD-First Implementation

**Problem**: AI tends to write implementation first, tests as afterthought

**Solution**: Enforce RED-GREEN-REFACTOR cycle

```
┌─────────────────────────────────────────┐
│           TDD CYCLE (Mandatory)          │
└─────────────────────────────────────────┘

    ┌───────────────┐
    │               │
    │   RED         │ Write failing test FIRST
    │   (test)      │ Test must fail to prove it tests something
    │               │
    └───────┬───────┘
            │
            ▼
    ┌───────────────┐
    │               │
    │   GREEN       │ Write MINIMAL code to pass
    │   (code)      │ No extra features, just pass test
    │               │
    └───────┬───────┘
            │
            ▼
    ┌───────────────┐
    │               │
    │   REFACTOR    │ Clean up without changing behavior
    │   (improve)   │ Tests still pass after refactor
    │               │
    └───────┬───────┘
            │
            └────► Next test case
```

### 5. Artifact Recording

**Problem**: Need to track what each task produces for cross-task reference

**Solution**: Record artifacts in task state

```json
{
  "id": "3",
  "title": "Create AuthService",
  "status": "completed",
  "artifacts": {
    "files_created": [
      "src/services/AuthService.ts",
      "src/services/AuthService.test.ts"
    ],
    "files_modified": [
      "src/services/index.ts"
    ],
    "exports": [
      "AuthService",
      "authenticate",
      "validateToken"
    ],
    "test_coverage": {
      "statements": 94,
      "branches": 88
    }
  }
}
```

### 6. Wave-Based Parallelization

**Problem**: Sequential task execution is slow for independent tasks

**Solution**: Analyze dependencies, group into parallel waves

```javascript
// Dependency analysis
const tasks = [
  { id: 1, deps: [] },      // Wave 1
  { id: 2, deps: [] },      // Wave 1
  { id: 3, deps: [] },      // Wave 1
  { id: 4, deps: [1, 2] },  // Wave 2 (waits for 1, 2)
  { id: 5, deps: [3] },     // Wave 2 (waits for 3)
  { id: 6, deps: [4, 5] }   // Wave 3 (waits for 4, 5)
];

// Execution
Wave 1: [1, 2, 3] run in parallel
Wave 2: [4, 5] run in parallel after Wave 1
Wave 3: [6] runs after Wave 2

// Result: 3 sequential steps instead of 6
```

---

## Adoption Guide

### For New Projects

1. **Initialize Agent OS**
   ```bash
   ./setup/project.sh --claude-code
   ```

2. **Create Product Definition**
   ```
   /plan-product
   ```
   This creates `.agent-os/product/` with mission, tech-stack, roadmap.

3. **Develop Features**
   ```
   /shape-spec → /create-spec → /create-tasks → /execute-tasks
   ```

### For Existing Projects

1. **Analyze Codebase**
   ```
   /analyze-product
   ```
   Creates product definition from existing code.

2. **Create Feature Branch**
   ```bash
   git checkout -b feature/my-feature
   ```

3. **Follow Standard Pipeline**
   ```
   /create-spec → /create-tasks → /execute-tasks
   ```

### Customization Points

| Component | Customization Method |
|-----------|---------------------|
| Commands | Create `.claude/commands/my-command.md` |
| Skills | Create `.claude/skills/my-skill.md` with YAML frontmatter |
| Hooks | Add scripts to `.claude/hooks/` and register in `settings.json` |
| Standards | Add to `.agent-os/standards/` |
| Rules | Create `.claude/rules/[path-pattern].md` |

### Skill Creation Template

```yaml
---
name: my-skill
description: "What this skill does. Auto-invoke when [trigger condition]."
allowed-tools: Read, Grep, Write
---

# My Skill

## When to Use
[Trigger conditions]

## Steps
1. [Step 1]
2. [Step 2]
3. [Step 3]

## Output
[What this skill produces]
```

### Hook Registration

```json
// .claude/settings.json
{
  "hooks": {
    "pre-commit": {
      "command": ".claude/hooks/my-hook.sh",
      "enabled": true
    }
  }
}
```

---

## Architecture Decisions

### ADR-001: Embedded vs Referenced Instructions

**Context**: Claude Code doesn't reliably follow external documentation references.

**Decision**: Embed all critical instructions directly in command files.

**Consequences**:
- Larger command files (100-550 lines)
- Duplication between commands
- 99% execution reliability
- Self-contained, portable commands

### ADR-002: tasks.json as Source of Truth

**Context**: Need single authoritative source for task state.

**Decision**: `tasks.json` is source of truth; `tasks.md` auto-generated.

**Consequences**:
- Machine-readable state
- Easy programmatic updates
- Human-readable view always in sync
- Schema validation possible

### ADR-003: Two-Tier Memory

**Context**: Need both fast caching and persistent memory.

**Decision**: Session cache (ephemeral) + Progress log (permanent).

**Consequences**:
- Session cache: fast, disposable, not git-tracked
- Progress log: permanent, git-tracked, team-visible
- Clear separation of concerns
- No single point of failure

### ADR-004: Phase-Based Architecture

**Context**: Different tasks need different capabilities and speed.

**Decision**: Split execution into phases with different models/tools.

**Consequences**:
- Discovery: fast model, read-only
- Implementation: capable model, full tools
- Delivery: capable model, git tools
- Cost optimization
- Clear isolation

### ADR-005: Deterministic Hooks over Probabilistic Skills

**Context**: Some validations MUST run, cannot be skipped.

**Decision**: Use shell hooks for critical gates, skills for optional enhancements.

**Consequences**:
- Hooks always execute (deterministic)
- Skills may or may not trigger (probabilistic)
- Git protection guaranteed
- Build checks enforced

---

## Summary

Agent OS provides a **structured, reliable approach** to AI-assisted development through:

| Feature | Benefit |
|---------|---------|
| Embedded Instructions | 99% reliable execution |
| Spec-Driven Development | Clear requirements → implementation |
| Phase Architecture | Optimized cost and speed |
| TDD Enforcement | Quality code output |
| Two-Tier Memory | Session performance + cross-session continuity |
| Deterministic Hooks | Critical validations never skipped |
| Wave Parallelization | 1.5-3x speedup for independent tasks |
| Artifact Recording | Cross-task reference without manual indexing |

The architecture represents evolved patterns from extensive AI-assisted development experience, designed for maximum reliability and efficiency.
