---
name: pr-review-handler
description: "Auto-invoke when processing PR review comments. Provides systematic approach to categorizing, addressing, and replying to review feedback with technical rigor."
allowed-tools: Read, Grep, Glob, Bash, Edit, Write
---

# PR Review Handler Skill

Systematic processing of PR review comments with technical rigor. This skill is auto-invoked by the `/pr-review-cycle` command.

**Core Principle:** ADDRESS WITH PRECISION, REPLY WITH CLARITY

## When to Use This Skill

Claude should invoke this skill:
- **During /pr-review-cycle command** execution
- **When manually addressing PR review feedback**
- **When review comments are pasted directly** into conversation
- **After pulling changes** that include review capture data

## Phase 1: Comment Categorization

### Detection Patterns

| Category | Keywords/Patterns | Priority | Action |
|----------|-------------------|----------|--------|
| `SECURITY` | security, vulnerability, unsafe, injection, XSS, SQL, CSRF, auth | **CRITICAL** | Fix immediately |
| `BUG` | bug, broken, doesn't work, error, crash, exception, fail | **HIGH** | Fix before other items |
| `LOGIC` | incorrect, wrong, should be, logic error, off-by-one | **HIGH** | Fix with test |
| `MISSING` | missing, add, implement, include, need, require | **MEDIUM** | Implement or explain |
| `PERF` | performance, slow, optimize, cache, memory, leak | **MEDIUM** | Evaluate and fix |
| `STYLE` | naming, format, style, convention, lint, indent | **LOW** | Apply project standard |
| `DOCS` | comment, document, explain, unclear, confusing | **LOW** | Add clarification |
| `QUESTION` | ends with ?, why, what, how, could you explain | **INFO** | Reply only, no code change |
| `SUGGESTION` | consider, might, could, optional, alternative | **INFO** | Evaluate and decide |
| `PRAISE` | great, nice, good, excellent, well done | **SKIP** | No action needed |

### Priority Processing Order

```
1. CRITICAL (SECURITY) - Block everything until fixed
2. HIGH (BUG, LOGIC) - Must fix, may reveal related issues
3. MEDIUM (MISSING, PERF) - Implement systematically
4. LOW (STYLE, DOCS) - Apply consistently
5. INFO (QUESTION, SUGGESTION) - Handle after code fixes
6. SKIP (PRAISE) - Acknowledge but no action
```

## Phase 2: Understanding Each Comment

### Context Gathering

For each comment:

```bash
# 1. Read the file
cat [FILE_PATH]

# 2. Check the diff context
git diff main...HEAD -- [FILE_PATH]

# 3. Find related code
grep -r "[RELATED_PATTERN]" src/
```

### Understanding Protocol

```
1. READ the diff_hunk (shows what reviewer saw)
2. READ surrounding context (±30 lines)
3. IDENTIFY what reviewer is concerned about
4. CHECK if there's a reason for current implementation
5. DETERMINE if fix is needed or explanation is sufficient
```

### Disambiguation

**IF comment is ambiguous:**
```
DO NOT assume. Ask for clarification:
"I see the comment on line X. Are you asking to:
A) [Interpretation 1]
B) [Interpretation 2]
Please clarify so I can address it correctly."
```

**IF multiple comments on same area:**
```
Group and address together to avoid conflicting changes.
Note which comments are addressed by which change.
```

## Phase 3: Implementing Fixes

### Fix Protocol

```
FOR EACH comment (in priority order):
  1. UNDERSTAND the request
  2. PLAN the minimal fix
  3. IMPLEMENT the change
  4. VERIFY no regressions
  5. MOVE to next comment
```

### Minimal Change Principle

```
DO:
- Make the smallest change that addresses the concern
- Match existing code style exactly
- Add tests if fixing bugs
- Keep changes in the same file when possible

DO NOT:
- Refactor unrelated code
- Add features not requested
- Change code style in other areas
- Over-engineer the solution
```

