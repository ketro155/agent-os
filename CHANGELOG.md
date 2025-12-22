# Changelog

All notable changes to Agent OS will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.0.4] - 2025-12-22

### Added

- **Future Recommendations Capture** (`/pr-review-cycle`): PR review comments suggesting future work are now captured and routed to appropriate locations
  - New `FUTURE` category detects keywords: future, later, v2, nice to have, follow-up, backlog, tech debt, out of scope, eventually
  - Two-destination classification system:
    - `WAVE_TASK` → `tasks.json` (future_tasks section) for small feature-related items
    - `ROADMAP_ITEM` → `.agent-os/product/roadmap.md` for anything larger needing its own spec
  - New Phase 3.5 in pr-review-cycle handles capture workflow
  - Updated summary report shows captured future items with locations
  - Replies posted to reviewers confirming capture

- **Future Classifier Subagent** (`future-classifier`): Context-aware classification of future recommendations
  - Uses haiku model for fast, cheap classification
  - Reads tasks.json, roadmap.md, and spec.md to understand context
  - Checks for duplicates before creating new entries
  - Returns classification with confidence level and reasoning
  - Four outcomes: WAVE_TASK, ROADMAP_ITEM, SKIP (duplicate), ASK_USER (ambiguous)
  - Graceful fallback to keyword heuristics if subagent unavailable

- **PR Review Handler Skill Enhancement**: Added `FUTURE` category with `CAPTURE` priority
  - Integrates with future-classifier subagent
  - Reply templates for captured future recommendations
  - Output format includes "Future Recommendations Captured" section

### Design Decision

Two destinations are sufficient for future recommendations:
- **Small items** (WAVE_TASK) → `tasks.json` - integrates with current spec workflow
- **Larger items** (ROADMAP_ITEM) → `roadmap.md` - visible, becomes its own spec when prioritized

A third "spec enhancement" destination was considered but rejected as redundant—items either fit as tasks or need roadmap visibility.

---

## [3.0.3] - 2025-12-17

### Added

- **Changelog Writer Skill** (`changelog-writer`): Automatic changelog maintenance for projects using Agent OS
  - Auto-detects change type using hybrid analysis (spec content + git diff patterns)
  - Confidence-based prompting: auto-proceeds when confident (≥70%), asks user when uncertain
  - Maintains Keep a Changelog format with proper sections (Added/Changed/Fixed/etc.)
  - Suggests semantic version bumps based on change type
  - Creates CHANGELOG.md from template if not exists
  - Non-blocking: failures warn but don't stop delivery

- **Phase 3 Delivery Integration** (Step 8.5): Changelog skill invoked automatically after recap creation
  - Receives spec folder, PR number, and spec name
  - Reports semver suggestion in delivery output
  - Added changelog fields to output format

### Change Type Detection

| Signal | Detection Method | Weight |
|--------|------------------|--------|
| Spec keywords | "fix/bug" → bugfix, "add/new" → feature, "breaking" → breaking | 0.3-0.5 |
| Git diff | New files → feature, modifications → bugfix, deletions → breaking | 0.2-0.4 |

### Semver Suggestion Logic

| Change Type | Section | Semver Impact |
|-------------|---------|---------------|
| feature | Added | MINOR |
| bugfix | Fixed | PATCH |
| breaking | Changed (BREAKING:) | MAJOR |
| refactor/docs/chore | Changed | PATCH |

---

## [3.0.2] - 2025-12-14

### Added

- **PR Review Cycle Command** (`/pr-review-cycle`): Automated processing of PR review feedback using direct GitHub API
  - Fetches reviews via `gh` CLI (no setup required)
  - Categorizes comments by priority (CRITICAL → HIGH → MEDIUM → LOW → INFO)
  - Processes comments in priority order
  - Posts replies to GitHub comments
  - Commits and pushes fixes automatically

- **PR Review Handler Skill** (`pr-review-handler`): Systematic approach to addressing review feedback
  - Comment categorization patterns
  - Fix protocols for security, bugs, logic errors
  - Reply templates by category
  - Verification checklists

### Fixed

- **Git Workflow Enforcement** (CRITICAL): Added mandatory branch validation gates to v3 native subagents
  - **phase1-discovery.md**: Added Step 0 MANDATORY Gate - returns `blocked` status if on main/master
  - **phase2-implementation.md**: Added pre-implementation defense-in-depth validation
  - Both gates HALT execution and require feature branch before proceeding

### Removed

- **v2.x Architecture Removed** (BREAKING): Legacy files deleted from source repository
  - `commands/phases/` directory removed (execute-phase0.md through execute-phase3.md)
  - `claude-code/agents/task-orchestrator.md` removed
  - `claude-code/agents/codebase-indexer.md` removed
  - Installer no longer installs these files
  - v3 uses native subagents in `v3/agents/` instead (phase1-discovery.md, phase2-implementation.md, phase3-delivery.md)

### Why Git Workflow Enforcement Was Needed

During task execution, workers could commit directly to main/master if branch setup was skipped or failed silently. The fix adds two enforcement layers in v3 architecture:

1. **Phase 1 Gate**: Blocks task discovery if on protected branch - fails early
2. **Phase 2 Gate**: Defense-in-depth - catches any bypass before implementation

---

## [3.0.1] - 2025-12-14

### Fixed

- **task-orchestrator.md**: Added missing YAML frontmatter with required `name` field (was causing agent parse errors)
- **settings.json**: Corrected schema URL from `https://claude.ai/schemas/settings.json` to `https://json.schemastore.org/claude-code-settings.json`
- **gitignore**: Added missing v3 session files (`session.json`, `checkpoints/`) to gitignore entries

### Added

- **Legacy file cleanup**: Installer now automatically removes v2.x files during v3 upgrades
  - Removes legacy agents: `build-checker`, `context-fetcher`, `date-checker`, `file-creator`, `spec-cache-manager`, `test-runner`, `task-orchestrator`, `codebase-indexer`, `project-manager`
  - Removes `skills/` directory (v3 uses hooks instead)
  - Removes `commands/phases/` directory (v3 uses native subagents)
  - Removes `shared/` directory (v3 uses memory hierarchy)
  - Removes deprecated `index-codebase.md` command
- **`--keep-legacy` flag**: Preserves v2.x files during upgrade if needed (not recommended)
- **.gitignore**: Added exclusions for test installation directories in source repo

### Changed

- Installer help text updated to document upgrade behavior and `--keep-legacy` flag

