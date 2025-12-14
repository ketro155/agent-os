# Agent OS v3.0 Upgrade Plan

## Overview

This upgrade leverages Claude Code's native capabilities to simplify Agent OS while improving reliability. The key changes:

1. **Single-source task format** (JSON primary, MD generated)
2. **Native hooks** replace skill-based sync
3. **Memory hierarchy** replaces embedded instructions
4. **Native subagents** replace phase files
5. **PreToolUse hooks** for validation gates
6. **MCP server** for core operations
7. **Extended thinking** for planning
8. **Native plan mode** integration
9. **Background commands** for tests/builds
10. **Enhanced TodoWrite** patterns
11. **Native checkpointing** for recovery

## Architecture Comparison

### v2.x Architecture
```
Commands (embedded instructions, 250-900 lines each)
├── Read phase files manually
├── Invoke skills (model-decided)
├── Dual-format sync (tasks.md ↔ tasks.json)
└── Custom state management
```

### v3.0 Architecture
```
Commands (lightweight, ~100 lines each)
├── Native subagents (tool-restricted, auto-skill loading)
├── Hooks (deterministic, cannot be skipped)
├── Single-source JSON (MD auto-generated)
└── Native memory + checkpointing
```

## Migration Path

### Phase 1: Foundation (Non-Breaking)
- Add v3 hooks alongside existing skills
- Add memory hierarchy files
- Add native subagent definitions
- Test in parallel with v2.x

### Phase 2: Cutover
- Update commands to use new architecture
- Deprecate dual-format sync
- Remove redundant skills (task-sync)
- Update installer

### Phase 3: Cleanup
- Remove deprecated components
- Update documentation
- Release v3.0

## File Changes Summary

### New Files
```
.claude/
├── settings.json              # Hooks configuration
├── CLAUDE.md                  # Core Agent OS memory
├── rules/
│   ├── execute-tasks.md       # Execute-tasks rules
│   ├── create-spec.md         # Create-spec rules
│   ├── tdd-workflow.md        # TDD enforcement
│   └── git-workflow.md        # Git conventions
├── agents/
│   ├── phase0-startup.md      # Session startup agent
│   ├── phase1-discovery.md    # Task discovery agent
│   ├── phase2-implementation.md # TDD implementation agent
│   └── phase3-delivery.md     # Completion agent
├── hooks/
│   ├── task-sync.sh           # Auto-sync tasks.md from JSON
│   ├── pre-commit-gate.sh     # Validation before commits
│   ├── validate-names.sh      # Name validation
│   └── session-state.sh       # Session lifecycle
├── scripts/
│   ├── json-to-markdown.js    # Generate tasks.md from JSON
│   └── collect-artifacts.js   # Collect task artifacts
└── mcp/
    └── agent-os-server.js     # Agent OS MCP server
```

### Deprecated (Remove in v3.0)
```
.claude/skills/
├── task-sync.md               # Replaced by hooks
└── session-startup.md         # Replaced by SessionStart hook + agent

.claude/commands/phases/       # Replaced by native subagents
├── execute-phase0.md
├── execute-phase1.md
├── execute-phase2.md
└── execute-phase3.md
```

### Modified
```
.claude/commands/
├── execute-tasks.md           # Simplified (~100 lines vs ~475)
├── create-spec.md             # Uses native plan mode
└── create-tasks.md            # JSON-only output
```
