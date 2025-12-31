# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Agent OS is a development framework that installs into other projects to provide structured AI-assisted software development workflows. It uses native Claude Code hooks for mandatory validation and single-source JSON tasks.

**v4.0.0 Baseline Cleanup**: Major version removing all legacy v2.x architecture. Only v3-based native hooks architecture is now supported. Legacy directories (`commands/`, `claude-code/`, `shared/`) have been removed. All source files now live in `v3/`.

**Critical**: This is the Agent OS **source repository**. Changes here affect all projects that install Agent OS. This is a meta-repository - files here are templates that get copied to target projects during installation.

## Development Commands

```bash
# Test installation in a separate test project
./setup/project.sh --claude-code        # Standard installation
./setup/project.sh --cursor             # Cursor support
./setup/project.sh --claude-code --upgrade  # Upgrade existing installation
```

**Workflow**: Make changes → Test in test project → Update SYSTEM-OVERVIEW.md → Update CHANGELOG.md → Commit

## Source Repository Structure

```
agent-os/
├── v3/                    # All source files for v4+ architecture
│   ├── commands/          # Command templates (8 commands) → .claude/commands/
│   ├── agents/            # Agent templates (13 agents) → .claude/agents/
│   ├── hooks/             # Native hooks (4 hooks) → .claude/hooks/
│   ├── scripts/           # Utility scripts → .claude/scripts/
│   ├── memory/            # CLAUDE.md + rules → .claude/
│   ├── schemas/           # JSON schemas → .agent-os/schemas/
│   └── settings.json      # Hooks configuration → .claude/settings.json
├── standards/             # Development standards → .agent-os/standards/
│   ├── global/            # Cross-cutting standards
│   ├── frontend/          # UI patterns
│   ├── backend/           # Server patterns
│   └── testing/           # Test patterns
├── setup/                 # Installation scripts
│   ├── project.sh         # Main installer
│   ├── base.sh            # Base installation
│   └── functions.sh       # Shared functions
├── config.yml             # Configuration template
└── SYSTEM-OVERVIEW.md     # Comprehensive system documentation
```

## Commands & Agents

**Commands** (source: `v3/commands/*.md`):
- `plan-product` / `analyze-product` - Product initialization
- `shape-spec` → `create-spec` → `create-tasks` → `execute-tasks` - Feature development pipeline
- `pr-review-cycle` - Automated PR review feedback processing
- `debug` - Context-aware debugging with git integration

**Agents** (source: `v3/agents/*.md`):

| Agent | Purpose |
|-------|---------|
| phase1-discovery | Task discovery and execution mode selection |
| phase2-implementation | TDD implementation loop |
| phase3-delivery | Completion and delivery |
| pr-review-discovery | PR comment analysis |
| pr-review-implementation | PR feedback implementation |
| future-classifier | Task classification |
| comment-classifier | Comment categorization |
| roadmap-integrator | Roadmap item placement |
| git-workflow | Branch management, commits, PRs |
| project-manager | Task/roadmap updates |

**Hooks** (source: `v3/hooks/*.sh`) - Mandatory validation:

| Hook | Purpose |
|------|---------|
| session-start | Initialize session, set CLAUDE_PROJECT_DIR |
| session-end | Clean up session |
| post-file-change | Auto-regenerate tasks.md from tasks.json |
| pre-commit-gate | Validate before git commits |

## Making Changes

### Modifying Commands
1. Edit `v3/commands/[command-name].md`
2. Test: Install in test project and run the command
3. Update `SYSTEM-OVERVIEW.md` if adding new features

### Adding New Agents
1. Create `v3/agents/[agent-name].md`
2. Add to installation list in `setup/project.sh` (line ~425)
3. Document in `SYSTEM-OVERVIEW.md`

### Adding New Hooks
1. Create `v3/hooks/[hook-name].sh`
2. Add hook configuration to `v3/settings.json`
3. Add to installation list in `setup/project.sh`

## State Management

**Atomic writes**: All state operations write to temp file first, then atomic rename.

**Session cache** (`.agent-os/state/session-cache.json`):
- 5-minute expiration with auto-extension (max 12 extensions = 1 hour)
- Stores spec cache, context cache, metadata

**Recovery**: Auto-backups in `.agent-os/state/recovery/` (keeps last 5 versions)

## References

- **Comprehensive docs**: `SYSTEM-OVERVIEW.md`
- **Version history**: `CHANGELOG.md`
- **Official site**: https://buildermethods.com/agent-os