## [3.0.0] - 2025-12-12

### Major Architecture Overhaul - Native Claude Code Integration

Agent OS v3.0 is a complete architectural refactor that leverages Claude Code's native capabilities. This release replaces custom solutions with deterministic, built-in features for improved reliability and reduced complexity.

**Key Insight**: Claude Code has evolved to natively support many patterns Agent OS previously implemented in markdown. v3.0 moves from "in markdown" to "in configuration."

### Breaking Changes

- **Single-source task format**: `tasks.json` is now the source of truth (not `tasks.md`)
- **Skills removed**: Replaced by native hooks and memory rules
- **Phase files removed**: Replaced by native subagents
- **Embedded instructions removed**: Replaced by memory hierarchy

### New: Native Hooks (Mandatory Validation)

Hooks are **deterministic** - they always run and cannot be skipped by the model.

| Hook | Trigger | Purpose |
|------|---------|---------|
| `session-start.sh` | SessionStart | Load progress context, validate environment |
| `session-end.sh` | SessionEnd | Save checkpoint, log session summary |
| `post-file-change.sh` | PostToolUse (Write/Edit) | Auto-regenerate tasks.md from JSON |
| `pre-commit-gate.sh` | PreToolUse (git commit) | Validate build, tests, types before commit |

**Why this matters**: In v2.x, skills like `build-check` and `task-sync` were model-invoked, meaning Claude decided when to use them. This led to validation being skipped. Hooks **cannot be bypassed**.

### New: Single-Source Task Format

- `tasks.json` is the **source of truth**
- `tasks.md` is **auto-generated** by `post-file-change.sh` hook
- No sync logic needed (eliminates drift problem from v2.1.1)
- Schema: `.agent-os/schemas/tasks-v3.json`

### New: Native Subagents for Phases

Phases are now native Claude Code subagents with tool restrictions:

| Agent | Model | Tools | Purpose |
|-------|-------|-------|---------|
| `phase1-discovery.md` | haiku | Read, Grep, Glob, Task | Task discovery, mode selection |
| `phase2-implementation.md` | sonnet | Read, Edit, Write, Bash | TDD implementation |
| `phase3-delivery.md` | sonnet | Read, Bash, Grep, Write | Final tests, PR, documentation |

**Benefits**:
- Fresh context per phase (prevents context bloat)
- Tool restrictions prevent scope creep
- Model specification (haiku for fast phases)
- Auto-skill loading via `skills:` field

### New: Planning Mode + Explore Agent Integration

v3.0 includes native Claude Code agent integration:

**Planning Mode** in `/shape-spec`:

| Step | Tool | Purpose |
|------|------|---------|
| Start | `EnterPlanMode` | Restrict to read-only, signal exploration |
| End | `ExitPlanMode` | Get user approval, ready for implementation |

**Explore Agent** with thoroughness levels:

| Command/Agent | Thoroughness | Use Case |
|---------------|--------------|----------|
| phase1-discovery | `quick` | Spec discovery, context loading |
| shape-spec (quick) | `quick` | Fast validation |
| shape-spec (standard) | `medium` | Balanced exploration |
| shape-spec (deep) | `very thorough` | Complex features |
| debug | `very thorough` | Root cause investigation |

### New: shape-spec and debug Commands (v3-style)

New simplified commands with native integration:

- **shape-spec.md** (~100 lines): Planning Mode + Explore agent for feature exploration
- **debug.md** (~100 lines): Explore agent for root cause investigation

### New: Memory Hierarchy

Instructions are now in Claude Code's native memory system:

```
.claude/
├── CLAUDE.md              # Core instructions (always loaded)
└── rules/
    ├── tdd-workflow.md    # TDD rules (path-specific)
    ├── git-conventions.md # Git rules
    └── execute-tasks.md   # Task execution rules
```

**Benefits**:
- Automatic loading (no Read tool needed)
- Path-specific rules with YAML frontmatter
- Hierarchical precedence

### New: Task Operations Script

All task operations consolidated into `.claude/scripts/task-operations.sh`:

```bash
# Get status
.claude/scripts/task-operations.sh status [spec_name]

# Update task
.claude/scripts/task-operations.sh update <task_id> <status>

# Collect artifacts from git
.claude/scripts/task-operations.sh collect-artifacts [since_commit]

# Validate names exist
.claude/scripts/task-operations.sh validate-names '["functionName"]'
```

### Changed: Installer

- Default architecture is now v3
- New flags: `--v3` (default), `--v2`/`--legacy`
- Version tracking includes `"architecture": "v3"` or `"v2"`
- v2 installation preserved for backwards compatibility

```bash
# v3 installation (default)
./setup/project.sh --claude-code

# v2 legacy installation
./setup/project.sh --claude-code --v2
```

### Removed

| Component | Replacement |
|-----------|-------------|
| `task-sync` skill | `post-file-change.sh` hook |
| `session-startup` skill | `session-start.sh` hook |
| `build-check` skill | `pre-commit-gate.sh` hook |
| Phase files (`execute-phase0-3.md`) | Native subagents |
| Embedded instructions (250-900 lines) | Memory hierarchy |
| Dual-format tasks (MD + JSON) | Single-source JSON |
| `codebase-indexer` subagent | Task artifacts + live Grep |

### Code Reduction

| Component | v2.x Lines | v3.0 Lines | Reduction |
|-----------|------------|------------|-----------|
| execute-tasks.md | 475 | ~120 | **75%** |
| Phase files | 970 | 0 (native) | **100%** |
| task-sync skill | 290 | 0 (hooks) | **100%** |
| session-startup skill | 286 | 0 (hooks) | **100%** |
| **Total** | ~2,000+ | ~120 | **~94%** |

### Migration from v2.x

1. Run `./setup/project.sh --claude-code --upgrade`
2. Old `skills/` directory can be deleted (not used in v3)
3. Existing `tasks.md` files work as-is (will be regenerated from JSON)
4. Progress logs are preserved

### Why Upgrade?

1. **More Reliable**: Hooks cannot be skipped
2. **Simpler**: ~50% less code to maintain
3. **Faster**: Native features, no Read tool overhead
4. **No Dependencies**: Uses only built-in Claude Code tools
5. **Cleaner**: Single-source data, deterministic validation

---

## [2.2.0] - 2025-12-13

### Native Claude Code Agent Integration (Planning Mode + Explore Agent)

This release deepens integration with Claude Code's native capabilities by incorporating Planning Mode and enhanced Explore agent usage into key commands.

