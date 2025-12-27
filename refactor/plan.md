# Refactor Plan - v4.0.0 Baseline Cleanup

**Created**: 2025-12-27
**Goal**: Remove all legacy v2.x architecture, baseline on v3.x only

## Initial State Analysis

**Current Version**: v3.8.2
**Problem**: Repository contains two parallel architectures:
- **v3/** - Modern architecture with native hooks (current, recommended)
- **commands/**, **claude-code/**, **shared/** - Legacy v2.x architecture (deprecated)

The installer supports both via `--v2` flag, creating maintenance burden and confusion.

## Directory Inventory

### TO REMOVE (Legacy v2.x)
| Directory | Files | Purpose | Status |
|-----------|-------|---------|--------|
| `commands/` | 9 | v2 command templates (embedded instructions) | Remove |
| `shared/` | 6 | v2 shared modules | Remove |
| `claude-code/skills/` | 16 | v2 model-invoked skills | Remove |
| `claude-code/agents/future-classifier.md` | 1 | Duplicate (exists in v3) | Remove |

### TO MIGRATE (Still needed in v3)
| File | From | To | Reason |
|------|------|-----|--------|
| `git-workflow.md` | `claude-code/agents/` | `v3/agents/` | Used by installer for v3 |
| `project-manager.md` | `claude-code/agents/` | `v3/agents/` | Used by installer for v3 |

### TO KEEP (v3 baseline)
| Directory | Files | Purpose |
|-----------|-------|---------|
| `v3/agents/` | 8 + 2 migrated = 10 | Native subagents |
| `v3/commands/` | 4 | Lean command stubs |
| `v3/hooks/` | 4 | Native Claude Code hooks |
| `v3/scripts/` | 3 | Shell utilities |
| `v3/memory/` | 4 | CLAUDE.md + rules |
| `v3/schemas/` | 1 | JSON schema |
| `standards/` | 9 | Development standards |
| `setup/` | 3 | Installer scripts |

## Refactoring Tasks

### Phase 1: Migration (Safe)
- [x] Create refactoring session
- [ ] 1.1 Copy `claude-code/agents/git-workflow.md` to `v3/agents/`
- [ ] 1.2 Copy `claude-code/agents/project-manager.md` to `v3/agents/`
- [ ] 1.3 Verify migrated files are identical or update v3 versions

### Phase 2: Installer Update (Critical)
- [ ] 2.1 Remove `--v2` flag support from `setup/project.sh`
- [ ] 2.2 Update agent installation list to reference v3/agents/
- [ ] 2.3 Remove shared module installation code
- [ ] 2.4 Remove v2 skills installation code
- [ ] 2.5 Update `setup/base.sh` to remove legacy paths
- [ ] 2.6 Update `setup/functions.sh` to remove legacy references

### Phase 3: Legacy Removal (Destructive)
- [ ] 3.1 Remove `commands/` directory (9 files)
- [ ] 3.2 Remove `shared/` directory (6 files)
- [ ] 3.3 Remove `claude-code/` directory (19 files)

### Phase 4: Documentation Update
- [ ] 4.1 Update `.claude/CLAUDE.md` to remove v2 references
- [ ] 4.2 Update `SYSTEM-OVERVIEW.md` to reflect v3-only
- [ ] 4.3 Update `README.md` to remove `--v2` documentation
- [ ] 4.4 Update `CHANGELOG.md` with v4.0.0 entry

### Phase 5: Validation
- [ ] 5.1 Test local installation: `./setup/project.sh --claude-code`
- [ ] 5.2 Verify all v3 files installed correctly
- [ ] 5.3 Verify no legacy files remain

## De-Para Mapping

| Before (v2) | After (v3) | Notes |
|-------------|------------|-------|
| `commands/*.md` | `v3/commands/*.md` | 9 → 4 files (simplified) |
| `shared/*.md` | Removed | Functionality moved to hooks |
| `claude-code/skills/*.md` | Removed | Replaced by hooks + rules |
| `claude-code/agents/*.md` | `v3/agents/*.md` | 3 → 10 agents |
| `--v2` flag | Removed | v3 is only option |

## Risk Assessment

| Risk | Mitigation |
|------|------------|
| Breaking existing v2 installations | None - v2 is deprecated, users should upgrade |
| Missing agent functionality | Migrate git-workflow and project-manager first |
| Installer failure | Test locally before committing |

## Rollback Strategy

Git checkpoint created before changes. Can revert with:
```bash
git checkout HEAD~1 -- commands/ claude-code/ shared/ setup/
```

## Validation Checklist

- [ ] All v3 agents present (10 total)
- [ ] All v3 commands present (4 total)
- [ ] All hooks present (4 total)
- [ ] Installer works without `--v2`
- [ ] No broken imports in installer
- [ ] Documentation updated
- [ ] CHANGELOG updated
