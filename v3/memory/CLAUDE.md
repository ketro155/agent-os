# Agent OS v3.0 - Core Memory

> This file is automatically loaded by Claude Code at session start.
> It replaces embedded instructions in commands with native memory hierarchy.

## Agent OS Overview

Agent OS is a development framework providing structured AI-assisted workflows. Version 3.0 uses Claude Code's native features:

- **Hooks** for deterministic validation (cannot be skipped)
- **Memory hierarchy** for instructions (this file + rules/)
- **Native subagents** for phase-based execution
- **Single-source tasks** (JSON primary, MD auto-generated)

## Core Workflows

### Feature Development Pipeline

```
/plan-product    → Initialize product with mission/vision/roadmap
/analyze-product → Set up Agent OS for existing codebase
/shape-spec      → Explore and refine feature concepts
/create-spec     → Create detailed feature specification
/create-tasks    → Generate task breakdown with parallelization analysis
/execute-tasks   → Implement with TDD workflow
```

### Task Execution Philosophy

1. **Single-task focus** is strongly recommended (research-backed)
2. **TDD is mandatory**: RED → GREEN → REFACTOR
3. **Validation gates cannot be skipped** (enforced by hooks)
4. **Artifacts are auto-collected** after task completion

## Key Conventions

### Task Format (v3.0)

- `tasks.json` is the **source of truth**
- `tasks.md` is **auto-generated** (read-only)
- Edit tasks via commands or direct JSON editing
- Hooks auto-regenerate markdown on JSON changes

### Git Workflow

- Feature branches: `feature/SPEC-NAME-brief-description`
- Commit after each completed subtask
- PR created automatically in Phase 3
- Pre-commit hooks validate build/tests/types

### Standards Location

```
.agent-os/standards/
├── global/      # Cross-cutting (coding-style, conventions, error-handling)
├── frontend/    # UI patterns (react-patterns, styling)
├── backend/     # Server patterns (api-design, database)
└── testing/     # Test patterns
```

## Hooks (Automatic)

These run automatically - you don't need to invoke them:

| Hook | Trigger | Purpose |
|------|---------|---------|
| SessionStart | Session begins | Load progress context, set up state |
| SessionEnd | Session ends | Log progress, create checkpoint |
| PostToolUse (Write/Edit) | File changes | Regenerate tasks.md from JSON |
| PreToolUse (git commit) | Before commits | Validate build, tests, types |

## Subagents Available

Use `Task` tool to invoke these specialized agents:

| Agent | Purpose | When to Use |
|-------|---------|-------------|
| phase0-startup | Session initialization | Start of execute-tasks |
| phase1-discovery | Task discovery & mode selection | After Phase 0 |
| phase2-implementation | TDD implementation | For each task |
| phase3-delivery | Completion & PR workflow | After all tasks done |
| git-workflow | Branch, commit, PR operations | Called by phases |

## Important: Extended Thinking

For complex planning tasks (/create-spec, /shape-spec), extended thinking is available:

```
When facing complex architectural decisions:
1. Consider multiple approaches
2. Analyze trade-offs thoroughly
3. Document reasoning in spec
```

## Progress Log

Cross-session memory is maintained in `.agent-os/progress/progress.json`:

- Automatically updated by hooks
- Contains: session events, task completions, blockers
- Git-tracked for team visibility

## Quick Reference

### Check Task Status
```bash
jq '.summary' .agent-os/tasks/*/tasks.json
```

### View Recent Progress
```bash
jq '.entries[-5:]' .agent-os/progress/progress.json
```

### Manual Task Regeneration
```bash
node .claude/scripts/json-to-markdown.js .agent-os/tasks/*/tasks.json
```

---

@import rules/tdd-workflow.md
@import rules/git-conventions.md
