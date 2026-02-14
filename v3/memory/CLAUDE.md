# Agent OS v5.4.2 - Core Memory

> Loaded at every session start. Keep concise. For detailed docs, see `rules/*.md` files.

## Overview

Agent OS is a development framework for structured AI-assisted workflows with hooks, subagents, skills, and dependency-first task execution. Key capabilities: deterministic validation hooks, 20 native subagents with four-tier security, 10 hot-reload skills, dependency-first tasks v4.0 with computed waves, Teams-based peer coordination, and two-tier code review (Sonnet real-time + Opus deep analysis).

## Core Workflows

```
/plan-product    → Initialize product with mission/vision/roadmap
/analyze-product → Set up Agent OS for existing codebase
/shape-spec      → Explore and refine feature concepts
/create-spec     → Create detailed feature specification
/create-tasks    → Generate task breakdown with parallelization analysis
/execute-tasks   → Implement with TDD workflow
```

## Task Execution Philosophy

1. **Single-task focus** is strongly recommended (research-backed)
2. **TDD is mandatory**: RED → GREEN → REFACTOR (see `rules/tdd-workflow.md`)
3. **Validation gates cannot be skipped** (enforced by hooks)
4. **Verification loops** ensure completion claims are verified (see `rules/verification-loop.md`)
5. **E2E validation** at wave boundaries and Phase 3 (see `rules/e2e-integration.md`)

## Key Conventions

### Task Format (v4.0)

