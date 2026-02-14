# Changelog

All notable changes to Agent OS will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


## [Unreleased]

### Changed
- **Installer sync (v5.4.1)**: `setup/base.sh` and `setup/project.sh` version bumped to 5.4.1
- **Version bumped** to 5.4.1 in `settings.json` (both `v3/` and `.claude/`), `setup/base.sh`, `setup/project.sh`, `CLAUDE.md` headers
- v3/ source templates already contain v5.4.1 hook fixes and agent spawn chain fix — installer copies them automatically

---

## [5.4.1] - 2026-02-13 - Agent Spawn Chain & Hook Observability Fix

### Fixed
- **CRITICAL: SubagentStart/Stop hooks always logged `agent_type: "unknown"`** — hooks were reading from environment variables but Claude Code passes context via stdin JSON. Now uses `HOOK_INPUT=$(cat)` + `jq` parsing pattern (matching `teammate-idle.sh` and `task-completed.sh`)
- **CRITICAL: Agent hierarchy collapse in wave-lifecycle-agent** — Step 1 delegated to `general-purpose` with prose instructions to "read execute-tasks.md and follow it." The general-purpose agent would short-circuit by implementing inline rather than spawning the expected `wave-orchestrator` → `phase2-implementation` chain. Step 1 now directly spawns typed agents.

### Changed
- **`subagent-start.sh`** — reads `agent_type`, `agent_id` from stdin JSON with jq fallback chain; backward-compatible env var fallback
- **`subagent-stop.sh`** — reads `agent_id`, `transcript_path`, `result` from stdin JSON with jq fallback chain
- **`wave-lifecycle-agent`** — Step 1 rewritten to directly spawn `wave-orchestrator` (for task execution) and `phase3-delivery` (for PR creation); frontmatter updated to `Task(wave-orchestrator, phase3-delivery, general-purpose)`; `general-purpose` retained only for review processing (Step 3) and E2E smoke tests (Step 3.5)
- **`agent-tool-restrictions.md`** — spawn restrictions table updated for wave-lifecycle-agent
- **`CLAUDE.md`** — spawn restriction bullet updated for wave-lifecycle-agent
- All changes synced to v3 templates

---

## [5.4.0] - 2026-02-13 - Two-Tier Code Review

### Added
- **Two-tier code review system** (`AGENT_OS_CODE_REVIEW=true`, opt-in):
  - `code-reviewer` (Sonnet teammate): real-time semantic review during wave execution — code smells, hardcoded secrets, spec compliance
  - `code-validator` (Opus subagent): deep design pattern analysis, OWASP security scan, spec compliance, cross-task consistency
  - Blocks on unresolved CRITICAL/HIGH findings from either tier
  - Fix cycle with bound (`MAX_REVIEW_FIX_ATTEMPTS=2`) prevents infinite reviewer-implementer feedback loops
- **Three-tier model strategy**: Opus (deep reasoning) + Sonnet (fast analysis) + Haiku (classification)
- **Utility teammate exemption**: `code-reviewer` and `review-watcher` don't count against `AGENT_OS_MAX_TEAMMATES` cap
- **`code-review-ops.sh`**: Extracted review coordination logic (finding accumulation, severity classification, tier combination, fix cycle bound)

### Changed
- `wave-orchestrator`: T4.75 (reviewer relay), T4.8 (finding routing), T5 (two-tier handoff with shutdown + Task invocation)
- `wave-orchestrator`: Task spawn restrictions updated to include `code-validator`
- `wave-orchestrator`: Teammate restrictions updated to include `code-reviewer`
- `wave-orchestrator`: T1.5 cap formula now explicitly excludes utility teammates
- `phase3-delivery`: PR description template includes two-tier code review results section (Step 3.75)
- Model strategy expanded from two-tier to three-tier across CLAUDE.md and agent-tool-restrictions.md
- `teams-integration.md`: Wave lifecycle updated with code review steps, utility exemption, fix cycle docs
- `ENV-VARS.md`: Added `AGENT_OS_CODE_REVIEW` documentation