**Design Philosophy**: Option B - Moderate Integration
- Wraps `shape-spec` with Planning Mode for formal exploration
- Adds Explore agent with thoroughness levels across commands
- Preserves the existing `create-spec` → `create-tasks` → `execute-tasks` pipeline

### New: Planning Mode Integration in shape-spec

The `/shape-spec` command now uses Claude Code's Planning Mode:

| Step | Tool | Purpose |
|------|------|---------|
| Step 0 | `EnterPlanMode` | Signal exploration phase, restrict to read-only tools |
| Step 9 | `ExitPlanMode` | Signal exploration complete, get user approval |

**Benefits**:
- Clear separation between "exploring options" and "building"
- Tool restrictions prevent premature implementation
- User approval required before proceeding to `/create-spec`

### New: Explore Agent with Thoroughness Levels

Commands now use the Explore agent with context-appropriate thoroughness:

| Command | Thoroughness | Use Case |
|---------|--------------|----------|
| `shape-spec` (quick mode) | `quick` | Fast validation, known patterns |
| `shape-spec` (standard) | `medium` | Balanced exploration |
| `shape-spec` (deep mode) | `very thorough` | Comprehensive analysis |
| `debug` | `very thorough` | Root cause investigation |
| `execute-tasks` Phase 1 | `quick` | Targeted context loading |
| `execute-tasks` Phase 1 | `medium` | Spec discovery (fallback) |

### Changed: shape-spec Command

Added new steps for native integration:

- **Step 0**: Enter Planning Mode
- **Step 2.5**: Deep Codebase Exploration (Explore agent)
- **Step 3**: Technical Feasibility now incorporates exploration results
- **Step 9**: Exit Planning Mode

Exploration depth parameter now maps to Explore agent thoroughness:
- `quick` → `thoroughness: quick`
- `standard` → `thoroughness: medium`
- `deep` → `thoroughness: very thorough`

### Changed: debug Command

Added Explore agent for root cause investigation:

- **Step 3.5**: Codebase Exploration for Root Cause
  - Traces error propagation through codebase
  - Finds working examples for comparison
  - Identifies related code and dependencies
  - Results feed into systematic-debugging skill

Investigation phases now leverage Explore agent results:
- Phase 1: Uses "Recent changes" and "Error propagation"
- Phase 2: Uses "Related code" and "Dependencies"

### Changed: execute-tasks Phase 1

Enhanced context loading with Explore agent:

- **Step 3-Alternative**: Uses `thoroughness: medium` for spec discovery fallback
- **Step 4**: Uses `thoroughness: quick` for targeted document retrieval

### Documentation Updates

- Updated SYSTEM-OVERVIEW.md with v2.2.0 features
- Added Planning Mode integration section
- Added Explore Agent thoroughness levels documentation
- Updated command workflow descriptions

### Why This Release?

This release implements "Option B: Moderate Integration" from our evaluation:

1. **Selective Planning Mode**: Only in `shape-spec` (exploration command)
2. **Deep Explore Agent**: Thoroughness-aware integration across commands
3. **Pipeline Preserved**: `create-spec` → `create-tasks` → `execute-tasks` unchanged
4. **Non-Breaking**: Existing projects work without modification

---

## [2.1.1] - 2025-12-12

### Automatic Task JSON Sync

Addresses task JSON drift where `tasks.json` becomes out of sync with `tasks.md` (source of truth) during task execution.

**Problem**: When tasks were executed outside `/execute-tasks` or Phase 2 update steps were skipped, `tasks.json` would show stale data (all tasks pending) even when `tasks.md` showed completed tasks.

**Solution**: Multi-layered auto-sync approach:

### New: task-sync Skill

New dedicated skill for synchronizing tasks.json with tasks.md:
- Auto-invokes when drift is detected
- Parses tasks.md as source of truth
- Preserves existing metadata (started_at, duration_minutes, artifacts)
- Updates status, progress_percent, and summary
- Performs atomic writes to prevent corruption

### Changed: session-startup Skill (Step 4.5)

Added new **Task JSON Validation & Auto-Sync** step:
- Checks if tasks.json exists and matches tasks.md
- Auto-syncs on drift detection
- Reports sync status in startup summary
- Catches issues before work begins

### Changed: execute-phase3.md (Step 9.7)

Added new **Task JSON Sync Gate (MANDATORY)**:
- Final validation before git commit
- Blocks completion if drift detected
- Auto-syncs to ensure accurate task state in commits
- Ensures artifacts are recorded correctly for cross-task verification

### Installation

- Added `task-sync` to default skills (Tier 1)
- Updated project.sh for both local and GitHub download paths

---

## [2.1.0] - 2025-12-11

### Task Artifacts for Cross-Task Verification

Major update replacing the static codebase-indexer with dynamic task artifacts. Tasks now record their outputs (files created, functions exported) in tasks.json, enabling reliable cross-task verification without maintaining a separate codebase index.

### New: Task Artifacts Schema (v2.1)

Each completed task now includes an `artifacts` object:

```json
{
  "id": "1",
  "status": "pass",
  "artifacts": {
    "files_modified": ["src/auth/middleware.ts"],
    "files_created": ["src/auth/login.ts", "src/auth/token.ts"],
    "functions_created": ["login", "validateToken", "refreshToken"],
    "exports_added": ["login", "validateToken", "refreshToken", "AuthError"],
    "test_files": ["tests/auth/login.test.ts"]
  }
}
```

### New: Enhanced Name Verification (Step 7.3)

Tasks now verify names using a multi-source approach:
1. **Predecessor Artifacts**: Trust exports_added from completed predecessor tasks
2. **Live Grep Search**: Always-fresh verification against actual codebase
3. **Context Summary** (fallback): Pre-computed refs for initial guidance

### Changed: Artifact Collection (Step 7.7)

Step 7.7 now uses `COLLECT_ARTIFACTS_PATTERN` instead of codebase-indexer:
- Captures git diff for file changes
- Extracts exports via Grep from new files
- Persists to tasks.json via `UPDATE_TASK_METADATA_PATTERN`

### Changed: Worker Result Format (task-orchestrator)

Workers now return artifact fields:
- `functions_created`: New function/class names
- `exports_added`: All new exports
- `test_files`: Test files created/modified

### Changed: codebase-names Skill (v2.1)

Skill now uses live Grep + task artifacts instead of static index:
- Queries tasks.json for predecessor artifacts
- Performs live Grep for verification
- Falls back to static index only as hint (if exists)