- `depends_on` per task is the **single source of truth** for dependencies
- `task_type`: `implementation`, `git-operation`, `verification`, `e2e-testing`
- `computed.waves` derived via topological sort (Kahn's algorithm)
- `tasks.json` is source of truth; `tasks.md` is auto-generated (read-only)
- Infrastructure tasks (branch, verify, PR, merge) are explicit in the graph
- Migration: `node .claude/scripts/migrate-v3-to-v4.js .agent-os/specs/*/tasks.json`

### Git Workflow

- Feature branches: `feature/SPEC-NAME-brief-description`
- Commit after each completed subtask; PR created in Phase 3
- Pre-commit hooks validate build/tests/types (with `additionalContext`, v5.3.0)
- See `rules/git-conventions.md` for full conventions

### Agent Security (v5.2.0)

Four mechanisms: `tools:` (positive), `disallowedTools:` (defense-in-depth), `Task(types)` (spawn restriction), `teammate_restrictions` (team restriction). See `rules/agent-tool-restrictions.md`.

### Teams Integration (v5.2.0)

Within-wave: Teams peer coordination. Cross-wave: Task() hierarchical spawning. Requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`. See `rules/teams-integration.md`.

### Standards Location

```
.agent-os/standards/
├── global/      # Cross-cutting (coding-style, conventions, error-handling)
├── frontend/    # UI patterns (react-patterns, styling)
├── backend/     # Server patterns (api-design, database)
└── testing/     # Test patterns
```

## Configuration

```bash
AGENT_OS_TASKS_V4=true         # Dependency-first tasks v4.0 format
AGENT_OS_TEAMS=true            # Teams-based wave coordination
AGENT_OS_MAX_TEAMMATES=5       # Max concurrent teammates per wave
AGENT_OS_CODE_REVIEW=false     # Two-tier code review (opt-in)
AGENT_OS_INLINE_MAX=512        # Context offloading inline threshold
AGENT_OS_SCRATCH_MAX_MB=250    # LRU eviction threshold
```

## Hooks (Automatic)

| Hook | Trigger | Purpose |
|------|---------|---------|
| Setup | `claude --init` | Project initialization (v4.12.0) |
| SessionStart | Session begins | Load progress context |
| SessionEnd | Session ends | Log progress, checkpoint |
| SubagentStart | Agent spawned | Initialize context, track metrics |
| SubagentStop | Agent completes | Capture transcript, offload outputs |
| TaskCompleted | Task → completed | Log completion, increment stats |
| TeammateIdle | Teammate idle | Track lifecycle metrics (v5.3.0) |
| PostToolUse | File changes | Regenerate tasks.md from JSON |
| PreToolUse | Before commits | Validate build/tests/types |

## Subagents

| Agent | Purpose |
|-------|---------|
| phase1-discovery | Task discovery & mode selection |
| phase2-implementation | TDD implementation (teammate mode) |
| phase3-delivery | Completion & PR workflow |
| wave-orchestrator | Parallel task execution (team lead) |
| wave-lifecycle-agent | Single wave lifecycle management |
| execute-spec-orchestrator | Cross-wave coordination |
| git-workflow | Branch, commit, PR operations |
| code-reviewer | Real-time Sonnet review (teammate) |
| code-validator | Deep Opus analysis (subagent) |
| pr-review-discovery | PR review context analysis |
| pr-review-implementation | Address review comments |
| test-discovery | Browser test scenario discovery |
| test-executor | Chrome MCP test execution |
| test-reporter | Test result report generation |

## Skills

| Skill | Invocation | Purpose |
|-------|------------|---------|
| artifact-verification | `/artifact-verification` | Verify predecessor task outputs |
| context-summary | `/context-summary` | Compress context for handoff |
| context-read | `/context-read <id>` | Retrieve offloaded output |
| context-search | `/context-search <term>` | Search offloaded outputs |
| context-stats | `/context-stats` | View context efficiency |
| log-entry | `/log-entry` | Add entry to memory logs |
| tdd-helper | `/tdd-helper` | Guide TDD cycle |
| test-guardian | `/test-guardian` | Classify test failures |
| subtask-expansion | `/subtask-expansion` | Generate subtasks for tasks |
| tmux-monitor | `/tmux-monitor` | Live agent monitoring dashboard |

## Model Strategy (v5.4.0)

| Tier | Model | Agents |
|------|-------|--------|
| Full | Opus 4.6 (default) | 13 agents + code-validator |
| Fast analysis | Sonnet | code-reviewer |
| Lightweight | Haiku | 5 classifiers + review-watcher |

## Agent Memory (v4.12.0)

Agents with `memory: project`: phase2-implementation, pr-review-discovery, test-executor, test-discovery, wave-lifecycle-agent. Complementary to Claude Code auto-memory (user-level, `~/.claude/`).

## Context Offloading (v4.10.0)

Large outputs (>512B) auto-offloaded to `.agent-os/scratch/tool_outputs/`. Use `/context-read`, `/context-search`, `/context-stats` to access. See `rules/context-offloading.md` for details.

## Memory Layer (v4.9.1)

Semantic memory in `.agent-os/logs/`: `decisions-log.md`, `implementation-log.md`, `insights.md`. Use `/log-entry [type]` to add entries. Progress tracking via `.agent-os/progress/progress.json`.

## Directory Structure

```
.agent-os/
├── scratch/          # Ephemeral (auto-cleaned, offloaded outputs)
├── memory/           # Persistent (pinned outputs, session archives)
├── metrics/          # Agent lifecycle tracking (agents.jsonl, transcripts/)
├── progress/         # Cross-session memory (progress.json)
├── logs/             # Semantic memory (decisions, implementations, insights)
├── specs/            # Feature specifications
├── standards/        # Project coding standards
├── test-plans/       # E2E test plans (per spec)
└── test-results/     # E2E execution results
```

## Quick Reference

```bash
jq '.summary' .agent-os/specs/*/tasks.json           # Task status
jq '.entries[-5:]' .agent-os/progress/progress.json   # Recent progress
cat .agent-os/scratch/session_stats.json | jq         # Context statistics
node .claude/scripts/json-to-markdown.js .agent-os/specs/*/tasks.json  # Regenerate tasks
```

## Detailed Documentation

| Topic | File |
|-------|------|
| TDD Workflow | `rules/tdd-workflow.md` |
| Git Conventions | `rules/git-conventions.md` |
| Verification Loop | `rules/verification-loop.md` |
| E2E Integration | `rules/e2e-integration.md` |
| Agent Tool Restrictions | `rules/agent-tool-restrictions.md` |
| Teams Integration | `rules/teams-integration.md` |
| Context Offloading | `rules/context-offloading.md` |
| Error Handling | `rules/error-handling.md` |