### Backward Compatibility
- `AGENT_OS_CODE_REVIEW=false` (default) — no code review agents spawned, zero overhead
- `AGENT_OS_TEAMS=false` + `AGENT_OS_CODE_REVIEW=true` — only Tier 2 (standalone mode) via Task()
- All existing agents unchanged — new agents are additive only

---

## [5.3.0] - 2026-02-12 - Claude Code & Opus 4.6 Alignment

### Added
- **`TeammateIdle` hook** — new hook event (Claude Code v2.1.33) tracks teammate lifecycle metrics in `agents.jsonl` for debugging slow waves
- **`additionalContext` in pre-commit gate** — PreToolUse hook (Claude Code v2.1.21) now returns staged files and validation summary as context, helping the model write better commit messages
- **Model strategy documentation** — two-tier assignment (Opus for reasoning agents, Haiku for classifiers) documented in `agent-tool-restrictions.md` with decision tree
- **Opus 4.6 adaptive thinking section** — replaces stale "Extended Thinking" guidance in CLAUDE.md; documents adaptive thinking mode and fast mode (`/fast`)
- **Auto-memory vs project memory** — clarification in CLAUDE.md that Claude Code auto-memory (user-level) and Agent OS `memory: project` (project-level) are complementary
- **`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` prerequisite** — documented in CLAUDE.md and `teams-integration.md`; setup hook emits warning if Teams enabled without the Claude Code feature flag
- **`${CLAUDE_SESSION_ID}` in skills** — context-stats and log-entry skills now include session ID for traceability
- **`--from-pr` flag** — documented in Git Workflow section for PR-linked session resume

### Changed
- **wave-lifecycle-agent model: sonnet → Opus** — removed `model: sonnet` override so agent inherits default Opus 4.6; stronger reasoning reduces risk of review decision bugs (v5.1.1 regression area)
- **teams-integration.md** — added Prerequisite section, TeammateIdle in hooks table, PR review status indicator note
- **agent-tool-restrictions.md** — added Model Strategy section with decision tree, current assignments table, fast mode documentation, validation checklist item
- **CLAUDE.md** — 7 documentation updates: Teams prerequisite, model strategy, fast mode, adaptive thinking, auto-memory distinction, `--from-pr`, TeammateIdle hook; bumped to v5.3.0
- **setup.sh** — validates Teams tools availability when `AGENT_OS_TEAMS=true`
- **pre-commit-gate.sh** — outputs `additionalContext` JSON field on success and warnings

### Backward Compatibility
- All changes are additive — no breaking changes
- `AGENT_OS_TEAMS=false` remains entirely unchanged
- Haiku classifiers remain on Haiku (unchanged)
- Only wave-lifecycle-agent model assignment changed (Sonnet → Opus)

---

## [5.2.0] - 2026-02-12 - Atomic Teammates: Group-Level Parallelism

### Added
- **Group-level teammate spawning** — `wave-orchestrator` can now spawn `subtask-group-worker` agents as lightweight teammates, each handling a single subtask group scoped to specific files (lower context pressure per agent)
- **Dynamic teammate cap** — teammate count computed from `isolation_score` instead of static `Math.min(tasks.length, 3)`; higher isolation enables more parallelism, low isolation falls back to sequential
- **Artifact relay protocol** — team lead relays verified artifacts from one teammate to all active siblings, preventing duplicate utility functions across parallel groups
- **`AGENT_OS_MAX_TEAMMATES` env var** — configurable upper bound for concurrent teammates per wave team (default: `5`)
- **Teammate mode for `subtask-group-worker`** — claims group tasks from shared task list, parses SubtaskGroupContext from description, broadcasts artifacts via SendMessage
- **Granularity decision tree** in `wave-orchestrator` (T1.5) — selects `task_level`, `group_level`, or `hybrid` based on `subtask_execution.mode` and `groups.length`
- Centralized environment variable documentation (`.claude/ENV-VARS.md`)
- Consolidated verification utilities in `verification-loop.ts`
- E2E utilities module (`e2e-utils.ts`) with `canAutoFix()` function
- Test pattern discovery utility (`test-patterns.ts`)
- Subtask execution mode decision tree in phase2-implementation