### Deprecated: codebase-indexer Subagent

The codebase-indexer subagent is now deprecated:
- Static index becomes stale during task execution
- No automatic update mechanism was implemented
- Live search + task artifacts are more reliable

### Deprecated: /index-codebase Command (Optional/Legacy)

Command is now optional, recommended only for:
- Initial project exploration
- Generating human-readable documentation
- Legacy compatibility

### New Patterns in task-json.md

- `COLLECT_ARTIFACTS_PATTERN`: Collect artifacts from git diff
- `QUERY_PREDECESSOR_ARTIFACTS_PATTERN`: Get artifacts from predecessor tasks
- `VERIFY_PREDECESSOR_OUTPUTS_PATTERN`: Verify predecessors' outputs exist

### Fixed: Phase File Loading Enforcement

Strengthened phase-based execution to prevent agents from skipping critical workflow steps:

**Problem**: Agents could bypass phase file loading and skip directly to implementation, missing git-workflow subagent calls (no branch setup, no commit, no PR).

**Solution**: Added mandatory enforcement language throughout `execute-tasks.md`:
- Prominent warning banner at top of file
- `MUST DO:` and `GATE:` language for each phase
- Explicit Read tool instructions (not just `@` references)
- Phase Enforcement Checklist before task completion
- Clear explanation of consequences (missing git workflow)

**Changed Files**:
- `commands/execute-tasks.md`: Added enforcement sections at lines 3-10, 186-207, 214-306

---

## [2.0.0] - 2025-12-11

### Parallel Async Agent Execution

Major update enabling **true parallel task execution** using Claude Code's async agent capabilities. Tasks without dependencies now run simultaneously, providing significant speedup for multi-task specs.

### New: Parallel Wave Execution

Tasks are automatically analyzed for dependencies and grouped into execution waves:

```
Wave 1: Independent Tasks (run in parallel)
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│   Worker 1   │   │   Worker 2   │   │   Worker 3   │
│  (Task 1)    │   │  (Task 2)    │   │  (Task 3)    │
└──────────────┘   └──────────────┘   └──────────────┘
       │                  │                  │
       └──────────────────┼──────────────────┘
                          │
                   AgentOutputTool
                   (collect all results)
                          │
                          ▼
Wave 2: Dependent Tasks (after Wave 1 completes)
```

**Mechanism:**
- `Task` tool with `run_in_background: true` spawns parallel workers
- `AgentOutputTool` collects results from all workers
- Pre-computed `execution_strategy` in `tasks.json` defines waves

**Performance:**
| Spec Structure | Sequential | Parallel | Speedup |
|----------------|------------|----------|---------|
| All independent | 150 min | 50 min | **3x** |
| 2 waves | 150 min | 90 min | **1.67x** |
| All dependent | 150 min | 150 min | 1x |

### New: Dependency Analysis at Task Creation

`/create-tasks` now analyzes task dependencies to generate parallel execution strategy:

```json
{
  "execution_strategy": {
    "mode": "parallel_waves",
    "waves": [
      { "wave_id": 1, "tasks": ["1", "2"], "rationale": "No shared files" },
      { "wave_id": 2, "tasks": ["3"], "rationale": "Depends on task 1" }
    ],
    "estimated_parallel_speedup": 1.5,
    "max_concurrent_workers": 2
  }
}
```

**Analysis Criteria:**
- File overlap detection (shared_files)
- Logical dependencies (blocked_by, blocks)
- Isolation scoring (0-1 scale)

### New: Parallel Context in Context Summaries

`context-summary.json` now includes `parallel_context` for each task:

```json
{
  "parallel_context": {
    "wave": 1,
    "concurrent_tasks": ["2"],
    "conflict_risk": "low",
    "shared_resources": [],
    "worker_instructions": "Independent execution safe."
  }
}
```

### New: Four Execution Modes

| Mode | When Used | Description |
|------|-----------|-------------|
| Direct Single | 1 task | Full instructions, no delegation |
| Sequential Orchestrated | 2+ tasks with dependencies | Workers per task, sequential |
| **Parallel Waves** | 2+ independent tasks | **Workers per wave, concurrent** |
| Direct Multi | Override only | All in session (not recommended) |

### Enhanced Task Orchestrator (v2.0)

The task-orchestrator subagent now supports parallel execution:

- Reads `execution_strategy.waves` from `tasks.json`
- Spawns parallel workers using `run_in_background: true`
- Tracks active `agentId` for each worker
- Collects results via `AgentOutputTool`
- Updates `tasks.json` with completion status

### New Shared Module

- `shared/parallel-execution.md` - Patterns for async agent coordination:
  - `SPAWN_PARALLEL_WORKERS_PATTERN`
  - `COLLECT_WORKER_RESULTS_PATTERN`
  - `MONITOR_WORKERS_PATTERN`
  - `EXECUTE_WAVE_WITH_RETRY_PATTERN`
  - `ORCHESTRATE_PARALLEL_EXECUTION_PATTERN`

### Updated Shared Modules

- `shared/task-json.md` (v2.0) - Added parallelization schema
- `shared/context-summary.md` (v2.0) - Added parallel_context patterns

### Updated Commands

- **create-tasks.md**: New Step 1.5 for dependency analysis
- **execute-tasks.md**: New Mode 3 (Parallel Wave Execution)
- **phases/execute-phase2.md**: Added parallel execution alternative

### Updated Agents

- **task-orchestrator.md**: Full parallel wave support

### Migration Notes

**For existing projects:**
- Existing `tasks.json` files without `execution_strategy` use sequential mode
- Run `/create-tasks` again to generate parallel analysis
- No breaking changes - parallel is opt-in when waves are detected

**New features require:**
- Claude Code with `run_in_background` Task parameter support
- `AgentOutputTool` for result collection

---

## [1.9.0] - 2025-12-09

### Context Efficiency Architecture

Major update based on Anthropic's "Effective Harnesses for Long-Running Agents" research. This release introduces architectural changes to prevent context window bloat during long task execution sessions.

### New: Task Orchestrator Pattern

For multi-task sessions, a new orchestrator subagent delegates to worker agents:

```
┌─────────────────────────────────────────────────────────┐
│ TASK ORCHESTRATOR (minimal state, coordinates)          │
└─────────────────────────────────────────────────────────┘
        ↓ spawns
┌─────────────────────────────────────────────────────────┐
│ TASK WORKER (full context for ONE task, terminates)     │
└─────────────────────────────────────────────────────────┘
```

