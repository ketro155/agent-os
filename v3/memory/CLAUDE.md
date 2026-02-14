# Agent OS v5.4.1 - Core Memory

> This file is automatically loaded by Claude Code at session start.
> It replaces embedded instructions in commands with native memory hierarchy.

## Agent OS Overview

Agent OS is a development framework providing structured AI-assisted workflows. Version 5.4.0 uses Claude Code's latest features:

- **Hooks** for deterministic validation (cannot be skipped)
- **Subagent lifecycle hooks** for tracking agent spawns (v4.8.0)
- **Memory hierarchy** for instructions (this file + rules/)
- **Skills** for reusable patterns with hot-reload (v4.8.0)
- **Native subagents** with `disallowedTools` security (v4.8.0)
- **Single-source tasks** (JSON primary, MD auto-generated)
- **Wildcard permissions** for simplified configuration (v4.8.0)
- **Context offloading** for token efficiency (v4.10.0)
- **E2E test integration** across spec/task workflow (v4.11.0)
- **Setup hook** for project initialization (v4.12.0)
- **TaskCompleted hook** for completion tracking (v4.12.0)
- **Task(type) spawn restrictions** for agent security (v4.12.0)
- **Agent memory** for cross-session learning (v4.12.0)
- **Dependency-first tasks v4.0** with computed waves (v5.0.0)
- **Explicit infrastructure tasks** visible in task graph (v5.0.0)
- **Topological sort** for wave computation from `depends_on` (v5.0.0)
- **Native Teams integration** for wave-level peer coordination (v5.1.0)
- **Review-watcher agent** for message-based PR review notification (v5.1.0)
- **Artifact broadcast protocol** for sibling task sharing (v5.1.0)
- **Atomic Teammates** with group-level parallelism and dynamic cap (v5.2.0)
- **Artifact relay protocol** for cross-teammate sibling sharing (v5.2.0)
- **TeammateIdle hook** for teammate lifecycle tracking (v5.3.0)
- **Opus 4.6 model strategy** with two-tier agent model assignment (v5.3.0)
- **PreToolUse additionalContext** for smarter pre-commit context (v5.3.0)
- **Two-tier code review** with Sonnet real-time + Opus deep analysis (v5.4.0)

## Context Offloading (v4.10.0)

> **"Why waste time say lot word when few word do trick?"**

Inspired by FewWord patterns, Agent OS now automatically offloads large outputs to preserve context tokens:

### How It Works

| Output Size | Behavior |
|-------------|----------|
| **< 512B** | Displayed inline (no change) |
| **512B - 4KB** | Compact pointer (~35 tokens) |
| **> 4KB** | Pointer + failure preview (for debugging) |

### Automatic Features

- **Tiered offloading**: Large outputs stored in `.agent-os/scratch/tool_outputs/`
- **Secret redaction**: AWS keys, GitHub tokens, API keys automatically redacted
- **Smart retention**: Failures kept 48h, successes 24h (for debugging)
- **LATEST symlinks**: Quick access to most recent outputs
- **Token statistics**: Track context savings per session
- **LRU eviction**: Auto-cleanup at 250MB scratch limit

### Context Management Skills

| Skill | Invocation | Purpose |
|-------|------------|---------|
| context-read | `/context-read <id>` | Retrieve offloaded output |
| context-search | `/context-search <term>` | Search across outputs |
| context-stats | `/context-stats` | View token savings |

### Example Workflow

When you see: `[Output offloaded: 45KB → /context-read phase2_20260112_143022_exit1]`

1. Use `/context-read phase2_20260112_143022_exit1` to view full content
2. Use `/context-read LATEST` for most recent output
3. Use `/context-search TypeError` to find errors across all outputs

### Configuration (Environment Variables)