### Changed
- **wave-orchestrator** — T1.5 granularity selection, dynamic cap formula, group-level TaskCreate, agent type routing in T3, artifact relay in T4.5
- **subtask-group-worker** — added team tools (SendMessage, TaskUpdate, TaskList, TaskGet) to frontmatter; teammate workflow with claim-execute-broadcast-loop
- **teams-integration.md** — expanded with Atomic Teammates section, granularity decision tree, relay protocol, backward compatibility notes
- **agent-tool-restrictions.md** — added "Implementation teammate" tool set, validation checklist note for subtask-group-worker
- **ENV-VARS.md** — added Teams section with `AGENT_OS_MAX_TEAMMATES`
- **CLAUDE.md** — bumped to v5.2.0; added Atomic Teammates and artifact relay feature bullets; updated Teams Integration section; added `AGENT_OS_MAX_TEAMMATES` to config
- Wave-orchestrator now references centralized verification module
- Updated phase3-delivery to use e2e-utils for auto-fix analysis
- Standardized tool restriction approach documentation

### Fixed
- Clarified subtask execution mode selection with decision tree
- Documented backlog graduation criteria explicitly

### Backward Compatibility
- `AGENT_OS_TEAMS=false` → entirely unchanged flow (legacy Task() mode)
- `AGENT_OS_TEAMS=true` + no `parallel_groups` → `task_level` granularity (v5.1 behavior)
- `AGENT_OS_TEAMS=true` + `isolation_score < 0.6` → `cap = 1` (sequential, safe fallback)

---

## [5.1.1] - 2026-02-10 - PR Review Safety: Compound Detection & Field Validation

### Fixed
- **Critical: PR review comments misclassified as "good"** — Step 2.5 in `pr-review-cycle` now scans for ALL actionable items (SECURITY, BUG, HIGH, etc.), not just FUTURE items; approved PRs with critical bot comments no longer exit early as "Ready to merge"
- **Critical: review result field mismatch** — `wave-lifecycle-agent` expected `blocking_issues_found` and `commits_made` but `pr-review-implementation` returned `comments_addressed` and `changes_made`; `|| 0` fallback silently made all safety checks pass; executor prompt now includes explicit derivation guide for each field
- **Ambiguous review states auto-merged** — `pr_approved: false` + `commits_made: 0` previously concluded "No blocking issues. Ready to merge"; now rejects ambiguous states with explicit error; `pr_approved` alone no longer gates merge (must also have zero blocking issues)
- **Compound reviews misclassified** — "Good code, but critical issue..." was classified as PRAISE; PRAISE now requires entire comment to be positive with no actionable items
- **FUTURE overrode critical content** — regex fallback compound detection now covers FUTURE and SUGGESTION categories (not just PRAISE); a comment under "Future Improvements" containing "Must Fix" or "Critical" signals gets overridden to HIGH
- **PRAISE priority inconsistency** — keyword fallback assigned PRAISE priority 6 instead of 7 (matching section detector and comment-classifier)
- **Overly broad APPROVE regex** — bare `APPROVE` matched "NOT APPROVED" and "DISAPPROVED"; changed to `\bAPPROVED\b` word boundary
- **Bare "Phase 2" in FUTURE patterns** — any comment mentioning "Phase 2" was classified as FUTURE; changed to `Defer to Phase \d` to only match explicit deferral language

### Changed
- **comment-classifier** — processing rule #5 reversed: when ambiguous between actionable and FUTURE, prefer actionable category (safer to flag than to defer)
- **pr-review-discovery** — explicit definition of `actionable_comments` calculation: SECURITY + BUG + LOGIC + HIGH + COVERAGE + MISSING + PERF + STYLE + DOCS; QUESTION, SUGGESTION, FUTURE, PRAISE excluded and tracked separately
- **wave-lifecycle-agent** — field existence validation: missing `blocking_issues_found` or `commits_made` fails safely instead of silently passing; decision logic rewritten with defense-in-depth
- **setup/base.sh** — version bumped from 4.9.0 to 5.1.1 (was outdated)