**Benefits:**
- Workers start with fresh context (no accumulation)
- Scalable to arbitrarily long task lists
- Consistent code quality throughout session

**New Files:**
- `.claude/agents/task-orchestrator.md` - Multi-task coordination

### New: Phase-Based Instruction Loading

The `execute-tasks` command now loads instructions on-demand:

```
execute-tasks.md (~360 lines, shell)
├── phases/execute-phase0.md (~50 lines) - Session startup
├── phases/execute-phase1.md (~150 lines) - Task discovery
├── phases/execute-phase2.md (~200 lines) - Implementation
└── phases/execute-phase3.md (~150 lines) - Completion
```

**Savings:** Only ~500 lines loaded at any time vs ~636 all at once

### New: Pre-Computed Context Summaries

`create-tasks` now generates `context-summary.json` alongside `tasks.json`:

| Approach | Tokens per Task |
|----------|-----------------|
| Full spec discovery | ~3,000 |
| Pre-computed summary | ~800 |
| **Savings** | **~73%** |

**New Files Created by `/create-tasks`:**
- `tasks.json` - Machine-readable task status (primary format)
- `context-summary.json` - Pre-computed per-task context

### New: Stricter Single-Task Default

Research shows single-task focus dramatically improves completion rates:

```
IF 2+ tasks selected:
  OFFER:
    1. Single task focus - RECOMMENDED (was: warning only)
    2. Orchestrated execution - NEW
    3. Direct multi-task - requires explicit override
```

### Three Execution Modes

| Mode | Tasks | Strategy | Recommendation |
|------|-------|----------|----------------|
| Direct Single | 1 | Full instructions | DEFAULT |
| Orchestrated | 2+ | Workers per task | For long sessions |
| Direct Multi | 2+ | All in session | Not recommended |

### New Shared Modules

- `shared/context-summary.md` - Patterns for pre-computed task context
- `shared/task-json.md` - Patterns for machine-readable task tracking (enhanced)

### Updated Commands

- **execute-tasks.md**: Now lightweight shell (~360 lines vs ~636)
- **create-tasks.md**: Generates tasks.json + context-summary.json

### Migration Notes

**For existing projects:**
- Existing `tasks.md` files continue to work (markdown is still source of truth)
- `tasks.json` and `context-summary.json` are generated alongside
- Orchestrator mode is optional (direct mode still available)
- Phase files are loaded automatically when needed

**No breaking changes** - all v1.8.0 workflows continue to function.

---

## [1.8.0] - 2025-12-08

### Upstream Integration from buildermethods/agent-os

This release integrates selected components from the main AgentOS repository (v2.1.1) while preserving our embedded instruction architecture for reliability.

### New Command: `/shape-spec` (Specification Shaping Phase)

New lightweight command for exploring and refining feature concepts before full specification.

**Purpose:**
- Explore feasibility before investing in full spec
- Analyze trade-offs between multiple approaches
- Define clear scope boundaries
- Validate ideas quickly

**Workflow:**
| Step | Action |
|------|--------|
| 1 | Understand feature concept |
| 2 | Check product alignment |
| 3 | Explore technical feasibility |
| 4 | Identify 2-3 approaches |
| 5 | Analyze trade-offs |
| 6 | Define scope boundaries |
| 7 | Create shaped spec summary |
| 8 | Get user validation |

**Creates:** `.agent-os/specs/shaped/YYYY-MM-DD-concept-name.md`

**Next Step:** Run `/create-spec` to generate full specification

### Categorized Standards Structure

Standards are now organized by domain for better discoverability in larger projects:

```
standards/
├── global/           # Cross-cutting concerns
│   ├── coding-style.md
│   ├── conventions.md
│   ├── error-handling.md
│   ├── validation.md
│   └── tech-stack.md
├── frontend/         # UI development
│   ├── react-patterns.md
│   └── styling.md
├── backend/          # Server-side development
│   ├── api-design.md
│   └── database.md
└── testing/          # Test patterns
    └── test-patterns.md
```

### New Skill: `implementation-verifier`

End-to-end verification skill that auto-invokes after completing all tasks in a spec.

**Verification Steps:**
1. **Task Completion Audit** - Verify all task checkboxes marked complete
2. **Specification Compliance** - Match implementation to spec requirements
3. **Test Suite Validation** - Run full test suite, check coverage
4. **Roadmap Synchronization** - Update completed items in roadmap
5. **Report Generation** - Create verification report

**Output:** `.agent-os/verification/YYYY-MM-DD-[spec-name].md`

### New Optional Skill: `standards-to-skill`

Template and guide for converting standards documents into Claude Code skills.

**Use When:**
- Converting existing standards to auto-invoked skills
- Creating new standards that warrant automatic application
- Optimizing how standards are surfaced during development

### Installation Updates

```bash
# Default installation now includes 9 skills (was 8)
./setup/project.sh --claude-code

# Full installation now includes 5 optional skills (was 4)
./setup/project.sh --claude-code --full-skills
```

**New Commands:**
- `/shape-spec` - Specification shaping phase

**New Skills (Default):**
- `implementation-verifier` - End-to-end verification

**New Skills (Optional):**
- `standards-to-skill` - Standards conversion template

**Skills Total:** 9 default + 5 optional = 14 skills

---

## [1.7.0] - 2025-12-08

### Progress Log System (Cross-Session Memory)

Based on Anthropic's "Effective Harnesses for Long-Running Agents" research, this release implements persistent progress logging for cross-session memory.

**Reference**: https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents

**New Features:**

| Feature | Description |
|---------|-------------|
| **Progress Log** | Permanent chronological log of accomplishments (`progress.json`) |
| **Human-Readable Log** | Auto-generated markdown version (`progress.md`) |
| **Archive System** | Automatic archival of entries older than 30 days |
| **Cross-Session Context** | New sessions can read previous accomplishments |

**Problem Solved:**

Previously, session cache expired after 1 hour max, losing all context between sessions. Now progress persists indefinitely, enabling:
- Context continuity across unlimited sessions
- Blocker tracking visible across sessions
- Team visibility via version-controlled progress files

**Integration Points:**

| Step | Event Logged | When |
|------|-------------|------|
| Step 6.5 | `session_started` | After Phase 1 (environment verified) |
| Step 7.10 | `task_completed` | After each parent task |
| Step 15 | `session_ended` | After Phase 3 (workflow complete) |

