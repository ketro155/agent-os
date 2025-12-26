# PR Review Cycle

> Process and address PR review feedback directly from GitHub

## Quick Navigation
- [Description](#description)
- [Parameters](#parameters)
- [Dependencies](#dependencies)
- [Task Tracking](#task-tracking)
- [Core Instructions](#core-instructions)
- [GitHub CLI Reference](#github-cli-reference)
- [Error Handling](#error-handling)

## Description
Fetch and address PR review feedback directly from GitHub using the `gh` CLI. No setup required - just run the command when you're ready to address review comments.

**Simple Workflow:**
```
execute-tasks → PR Created → Review Submitted → /pr-review-cycle → Address → Push → Repeat
```

## Parameters
- `pr_number` (optional): PR number to process. If omitted, auto-detects from current branch.

## Dependencies
**Required:**
- `gh` CLI installed and authenticated (`gh auth status`)
- On a branch with an open PR

## Task Tracking
**IMPORTANT: Use Claude's TodoWrite tool throughout execution:**
```javascript
const todos = [
  { content: "Fetch PR and review data from GitHub", status: "pending", activeForm: "Fetching PR data" },
  { content: "Parse review comments into todos", status: "pending", activeForm: "Parsing review comments" },
  { content: "Address review comments", status: "pending", activeForm: "Addressing review comments" },
  { content: "Capture future recommendations", status: "pending", activeForm: "Capturing future recommendations" },
  { content: "Assign waves to future tasks", status: "pending", activeForm: "Assigning waves to future tasks" },
  { content: "Commit and push fixes", status: "pending", activeForm: "Committing and pushing fixes" }
];
```

## Core Instructions

### Phase 1: Fetch PR Data

**Step 1.1: Determine PR Number**

IF `pr_number` parameter provided:
  USE: Provided PR number

ELSE:
  ```bash
  # Get PR for current branch
  gh pr view --json number,state,title,url,headRefName,baseRefName
  ```

  IF no PR found:
    ERROR: "No PR found for current branch. Please provide PR number or create a PR first."

**Step 1.2: Fetch Review Status**

```bash
# Get review decision and reviews
gh pr view [PR_NUMBER] --json reviewDecision,reviews,state
```

CHECK state:
- `MERGED` → SKIP: "PR already merged"
- `CLOSED` → SKIP: "PR is closed"

CHECK reviewDecision:
- `APPROVED` → SKIP: "PR is approved! Ready to merge: gh pr merge [NUMBER]"
- `CHANGES_REQUESTED` → CONTINUE: Process feedback
- `REVIEW_REQUIRED` → CHECK for comments anyway

**Step 1.3: Fetch Review Comments**

GitHub stores PR feedback in three separate locations. Check ALL THREE:

```bash
# 1. Inline code comments (attached to specific lines of code)
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments --jq '.[] | {id, path, line, body, user: .user.login, created_at, in_reply_to_id, type: "inline"}'

# 2. Formal reviews (approve/request changes submissions with body text)
gh api repos/{owner}/{repo}/pulls/{pr_number}/reviews --jq '.[] | select(.state != "APPROVED" and .body != "") | {id, body, user: .user.login, state, submitted_at, type: "review"}'

# 3. Issue comments (general PR conversation - where bots often post!)
gh api repos/{owner}/{repo}/issues/{pr_number}/comments --jq '.[] | {id, body, user: .user.login, created_at, type: "conversation"}'
```

> **Why three endpoints?** In GitHub's data model, PRs are also issues. Comments can be:
> - **Inline** (`/pulls/.../comments`): Attached to specific code lines
> - **Reviews** (`/pulls/.../reviews`): Part of formal review submissions
> - **Conversation** (`/issues/.../comments`): General comments in PR thread (common for bots)

IF no comments across ALL THREE endpoints:
  OUTPUT: "No actionable feedback found. PR may be waiting for review."
  EXIT

---

### Phase 2: Parse Comments into Todos

**Step 2.1: Categorize Each Comment**

For each comment, detect category from content:

| Category | Detection Pattern | Priority |
|----------|-------------------|----------|
| `SECURITY` | security, vulnerability, unsafe, injection, XSS, SQL | **CRITICAL** |
| `BUG` | bug, broken, doesn't work, error, crash, fail | **HIGH** |
| `LOGIC` | incorrect, wrong, should be, logic error | **HIGH** |
| `MISSING` | missing, add, implement, include, need | **MEDIUM** |
| `PERF` | performance, slow, optimize, memory | **MEDIUM** |
| `STYLE` | naming, format, style, convention, lint | **LOW** |
| `DOCS` | comment, document, explain, unclear | **LOW** |
| `QUESTION` | ends with ?, why, what, how | **INFO** |
| `SUGGESTION` | consider, might, could, optional | **INFO** |
| `FUTURE` | future, later, v2, next version, nice to have, follow-up, backlog, tech debt, out of scope, enhancement for later, eventually | **CAPTURE** |

**Step 2.2: Create Prioritized Todo List**

```javascript
// Sort: CRITICAL → HIGH → MEDIUM → LOW → INFO (FUTURE handled separately in Phase 3.5)
const todos = comments
  .filter(c => c.category !== 'QUESTION' && c.category !== 'FUTURE') // Questions and Future handled separately
  .sort((a, b) => priorityOrder[a.category] - priorityOrder[b.category])
  .map(c => ({
    content: `[${c.category}] ${summarize(c.body)} (${c.path}:${c.line})`,
    status: "pending",
    activeForm: `Addressing ${c.category.toLowerCase()} in ${c.path}`
  }));

// Separate future recommendations for capture
const futureItems = comments.filter(c => c.category === 'FUTURE');
```

**Step 2.3: Display Summary**

```
╔══════════════════════════════════════════════════════════════╗
║                    PR REVIEW FEEDBACK                         ║
╠══════════════════════════════════════════════════════════════╣
║ PR: #[NUMBER] - [TITLE]                                      ║
║ Status: Changes Requested                                     ║
║ Reviewer(s): @[REVIEWER1], @[REVIEWER2]                      ║
╠══════════════════════════════════════════════════════════════╣
║ Comments by Priority:                                         ║
║   CRITICAL: 0  |  HIGH: 2  |  MEDIUM: 3  |  LOW: 1           ║
╠══════════════════════════════════════════════════════════════╣
║ Questions (reply only): 1                                     ║
║ Future Recommendations (capture): 2                           ║
╚══════════════════════════════════════════════════════════════╝
```

---

### Phase 3: Address Each Comment

**Step 3.1: Process in Priority Order**

FOR EACH comment (CRITICAL → HIGH → MEDIUM → LOW):

1. **Mark todo in_progress**

2. **Read the file and context**
   ```bash
   # Read file at the commented line
   Read [FILE_PATH]
   # Focus on the specific line ± 20 lines for context
   ```

3. **Understand the feedback**
   - What is the reviewer asking for?
   - Is the current code actually wrong?
   - What's the minimal fix?

4. **Implement the fix**
   - Make targeted changes
   - Match existing code style
   - Don't over-engineer

5. **Mark todo completed**

**Step 3.2: Handle Questions**

For QUESTION category comments:
- DO NOT modify code
- PREPARE a reply explaining the reasoning
- Store for Phase 4

**Step 3.3: Handle Suggestions**

For SUGGESTION category:
- EVALUATE if it improves the code
- IF yes: Implement
- IF no: Prepare explanation for reply

---

### Phase 3.5: Capture Future Recommendations

**Purpose:** Capture reviewer suggestions for future work so they don't get lost after merge.

**Step 3.5.1: Classify Future Items (Using Subagent)**

For each FUTURE category comment, invoke the `future-classifier` subagent for context-aware classification:

```
INVOKE: Task tool with subagent_type="future-classifier"
INPUT:
  COMMENT: "[COMMENT_TEXT]"
  FILE_CONTEXT: "[FILE:LINE]"
  SPEC_FOLDER: "[CURRENT_SPEC_PATH]"
  PR_NUMBER: [NUMBER]
  REVIEWER: "@[REVIEWER]"
```

The subagent will:
1. Read `tasks.json` to check for duplicates and understand current scope
2. Read `roadmap.md` to check for existing similar items
3. Read the spec to understand feature domain
4. Return a classification with confidence and reasoning

**Classification Outcomes:**

| Result | Action |
|--------|--------|
| `WAVE_TASK` | Add to tasks.json future_tasks section |
| `ROADMAP_ITEM` | Add to roadmap.md |
| `SKIP` | Already captured elsewhere, no action needed |
| `ASK_USER` | Present options to user for decision |

**Fallback (if subagent unavailable):**
```
IF subagent fails OR timeout:
  USE keyword heuristics:
    - "quick fix", "small addition", "minor" → WAVE_TASK
    - "new feature", "v2", "major", "architecture" → ROADMAP_ITEM
  DEFAULT: ROADMAP_ITEM (more visible)
```

**Step 3.5.2: Create Future Task Entries**

> **CRITICAL: Future items get their OWN task entries in a `future_tasks` section.**
> **DO NOT attach `future_enhancement` fields to existing tasks - this breaks semantics when parent tasks are completed.**

For `WAVE_TASK` items:

```bash
# Read current tasks.json
cat .agent-os/specs/[SPEC_FOLDER]/tasks.json
```

```json
// Add to tasks.json under new "future_tasks" section (NOT as a field on existing tasks!)
{
  "future_tasks": [
    {
      "id": "F1",
      "source": "pr_review",
      "pr_number": [NUMBER],
      "reviewer": "@[REVIEWER]",
      "description": "[SUMMARIZED_RECOMMENDATION]",
      "original_comment": "[FULL_COMMENT_TEXT]",
      "file_context": "[FILE:LINE if applicable]",
      "captured_at": "[ISO_TIMESTAMP]",
      "priority": "backlog"
    }
  ]
}
```

**Anti-Pattern (DO NOT DO THIS):**
```json
// ❌ WRONG: Attaching to existing task
{
  "id": "3.9",
  "status": "pending",
  "future_enhancement": { ... }  // ❌ Task 3 may already be complete!
}

// ✓ CORRECT: Separate future_tasks section
{
  "future_tasks": [
    { "id": "F1", ... }  // ✓ Independent entry that won't be orphaned
  ]
}
```

**Step 3.5.3: Integrate Roadmap Items (v3.5.0)**

For `ROADMAP_ITEM` items, determine optimal phase placement before adding:

**Step 3.5.3a: Determine Placement**

```
INVOKE: Task tool with subagent_type="roadmap-integrator"
INPUT:
  ITEM_TITLE: "[SUGGESTED_TITLE from future-classifier]"
  ITEM_DESCRIPTION: "[SUMMARIZED_RECOMMENDATION]"
  ITEM_SOURCE: "PR #[NUMBER] review by @[REVIEWER]"
  ROADMAP_PATH: ".agent-os/product/roadmap.md"
  CURRENT_SPEC: "[SPEC_FOLDER]"
```

The subagent will:
1. Parse roadmap phase structure (goals, status, features)
2. Score each phase for theme similarity, dependency satisfaction, effort grouping
3. Return placement recommendation: existing_phase, new_phase, or ask_user

**Step 3.5.3b: Apply Placement Decision**

| Recommendation | Action |
|----------------|--------|
| `existing_phase` | Insert item into target phase at recommended position |
| `new_phase` | Create new phase section, then add item |
| `ask_user` | Present options, await user decision |

**For `existing_phase`:**
```
LOCATE: Target phase section in roadmap.md
INSERT at recommended position:
  - [ ] [ITEM_TITLE] `[EFFORT]` (from PR #[NUMBER])
    - Source: @[REVIEWER]
    - [SUMMARIZED_RECOMMENDATION]
```

**For `new_phase`:**
```markdown
## [SUGGESTED_PHASE_NAME]

**Goal:** [SUGGESTED_GOAL]

**Status:** Proposed

### Features

- [ ] [ITEM_TITLE] `[EFFORT]` (from PR #[NUMBER])
  - Source: @[REVIEWER]
  - [SUMMARIZED_RECOMMENDATION]
```

**For `ask_user`:**
```
PRESENT options from roadmap-integrator output
AWAIT user selection
APPLY selected placement
```

**Fallback (if subagent unavailable):**
```bash
# Append to end of roadmap.md (legacy behavior)
cat >> .agent-os/product/roadmap.md << 'EOF'

### [ITEM_TITLE] (from PR #[NUMBER] review)
- **Source:** PR review by @[REVIEWER]
- **Description:** [SUMMARIZED_RECOMMENDATION]
- **Status:** Proposed
- **Added:** [DATE]
EOF
```

**Step 3.5.4: Reply to Future Comments**

For each captured FUTURE comment:

```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments/{comment_id}/replies \
  -X POST -f body="Captured for future work. Added to [tasks.json|roadmap.md]."
```

---

### Phase 3.6: Assign Waves to Future Tasks (v3.4.0)

> **Purpose:** Assign wave numbers to WAVE_TASK items immediately after capture, while context is fresh. This eliminates the need for wave assignment during execute-tasks.

**Step 3.6.1: Determine Next Wave Number**

```bash
# Read current tasks.json to find the highest wave
cat .agent-os/specs/[SPEC_FOLDER]/tasks.json | jq '
  .execution_strategy.waves |
  if . then (map(.wave_id) | max) else 0 end
'
```

**Wave Assignment Logic:**
```
1. GET highest_wave from execution_strategy.waves
   IF no waves exist: highest_wave = 0

2. GET pending_tasks from tasks where status != "completed"

3. DETERMINE target_wave:
   IF pending_tasks in highest_wave exist:
     target_wave = highest_wave + 1  # New wave after current work
   ELSE:
     target_wave = highest_wave + 1  # Next sequential wave

4. STORE: target_wave for assignment
```

**Step 3.6.2: Update WAVE_TASK Priorities**

For each WAVE_TASK item just added to future_tasks:

```bash
# Update the priority from "backlog" to "wave_N"
bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/task-operations.sh" update-future-priority [FUTURE_ID] "wave_[TARGET_WAVE]" [spec-name]
```

**Alternative (direct JSON update):**
```json
// Change from:
{
  "id": "F1",
  "priority": "backlog",
  ...
}

// To:
{
  "id": "F1",
  "priority": "wave_8",
  "assigned_wave": 8,
  "wave_assigned_at": "[ISO_TIMESTAMP]",
  ...
}
```

**Step 3.6.3: Immediate Task Expansion (v3.6.0)**

> **MANDATORY**: Expand ALL WAVE_TASK items immediately into actual tasks. This prevents orphan future_tasks and ensures the task list is immediately actionable.

```
FOR EACH wave_task in captured WAVE_TASKs:

  # 1. Read file context for intelligent subtask generation
  IF wave_task.file_context exists:
    READ: wave_task.file_context to understand code structure

  # 2. Generate subtasks using expand-backlog patterns
  INVOKE: expand-backlog skill (inline, no subagent needed)
  INPUT:
    description: wave_task.description
    file_context: wave_task.file_context
    category: wave_task.category
    target_wave: [TARGET_WAVE]

  # 3. Determine next available task ID
  next_task_id = max(existing_task_ids) + 1

  # 4. Create parent task with subtasks
  parent_task = {
    "id": "[next_task_id]",
    "type": "parent",
    "description": wave_task.description,
    "status": "pending",
    "wave": [TARGET_WAVE],
    "source": "PR #[NUMBER] review",
    "expanded_from": wave_task.id,
    "subtasks": ["[next_task_id].1", "[next_task_id].2", ...],
    "created_at": "[ISO_TIMESTAMP]"
  }

  subtasks = [
    {
      "id": "[next_task_id].1",
      "type": "subtask",
      "parent": "[next_task_id]",
      "description": "Write tests for [functionality] (TDD RED)",
      "status": "pending",
      "tdd_phase": "red",
      "file_path": "[test_file_path]"
    },
    // ... additional subtasks based on complexity
  ]

  # 5. Add to main tasks array
  bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/task-operations.sh" add-expanded-task '<json>' [spec-name]

  # 6. Remove from future_tasks (task is now in main tasks)
  bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/task-operations.sh" remove-future-task [wave_task.id] [spec-name]

  TRACK: expanded_tasks.push({ from: wave_task.id, to: next_task_id })
```

**Subtask Generation Guidelines:**

| Category | Typical Subtasks |
|----------|------------------|
| REFACTOR | 1. Write characterization tests, 2. Extract/rename, 3. Verify |
| DOCS | 1. Add documentation, 2. Verify renders correctly |
| LOGGING | 1. Add log statements, 2. Test log output, 3. Verify |
| TEST_COVERAGE | 1. Write tests, 2. Verify coverage, 3. Commit |
| PERF | 1. Benchmark current, 2. Implement optimization, 3. Verify improvement |

**Why Immediate Expansion (v3.6.0):**
- No orphan `future_tasks` waiting indefinitely
- Task list immediately reflects full scope
- User can see and prioritize all work
- `execute-tasks` fallback handles edge cases only

**Step 3.6.4: Update Summary with Wave Assignments**

Include wave assignments in the Phase 6 summary:

```
╠══════════════════════════════════════════════════════════════╣
║ FUTURE RECOMMENDATIONS CAPTURED:                              ║
║   • Wave Tasks: [COUNT] → tasks.json (assigned to wave [N])  ║
║   • Roadmap Items: [COUNT] → roadmap.md                      ║
╚══════════════════════════════════════════════════════════════╝
```

---

### Phase 4: Reply to Comments (Optional)

**Step 4.1: Reply to Inline Comments**

For each addressed comment:

```bash
# Reply to a review comment
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments/{comment_id}/replies \
  -X POST -f body="Fixed. [Brief explanation]"
```

Reply formats:
- Bug/Security: "Fixed in this commit. [Explanation of fix]"
- Logic: "Corrected - now [describes correct behavior]"
- Style: "Updated to follow project conventions"
- Question: "[Direct answer to question]"
- Suggestion declined: "Kept as-is because [reason]"

---

### Phase 5: Commit and Push

**Step 5.1: Check for Changes**

```bash
git status --porcelain
```

IF no changes:
  OUTPUT: "No code changes needed - only replies posted"
  EXIT

**Step 5.2: Stage and Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
fix: address PR review feedback

Addressed feedback from reviewer(s):
- [Summary of fix 1]
- [Summary of fix 2]

Comments addressed: [COUNT]

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

**Step 5.3: Push**

```bash
git push origin [BRANCH_NAME]
```

---

### Phase 6: Report Summary

```
╔══════════════════════════════════════════════════════════════╗
║                 PR REVIEW CYCLE COMPLETE                      ║
╠══════════════════════════════════════════════════════════════╣
║ PR: #[NUMBER] - [TITLE]                                      ║
║ Comments Addressed: [COUNT]                                   ║
║ Replies Posted: [COUNT]                                       ║
║ Commit: [SHORT_SHA]                                          ║
╠══════════════════════════════════════════════════════════════╣
║ FUTURE RECOMMENDATIONS EXPANDED (v3.6.0):                     ║
║   • Wave Tasks: [COUNT] → expanded into wave [N] tasks       ║
║   • New Parent Tasks: [IDS] with [SUBTASK_COUNT] subtasks    ║
║   • Roadmap Items: [COUNT] → roadmap.md                      ║
╠══════════════════════════════════════════════════════════════╣
║ NEXT STEPS:                                                   ║
║                                                               ║
║ Wait for re-review, then either:                             ║
║   • Run /pr-review-cycle again (if more feedback)            ║
║   • Merge: gh pr merge [NUMBER] --squash                     ║
║   • Start wave [N]: /execute-tasks (tasks ready immediately) ║
╚══════════════════════════════════════════════════════════════╝
```

**Expanded Tasks Detail (v3.6.0):**
```
┌──────────────────────────────────────────────────────────────────────┐
│ EXPANDED FUTURE RECOMMENDATIONS → ACTUAL TASKS                        │
├──────────────┬────────┬──────────────────────────────────────────────┤
│ Source       │ Task   │ Description                                  │
├──────────────┼────────┼──────────────────────────────────────────────┤
│ F1 (REFACTOR)│ 8      │ [DESCRIPTION] (3 subtasks)                  │
│ F2 (DOCS)    │ 9      │ [DESCRIPTION] (2 subtasks)                  │
│ F3 (LOGGING) │ 10     │ [DESCRIPTION] (3 subtasks)                  │
├──────────────┴────────┴──────────────────────────────────────────────┤
│ ROADMAP ITEMS (not expanded - larger scope)                          │
├──────────────┬────────┬──────────────────────────────────────────────┤
│ ROADMAP      │ -      │ [DESCRIPTION] → roadmap.md                  │
└──────────────┴────────┴──────────────────────────────────────────────┘
```

---

## GitHub CLI Reference

### Check PR Status
```bash
gh pr view [NUMBER] --json state,reviewDecision,title,url
```

### Get PR Comments (Three Endpoints!)

GitHub stores comments in three locations - **check all three** for complete coverage:

```bash
# 1. Inline code comments (attached to specific lines)
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments

# 2. Formal review submissions (approve/request changes with body)
gh api repos/{owner}/{repo}/pulls/{pr_number}/reviews

# 3. Conversation comments (general PR thread - common for bots!)
gh api repos/{owner}/{repo}/issues/{pr_number}/comments
```

| Endpoint | Contains | Common Use |
|----------|----------|------------|
| `/pulls/.../comments` | Line-specific code comments | Human reviewers clicking on code |
| `/pulls/.../reviews` | Review submission bodies | Formal approve/request changes |
| `/issues/.../comments` | General PR comments | Bots, CI feedback, discussions |

### Reply to Comment
```bash
# Reply to inline code comment
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments/{comment_id}/replies \
  -X POST -f body="Reply text"

# Reply to conversation comment (issue comment)
gh api repos/{owner}/{repo}/issues/comments/{comment_id} \
  -X PATCH -f body="Reply text"
```

### Check Review Decision
```bash
gh pr view [NUMBER] --json reviewDecision --jq '.reviewDecision'
# Returns: APPROVED, CHANGES_REQUESTED, or REVIEW_REQUIRED
```

### Get Owner/Repo
```bash
gh repo view --json owner,name --jq '"\(.owner.login)/\(.name)"'
```

---

## Error Handling

| Error | Recovery |
|-------|----------|
| `gh` not authenticated | Run `gh auth login` |
| No PR for branch | Create PR first: `gh pr create` |
| API rate limit | Wait or use PAT with higher limits |
| Push rejected | Pull and rebase: `git pull --rebase` |
| Comment reply fails | Log warning, continue with fixes |

---

## Integration with execute-tasks

After PR is approved:
1. Merge PR: `gh pr merge [NUMBER] --squash`
2. Switch to main: `git checkout main && git pull`
3. Continue to next wave: `/execute-tasks [SPEC_PATH]`