---

## [5.1.0] - 2026-02-09 - Native Teams Integration

### Added
- **Wave-level Teams coordination** — parallel tasks within a wave coordinate as teammates via `SendMessage`, sharing artifact discoveries in real-time to prevent duplicate implementations
- **`AGENT_OS_TEAMS` feature flag** — enables Teams mode (default: `false`); both modes produce identical outputs
- **`review-watcher` agent** — lightweight Haiku-model teammate that polls for PR reviews every 60 seconds and notifies team lead via message, replacing the sleep-and-re-invoke pattern
- **Artifact broadcast protocol** — phase2-implementation teammates notify siblings and team lead when creating new exports/files, enabling real-time artifact sharing
- **Incremental verification pre-check** — wave-orchestrator validates artifacts as teammates produce them, sends fix requests before full Ralph verification runs
- **`teammate_restrictions` convention** — documents which agent types can be spawned as teammates, mirroring `Task(type)` pattern for team spawning
- **`rules/teams-integration.md`** — comprehensive documentation: feature flag, artifact protocol schema, team lifecycle, dual-mode routing, Teams vs Task() decision tree

### Changed
- **wave-orchestrator** — dual-mode execution: TeamCreate flow (`AGENT_OS_TEAMS=true`) or legacy `run_in_background` + `TaskOutput` (`false`); Teams tools added to frontmatter
- **phase2-implementation** — teammate mode: claims tasks from shared task list, broadcasts artifacts via `SendMessage`; Teams tools added to frontmatter
- **execute-spec-orchestrator** — spawns `review-watcher` teammate instead of sleep-and-re-invoke for review wait (`AGENT_OS_TEAMS=true`); Teams tools added to frontmatter
- **agent-tool-restrictions.md** — expanded to four complementary mechanisms; added `teammate_restrictions` convention, review-watcher agent, teammate restrictions table, validation checklist update
- **CLAUDE.md** — bumped to v5.1.0; added Teams Integration section, Teams feature bullets, `AGENT_OS_TEAMS` env var, `@import rules/teams-integration.md`

---

## [5.0.1] - 2026-02-09 - Hardening: Wrong-Approach Prevention, E2E Resilience, Context Management

### Added
- **`constraints` field in tasks v4.0 schema** — `do_not`, `prefer`, `require` arrays prevent wrong implementation approaches before code is written
- **Constraint validation gate** in phase2-implementation (Step 0.1) — enforces constraints at task start with verification at completion
- **E2E error codes (E300-E304)** in ERROR_CATALOG — E2E_SCENARIO_FAILED, E2E_TIMEOUT, E2E_ELEMENT_NOT_FOUND, E2E_BROWSER_CRASH, E2E_NETWORK_ERROR now resolve correctly
- **Auth health check** in test-executor (Step -1) — pre-flight check catches server-down/auth-service-down before running any fixtures
- **E2E batch checkpointing** (`rules/e2e-batch-checkpoint.md`) — checkpoint after each scenario enables resume on interruption with 2-hour staleness threshold
- **Session workload estimator** in session-start hook — estimates context budget at session start, classifies as LOW/MEDIUM/HIGH
- **Context pressure detection** in subagent-stop hook — surfaces `[Context Pressure: HIGH/MODERATE]` warnings when bytes offloaded exceed thresholds
- **Automatic context pressure response** in phase2-implementation — MUST invoke `/context-summary` at HIGH pressure, SHOULD at MODERATE with >2 subtasks remaining
- **`/test-guardian` skill** (`skills/test-guardian/SKILL.md`) — classifies test failures as FLAKY/BROKEN/NEW based on history, recommends retry vs fix vs quarantine

### Changed
- **test-executor `findWithRetry`** — replaced fixed 1s delay with exponential backoff (1s → 2s → 4s) using structured E302 error codes
- **wave-lifecycle-agent review polling** — refactored from blocking 30-minute loop to non-blocking single-check + return `"awaiting_review"` pattern, freeing agent context slots
- **execute-spec-orchestrator** — handles `awaiting_review` status with 2-minute delay before re-invoking wave agent
- **json-to-markdown.js** — renders `constraints` field as Do Not / Prefer / Require bullet lists in v4.0 task output
- **verification-loop.md** — added `Constraints Met` to verification criteria table
- **phase1-discovery** — surfaces constraint summaries during task discovery
- **create-tasks.md** — guidance to populate `constraints` from spec + standards during task generation