```bash
AGENT_OS_TASKS_V4=true         # Dependency-first tasks v4.0 format (v5.0, default true since v5.1)
AGENT_OS_TEAMS=true            # Teams-based wave coordination (v5.1, default true since v5.1)
AGENT_OS_MAX_TEAMMATES=5       # Max concurrent teammates per wave (v5.2)
AGENT_OS_CODE_REVIEW=false     # Two-tier code review (v5.4.0, opt-in)
AGENT_OS_INLINE_MAX=512        # Inline display threshold
AGENT_OS_PREVIEW_MIN=4096      # Preview trigger for failures
AGENT_OS_SUCCESS_RETENTION=24  # Hours to keep success outputs
AGENT_OS_FAILURE_RETENTION=48  # Hours to keep failure outputs
AGENT_OS_SCRATCH_MAX_MB=250    # LRU eviction threshold
```

## E2E Test Integration (v4.11.0)

> **"Unit tests verify code works. E2E tests verify users can work."**

E2E tests are now integrated into the spec/task execution workflow at three strategic points:

### Integration Points

| Point | When | What Happens | Blocking? |
|-------|------|--------------|-----------|
| `/create-spec` Step 11.75 | After spec approval | Generate E2E test plan | No |
| `wave-lifecycle-agent` Step 3.5 | Final wave, before merge | Run smoke E2E tests | Yes |
| `phase3-delivery` Step 3.5 | After build passes | Run full E2E plan | Yes |

### Workflow

```
/create-spec → E2E plan generated (5-50 scenarios)
     ↓
/execute-tasks → TDD implementation (unit/integration tests)
     ↓
wave-lifecycle → Smoke E2E (5-10 scenarios, final wave only)
     ↓
phase3-delivery → Full E2E validation (all scenarios)
     ↓
PR created with E2E results
```

### E2E Failure Behavior

E2E failures are **hard-blocking** (same as unit tests):
- Phase 3 E2E failures prevent PR creation
- Smoke E2E failures in wave-lifecycle prevent merge
- Failures include screenshots and remediation suggestions

### Skipping E2E

| Flag | Scope | Usage |
|------|-------|-------|
| `--no-e2e-plan` | create-spec | Don't generate E2E plan |
| `--skip-e2e` | execute-tasks | Skip E2E in Phase 3 |

### Directory Structure

```
.agent-os/
├── test-plans/           # E2E test plans (per spec)
│   └── ${SPEC_NAME}/
│       ├── test-plan.json
│       └── fixtures/
├── test-results/         # E2E execution results
│   └── ${SPEC_NAME}/
│       ├── results.json
│       └── evidence/     # Screenshots, GIFs
```

See `rules/e2e-integration.md` for full documentation.

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
5. **Verification loops** ensure completion claims are verified (v4.9.0)
6. **E2E validation** ensures features work in browser (v4.11.0)

### Ralph Wiggum Verification Pattern (v4.9.0)

> **"Completion must be earned, not declared."**

Tasks cannot claim completion without passing verification. If verification fails,
the task is re-invoked with feedback until it passes or max attempts (3) reached.

```
Traditional:  Agent says "done" → Trust → Proceed
Ralph:        Agent says "done" → Verify → If fail → Re-invoke → Loop
```

**What gets verified:**
- All claimed files exist
- All claimed exports found in codebase
- All claimed functions exist
- Tests pass (`npm test`)
- No TypeScript errors (`tsc --noEmit`)

**Reference:** https://awesomeclaude.ai/ralph-wiggum

See `rules/verification-loop.md` for implementation details.

## Key Conventions

### Task Format

