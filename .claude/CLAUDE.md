# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Agent OS is a development framework that installs into other projects to provide structured AI-assisted software development workflows. All command instructions are embedded within command files (~250-636 lines each) to ensure 99% reliable execution.

**v3.7.0 Wave-Specific Branching**: Each wave now gets its own isolated branch (`feature/spec-wave-1`, `feature/spec-wave-2`, etc.) to prevent merge conflicts. Wave PRs target the base feature branch (not main), and the final PR merges `feature/spec` to main. This eliminates conflicts in tasks.json, progress.json, and roadmap.md when running parallel waves.

**v3.6.0 Immediate Task Expansion**: WAVE_TASK items from PR reviews are now expanded immediately into actual tasks during `/pr-review-cycle`, not deferred to `/execute-tasks`. This prevents orphan `future_tasks` and makes the task list immediately actionable. New `remove-future-task` command added to task-operations.sh.

**v3.5.1 Script Path Fix**: Fixed "No such file or directory" errors for task-operations.sh and pr-review-operations.sh when Claude's working directory differs from project root. All script invocations now use `"${CLAUDE_PROJECT_DIR}/.claude/scripts/..."` pattern.

**v3.5.0 Intelligent Roadmap Integration**: New `roadmap-integrator` subagent determines optimal phase placement for ROADMAP_ITEMs during `/pr-review-cycle`. Analyzes phase themes, dependencies, and effort grouping to place items in the right phase instead of appending to the end.

**v3.4.0 Wave Assignment in PR Review**: Wave/roadmap assignments for future tasks now happen at the end of `/pr-review-cycle` instead of during `/execute-tasks`. Tasks arrive pre-tagged with `priority: "wave_N"`, simplifying the execute-tasks flow.

**v3.0.5 Paths with Spaces Fix**: Fixed hook execution and script failures when project paths contain spaces (common with OneDrive-synced projects like `AI Projects/`). All hooks now use `bash "${CLAUDE_PROJECT_DIR}/..."` pattern for proper quoting.

**v3.0.2 Git Workflow Enforcement + v2.x Removal**: Adds mandatory branch validation gates to v3 native subagents to prevent direct commits to main/master. `phase1-discovery.md` has Step 0 MANDATORY Gate that blocks if on protected branch. `phase2-implementation.md` has defense-in-depth validation. Also adds `/pr-review-cycle` command for automated PR review feedback processing. **BREAKING**: v2.x architecture removed entirely (phase files, task-orchestrator, codebase-indexer).

**v2.1.1 Task JSON Auto-Sync**: Addresses task JSON drift with multi-layered auto-sync. New `task-sync` skill, enhanced `session-startup` (Step 4.5), and mandatory sync gate in Phase 3 (Step 9.7) ensure tasks.json stays synchronized with tasks.md.

**v2.1.0 Task Artifacts**: Tasks now record their outputs (files created, functions exported) in tasks.json. This enables cross-task verification without maintaining a separate codebase index. The codebase-names skill uses live Grep + task artifacts for reliable name validation.

**v2.0.0 Parallel Async Execution**: Leverages Claude Code's async agent capabilities (`run_in_background`, `AgentOutputTool`) for true parallel task execution. Independent tasks now run simultaneously via wave-based orchestration, providing 1.5-3x speedup.

**v1.9.0+ Context Efficiency**: Based on Anthropic's "Effective Harnesses for Long-Running Agents" research, execute-tasks now uses phase-based loading, pre-computed context summaries, and an orchestrator pattern for multi-task sessions. See CHANGELOG.md for details.

**Critical**: This is the Agent OS **source repository**. Changes here affect all projects that install Agent OS. This is a meta-repository - files here are templates that get copied to target projects during installation.

## Development Commands

```bash
# Test installation in a separate test project
./setup/project.sh --claude-code                 # Basic installation (10 default skills)
./setup/project.sh --claude-code --full-skills   # Full installation (14 skills)
./setup/project.sh --claude-code --with-hooks    # With validation hooks
./setup/project.sh --cursor                      # Cursor support
```

**Workflow**: Make changes → Test in test project → Update SYSTEM-OVERVIEW.md → Update CHANGELOG.md → Commit

## Source Repository Structure

```
agent-os/
├── commands/              # Source command files → copied to .claude/commands/
├── claude-code/
│   ├── agents/            # Source subagent files → copied to .claude/agents/
│   └── skills/            # Source skill files → copied to .claude/skills/
├── setup/                 # Installation scripts
│   ├── project.sh         # Main installer
│   ├── base.sh
│   └── functions.sh
├── standards/             # Categorized development standards → copied to .agent-os/standards/
│   ├── global/            # Cross-cutting: coding-style, conventions, error-handling, validation, tech-stack
│   ├── frontend/          # UI patterns: react-patterns, styling
│   ├── backend/           # Server patterns: api-design, database
│   └── testing/           # Test patterns: test-patterns
├── config.yml             # Configuration template
└── SYSTEM-OVERVIEW.md     # Comprehensive system documentation
```