### Performance Impact
- Auth health check prevents 4+ cascading E2E scenario failures per session
- Non-blocking review saves ~30 minutes of blocked agent context per PR review
- Session workload estimator provides early warning for context overflow
- Batch checkpointing eliminates re-running completed scenarios on interruption

---

## [5.0.0] - 2026-02-06 - Dependency-First Tasks (Phase A)

### Added
- **tasks.json v4.0 format** — `depends_on` is the single source of truth for task dependencies, replacing triple duplication across `parallelization.blocked_by`, `execution_strategy.dependency_graph`, and wave ordering
- **Explicit infrastructure tasks** — Branch setup (`W{N}-BRANCH`), verification (`W{N}-VERIFY`), PR creation (`W{N}-PR`), merge (`W{N}-MERGE`), E2E testing (`E2E`), and final delivery (`DELIVER`) are now visible tasks in the graph with proper dependencies
- **`task_type` field** — Classifies tasks as `implementation`, `git-operation`, `verification`, `e2e-testing`, or `discovery` for role-based assignment
- **`computed` section** — Waves derived automatically via Kahn's algorithm topological sort from `depends_on` fields
- **`compute-waves.ts`** (`.claude/scripts/`) — Standalone topological sort script with inline tests, computes wave depth from dependency graph
- **`migrate-v3-to-v4.js`** (`.claude/scripts/`) — Migration script converting v3.0 tasks.json to v4.0 in-place with automatic backup
- **tasks-v4.json schema** (`.agent-os/schemas/`) — Full JSON Schema for v4.0 format validation
- **`AGENT_OS_TASKS_V4` feature flag** — Controls v4.0 format generation (default: `false`)
- **Steps 8.7 and 8.8 in create-spec** — Implementation Dependencies table and Complexity & Role Hints for better task generation input

### Changed
- **`json-to-markdown.js`** — Version-routed renderer: v3.0 tasks use existing renderer, v4.0 tasks get dependency graph visualization, task type icons (`[G]`, `[V]`, `[E]`, `[D]`), separate infrastructure/implementation sections
- **`wave-parallel.ts`** — Accepts both v3.0 (`parallelization.blocked_by`) and v4.0 (`depends_on`) formats via version detection
- **`task-operations.sh`** — `status` and `update` commands detect version and use format-appropriate jq queries; v4.0 summary splits implementation vs infrastructure counts
- **`create-tasks.md`** Step 1.5 — Replaced "Analyze Parallel Execution Opportunities" with "Dependency Analysis & Infrastructure Generation" (behind feature flag)
- **`create-tasks.md`** Step 2 — Readiness check shows dependency graph visualization for v4.0, legacy wave summary for v3.0
- **`settings.json`** — Version bumped to 5.0.0, added `AGENT_OS_TASKS_V4` env var
- **`CLAUDE.md`** — Documented v4.0 task format, feature flag, migration path

### Backward Compatibility
- All scripts support both v3.0 and v4.0 via version detection
- `AGENT_OS_TASKS_V4=false` (default) preserves existing v3.0 behavior
- Migration script backs up originals as `tasks.v3-backup.json`
- No changes to execution agents — format migration is data-layer only (Phase A)

---

## [4.12.0] - 2026-02-06 - Quick Wins: Native Feature Adoption

### Added
- **Setup hook** (`.claude/hooks/setup.sh`): One-time project initialization triggered by `claude --init` / `--maintenance`. Creates `.agent-os/` directory structure, initializes `version.json`, `progress.json`, and `session_stats.json` idempotently.
- **TaskCompleted hook** (`.claude/hooks/task-completed.sh`): Fires when `TaskUpdate` sets status to `"completed"`. Appends `task_completed` entries to `progress.json` and increments `tasks_completed` counter in `session_stats.json`.
- **`Task(agent_type)` spawn restrictions**: Six orchestrators now declare exactly which agent types they can spawn via `Task(types)` syntax, enforcing principle of least privilege for agent spawning.
- **`memory: project` frontmatter**: Five learning-capable agents (`phase2-implementation`, `pr-review-discovery`, `test-executor`, `test-discovery`, `wave-lifecycle-agent`) now persist cross-session knowledge scoped to the project.

