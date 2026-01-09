---
name: context-summary
description: When you need to compress current context for handoff to another agent or for session recovery. Use before spawning subagents or ending sessions.
version: 1.0.0
context: fork
---

# Context Summary Skill

Compress current working context into a structured summary for handoff to subagents or session recovery.

## When to Use

- Before spawning a subagent that needs current context
- At session end for cross-session continuity
- When context window is filling up
- Before wave transitions in multi-wave execution

## Summary Structure

Generate summaries in this format:

```markdown
## Context Summary
**Generated**: [timestamp]
**Scope**: [task-id or spec-name]

### Current State
- **Active Task**: [task-id]: [description]
- **Branch**: [git-branch]
- **Progress**: [X/Y tasks complete]

### Key Decisions Made
1. [Decision 1 and rationale]
2. [Decision 2 and rationale]

### Files Modified
- `src/path/file.ts` - [what changed]
- `src/path/other.ts` - [what changed]

### Pending Items
- [ ] [Item not yet addressed]
- [ ] [Blocker if any]

### Critical Context for Next Agent
- [Important detail 1]
- [Important detail 2]
```

## Compression Guidelines

### What to Include

1. **Decisions with rationale** - Why, not just what
2. **File paths with changes** - Specific locations matter
3. **Blockers or risks** - Don't hide problems
4. **Test status** - Which tests pass/fail
5. **Dependencies verified** - What's confirmed working

### What to Exclude

1. **Full file contents** - Use paths instead
2. **Conversation history** - Summarize, don't quote
3. **Failed attempts** - Only final approach
4. **Tool output verbatim** - Summarize results
5. **Speculation** - Only confirmed facts

## Compression Ratios

Target these compression levels:

| Original Context | Target Summary |
|------------------|----------------|
| < 2KB | No compression needed |
| 2-10KB | ~500 words |
| 10-50KB | ~1000 words |
| > 50KB | ~2000 words max |

## Handoff Templates

### For Subagent Spawn

```markdown
## Handoff to [agent-type]

**Your Task**: [specific task]

**Current State**:
- Branch: [branch]
- Last commit: [commit-msg]

**Files to Work With**:
- [file1] - [purpose]
- [file2] - [purpose]

**Constraints**:
- [constraint 1]
- [constraint 2]

**Success Criteria**:
- [ ] [criterion 1]
- [ ] [criterion 2]
```

### For Session Recovery

```markdown
## Session Recovery Context

**Last Session**: [date]
**Duration**: [time]

**Completed**:
- [task 1]
- [task 2]

**In Progress**:
- [task] at [step]

**Next Actions**:
1. [action 1]
2. [action 2]

**Open Questions**:
- [question needing user input]
```

### For Wave Transition

```markdown
## Wave [N] Complete → Wave [N+1]

**Wave [N] Deliverables**:
- [artifact 1] at [path]
- [artifact 2] at [path]

**Verified Exports**:
- [export 1] from [file]
- [export 2] from [file]

**Wave [N+1] Dependencies Met**: YES/NO

**Blockers for Wave [N+1]**:
- [blocker if any]
```

## Quality Checklist

Before finalizing summary:

- [ ] Can another agent understand the task from this?
- [ ] Are all file paths absolute or clearly relative?
- [ ] Are decisions explained, not just listed?
- [ ] Is success criteria clear and testable?
- [ ] Are blockers explicitly called out?
