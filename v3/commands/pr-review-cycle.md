# PR Review Cycle (v3.0)

Process and address PR review feedback with deep codebase understanding.

## Parameters
- `pr_number` (optional): PR number to process. Auto-detects from current branch if omitted.

## Quick Start

```bash
# Process review for current branch's PR
/pr-review-cycle

# Process specific PR
/pr-review-cycle 123
```

## How It Works

v3.0 uses a discovery-first approach with native Claude Code features:

| v2.x | v3.0 |
|------|------|
| Shallow context (file + grep) | Deep context via Explore agent |
| Embedded instructions (348 lines) | Native subagents + scripts |
| Manual GitHub API calls | Shell script abstraction |
| No convention awareness | Convention discovery before fixing |

## Execution Flow

```
Git Branch Gate → Verify on PR branch
        ↓
PR Review Discovery Agent → Analyze scope, discover conventions
        │
        ├── PR Scope Analysis (files, modules)
        ├── Comment Categorization (priority ordering)
        ├── Convention Discovery (Explore agent)
        └── Reviewer Reference Resolution
        ↓
[Discovery returns context]
        ↓
PR Review Implementation Agent → Address comments with context
        │
        ├── Priority-ordered fixes (SECURITY → BUG → STYLE)
        ├── Convention-matched implementation
        ├── Commit and push
        ├── Post replies to GitHub
        └── Update PR with completion summary
        ↓
[Cycle complete - ready for re-review]
```

## For Claude Code

### Step 1: Validate Environment

```bash
# Check gh CLI authentication
gh auth status

# Verify on a branch with PR
gh pr view --json number,state,title,headRefName 2>/dev/null || echo "NO_PR"
```

**If no PR found:**
```
INFORM: "No PR found for current branch. Either:
         1. Provide PR number: /pr-review-cycle 123
         2. Create PR first: gh pr create"
EXIT
```

### Step 2: Get PR Status and Comments

```bash
# Get PR status
.claude/scripts/pr-review-operations.sh status [PR_NUMBER]

# Get all review comments
.claude/scripts/pr-review-operations.sh comments [PR_NUMBER]
```

**Check Review Decision:**
```
IF state == "MERGED":
  INFORM: "PR already merged"
  EXIT

IF state == "CLOSED":
  INFORM: "PR is closed"
  EXIT

IF reviewDecision == "APPROVED":
  INFORM: "PR is approved! Ready to merge: gh pr merge [NUMBER]"
  EXIT

IF no comments across all endpoints:
  INFORM: "No actionable feedback found. PR may be waiting for review."
  EXIT
```

### Step 3: Invoke Discovery Agent

```javascript
Task({
  subagent_type: "pr-review-discovery",
  prompt: `Analyze PR review context:
           PR Number: ${pr_number}
           PR Info: ${JSON.stringify(pr_info)}
           Comments: ${JSON.stringify(comments)}

           Return: Scope analysis, convention discovery, prioritized comments`
})
```

**Discovery Output:**
```json
{
  "status": "ready",
  "pr_number": 123,
  "actionable_comments": 6,
  "execution_recommendation": {...},
  "context": {
    "pr_scope": {...},
    "comments_by_priority": {...},
    "conventions_discovered": {...},
    "reference_resolutions": [...]
  }
}
```

### Step 4: Confirm Execution (if complex)

If discovery returns high complexity or many comments:

```javascript
AskUserQuestion({
  questions: [{
    question: `Discovery found ${actionable_comments} comments to address. Proceed?`,
    header: "Confirm",
    multiSelect: false,
    options: [
      { label: "Address All", description: `Process all ${actionable_comments} comments in priority order` },
      { label: "Critical Only", description: "Only address SECURITY and BUG categories" },
      { label: "Review First", description: "Show me the comments before proceeding" }
    ]
  }]
})
```

### Step 5: Invoke Implementation Agent

```javascript
Task({
  subagent_type: "pr-review-implementation",
  prompt: `Address PR review feedback:
           PR Number: ${pr_number}
           PR Info: ${JSON.stringify(pr_info)}
           Context: ${JSON.stringify(discovery_context)}

           Execute: Fix comments, commit, push, post replies, update PR`
})
```

### Step 6: Report Results

Display completion summary:

```
╔══════════════════════════════════════════════════════════════╗
║                 PR REVIEW CYCLE COMPLETE                      ║
╠══════════════════════════════════════════════════════════════╣
║ PR: #[NUMBER] - [TITLE]                                      ║
║ Branch: [BRANCH_NAME]                                        ║
║ Commit: [SHORT_SHA]                                          ║
╠══════════════════════════════════════════════════════════════╣
║ Comments Addressed: [COUNT]                                   ║
║   • Security: [X]  • Bugs: [Y]  • Style: [Z]                ║
║ Replies Posted: [COUNT]                                       ║
║ PR Updated: ✅                                                ║
║ Re-Review Triggered: ✅                                       ║
╠══════════════════════════════════════════════════════════════╣
║ NEXT STEPS:                                                   ║
║                                                               ║
║ Automated re-review requested via @claude-code mention.      ║
║ After re-review completes:                                   ║
║   • Run /pr-review-cycle again (if more feedback)            ║
║   • Merge: gh pr merge [NUMBER] --squash                     ║
╚══════════════════════════════════════════════════════════════╝
```

## Automated Re-Review Trigger

After addressing feedback and pushing, the implementation agent posts a PR comment with a review trigger:

```markdown
**@claude-code** please review the changes in commit `abc1234`
```

This creates an automated feedback loop:

```
/pr-review-cycle → Fix → Push → Trigger → @claude-code reviews → New comments → /pr-review-cycle
```

**Customization:**

| Your Setup | Trigger | How to Configure |
|------------|---------|------------------|
| Claude Code GitHub App | `@claude-code` | Default, works automatically |
| GitHub Actions | `<!-- REVIEW_TRIGGER -->` | Add workflow watching for comment |
| Other Bot | `@your-bot` | Edit `pr-review-implementation.md` |
| Manual Only | Remove trigger | Edit Step 7 in implementation agent |

## PR Review Operations (Shell Script)

All GitHub operations use `.claude/scripts/pr-review-operations.sh`:

```bash
# Get PR status
.claude/scripts/pr-review-operations.sh status [pr_number]

# Get all review comments
.claude/scripts/pr-review-operations.sh comments [pr_number]

# Get files changed
.claude/scripts/pr-review-operations.sh files [pr_number]

# Analyze PR scope
.claude/scripts/pr-review-operations.sh scope [pr_number]

# Categorize comments
.claude/scripts/pr-review-operations.sh categorize '[comments_json]'

# Reply to inline comment
.claude/scripts/pr-review-operations.sh reply-inline [pr] [comment_id] "[body]"

# Generate summary
.claude/scripts/pr-review-operations.sh summary [pr] [addressed] [replies]
```

## Native Agent Benefits

### Discovery Agent + Explore

```
WITHOUT Explore (v2.x):
  Comment: "This doesn't match our error handling pattern"
  Context: Only reads the specific file
  Result: May fix incorrectly, causing another review round

WITH Explore (v3.0):
  Comment: "This doesn't match our error handling pattern"
  Context: Discovers error handling pattern across codebase
  Result: Fix matches existing patterns, reviewer satisfied
```

### Convention-Aware Implementation

```
BEFORE: Fix based on general best practices
AFTER:  Fix matches discovered project conventions

Example:
  Convention discovered: "All handlers use AppError class with error codes"
  Fix applied: Uses AppError with appropriate code, not generic Error
```

## Error Handling

### Discovery Blocked
```
IF discovery returns status: "blocked"
  DISPLAY: blocker message
  SUGGEST: Resolution steps
  EXIT
```

### Implementation Partial
```
IF implementation returns status: "partial"
  DISPLAY: What was completed
  DISPLAY: What was skipped and why
  SUGGEST: Manual follow-up actions
```

### Push Failed
```
IF push fails:
  Implementation agent handles rebase
  IF still fails: Return manual instructions
```

### Reply Failed
```
IF GitHub API fails:
  Log warning
  Continue with other operations
  Report failed replies in summary
```

## Comparison: v2.x vs v3.0

| Aspect | v2.x | v3.0 |
|--------|------|------|
| Command size | 348 lines | ~150 lines |
| Context depth | File + grep | Explore agent + conventions |
| Comment handling | pr-review-handler skill | Native subagents |
| GitHub API | Inline bash | Shell script |
| Convention awareness | None | Full discovery |
| Reference resolution | None | Automatic |
| PR update | Manual | Automatic summary comment |

## Dependencies

**Required:**
- `gh` CLI installed and authenticated
- On a branch with an open PR (or provide PR number)
- `.claude/agents/pr-review-discovery.md`
- `.claude/agents/pr-review-implementation.md`
- `.claude/scripts/pr-review-operations.sh`

**No MCP server required** - all operations use native Bash tool with shell scripts.

## Integration with execute-tasks

After PR is approved:
```bash
# Merge the PR
gh pr merge [NUMBER] --squash

# Switch to main and pull
git checkout main && git pull

# Continue to next task/spec
/execute-tasks [SPEC_NAME]
```
