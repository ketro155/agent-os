---
name: log-entry
description: Add an entry to the project memory logs (decisions, implementations, or insights)
version: 1.0.0
---

# Log Entry Skill

Add entries to the Agent OS memory layer for cross-session continuity.

## Usage

Invoke with: `/log-entry [type]`

Where `[type]` is one of:
- `decision` - Record an architectural or product decision
- `implementation` - Document significant code changes
- `insight` - Capture a learning or pattern

## Process

### 1. Determine Log Type

If not specified, ask the user:

<question>
What type of entry do you want to add?
- **decision**: An architectural or product choice with rationale
- **implementation**: Significant code changes and why
- **insight**: A learning, pattern, or idea for the future
</question>

### 2. Gather Entry Details

Based on type, collect the required information:

**For decisions:**
- Title
- Context (what prompted this?)
- Options considered
- Decision made
- Rationale (why this option?)
- Consequences (implications)

**For implementations:**
- Title
- Related spec/task
- Files changed
- Summary
- Why (motivation)
- Gotchas
- Future work

**For insights:**
- Title
- Category (Pattern | Anti-pattern | Idea | Learning)
- Source
- The insight itself
- How to apply it

### 3. Format and Append

Format the entry using the template from the appropriate log file and append it.

### 4. Log File Locations

```
.agent-os/logs/
├── decisions-log.md
├── implementation-log.md
└── insights.md
```

## Example Invocations

```
/log-entry decision
# Prompts for decision details, adds to decisions-log.md

/log-entry insight
# Prompts for insight details, adds to insights.md

/log-entry
# Asks which type, then collects details
```

## Tips

- Keep entries focused and concise
- Not every change needs logging - focus on significant decisions
- Cross-reference related specs, tasks, or code
- Use today's date in YYYY-MM-DD format