**New Files:**

- `shared/progress-log.md` - Canonical patterns for progress logging
- `shared/task-json.md` - Patterns for JSON task tracking
- `claude-code/skills/session-startup.md` - Session startup protocol skill
- `.agent-os/progress/progress.json` - Machine-readable progress data
- `.agent-os/progress/progress.md` - Human-readable progress log
- `.agent-os/progress/archive/` - Archived old entries
- `tests/progress-log-validation.md` - Validation procedures

### Session Startup Protocol (New Skill)

New `session-startup` skill auto-invokes at execute-tasks start:

| Step | Purpose |
|------|---------|
| 1. Directory verification | Confirm project root |
| 2. Progress context load | Read recent accomplishments |
| 3. Git state review | Check branch, uncommitted changes |
| 4. Task status check | Current spec progress |
| 5. Environment health | Dev server, config files |
| 6. Session focus confirmation | Confirm task selection |

**Benefits**: Cross-session context automatically loaded, blockers highlighted, environment issues caught early.

### Scope Constraint Logic

New Step 1.5 in execute-tasks warns when multiple parent tasks selected:

- Displays research-backed recommendation for single-task focus
- User can override with explicit confirmation
- Overrides logged to progress log for analysis

### JSON Task Format

New `tasks.json` generated alongside `tasks.md`:

```json
{
  "tasks": [{
    "id": "1.1",
    "status": "pass",
    "attempts": 2,
    "duration_minutes": 45
  }],
  "summary": {
    "completed": 5,
    "total_tasks": 10,
    "overall_percent": 50
  }
}
```

**Benefits**: Programmatic task queries, attempt tracking, duration metrics.

**Installation:**

All features automatically available on new installations:
```bash
./setup/project.sh --claude-code
```

Existing installations get new features on upgrade:
```bash
./setup/project.sh --claude-code --upgrade
```

**Skills Total:** 8 default + 4 optional = 12 skills

---

## [1.6.0] - 2025-12-05

### Extended Skills Library

Major skills expansion integrating battle-tested development workflow skills from the community (obra/superpowers) and official Anthropic skills.

**New Tier 1 Skills (Default - Always Installed):**

| Skill | Purpose | Source |
|-------|---------|--------|
| systematic-debugging | 4-phase root cause analysis before fixes | obra/superpowers |
| tdd | RED-GREEN-REFACTOR cycle enforcement | obra/superpowers |
| brainstorming | Socratic design refinement through questioning | obra/superpowers |
| writing-plans | Detailed micro-task breakdown (2-5 min tasks) | obra/superpowers |

**New Tier 2 Skills (Optional - `--full-skills` flag):**

| Skill | Purpose | Source |
|-------|---------|--------|
| code-review | Pre-review checklists, feedback integration | obra/superpowers |
| verification | Evidence-based completion verification | obra/superpowers |
| skill-creator | Guide for creating custom Agent OS skills | anthropics/skills |
| mcp-builder | Guide for creating MCP servers | anthropics/skills |

**Command Integrations:**

| Command | New Skills Integrated |
|---------|----------------------|
| debug.md | systematic-debugging (root cause analysis) |
| create-spec.md | brainstorming (scope exploration) |
| create-tasks.md | tdd, writing-plans (TDD structure) |
| execute-tasks.md | tdd, verification (implementation gates) |

**Installation:**

```bash
# Default (7 skills)
./setup/project.sh --claude-code

# Full (11 skills including optional)
./setup/project.sh --claude-code --full-skills
```

**Skills Total:** 7 default + 4 optional = 11 skills

---

## [1.5.0] - 2025-12-05

### Native Claude Code Integration - BREAKING CHANGE

Major architectural update to leverage Claude Code's native features, reducing complexity while preserving unique value. **This is a breaking change requiring re-installation in existing projects.**

**Component Changes:**
- Subagents reduced from 9 to 3 (56% reduction)
- Added 3 new Skills (model-invoked capabilities)
- Commands simplified to use native Explore agent

### Retired Subagents (6)

| Agent | Replacement |
|-------|-------------|
| date-checker | Native environment context (Claude receives date in every session) |
| file-creator | Native Write tool + embedded templates in commands |
| spec-cache-manager | Native Explore agent (fast enough without caching) |
| context-fetcher | Native Explore agent + codebase-names Skill |
| test-runner | Converted to test-check Skill |
| build-checker | Converted to build-check Skill |

### New Skills (3)

Skills are model-invoked - Claude automatically decides when to use them based on context.

| Skill | Purpose |
|-------|---------|
| build-check | Auto-invoked before git commits to verify build and classify errors |
| test-check | Auto-invoked after code changes to run tests and analyze failures |
| codebase-names | Auto-invoked when writing code to validate existing function/variable names |

### Remaining Subagents (3)

| Agent | Purpose |
|-------|---------|
| git-workflow | Branch management, commits, PRs (unique conventions) |
| codebase-indexer | Code reference updates and compliance tracking |
| project-manager | Task/roadmap state management |

### Key Benefits

- **56% fewer custom components** (9 subagents → 3 subagents + 3 skills)
- **Automatic quality gates** via Skills (tests & builds never forgotten)
- **Faster execution** using native Explore agent
- **Simpler maintenance** (fewer custom components to maintain)
- **Better alignment** with Claude Code's native patterns

### Migration

This is a breaking change. Existing AgentOS installations must re-run the installer:
```bash
./setup/project.sh --claude-code
```

## [1.4.1] - 2025-08-18

### Replaced Decisions with Recaps

Earlier versions added a decisions.md inside a project's .agent-os/product/.  In practice, this was rarely used and didn't help future development.

It's been replaced with a new system for creating "Recaps"—short summaries of what was built—after every feature spec's implementation has been completed.  Similar to a changelog, but more descriptive and context-focused.  These recaps are easy to reference by both humans and AI agents.

Recaps are automatically generated via the new complete-tasks.md process.

### Added Project-Manager Subagent

A goal of this update was to tighten up the processes for creating specs and executing tasks, ensuring these processes are executed reliably.  Sounds like the job for a "project manager".

This update introduces a new subagent (for Claude Code) called project-manager which handles all task completion, status updates, and reporting progress back to you.

### Spec Creation & Task Execution Reliability Improvements

Several changes to the instructions, processes, and executions, all aimed at helping agents follow the process steps consistently.