### Changed
- `session-start.sh`: Simplified `.agent-os` existence check to lightweight hint suggesting `claude --init` (full init moved to Setup hook)
- `settings.json`: Bumped version to 4.12.0, added Setup and TaskCompleted hook entries
- `agent-tool-restrictions.md`: Expanded from two to three complementary mechanisms, added `Task(types)` documentation
- `CLAUDE.md`: Bumped to v4.12.0, added new feature bullets, expanded hooks table, expanded agent security section, added Agent Memory section

---

## [4.11.0] - 2026-01-14 - E2E Test Integration

### Added
- **E2E Test Integration** at three strategic points: create-spec, wave-lifecycle, phase3-delivery
- Hard-blocking E2E failures (same treatment as unit tests)
- Auto-fix for E2E failures < 3 with high confidence patterns
- E2E test plan generation during spec creation
- Smoke E2E tests in wave-lifecycle final wave
- Full E2E validation gate in phase3-delivery
- `--skip-e2e` flag for backend-only changes
- `--no-e2e-plan` flag for create-spec

### Changed
- PR descriptions now include E2E test results summary
- Phase 3 delivery includes E2E validation step

---

## [4.10.0] - 2026-01-12 - Context Offloading

### Added
- **FewWord-inspired context offloading** for token efficiency
- Tiered offloading: inline (< 512B), compact pointer (512B-4KB), preview (> 4KB)
- Secret redaction in offloaded outputs (AWS keys, GitHub tokens, API keys)
- Context management skills: `/context-read`, `/context-search`, `/context-stats`
- LATEST symlinks for quick access to recent outputs
- Session statistics tracking (`session_stats.json`)
- LRU eviction at 250MB scratch limit

### Changed
- SubagentStop hook now offloads large outputs automatically
- Environment variables for offloading configuration (AGENT_OS_*)

---

## [4.9.1] - 2026-01-11 - Memory Layer Integration

### Added
- **Memory Layer Logging** prompts integrated across workflows
- `/log-entry` skill for adding entries to semantic memory
- Session end hook reminder for logging opportunities
- Logging prompts in: shape-spec, create-spec, debug, phase2, phase3, pr-review-cycle

### Changed
- Semantic logs now in `.agent-os/logs/` (decisions-log.md, implementation-log.md, insights.md)

---

## [4.9.0] - 2026-01-10 - Architecture Refinement

### Added

