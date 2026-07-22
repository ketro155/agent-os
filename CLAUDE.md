# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repository Is

Agent OS is a **development framework** that gets installed INTO other projects to provide structured AI-assisted software development workflows. This repo is the **source repository** — it contains the installer scripts and all template files that get copied to target projects.

This is NOT an application to build and run. It's a distribution of shell scripts, markdown agent definitions, JSON schemas, and installer tooling.

## Repository Architecture

### Dual-directory pattern

| Directory | Purpose | Git-tracked? |
|-----------|---------|-------------|
| `v3/` | **Source templates** — the canonical versions of all framework files | Yes |
| `.claude/` | **Local test installation** — created by running the installer locally | No (gitignored) |
| `.agent-os/` | **Local runtime state** — created by running the installer locally | No (gitignored) |
| `setup/` | **Installer scripts** — `base.sh` (downloads from GitHub) and `project.sh` (installs to a project) | Yes |
| `standards/` | **Development standards templates** — coding style, patterns, conventions | Yes |

**Critical**: When modifying framework files, edit in `v3/` first, then sync to `.claude/` (or re-run the installer). The `v3/` directory is the source of truth for distribution.

### v3/ internal structure

```
v3/
├── settings.json              # Hooks configuration (single source for version number)
├── memory/
│   ├── CLAUDE.md              # Framework CLAUDE.md (installed to .claude/CLAUDE.md)
│   ├── ENV-VARS.md            # Environment variable documentation
│   └── rules/                 # Path-scoped rule files (11 rules)
├── agents/                    # 20 agent definitions + 3 reference docs
│   └── references/            # On-demand reference docs loaded via paths: frontmatter
├── commands/                  # 11 slash commands (plan-product, execute-tasks, etc.)
├── hooks/                     # 9 shell script hooks (session, commit, subagent lifecycle)
├── scripts/                   # 19 utility scripts (shell + JS + TS)
├── skills/                    # 10 hot-reload skills (each in subdirectory with SKILL.md)
├── schemas/                   # JSON schemas (tasks-v3, tasks-v4, execute-spec-v1)
└── templates/                 # Spec, task, and test-scenario templates
```

### Installer flow

```
base.sh (GitHub → local base)  →  project.sh (base → target project)
                                   project.sh --no-base (GitHub → target project directly)
                                   project.sh --upgrade (merge strategy: replace framework, preserve project)
```

## Common Commands

### Install to a target project (from local base)

```bash
cd /path/to/target-project
/path/to/agent-os/setup/project.sh --claude-code
```

### Upgrade an existing installation

```bash
cd /path/to/target-project
/path/to/agent-os/setup/project.sh --claude-code --upgrade
# --force flag overwrites everything including standards
```

### Install base from GitHub

```bash
bash setup/base.sh --claude-code
```

### Regenerate tasks.md from tasks.json

```bash
node .claude/scripts/json-to-markdown.js .agent-os/specs/*/tasks.json
```

### Migrate v3 tasks to v4 format

```bash
node .claude/scripts/migrate-v3-to-v4.js .agent-os/specs/*/tasks.json
```

### Validate skill trigger registrations

```bash
bash .claude/scripts/test-skill-triggers.sh
```

### Check task status (in an installed project)

```bash
jq '.summary' .agent-os/specs/*/tasks.json
```

## Development Patterns

### Version bumping

Version appears in multiple places that must stay in sync:
- `v3/settings.json` → `env.AGENT_OS_VERSION` (single source of truth for installer)
- `v3/memory/CLAUDE.md` → header and overview text
- `setup/base.sh` → `AGENT_OS_VERSION` variable (fallback only)
- `CHANGELOG.md` → release entry

### The merge strategy for upgrades

`project.sh --upgrade` uses a three-tier file ownership model:
- **Framework files** (commands, agents, hooks, scripts): always overwritten
- **Mixed files** (CLAUDE.md, settings.json): merged — framework section replaced, project customizations preserved
- **Project files** (standards): never overwritten (use `--force` to override)

CLAUDE.md merge uses `<!-- AGENT-OS:START -->` / `<!-- AGENT-OS:END -->` markers. Project content after the END marker is preserved during upgrades.

settings.json merge replaces hooks/permissions but preserves custom (non-`AGENT_OS_*`) env vars.

### Hook stdin pattern

Hooks receive context via **stdin JSON**, not environment variables. All hooks use:
```bash
HOOK_INPUT=$(cat)
AGENT_TYPE=$(echo "$HOOK_INPUT" | jq -r '.agent_type // "unknown"')
```

### Agent frontmatter conventions

Agent `.md` files use YAML frontmatter for configuration:
- `tools:` — positive tool allowlist
- `disallowedTools:` — defense-in-depth deny list
- `model:` — model override (e.g., `sonnet` for fast analysis, `haiku` for classifiers)
- `memory:` — `project` enables cross-session agent memory
- `paths:` — reference docs loaded on-demand

### Syncing v3/ to .claude/

After editing files in `v3/`, sync to local installation:
```bash
# Re-run installer locally for full sync
cd /path/to/agent-os
setup/project.sh --claude-code --upgrade --force
```

Or copy individual files:
```bash
cp v3/agents/phase2-implementation.md .claude/agents/
cp v3/memory/CLAUDE.md .claude/CLAUDE.md
```

## Key Dependencies

- `jq` — JSON processing in shell scripts
- `node` — JavaScript runtime for markdown generation scripts
- `git` — version control operations
- `typescript` (devDependency) — for `.ts` utility scripts
- `uuid` (dependency) — unique ID generation

No MCP servers or external services required by the framework itself.

## File Conventions

- Shell scripts must be `chmod +x` after creation
- All shell scripts use `set -e` for fail-fast behavior
- JSON schemas live in `v3/schemas/` and get installed to `.agent-os/schemas/`
- `tasks.json` is always the source of truth; `tasks.md` is auto-generated and read-only
- The `CHANGELOG.md` follows Keep a Changelog format with Semantic Versioning