- Consolidated task execution instructions with clear step-by-step processes
- Added post-flight verification rules to ensure instruction compliance
- Improved subagent delegation tracking and reporting
- Standardized test suite verification and git workflow integration
- Enhanced task completion criteria validation and status management

## [1.4.0] - 2025-08-17

BIG updates in this one!  Thanks for all the feedback, requests and support 🙏

### All New Installation Process

The way Agent OS gets installed is structured differently from prior versions.  The new system works as follows:

There are 2 installation processes:
- Your "Base installation" (now optional, but still recommended!)
- Your "Project installation"

**"Base installation"**
- Installs all of the Agent OS files to a location of your choosing on your system where they can be customized (especially your standards) and maintained.
- Project installations copy files from your base installation, so they can be customized and self-contained within each individual project.
- Your base installation now has a config.yml

To install the Agent OS base installation,

1. cd to a location of your choice (your system's home folder is a good choice).

2. Run one of these commands:
  - Agent OS with Claude Code support:
  `curl -sSL https://raw.githubusercontent.com/buildermethods/agent-os/main/setup/base.sh | bash -s -- --claude-code`
  - Agent OS with Cursor support:
  `curl -sSL https://raw.githubusercontent.com/buildermethods/agent-os/main/setup/base.sh | bash -s -- --cursor`
  - Agent OS with Claude Code & Cursor support:
  `curl -sSL https://raw.githubusercontent.com/buildermethods/agent-os/main/setup/base.sh | bash -s -- --claude-code --cursor`

3. Customize your /standards (just like earlier versions)

**Project installation**

- Now each project codebase gets it's own self-contained installation of Agent OS.  It no longer references instructions or standards that reside elsewhere on your system.  These all get installed directly into your project's .agent-os folder, which brings several benefits:
  - No external references = more reliable Agent OS commands & workflows.
  - You can commit your instructions, standards, Claude Code commands and agents to your project's github repo for team access.
  - You can customize standards differently per project than what's in your base installation.

Your project installation command will be based on where you installed the Agent OS base installation.
- If you've installed it to your system's home folder, then your project installation command will be `~/.agent-os/setup/project.sh`.
- If you've installed it elsewhere, your command will be `/path/to/agent-os/setup/project.sh`
(after your base installation, it will show you _your_ project installation command. It's a good idea to save it or make an alias if you work on many projects.)

If (for whatever reason) you didn't install the base installation, you can still install Agent OS directly into a project, by pulling it directly off of the public github repo using the following command.
- Note: This means your standards folder won't inherit your defaults from a base installation. You'd need to customize the files in the standards folder for this project.
`curl -sSL https://raw.githubusercontent.com/buildermethods/agent-os/main/setup/project.sh | bash -s -- --no-base --claude-code --cursor`

### Agent OS config.yml

When you install the Agent OS base installation, that now includes a config.yml file.  Currently this file is used for:
- Tracking the Agent OS version you have installed
- Which coding agents (Claude Code, Cursor) you're using
- Project Types (new! read on...)

### Project Types

If you work on different types of projects, you can define different sets of standards, code style, and instructions for each!

- By default, a new installation of Agent OS into a project will copy its instructions and standards from your base installation's /instructions and /standards.
- You can define additional project types by doing the following:
  - Setup a folder (typically inside your base installation's .agent-os folder, but it can be anywhere on your system) which contains /instructions and /standards folders (copy these from your base install, then customize).
  - Define the project type's folder location on your system in your base install's config.yml
- Using project types:
  - If you've named a project type, 'ruby-on-rails', when running your project install command, add the flag --project-type=ruby-on-rails.
  - To make a project type your default for new projects, set it's name as the value for default_project_type in config.yml

### Removed or changed in version 1.4.0:

This update does away with the old installation script files:
- setup.sh (replaced by /setup/base.sh and /setup/project.sh)
- setup-claude-code.sh (now you add --claude-code flag to the install commands or enable it in your Agent OS config.yml)
- setup-cursor.sh (now you add --cursor flag to the install commands or enable it in your Agent OS config.yml)

Claude Code Agent OS commands now should _not_ be installed in the `~/.agent-os/.claude/commands` folder.  Now, these are copied from ~/.agent-os/commands into each project's `~/.claude/commands` folder (this prevents duplicate commands showing in in Claude Code's commands list).  The same approach applies to Claude Code subagents files.

### Upgrading to version 1.4.0

Follow these steps to update a previous version to 1.4.0:

1. If you've customized any files in /instructions, back those up now. They will be overwritten.

2. Navigate to your home directory (or whichever location you want to have your Agent OS base installation)

3. Run the following to command, which includes flags to overwrite your /instructions (remove the --cursor flag if not using Cursor):
`curl -sSL https://raw.githubusercontent.com/buildermethods/agent-os/main/setup/base.sh | bash -s -- --overwrite-instructions --claude-code --cursor`

4. If your ~/.claude/commands contain Agent OS commands, remove those and copy the versions that are now in your base installation's commands folder into your _project's_ `.claude/commands` folder.

5. Navigate to your project. Run your project installation command to install Agent OS instructions and standards into your project's installation. If your Agent OS base installation is in your system's home folder (like previous versions), then your project installation will be: `~/.agent-os/setup/project.sh`

## [1.3.1] - 2025-08-02

### Added
- **Date-Checker Subagent** - New specialized Claude Code subagent for accurate date determination using file system timestamps
  - Uses temporary file creation to extract current date in YYYY-MM-DD format
  - Includes context checking to avoid duplication
  - Provides clear validation and error handling

### Changed
- **Create-Spec Instructions** - Updated `instructions/core/create-spec.md` to use the new date-checker subagent
  - Replaced complex inline date determination logic with simple subagent delegation
  - Simplified step 4 (date_determination) by removing 45 lines of validation and fallback code
  - Cleaner instruction flow with specialized agent handling date logic

### Improved
- **Code Maintainability** - Date determination logic centralized in reusable subagent
- **Instruction Clarity** - Simplified create-spec workflow with cleaner delegation pattern
- **Error Handling** - More robust date determination with dedicated validation rules

## [1.3.0] - 2025-08-01

### Added
- **Pre-flight Check System** - New `meta/pre-flight.md` instruction for centralized agent detection and initialization
- **Proactive Agent Usage** - Updated agent descriptions to encourage proactive use when appropriate
- **Structured Instruction Organization** - New folder structure with `core/` and `meta/` subdirectories

### Changed
- **Instruction File Structure** - Reorganized all instruction files into subdirectories:
  - Core instructions moved to `instructions/core/` (plan-product, create-spec, execute-tasks, execute-task, analyze-product)
  - Meta instructions in `instructions/meta/` (pre-flight, more to come)
- **Simplified XML Metadata** - Removed verbose `<ai_meta>` and `<step_metadata>` blocks for cleaner, more readable instructions
- **Subagent Integration** - Replaced manual agent detection with centralized pre-flight check across all instruction files to enforce delegation and preserve main agent's context.
- **Step Definitions** - Added `subagent` attribute to steps for clearer delegation of work to help enforce delegation and preserve main agent's context.
- **Setup Script** - Updated to create subdirectories and download files to new locations

### Improved
- **Code Clarity** - Removed redundant XML instructions in favor of descriptive step purposes
- **Agent Efficiency** - Centralized agent detection reduces repeated checks throughout workflows
- **Maintainability** - Cleaner instruction format with less XML boilerplate
- **User Experience** - Clearer indication of when specialized agents will be used proactively

### Removed
- **CLAUDE.md** - Removed deprecated Claude Code configuration file (functionality moved to pre-flight system, preventing over-reading instructions into context)
- **Redundant Instructions** - Eliminated verbose ACTION/MODIFY/VERIFY instruction blocks

## [1.2.0] - 2025-07-29

### Added
- **Claude Code Specialized Subagents** - New agents to offload specific tasks for improved efficiency:
  - `test-runner.md` - Handles test execution and failure analysis with minimal toolset
  - `context-fetcher.md` - Retrieves information from files while checking context to avoid duplication
  - `git-workflow.md` - Manages git operations, branches, commits, and PR creation
  - `file-creator.md` - Creates files, directories, and applies consistent templates
- **Agent Detection Pattern** - Single check at process start with boolean flags for efficiency
- **Subagent Integration** across all instruction files with automatic fallback for non-Claude Code users

### Changed
- **Instruction Files** - All updated to support conditional agent usage:
  - `execute-tasks.md` - Uses git-workflow (branch management, PR creation), test-runner (full suite), and context-fetcher (loading lite files)
  - `execute-task.md` - Uses context-fetcher (best practices, code style) and test-runner (task-specific tests)
  - `plan-product.md` - Uses file-creator (directory creation) and context-fetcher (tech stack defaults)
  - `create-spec.md` - Uses file-creator (spec folder) and context-fetcher (mission/roadmap checks)
- **Standards Files** - Updated for conditional agent usage:
  - `code-style.md` - Uses context-fetcher for loading language-specific style guides
- **Setup Scripts** - Enhanced to install Claude Code agents:
  - `setup-claude-code.sh` - Downloads all agents to `~/.claude/agents/` directory

### Improved
- **Context Efficiency** - Specialized agents use minimal context for their specific tasks
- **Code Organization** - Complex operations delegated to focused agents with clear responsibilities
- **Error Handling** - Agents provide targeted error analysis and recovery strategies
- **Maintainability** - Cleaner main agent code with operations abstracted to subagents
- **Performance** - Reduced context checks through one-time agent detection pattern

### Technical Details
- Each agent uses only necessary tools (e.g., test-runner uses only Bash, Read, Grep, Glob)
- Automatic fallback ensures compatibility for users without Claude Code
- Consistent `IF has_[agent_name]:` pattern reduces code complexity
- All agents follow Agent OS conventions (branch naming, commit messages, file templates)

## [1.1.0] - 2025-07-29

### Added
- New `mission-lite.md` file generation in product initialization for efficient AI context usage
- New `spec-lite.md` file generation in spec creation for condensed spec summaries
- New `execute-task.md` instruction file for individual task execution with TDD workflow
- Task execution loop in `execute-tasks.md` that calls `execute-task.md` for each parent task
- Language-specific code style guides:
  - `standards/code-style/css-style.md` for CSS and TailwindCSS
  - `standards/code-style/html-style.md` for HTML markup
  - `standards/code-style/javascript-style.md` for JavaScript
- Conditional loading blocks in `best-practices.md` and `code-style.md` to prevent duplicate context loading
- Context-aware file loading throughout all instruction files

### Changed
- Optimized `plan-product.md` to generate condensed versions of documents
- Enhanced `create-spec.md` with conditional context loading for mission-lite and tech-stack files
- Simplified technical specification structure by removing multiple approach options
- Made external dependencies section conditional in technical specifications
- Updated `execute-tasks.md` to use minimal context loading strategy
- Improved `execute-task.md` with selective reading of relevant documentation sections
- Modified roadmap progress check to be conditional and context-aware
- Updated decision documentation to avoid loading decisions.md and use conditional checks
- Restructured task execution to follow typical TDD pattern (tests first, implementation, verification)

### Improved
- Context efficiency by 60-80% through conditional loading and lite file versions
- Reduced duplication when files are referenced multiple times in a workflow
- Clearer separation between task-specific and full test suite execution
- More intelligent file loading that checks current context before reading
- Better organization of code style rules with language-specific files

### Fixed
- Duplicate content loading when instruction files are called in loops
- Unnecessary loading of full documentation files when condensed versions suffice
- Redundant test suite runs between individual task execution and overall workflow

## [1.0.0] - 2025-07-21

### Added
- Initial release of Agent OS framework
- Core instruction files:
  - `plan-product.md` for product initialization
  - `create-spec.md` for feature specification
  - `execute-tasks.md` for task execution
  - `analyze-product.md` for existing codebase analysis
- Standard files:
  - `tech-stack.md` for technology choices
  - `code-style.md` for formatting rules
  - `best-practices.md` for development guidelines
- Product documentation structure:
  - `mission.md` for product vision
  - `roadmap.md` for development phases
  - `decisions.md` for decision logging
  - `tech-stack.md` for technical architecture
- Setup scripts for easy installation
- Integration with AI coding assistants (Claude Code, Cursor)
- Task management with TDD workflow
- Spec creation and organization system

[1.4.1]: https://github.com/buildermethods/agent-os/compare/v1.4.0...v1.4.1
[1.4.0]: https://github.com/buildermethods/agent-os/compare/v1.3.1...v1.4.0
[1.3.1]: https://github.com/buildermethods/agent-os/compare/v1.3.0...v1.3.1
[1.3.0]: https://github.com/buildermethods/agent-os/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/buildermethods/agent-os/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/buildermethods/agent-os/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/buildermethods/agent-os/releases/tag/v1.0.0