**v4.0 (dependency-first, behind `AGENT_OS_TASKS_V4=true` flag):**
- `depends_on` per task is the **single source of truth** for dependencies
- `task_type` classifies tasks: `implementation`, `git-operation`, `verification`, `e2e-testing`
- Infrastructure tasks (branch, verify, PR, merge, deliver) are **explicit** in the graph
- `computed.waves` derived automatically via topological sort (Kahn's algorithm)
- `isolation_score` and `shared_files` at top level (moved from `parallelization`)
- Migration: `node .claude/scripts/migrate-v3-to-v4.js .agent-os/specs/*/tasks.json`

**v3.0 (parallel waves, legacy):**
- `execution_strategy.waves` and `parallelization.blocked_by` define dependencies
- `type: parent|subtask` hierarchy

**Common to both:**
- `tasks.json` is the **source of truth**
- `tasks.md` is **auto-generated** (read-only)
- Edit tasks via commands or direct JSON editing
- Hooks auto-regenerate markdown on JSON changes

### Agent Security (v5.2.0)

Agent tool access uses **four complementary mechanisms**:

| Mechanism | Type | When to Use |
|-----------|------|-------------|
| `tools:` | Positive list | **Always** - primary restriction |
| `disallowedTools:` | Negative list | Security-critical agents only (defense-in-depth) |
| `Task(types)` | Spawn restriction | Orchestrators — limit spawnable agent types (v4.12.0) |

**Defense-in-depth agents** (read-only, process untrusted input):
- `comment-classifier`, `future-classifier`, `roadmap-integrator`, `code-reviewer`

**Spawn-restricted orchestrators** (v4.12.0):
- `execute-spec-orchestrator` → `Task(wave-lifecycle-agent)`
- `wave-orchestrator` → `Task(phase2-implementation, subtask-group-worker, code-validator)`
- `wave-lifecycle-agent` → `Task(wave-orchestrator, phase3-delivery, general-purpose)`
- `phase1-discovery` → `Task(Explore)`
- `pr-review-discovery` → `Task(comment-classifier, Explore)`
- `test-discovery` → `Task(Explore)`

See `rules/agent-tool-restrictions.md` for full decision tree and examples.

### Teams Integration (v5.2.0)

Agent OS uses Claude Code's native Teams API for peer coordination where it adds clear value:

| Scenario | Mode | Mechanism |
|----------|------|-----------|
| Within-wave task coordination | Teams | `TeamCreate` + `SendMessage` artifact sharing |
| Within-wave group coordination | Teams (v5.2) | `subtask-group-worker` teammates with artifact relay |
| PR review waiting | Teams | `review-watcher` teammate with message notification |
| Cross-wave orchestration | Task() | Hierarchical spawning for context isolation |
| PR review cycle | Task() | Sequential discovery + implementation |

**Prerequisite**: Claude Code Agent Teams must be enabled: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` (set in environment or `~/.claude.json`).

**Feature flags**: `AGENT_OS_TEAMS` (default: `true`). `AGENT_OS_MAX_TEAMMATES` (default: `5`).

**Key agents affected:**
- `wave-orchestrator` — team lead, dynamic granularity (task-level or group-level) with isolation-based cap
- `phase2-implementation` — teammate mode: claims tasks, broadcasts artifacts
- `subtask-group-worker` — teammate mode (v5.2): claims group tasks, broadcasts scoped artifacts
- `execute-spec-orchestrator` — spawns `review-watcher` teammate for PR polling
- `review-watcher` — lightweight Haiku-model teammate that notifies on review arrival

See `rules/teams-integration.md` for full documentation.

### Git Workflow

- Feature branches: `feature/SPEC-NAME-brief-description`
- Commit after each completed subtask
- PR created automatically in Phase 3
- Pre-commit hooks validate build/tests/types (with `additionalContext` for commit messages, v5.3.0)
- Resume PR-linked sessions with `claude --from-pr <PR_NUMBER>` (v5.3.0)

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
| **Setup** | `claude --init` / `--maintenance` | **One-time project initialization, directory creation** (v4.12.0) |
| SessionStart | Session begins | Load progress context, set up state |
| SessionEnd | Session ends | Log progress, checkpoint, logging reminder (v4.9.1) |
| **SubagentStart** | Agent spawned | Initialize agent context, track metrics (v4.8.0) |
| **SubagentStop** | Agent completes | **Capture transcript, offload large outputs, track tokens** (v4.10.0) |
| **TaskCompleted** | Task status → completed | **Log completion to progress, increment session stats** (v4.12.0) |
| **TeammateIdle** | Teammate goes idle | **Track teammate lifecycle metrics** (v5.3.0) |
| PostToolUse (Write/Edit) | File changes | Regenerate tasks.md from JSON |
| PreToolUse (git commit) | Before commits | Validate build, tests, types; **return additionalContext** (v5.3.0) |

### Agent Metrics (v4.8.0+)

Subagent lifecycle is tracked in `.agent-os/metrics/`:
- `agents.jsonl` - Start/stop events with duration, exit codes, bytes offloaded
- `transcripts/` - Saved agent transcripts (last 20 kept)

### Context Statistics (v4.10.0)

Token savings tracked in `.agent-os/scratch/session_stats.json`:
- `bytes_offloaded` - Total bytes saved from context
- `offload_count` - Number of outputs offloaded
- `estimated_tokens_saved` - Approximate token savings (~4 chars/token)

### Directory Structure (v4.10.0)

```
.agent-os/
├── scratch/                  # Ephemeral (auto-cleaned)
│   ├── tool_outputs/        # Offloaded command outputs
│   │   ├── LATEST.txt       # Most recent output symlink
│   │   └── LATEST_*.txt     # Per-agent-type symlinks
│   ├── index.jsonl          # Output manifest
│   └── session_stats.json   # Token savings tracking
├── memory/                   # Persistent (never auto-cleaned)
│   ├── pinned/              # User-pinned outputs
│   └── sessions/            # Session archives
├── metrics/                  # Agent lifecycle tracking
│   ├── agents.jsonl         # Start/stop events
│   └── transcripts/         # Last 20 transcripts
├── progress/                 # Cross-session memory
├── logs/                     # Semantic memory
└── specs/                    # Feature specifications
```

## Subagents Available

Use `Task` tool to invoke these specialized agents:

| Agent | Purpose | When to Use |
|-------|---------|-------------|
| phase0-startup | Session initialization | Start of execute-tasks |
| phase1-discovery | Task discovery & mode selection | After Phase 0 |
| phase2-implementation | TDD implementation | For each task |
| phase3-delivery | Completion & PR workflow | After all tasks done |
| git-workflow | Branch, commit, PR operations | Called by phases |
| code-reviewer | Real-time code review (Sonnet) | Reactive teammate in wave teams; reviews artifacts as they're broadcast |
| code-validator | Deep code validation (Opus) | Wave-level design, security, spec compliance, and cross-task review |

## Skills (v4.8.0+)

Reusable patterns that hot-reload without restarting sessions:

| Skill | Invocation | Purpose |
|-------|------------|---------|
| artifact-verification | `/artifact-verification` | Verify predecessor task outputs exist |
| context-summary | `/context-summary` | Compress context for agent handoff |
| log-entry | `/log-entry` | Add entry to memory logs (v4.9.1) |
| tdd-helper | `/tdd-helper` | Guide RED-GREEN-REFACTOR cycle |
| **context-read** | `/context-read <id>` | Retrieve offloaded output (v4.10.0) |
| **context-search** | `/context-search <term>` | Search offloaded outputs (v4.10.0) |
| **context-stats** | `/context-stats` | View context efficiency (v4.10.0) |

Skills live in `.claude/skills/[name]/SKILL.md` and are automatically discovered.

### Creating New Skills

```yaml
---
name: my-skill
description: When user needs [specific capability]
version: 1.0.0
context: fork  # Optional: isolate execution context
---

# Skill instructions here...
```

## Opus 4.6: Adaptive Thinking & Fast Mode (v5.3.0)

Opus 4.6 uses **adaptive thinking** — the model dynamically decides when and how deeply to think. The previous `budget_tokens` approach is deprecated.

For complex planning tasks (`/create-spec`, `/shape-spec`), adaptive thinking engages automatically:
- At **high effort** (default): Claude almost always thinks before responding
- At **lower effort**: thinking is skipped for simple problems
- **Fast mode** (`/fast`): 2.5x faster output at premium pricing — useful for long `/execute-tasks` runs

### Model Strategy (v5.4.0)

Agent OS uses a three-tier model assignment:

| Tier | Model | Agents | Rationale |
|------|-------|--------|-----------|
| **Full** | Opus 4.6 (default) | 13 agents + code-validator | Complex reasoning, multi-step logic |
| **Fast analysis** | Sonnet | code-reviewer | Real-time semantic review, moderate reasoning |
| **Lightweight** | Haiku | 5 agents (classifiers + review-watcher) | Simple classification, low token overhead |

## Progress Log

Cross-session memory is maintained in `.agent-os/progress/progress.json`:

- Automatically updated by hooks
- Contains: session events, task completions, blockers
- **Local-only** (gitignored v3.8.0+) to prevent merge conflicts

## Memory Layer (v4.9.1)

Beyond event tracking, Agent OS maintains semantic memory in `.agent-os/logs/`:

| Log | Purpose | When to Update |
|-----|---------|----------------|
| `decisions-log.md` | Architectural & product decisions with rationale | After significant choices |
| `implementation-log.md` | Code changes with context and gotchas | After major implementations |
| `insights.md` | Patterns, learnings, and future ideas | When discoveries emerge |

**Key Principle**: `progress.json` tracks *what* happened; logs capture *why*.

### Adding Log Entries

Use the `/log-entry` skill:
```
/log-entry decision    # Record a decision with rationale
/log-entry implementation  # Document significant changes
/log-entry insight     # Capture a learning or pattern
```

### When to Log

- **Do log**: Architectural decisions, non-obvious choices, gotchas discovered
- **Don't log**: Routine tasks, obvious changes, things clear from git history

### Integrated Workflows

Logging prompts are built into these workflows:

| Workflow | Trigger | Suggested Log |
|----------|---------|---------------|
| `/shape-spec` | After approach selected | Decision (trade-offs) |
| `/create-spec` | After spec approved | Decision (technical approach) |
| `/debug` | After root cause found | Insight (pattern) + Implementation (fix) |
| Phase 2 | After complex task | Implementation (gotchas) |
| Phase 3 | After backlog graduation | Decision (triage rationale) |
| `/pr-review-cycle` | After review complete | Insight (conventions) + Decision (triage) |
| Session End | If tasks completed | Reminder via hook |

## Quick Reference

### Check Task Status
```bash
jq '.summary' .agent-os/specs/*/tasks.json
```

### View Recent Progress
```bash
jq '.entries[-5:]' .agent-os/progress/progress.json
```

### View Context Statistics (v4.10.0)
```bash
cat .agent-os/scratch/session_stats.json | jq
```

### List Offloaded Outputs (v4.10.0)
```bash
tail -5 .agent-os/scratch/index.jsonl | jq -r '.id'
```

### Manual Task Regeneration
```bash
node .claude/scripts/json-to-markdown.js .agent-os/specs/*/tasks.json
```

## Agent Memory (v4.12.0)

Agents with `memory: project` accumulate cross-session knowledge scoped to the project:

| Agent | Why Memory Helps |
|-------|-----------------|
| `phase2-implementation` | Learns test patterns, coding conventions, common verification failures |
| `pr-review-discovery` | Learns reviewer preferences, convention patterns, common issues |
| `test-executor` | Learns working selectors, timing, flaky test recovery |
| `test-discovery` | Learns app routes, form fields, testable patterns |
| `wave-lifecycle-agent` | Learns review polling, merge patterns per project |

**NOT given memory:** Haiku-model classifiers (token overhead disproportionate), stateless/procedural agents (`git-workflow`, `project-manager`, `subtask-group-worker`, `phase3-delivery`, `pr-review-implementation`).

### Auto-Memory vs Project Memory (v5.3.0)

Claude Code v2.1.32+ has **automatic memory** that records and recalls user-level memories across sessions (stored in `~/.claude/`). This is **complementary** to Agent OS project memory:

| System | Scope | Storage | Purpose |
|--------|-------|---------|---------|
| Claude Code auto-memory | User-level | `~/.claude/` | User preferences, workflow habits |
| Agent OS `memory: project` | Project-level | Agent-specific | Test patterns, coding conventions, reviewer preferences |

Both systems operate simultaneously without conflict.

---

@import rules/tdd-workflow.md
@import rules/git-conventions.md
@import rules/verification-loop.md
@import rules/e2e-integration.md
@import rules/agent-tool-restrictions.md
@import rules/teams-integration.md