- **Subtask Expansion Skill**: Extracted inline subtask logic from phase1-discovery into reusable `.claude/skills/subtask-expansion/SKILL.md` with complexity heuristics and TDD templates (Wave 1, PR #3)

- **Spec Templates**: Added template library for common spec types - feature.md, bugfix.md, refactor.md, integration.md at `.claude/templates/specs/` (Wave 1, PR #3)

- **Dependency Detection**: New `detectDependencies` function in create-spec analyzing imports and package relationships (Wave 1, PR #3)

- **Feasibility Analysis**: Added `analyzeFeasibility` using Explore agent in shape-spec (Wave 1, PR #3)

- **AST-Based Verification System**: New `.claude/scripts/ast-verify.ts` using TypeScript compiler API for accurate export/function detection, replacing brittle grep patterns (Wave 2, PR #4)

- **Verification Caching**: File hash-based caching in `.agent-os/cache/verification/` to avoid redundant verification checks (Wave 2, PR #4)

- **Task Templates**: Four JSON templates for common task patterns at `.claude/templates/tasks/` - api-endpoint, react-component, bugfix, refactor (Wave 2, PR #4)

- **Test Pattern Discovery**: New `discoverTestPatterns()` utility in phase2-implementation reading from jest.config.js and vitest.config.ts (Wave 2, PR #4)

- **Parallel Wave Execution**: New `.claude/scripts/wave-parallel.ts` with `identifyParallelWaves()` for dependency-aware parallel task execution (Wave 3, PR #5)

- **Test Scenario Templates**: Three JSON templates for common test patterns at `.claude/templates/test-scenarios/` - authentication, form-validation, crud-operations with negative test cases (Wave 3, PR #5)

- **Negative Test Discovery**: New `discoverNegativeTests()` function in test-discovery generating invalid input and missing field cases (Wave 3, PR #5)

- **Coverage Gap Detection**: New `checkTestCoverage()` function in pr-review-discovery analyzing changed files against test files (Wave 3, PR #5)

- **Reproduction Script Generation**: New `generateReproScript()` function in debug command for minimal bug reproduction (Wave 3, PR #5)

- **Export Type Verification**: New `verifyExportTypes()` function in ast-verify.ts validating type exports match expected TypeKind (interface, type, enum, class) with detailed error messages (Wave 4, PR #6)

- **Three-Tier Error Handling System**: New `.claude/rules/error-handling.md` with `ErrorTier` enum (BLOCKING, WARN_CONTINUE, RETRY_THEN_FAIL), `AgentError` interface, `ERROR_CATALOG` with 20+ pre-defined error codes, `handleError()`, `withRetry()`, and `mapErrorToCode()` functions (Wave 5, PR #7)

- **Agent Changelog Sections**: All 17 agents now include inline `## Changelog` sections documenting version history and v4.9.0 enhancements (Wave 5, PR #7)

### Changed

- **Classifier Batch Processing**: comment-classifier now processes in batches of 10 for 20+ items (Wave 1, PR #3)

- **Explore-Based Complexity**: future-classifier uses Explore agent instead of crude heuristics for complexity estimation (Wave 1, PR #3)

- **Create-Tasks Command**: Enhanced with `analyzeComplexity()` for complexity scoring, `validateSpec()` gate for spec completeness, and `selectTaskTemplate()` for template-based task generation (Wave 2, PR #4)

- **Wave Orchestrator**: Integrated `verifyWithCache()` and `batchVerifyExports()` for AST-based artifact verification with caching (Wave 2, PR #4)

- **Phase2 Implementation**: Added context compression via `invokeContextSummary()` between subtasks, explicit `executeSubtask()` flow with context handoff (Wave 2, PR #4)

- **Execute-Spec-Orchestrator**: Step 4 updated for parallel wave spawning with `run_in_background` and barrier synchronization (Wave 3, PR #5)

- **Test Discovery Agent**: Enhanced with negative test case generation and spec template integration (Wave 3, PR #5)

- **Test Executor Agent**: New `resolveSelector()` with `data-testid` priority over fragile CSS selectors (Wave 3, PR #5)

- **Create-Test-Plan Command**: Added `detectBaseUrl()` reading from package.json scripts (Wave 3, PR #5)

- **Run-Tests Command**: Added `--parallel` flag for concurrent scenario execution and `--headless` flag for CI pipelines (Wave 3, PR #5)

- **PR Review Cycle Command**: Added `finalizeReviewResponse()` with `gh pr ready` and automatic reviewer re-request (Wave 3, PR #5)

- **Artifact Verification Skill**: Upgraded to v2.0.0 with auto-invocation at wave boundaries and AST-based type verification using `verifyExportTypes()` (Wave 4, PR #6)

- **All Agents Updated to v4.9.0**: Updated version references and added standardized error handling imports via `@import rules/error-handling.md` across 17 agents (Wave 5, PR #7)

- **CLAUDE.md Core Memory**: Version bumped from v4.8.0 to v4.9.0 with updated agent security documentation and error handling reference (Wave 5, PR #7)

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
  - Added Tool Handoff Pattern section explaining Explore -> AskUserQuestion -> brainstorming flow
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
  - `wave-lifecycle-agent.md`: Individual wave manager handling task execution -> PR -> review cycle
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
  - Documented handoff pattern: Explore -> AskUserQuestion

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
