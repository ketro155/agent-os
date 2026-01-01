# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Agent OS is a development framework that installs into other projects to provide structured AI-assisted software development workflows. It uses native Claude Code hooks for mandatory validation and single-source JSON tasks.

**Critical**: This is the Agent OS **source repository**. Changes here affect all projects that install Agent OS via `./setup/project.sh`. Files in `v3/` are templates that get copied to target projects during installation.

## Development Commands

```bash
# Test installation in a separate test project
./setup/project.sh --claude-code --target /path/to/test-project
./setup/project.sh --claude-code --upgrade --target /path/to/existing-project
```

**Workflow**: Make changes in `v3/` → Test in separate project → Update SYSTEM-OVERVIEW.md → Update CHANGELOG.md → Commit

## Core Architecture

### Feature Pipeline (End-User Commands)
```
/plan-product or /analyze-product  →  Product foundation (mission.md, roadmap.md)
        ↓
/shape-spec (optional)             →  Explore & refine requirements
        ↓
/create-spec                       →  Detailed specification (spec.md)
        ↓
/create-tasks                      →  Task breakdown with waves (tasks.json)
        ↓
/execute-tasks                     →  TDD implementation via Phase 1→2→3
        ↓
/execute-spec (automated)          →  Full wave automation with PR review
```

### Three-Phase Execution Model
The core innovation is **context isolation** via native subagents:

| Phase | Agent | Model | Tools | Purpose |
|-------|-------|-------|-------|---------|
| 1 | phase1-discovery | haiku | Read, Grep, Glob, Task | Discovery (read-only) |
| 2 | phase2-implementation | sonnet | Read, Edit, Write, Bash | TDD implementation |
| 3 | phase3-delivery | sonnet | Read, Bash, Grep, Write | Verification, PR creation |

Each phase gets **fresh context** - prevents accumulation that causes large features to fail.

### Key Architectural Patterns
- **Deterministic hooks** over model-invoked skills (hooks cannot be skipped)
- **Single-source tasks.json** with auto-generated tasks.md via hook
- **Artifact verification** via grep before passing to next wave (prevents hallucinations)
- **Wave-aware branching**: Each wave gets its own branch from base feature branch

## Source Structure

```
v3/
├── commands/     # 9 commands → .claude/commands/
├── agents/       # 13 agents → .claude/agents/
├── hooks/        # 4 hooks → .claude/hooks/
├── scripts/      # Utilities → .claude/scripts/
├── memory/       # CLAUDE.md template → .claude/
└── settings.json # Hook config → .claude/settings.json
```

## Making Changes

### Modifying Commands/Agents
1. Edit source in `v3/commands/` or `v3/agents/`
2. Test: `./setup/project.sh --claude-code --upgrade --target /path/to/test-project`
3. Run the command in test project to verify
4. Update SYSTEM-OVERVIEW.md and CHANGELOG.md

### Adding New Components
- **New agent**: Create `v3/agents/[name].md`, add to `setup/project.sh` AGENTS array
- **New hook**: Create `v3/hooks/[name].sh`, add config to `v3/settings.json`
- **New script**: Create `v3/scripts/[name].sh`, add to SCRIPTS array in installer

### Key Files When Debugging
- `v3/agents/phase2-implementation.md` - TDD loop, subtask protocols
- `v3/hooks/post-file-change.sh` - tasks.json → tasks.md sync, future_tasks promotion
- `v3/hooks/pre-commit-gate.sh` - Validation before commits
- `v3/scripts/task-operations.sh` - Task state manipulation
- `v3/scripts/branch-setup.sh` - Wave branch creation

## Agents Reference

| Agent | Purpose |
|-------|---------|
| phase1-discovery | Task discovery, branch setup, execution mode selection |
| phase2-implementation | TDD loop with batched/parallel subtask protocols |
| phase3-delivery | Test verification, PR creation, roadmap updates |
| wave-orchestrator | Parallel wave execution, artifact verification |
| subtask-group-worker | Parallel subtask group execution within a task |
| execute-spec-orchestrator | State machine for automated spec execution |
| git-workflow | Branch management, commits, PRs |
| project-manager | Task/roadmap state updates |
| pr-review-discovery | PR comment analysis and categorization |
| pr-review-implementation | PR feedback implementation |
| future-classifier | Classify deferred items (ROADMAP_ITEM vs WAVE_TASK) |
| comment-classifier | Categorize PR review comments by priority |
| roadmap-integrator | Place roadmap items in appropriate phase |

## Hooks (Deterministic Validation)

| Hook | Trigger | Purpose |
|------|---------|---------|
| session-start | Session begins | Set CLAUDE_PROJECT_DIR, load context |
| session-end | Session ends | Log progress, cleanup |
| post-file-change | Write/Edit to tasks.json | Regenerate tasks.md, auto-promote future_tasks |
| pre-commit-gate | git commit | Validate build/types/tests, warn on orphaned future_tasks |

## State Management

- **tasks.json**: Single source of truth for tasks (human-editable JSON)
- **tasks.md**: Auto-generated via hook (read-only view)
- **Atomic writes**: All state ops use temp file → atomic rename
- **Recovery**: `.agent-os/state/recovery/` keeps last 5 backups

## References

- **SYSTEM-OVERVIEW.md**: Comprehensive technical documentation
- **CHANGELOG.md**: Version history with migration notes
- **docs/AGENT-OS-ARCHITECTURE-GUIDE.md**: Educational guide to the architecture