### Security Comment Handling

```
FOR SECURITY comments:
  1. STOP all other work
  2. UNDERSTAND the vulnerability
  3. RESEARCH proper mitigation
  4. IMPLEMENT fix with defense in depth
  5. ADD test proving vulnerability is fixed
  6. VERIFY no bypass exists
```

### Bug Fix Protocol

```
FOR BUG comments:
  1. REPRODUCE the issue (if possible)
  2. IDENTIFY root cause (not just symptom)
  3. WRITE failing test first
  4. FIX the bug
  5. VERIFY test passes
  6. CHECK for similar issues nearby
```

## Phase 4: Crafting Replies

### Reply Formats by Category

**Security/Bug Fix:**
```markdown
Fixed in [commit].

The vulnerability was [brief explanation].
Mitigation: [what was done].
Added test to prevent regression.
```

**Logic Error:**
```markdown
Corrected. The issue was [explanation].
Now [describes correct behavior].
See line [X] for the fix.
```

**Missing Implementation:**
```markdown
Added [feature/code].
Implementation: [brief explanation of approach].
```

**Style/Docs:**
```markdown
Updated to follow [convention/standard].
```
or
```markdown
Added documentation clarifying [topic].
```

**Question (no code change):**
```markdown
[Direct answer to the question]

The current implementation [reason for approach] because [technical justification].
```

**Suggestion (accepted):**
```markdown
Implemented. Good suggestion - [brief explanation of benefit].
```

**Suggestion (declined):**
```markdown
Considered but kept as-is because:
[Technical reason 1]
[Technical reason 2]

Happy to discuss if you see issues with this reasoning.
```

### What NOT to Say

```
NEVER:
- "You're absolutely right!" (performative)
- "Great catch!" (sycophantic)
- "Thanks for the feedback!" (unnecessary)
- "I should have caught that" (self-deprecating)

INSTEAD:
- Just fix it and describe what was done
- Provide technical explanation
- Ask clarifying questions if needed
```

## Phase 5: Verification

### Pre-Push Checklist

```
[ ] All HIGH priority comments addressed
[ ] All code changes compile/lint
[ ] Tests pass (including new tests)
[ ] No unrelated changes introduced
[ ] Reply drafted for each comment
[ ] Commit message summarizes all fixes
```

### Regression Check

```bash
# Run test suite
npm test  # or pytest, cargo test, etc.

# Check build
npm run build  # or equivalent

# Verify lint
npm run lint  # or equivalent
```

## Output Format

After processing all comments:

```markdown
## Review Response Summary

### Comments Processed: [N]

| # | Category | File:Line | Status | Action |
|---|----------|-----------|--------|--------|
| 1 | SECURITY | auth.ts:45 | Fixed | Added input sanitization |
| 2 | BUG | api.ts:123 | Fixed | Corrected null check |
| 3 | QUESTION | config.ts:67 | Replied | Explained caching strategy |
| 4 | SUGGESTION | utils.ts:89 | Declined | YAGNI - not used elsewhere |

### Changes Made
- `auth.ts`: Added XSS protection (lines 45-52)
- `api.ts`: Fixed null pointer dereference (line 123)

### Pending Clarification
- Comment #5: Need clarification on expected behavior

### Verification
- [x] All tests pass
- [x] Build succeeds
- [x] Linting clean
```

## Integration Notes

### With /pr-review-cycle Command

This skill is automatically invoked by `/pr-review-cycle`. The command:
1. Loads review data from `.agent-os/reviews/`
2. Invokes this skill for systematic processing
3. Handles commit and push after fixes

### With code-review Skill

This skill complements `code-review`:
- `code-review`: Requesting reviews and general feedback handling
- `pr-review-handler`: Automated processing of captured review data

### Standalone Usage

Can be used directly when review comments are provided:
```
User: "Here's the review feedback: [paste comments]"
Claude: [Invokes pr-review-handler skill]
```
