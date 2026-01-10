# Changelog

All notable changes to Agent OS will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


## [Unreleased] - v4.9.0 Architecture Refinement

### Added

- **Subtask Expansion Skill**: Extracted inline subtask logic from phase1-discovery into reusable `.claude/skills/subtask-expansion/SKILL.md` with complexity heuristics and TDD templates (Wave 1, PR #3)

- **Spec Templates**: Added template library for common spec types - feature.md, bugfix.md, refactor.md, integration.md at `.claude/templates/specs/` (Wave 1, PR #3)

- **Dependency Detection**: New `detectDependencies` function in create-spec analyzing imports and package relationships (Wave 1, PR #3)

- **Feasibility Analysis**: Added `analyzeFeasibility` using Explore agent in shape-spec (Wave 1, PR #3)

- **AST-Based Verification System**: New `.claude/scripts/ast-verify.ts` using TypeScript compiler API for accurate export/function detection, replacing brittle grep patterns (Wave 2, PR #4)

- **Verification Caching**: File hash-based caching in `.agent-os/cache/verification/` to avoid redundant verification checks (Wave 2, PR #4)

- **Task Templates**: Four JSON templates for common task patterns at `.claude/templates/tasks/` - api-endpoint, react-component, bugfix, refactor (Wave 2, PR #4)

- **Test Pattern Discovery**: New `discoverTestPatterns()` utility in phase2-implementation reading from jest.config.js and vitest.config.ts (Wave 2, PR #4)

### Changed

- **Classifier Batch Processing**: comment-classifier now processes in batches of 10 for 20+ items (Wave 1, PR #3)

- **Explore-Based Complexity**: future-classifier uses Explore agent instead of crude heuristics for complexity estimation (Wave 1, PR #3)

- **Create-Tasks Command**: Enhanced with `analyzeComplexity()` for complexity scoring, `validateSpec()` gate for spec completeness, and `selectTaskTemplate()` for template-based task generation (Wave 2, PR #4)

- **Wave Orchestrator**: Integrated `verifyWithCache()` and `batchVerifyExports()` for AST-based artifact verification with caching (Wave 2, PR #4)

- **Phase2 Implementation**: Added context compression via `invokeContextSummary()` between subtasks, explicit `executeSubtask()` flow with context handoff (Wave 2, PR #4)

## [4.7.1] - 2026-01-09

### Added

- **Explicit `AskUserQuestion` tool integration in spec commands**: Added structured decision points to `/shape-spec` and `/create-spec` for better user interaction
  - Clear handoff pattern: `Explore Agent (autonomous) → AskUserQuestion (decision) → Continue`
  - Distinguishes autonomous codebase exploration from user decision points
  - Prevents vague "ASK" directives that left Claude guessing how to interact

### Changed

- **`/shape-spec`**:
  - Added `AskUserQuestion` to Native Integration tool table
  - Step 2 (Concept Understanding): Optional structured question for feature type classification
  - Step 6 (Approach Exploration): Split into Phase A (brainstorming) + Phase B (AskUserQuestion for selection)
  - Step 7 (Scope Definition): Multi-select AskUserQuestion for in-scope/out-of-scope confirmation

- **`/create-spec`**:
  - Added Tool Handoff Pattern section explaining Explore → AskUserQuestion → brainstorming flow
  - Step 1 (Spec Initiation): Marked as USER DECISION POINT with roadmap acceptance options
  - Step 3 (Requirements Clarification): Split into Phase A/B/C with approach selection AskUserQuestion
  - Step 11 (User Review): Full approval workflow with Approve/Request Changes/Major Revision/Cancel
  - Subagent Integration: New table mapping tools to purposes and usage patterns

## [4.6.3] - 2026-01-04

### Fixed

- **PR Review: HIGH items no longer deferred to FUTURE**: Added validation to ensure reviewer-marked HIGH priority items are addressed immediately, not captured for future waves
  - Added "HIGH OVERRIDES FUTURE" rule to comment-classifier
  - HIGH signals ("high priority", "must fix", "blocking", etc.) now override section headers
  - Post-classification validation in discovery agent reclassifies misplaced HIGH items
  - Implementation agent validates FUTURE bucket before capturing

### Changed

- `comment-classifier.md`: Added explicit rule that HIGH signals override FUTURE section headers
- `pr-review-discovery.md`: Added step 2e to validate no HIGH items in FUTURE bucket
- `pr-review-implementation.md`: Added pre-check before capturing FUTURE items

## [4.6.2] - 2026-01-04

### Fixed

- **CRITICAL: Orchestrator stops after wave 1**: The `for` loop pseudocode lacked explicit continuation instructions. The agent would complete wave 1 successfully but not continue to wave 2.
  - Root cause: `// Continue loop to next wave` was just a comment - no explicit instruction for agent to iterate
  - Symptom: First `/execute-spec` run stops after wave 1 merges; restart continues from wave 2
  - Fix: Changed to labeled `WAVE_LOOP: while(wave <= TOTAL_WAVES)` with explicit `wave++` and `continue WAVE_LOOP`
  - Added `CRITICAL` callout box explaining loop must iterate through ALL waves

### Changed

- Orchestrator wave loop now uses `while` pattern with explicit increment and `continue` statement
- Matches the labeled loop pattern already used in wave-lifecycle-agent's re-review loop

## [4.6.1] - 2026-01-02

### Fixed

- **CRITICAL: Removed non-existent `record-wave` call**: Orchestrator was calling `record-wave` which doesn't exist in the operations script. Removed the call since `advance-wave` already handles recording wave history.

- **CRITICAL: Fixed phase name mismatch**: Wave-lifecycle-agent was using `PROCESS_REVIEW` but the state machine uses `REVIEW_PROCESSING`. Updated all references to use correct phase names.

- **CRITICAL: Implemented proper re-review loop**: Previous version used pseudo-GOTO instructions that wouldn't work. Rewrote with proper labeled `while(true)` loop structure with `break` and `continue` statements.

- **HIGH: Added poll count state synchronization**: Polling loop now syncs `poll_count` to state file after each iteration, enabling crash recovery to resume polling from correct position.

- **HIGH: Added resume phase support**: Wave-lifecycle-agent now accepts `resume_phase` input parameter. Orchestrator passes current phase when resuming, allowing wave agent to skip completed steps.

### Changed

- Wave-lifecycle-agent input format now includes optional `resume_phase` field
- Orchestrator prompt to wave agent now includes phase-specific resume instructions
- Polling loop saves state after each poll for durability

## [4.6.0] - 2026-01-02

### Added

- **Wave-based PR review workflow**: Full state machine implementation for multi-wave PR review cycles
  - `execute-spec-orchestrator.md`: Top-level coordinator managing spec execution across waves
  - `wave-lifecycle-agent.md`: Individual wave manager handling task execution → PR → review cycle
  - `state-machine.json`: Wave state tracking with phases: PREP, IMPL, REVIEW_PENDING, REVIEW_PROCESSING, COMPLETE
  - `wave-operations.sh`: CLI for state transitions (create-state, advance-wave, set-phase, record-review)

- **PR Review Classification System**: Intelligent review comment categorization
  - `comment-classifier.md`: Classifies PR comments into HIGH/MEDIUM/LOW/FUTURE buckets
  - `future-classifier.md`: Further categorizes FUTURE items as WAVE_TASK or ROADMAP_ITEM
  - `roadmap-integrator.md`: Graduates ROADMAP_ITEM entries to product roadmap

- **Task Operations Enhancement**: Extended task management capabilities
  - `task-operations.sh list-future`: List future_tasks from tasks.json
  - `task-operations.sh graduate`: Move future tasks to roadmap or next spec
  - `task-operations.sh promote`: Upgrade future task to specific wave
  - Automatic backlog graduation gate in Phase 3 delivery

### Changed

- `/execute-tasks` now coordinates with wave-lifecycle-agent for PR-aware execution
- Phase 3 delivery includes mandatory backlog graduation before PR creation
- Progress logging includes wave and phase information

## [4.5.0] - 2025-12-28

### Added

- **Codebase Reference System**: Intelligent dependency tracking across specs
  - `.agent-os/codebase/` directory structure for storing analyzed codebase state
  - `codebase-reference.json` schema for recording existing patterns, exports, and file structures
  - Auto-population during `/analyze-product` and `/create-spec` workflows

- **Task Dependency Visualization**: Enhanced task breakdown with dependency graphs
  - `dependency_map` field in tasks.json showing inter-task relationships
  - `blocked_by` arrays for explicit predecessor tracking
  - Visual dependency tree in tasks.md output

- **Artifact Collection System**: Automatic tracking of task outputs
  - `artifacts` field in tasks.json capturing files_created, exports_added, functions_created
  - Predecessor artifact verification before task execution
  - Cumulative artifact aggregation in Phase 3 delivery

### Changed

- `/create-tasks` now analyzes codebase references for complexity estimation
- Phase 2 implementation validates predecessor artifacts exist before starting
- Phase 3 delivery aggregates all task artifacts for PR description

## [4.4.0] - 2025-12-20

### Added

- **Skills Hot-Reload**: Skills can be modified without restarting Claude Code session
  - Skills discovered via glob pattern `.claude/skills/*/SKILL.md`
  - Invoked via `/skill-name` pattern in conversations
  - `context: fork` option for isolated execution

- **Artifact Verification Skill**: Validates predecessor task outputs exist
  - Checks for expected exports and files from predecessor tasks
  - Runs automatically at task boundaries
  - Fails fast if critical artifacts missing

- **Context Summary Skill**: Compresses context for agent handoffs
  - Extracts key decisions, files modified, and state changes
  - Reduces token usage during multi-agent workflows
  - Invocable via `/context-summary`

- **TDD Helper Skill**: Guides RED-GREEN-REFACTOR cycle
  - Structured prompts for each TDD phase
  - Test failure analysis and fix suggestions
  - Invocable via `/tdd-helper`

### Changed

- Phase 2 now invokes context-summary between subtask transitions
- Skill discovery is lazy-loaded on first invocation
- Skills directory structure documented in CLAUDE.md

## [4.3.0] - 2025-12-15

### Added

- **Wave-Aware Branch Strategy**: Multi-wave implementations get isolated branches
  - Base branch: `feature/SPEC-NAME` (accumulates all waves)
  - Wave branches: `feature/SPEC-NAME-wave-N` (individual wave work)
  - Wave PRs merge to base branch, final PR merges base to main
  - `branch-setup.sh` script with `create`, `pr-target`, `validate` commands

- **Execution Strategy in tasks.json**: Task parallelization metadata
  - `execution_strategy.waves` array grouping tasks by execution order
  - `dependency_graph` mapping task relationships
  - `estimated_parallel_speedup` calculation
  - `can_parallel_with` arrays on individual tasks

### Changed

- Phase 3 delivery uses `branch-setup.sh pr-target` to determine merge target
- Wave PRs include "Merge Target" note in description
- Final PR aggregates all wave summaries

## [4.2.0] - 2025-12-10

### Added

- **Subagent Lifecycle Hooks** (v4.8.0 backport):
  - `SubagentStart` hook initializes agent context and tracks spawn time
  - `SubagentStop` hook captures transcript and logs duration
  - Metrics stored in `.agent-os/metrics/agents.jsonl`
  - Last 20 transcripts retained in `.agent-os/metrics/transcripts/`

- **Agent Security Hardening**: Classification agents use `disallowedTools`
  - `comment-classifier`: Read-only (no Write, Edit, Bash, NotebookEdit)
  - `future-classifier`: Read-only (no Write, Edit, Bash, NotebookEdit)
  - `roadmap-integrator`: Read-only (no Write, Edit, Bash, NotebookEdit)

### Changed

- Agent definitions include explicit `tools` and `disallowedTools` frontmatter
- Subagent invocations include metrics tracking automatically
- CLAUDE.md documents new hook types and agent security patterns

## [4.1.0] - 2025-12-05

### Added

- **Progress Log Gitignore**: `.agent-os/progress/` added to .gitignore (v3.8.0+)
  - Prevents merge conflicts from parallel sessions
  - Progress.json is local-only session state
  - Recaps directory still tracked for documentation

- **Checkpoint Recovery**: SessionEnd hook saves resumption state
  - Captures current task, subtask, and phase
  - SessionStart hook loads and reports checkpoint
  - Native Claude Code `Esc+Esc` checkpointing also available

### Changed

- Progress.json includes `last_checkpoint` field with resumption data
- SessionStart hook prints resumption guidance when checkpoint exists
- Documentation clarifies progress log is local-only

## [4.0.0] - 2025-12-01

### Added

- **Single-Source Tasks**: tasks.json is now the source of truth
  - tasks.md auto-generated from JSON (read-only)
  - PostToolUse hook regenerates markdown on JSON changes
  - `json-to-markdown.js` script for manual regeneration

- **Hook-Enforced Validation Gates**: PreToolUse hooks for git commit
  - Build must pass before commit
  - Tests must pass before commit
  - Types must check before commit
  - Cannot be skipped by model behavior

- **Memory Hierarchy**: CLAUDE.md replaces embedded command instructions
  - Core memory in `.claude/CLAUDE.md`
  - Rule imports via `@import rules/*.md`
  - User-specific overrides in `~/.claude/CLAUDE.md`

### Changed

- All command files reference CLAUDE.md instead of embedding full instructions
- Task editing goes through JSON, not markdown
- Hooks are deterministic - always run regardless of model behavior

### Removed

- Inline instruction blocks in command files
- Manual tasks.md editing (now auto-generated)
- Optional validation steps (now mandatory via hooks)

## [3.9.0] - 2025-11-25

### Added

- **TDD Workflow Rule**: Mandatory test-first development
  - RED phase: Write failing test first
  - GREEN phase: Minimal implementation to pass
  - REFACTOR phase: Clean up while keeping tests green
  - Documented in `.claude/rules/tdd-workflow.md`

- **Git Conventions Rule**: Standardized git practices
  - Branch naming: `feature/SPEC-NAME-brief-description`
  - Commit message format with scope
  - PR description template
  - Documented in `.claude/rules/git-conventions.md`

### Changed

- Execute-tasks workflow enforces TDD phases
- Phase 2 implementation includes explicit TDD phase markers
- Commit messages include TDD phase when relevant

## [3.8.0] - 2025-11-20

### Added

- **Standards Directory**: Coding standards organized by domain
  - `.agent-os/standards/global/` for cross-cutting concerns
  - `.agent-os/standards/frontend/` for UI patterns
  - `.agent-os/standards/backend/` for server patterns
  - `.agent-os/standards/testing/` for test patterns

- **Micro-Todo Pattern**: Fine-grained progress tracking
  - TodoWrite tool for step-by-step visibility
  - Update after each implementation step
  - Documented pattern in execute-tasks rules

### Changed

- Phase 2 implementation uses micro-todos for subtask tracking
- Standards loaded at session start based on project type
- Create-spec references relevant standards during generation

## [3.7.0] - 2025-11-15

### Added

- **Phase 0 Startup Agent**: Dedicated session initialization
  - Loads progress context from previous session
  - Reports resumption guidance if applicable
  - Sets up working state for Phase 1

- **Background Command Support**: Long-running operations
  - `run_in_background: true` parameter for Bash tool
  - `BashOutput` tool for checking background results
  - Documented for test suites > 30 seconds

### Changed

- Execute-tasks starts with Phase 0 before Phase 1
- Full test suite runs in background when > 30 seconds expected
- Progress log includes session duration estimates

## [3.6.0] - 2025-11-10

### Added

- **Recap Documents**: Session completion summaries
  - Created in `.agent-os/recaps/YYYY-MM-DD-SPEC_NAME.md`
  - Captures what was built, key decisions, files created
  - Generated automatically in Phase 3 delivery

- **Changelog Integration**: Automatic changelog updates
  - Detects change type from spec keywords
  - Adds entry to appropriate section
  - Updates PR number after creation

### Changed

- Phase 3 delivery includes recap generation step
- Changelog update is non-blocking (warns on failure)
- PR description links to recap document

## [3.5.0] - 2025-11-05

### Added

- **Explore Agent Integration**: Autonomous codebase exploration
  - Used in shape-spec for feasibility analysis
  - Used in create-tasks for complexity estimation
  - Operates with read-only permissions

- **AskUserQuestion Tool Pattern**: Structured decision points
  - Clear separation from autonomous exploration
  - Multi-select and single-select options
  - Documented handoff pattern: Explore → AskUserQuestion

### Changed

- Shape-spec uses Explore before asking user questions
- Create-spec includes explicit decision point markers
- Documentation distinguishes autonomous vs interactive steps

## [3.4.0] - 2025-11-01

### Added

- **Product Planning Workflow**: High-level product initialization
  - `/plan-product` command for mission/vision/roadmap
  - `/analyze-product` for existing codebase setup
  - Product context stored in `.agent-os/product/`

- **Roadmap Management**: Feature prioritization tracking
  - `roadmap.md` in product directory
  - Priority levels: P0 (critical), P1 (high), P2 (medium), P3 (low)
  - Spec references link to roadmap items

### Changed

- Create-spec can reference roadmap items
- Shape-spec validates alignment with product vision
- Specs include roadmap_item field when applicable

## [3.3.0] - 2025-10-25

### Added

- **Sub-Specs Directory**: Technical specification breakdown
  - `.agent-os/specs/[spec-folder]/sub-specs/` structure
  - `technical-spec.md` for implementation details
  - `api-spec.md` for API contracts (when applicable)

- **Context Summary JSON**: Pre-computed task context
  - `context-summary.json` generated with tasks
  - Per-task file lists and relevant excerpts
  - Reduces Phase 2 context loading time

### Changed

- Create-tasks generates context-summary.json
- Phase 2 loads context from JSON instead of re-analyzing
- Sub-specs referenced in task generation

## [3.2.0] - 2025-10-20

### Added

- **Parallelization Analysis**: Task dependency detection
  - `blocked_by` arrays on tasks
  - `can_parallel_with` suggestions
  - `isolation_score` for conflict likelihood

- **Wave Grouping**: Tasks organized by execution order
  - Wave 1: No dependencies, maximum parallelism
  - Subsequent waves: Dependencies on prior waves
  - Visual wave breakdown in tasks.md

### Changed

- Create-tasks includes parallelization analysis
- Tasks.json includes execution_strategy section
- Phase 1 discovery uses wave information for ordering

## [3.1.0] - 2025-10-15

### Added

- **Subtask Generation**: Automatic task decomposition
  - Parent tasks with `subtasks` array
  - Subtask IDs: `1.1`, `1.2`, etc.
  - TDD phase markers on subtasks

- **Complexity Override**: Manual complexity adjustment
  - `complexity_override` field in tasks.json
  - Values: LOW, MEDIUM, HIGH
  - Affects subtask generation depth

### Changed

- Phase 1 discovery generates subtasks for complex tasks
- Phase 2 implements subtasks individually
- Task completion requires all subtasks complete

## [3.0.0] - 2025-10-10

### Added

- **Agent OS Framework**: Initial release
  - Structured AI-assisted development workflows
  - Spec-driven feature development
  - Task breakdown and execution pipeline

- **Core Commands**:
  - `/shape-spec` for concept exploration
  - `/create-spec` for specification creation
  - `/create-tasks` for task generation
  - `/execute-tasks` for implementation

- **Phase Agents**:
  - Phase 0: Startup and context loading
  - Phase 1: Task discovery and mode selection
  - Phase 2: TDD implementation
  - Phase 3: Delivery and PR creation

- **Directory Structure**:
  - `.agent-os/` for framework state
  - `.claude/` for commands, agents, skills
  - Spec folders with consistent structure