## Commands & Subagents

**Commands** (source: `commands/*.md`):
- `plan-product` / `analyze-product` - Product initialization
- `shape-spec` → `create-spec` → `create-tasks` → `execute-tasks` - Feature development pipeline
- `pr-review-cycle` - Automated PR review feedback processing (v3.0.2+)
- `index-codebase` - Code reference management (legacy - replaced by task artifacts)
- `debug` - Context-aware debugging with git integration

**Subagents** (source: `claude-code/agents/*.md`):

| Subagent | Purpose |
|----------|---------|
| git-workflow | Branch management, commits, PRs |
| codebase-indexer | Code reference updates (deprecated v2.1 - use task artifacts) |
| project-manager | Task/roadmap updates |
| task-orchestrator | Multi-task coordination with workers (v1.9.0+) |

**Phase Files** (source: `commands/phases/*.md`) - Loaded on-demand by execute-tasks (v1.9.0+):

| Phase | Purpose |
|-------|---------|
| execute-phase0 | Session startup protocol |
| execute-phase1 | Task discovery and mode selection |
| execute-phase2 | TDD implementation loop |
| execute-phase3 | Completion and delivery |

**Skills** (source: `claude-code/skills/*.md`) - Model-invoked, auto-triggered:

| Skill | Purpose |
|-------|---------|
| build-check | Auto-invoke before commits to verify build and classify errors |
| test-check | Auto-invoke after code changes to run and analyze tests |
| codebase-names | Auto-invoke when writing code to validate names via live Grep + task artifacts (v2.1) |
| systematic-debugging | Auto-invoke when debugging to enforce 4-phase root cause analysis |
| tdd | Auto-invoke before implementing features to enforce RED-GREEN-REFACTOR |
| brainstorming | Invoke during spec creation for Socratic design refinement |
| writing-plans | Invoke during task breakdown for detailed micro-task planning |
| session-startup | Load progress context, verify environment, validate task JSON sync at execute-tasks start |
| implementation-verifier | End-to-end verification before delivery (after all tasks complete) |
| task-sync | Auto-invoke to synchronize tasks.json with tasks.md when drift detected (v2.1.1) |
| pr-review-handler | Systematic PR review comment processing for /pr-review-cycle (v3.0.2+) |

**Optional Skills** (source: `claude-code/skills/optional/*.md`) - Installed with `--full-skills`:

| Skill | Purpose |
|-------|---------|
| code-review | Pre-review checklists and feedback integration |
| verification | Evidence-based completion verification |
| skill-creator | Guide for creating custom Agent OS skills |
| mcp-builder | Guide for creating MCP servers |
| standards-to-skill | Template for converting standards to skills |

**Native Claude Code Features Used:**
- **Explore agent**: Specification discovery, document retrieval (replaces spec-cache-manager, context-fetcher)
- **Write tool**: File creation (replaces file-creator)
- **Environment context**: Date/time utilities (replaces date-checker)

## Making Changes

### Modifying Commands
1. Edit `commands/[command-name].md` (all instructions embedded)
2. Test: Install in test project and run the command
3. Update `SYSTEM-OVERVIEW.md` if adding new features

### Adding New Subagents
1. Create `claude-code/agents/[agent-name].md`
2. Add to installation list in `setup/project.sh`
3. Document in `SYSTEM-OVERVIEW.md`

### Adding New Skills
1. Create `claude-code/skills/[skill-name].md` with YAML frontmatter (name, description, allowed-tools)
2. Add to installation list in `setup/project.sh`
3. Document in `SYSTEM-OVERVIEW.md`
4. Skills are model-invoked (Claude decides when to use them based on description)

### Command Structure Pattern
All commands follow this structure:
1. Quick Navigation
2. Description & Parameters
3. Dependencies
4. Task Tracking (TodoWrite examples)
5. For Claude Code (meta instructions)
6. Core Instructions (embedded)
7. State Management
8. Error Handling
9. Subagent Integration

## State Management

**Atomic writes**: All state operations write to temp file first, then atomic rename.

**Session cache** (`.agent-os/state/session-cache.json`):
- 5-minute expiration with auto-extension (max 12 extensions = 1 hour)
- Stores spec cache, context cache, metadata

**Recovery**: Auto-backups in `.agent-os/state/recovery/` (keeps last 5 versions)

## Content Mapping

For features referencing external content (images, data files), create `content-mapping.md` in specs. See `docs/content-mapping-pattern.md` for full documentation.

## References

- **Comprehensive docs**: `SYSTEM-OVERVIEW.md`
- **Version history**: `CHANGELOG.md`
- **Official site**: https://buildermethods.com/agent-os
