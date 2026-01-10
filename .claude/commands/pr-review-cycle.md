# PR Review Cycle (v4.9.0)

Process and address PR review feedback with deep codebase understanding.

**v4.9.0 Enhancements:**
- finalizeReviewResponse with gh pr ready and reviewer re-request
- Test coverage gap detection and recommendations
- Enhanced completion reporting

## Parameters
- `pr_number` (optional): PR number to process. Auto-detects from current branch if omitted.
- `--re-request` (optional): Automatically re-request review from original reviewers (v4.9.0)

## Quick Start

```bash
# Process review for current branch's PR
/pr-review-cycle

# Process specific PR
/pr-review-cycle 123

# Process and re-request review when done (v4.9.0)
/pr-review-cycle 123 --re-request
```

## How It Works

v3.0 uses a discovery-first approach with native Claude Code features:

| v2.x | v3.0+ |
|------|------|
| Shallow context (file + grep) | Deep context via Explore agent |
| Embedded instructions (348 lines) | Native subagents + scripts |
| Manual GitHub API calls | Shell script abstraction |
| No convention awareness | Convention discovery before fixing |
| No coverage analysis | Test coverage gap detection (v4.9.0) |

## Execution Flow

```
Git Branch Gate → Verify on PR branch
        ↓
PR Review Discovery Agent → Analyze scope, discover conventions
        │
        ├── PR Scope Analysis (files, modules)
        ├── Test Coverage Analysis (v4.9.0)
        ├── Comment Categorization (priority ordering)
        ├── Convention Discovery (Explore agent)
        └── Reviewer Reference Resolution
        ↓
[Discovery returns context]
        ↓
PR Review Implementation Agent → Address comments with context
        │
        ├── Priority-ordered fixes (SECURITY → BUG → COVERAGE → STYLE)
        ├── Convention-matched implementation
        ├── Commit and push
        ├── Post replies to GitHub
        └── Update PR with completion summary
        ↓
Finalize Review Response (v4.9.0)
        │
        ├── gh pr ready (mark as ready for review)
        ├── Re-request review from original reviewers
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
bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/pr-review-operations.sh" status [PR_NUMBER]

# Get all review comments
bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/pr-review-operations.sh" comments [PR_NUMBER]
```

**Check Review Decision:**
```
IF state == "MERGED":
  INFORM: "PR already merged"
  EXIT

IF state == "CLOSED":
  INFORM: "PR is closed"
  EXIT

IF no comments across all endpoints:
  INFORM: "No actionable feedback found. PR may be waiting for review."
  EXIT

# IMPORTANT: Even if PR is approved, we still need to check for FUTURE items!
# Don't short-circuit here - proceed to discovery to capture future enhancements
```

### Step 2.5: Check for FUTURE Items (Even on Approved PRs)

> **CRITICAL**: FUTURE items must be captured even when PR is approved. Reviews often include "Future Enhancements" sections that should be saved to `tasks.json` or `roadmap.md`.

```javascript
// Quick classification check for FUTURE items
Task({
  subagent_type: "comment-classifier",
  model: "haiku",
  prompt: `Quickly scan these PR comments for FUTURE items:
           ${JSON.stringify(comments)}

           Look for sections like:
           - "Future Enhancements"
           - "Nice to Have"
           - "Follow-up PRs"
           - "Wave X Enhancements"
           - "Should Address Soon"
           - "Low Priority"

           Return: { has_future_items: boolean, count: number }`
})
```

```
IF reviewDecision == "APPROVED" AND has_future_items == false:
  INFORM: "PR is approved! Ready to merge: gh pr merge [NUMBER]"
  EXIT

IF reviewDecision == "APPROVED" AND has_future_items == true:
  INFORM: "PR is approved. Capturing ${count} future enhancement items before merge..."
  CONTINUE to Step 3 (Discovery)
```

### Step 3: Invoke Discovery Agent

```javascript
Task({
  subagent_type: "pr-review-discovery",
  prompt: `Analyze PR review context:
           PR Number: ${pr_number}
           PR Info: ${JSON.stringify(pr_info)}
           Comments: ${JSON.stringify(comments)}

           Return: Scope analysis, convention discovery, prioritized comments, coverage analysis`
})
```

**Discovery Output:**
```json
{
  "status": "ready",
  "pr_number": 123,
  "actionable_comments": 6,
  "coverage_issues": 1,
  "execution_recommendation": {...},
  "coverage_summary": {
    "percentage": 75,
    "gaps": 1,
    "action_required": true
  },
  "context": {
    "pr_scope": {...},
    "coverage_analysis": {...},
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
    question: `Discovery found ${actionable_comments} comments to address (including ${coverage_issues} coverage issues). Proceed?`,
    header: "Confirm",
    multiSelect: false,
    options: [
      { label: "Address All", description: `Process all ${actionable_comments} comments in priority order` },
      { label: "Critical Only", description: "Only address SECURITY, BUG, and COVERAGE categories" },
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

### Step 6: Finalize Review Response (v4.9.0)

> **NEW in v4.9.0**: After implementation completes, finalize the review response

```javascript
/**
 * Finalize the PR review response
 * Marks PR as ready and optionally re-requests review
 */
async function finalizeReviewResponse(
  prNumber: number,
  options: { reRequest: boolean, originalReviewers: string[] }
): Promise<FinalizeResult> {
  const result: FinalizeResult = {
    pr_ready: false,
    reviewers_requested: [],
    errors: []
  };
  
  // 1. Mark PR as ready for review (converts from draft if applicable)
  try {
    await Bash({
      command: `gh pr ready ${prNumber} 2>/dev/null || echo "PR already ready"`
    });
    result.pr_ready = true;
  } catch (e) {
    result.errors.push(`Failed to mark PR ready: ${e.message}`);
  }
  
  // 2. Re-request review from original reviewers
  if (options.reRequest && options.originalReviewers.length > 0) {
    for (const reviewer of options.originalReviewers) {
      try {
        await Bash({
          command: `gh pr edit ${prNumber} --add-reviewer "${reviewer}"`
        });
        result.reviewers_requested.push(reviewer);
      } catch (e) {
        result.errors.push(`Failed to request review from ${reviewer}: ${e.message}`);
      }
    }
  }
  
  // 3. Post completion comment with @claude-code trigger
  const completionComment = `
## Review Feedback Addressed

All actionable review comments have been addressed in the latest commit.

### Changes Made
${generateChangesSummary(implementationResult)}

### Coverage Status
${formatCoverageStatus(discoveryContext.coverage_analysis)}

---

**@claude-code** please review the changes in the latest commit.
`;
  
  await Bash({
    command: `gh pr comment ${prNumber} --body "${escapeForBash(completionComment)}"`
  });
  
  return result;
}

/**
 * Get original reviewers from PR
 */
async function getOriginalReviewers(prNumber: number): Promise<string[]> {
  const result = await Bash({
    command: `gh pr view ${prNumber} --json reviews --jq '.reviews[].author.login' | sort -u`
  });
  return result.trim().split('\n').filter(Boolean);
}
```

### Step 7: Report Results

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
║   • Security: [X]  • Bugs: [Y]  • Coverage: [Z]  • Style: [W] ║
║ Replies Posted: [COUNT]                                       ║
║ PR Updated: ✅                                                ║
║ Re-Review Triggered: ✅                                       ║
╠══════════════════════════════════════════════════════════════╣
║ COVERAGE STATUS (v4.9.0):                                     ║
║   • Coverage: [XX]%                                          ║
║   • Tests Added: [N] files                                   ║
║   • Gaps Remaining: [M]                                      ║
╠══════════════════════════════════════════════════════════════╣
║ FUTURE ITEMS CAPTURED: [COUNT]                                ║
║   • tasks.json: [WAVE_TASK_COUNT] items                      ║
║   • roadmap.md: [ROADMAP_COUNT] items                        ║
╠══════════════════════════════════════════════════════════════╣
║ REVIEW RE-REQUEST (v4.9.0):                                   ║
║   • Reviewers notified: [REVIEWER_LIST]                      ║
║   • PR marked as ready: ✅                                    ║
╠══════════════════════════════════════════════════════════════╣
║ NEXT STEPS:                                                   ║
║                                                               ║
║ Automated re-review requested via @claude-code mention.      ║
║ After re-review completes:                                   ║
║   • Run /pr-review-cycle again (if more feedback)            ║
║   • Merge: gh pr merge [NUMBER] --squash                     ║
╚══════════════════════════════════════════════════════════════╝
```

**For approved PRs with only FUTURE items:**

```
╔══════════════════════════════════════════════════════════════╗
║              PR APPROVED - FUTURE ITEMS CAPTURED              ║
╠══════════════════════════════════════════════════════════════╣
║ PR: #[NUMBER] - [TITLE]                                      ║
║ Status: ✅ APPROVED - Ready to merge                         ║
╠══════════════════════════════════════════════════════════════╣
║ FUTURE ITEMS CAPTURED: [COUNT]                                ║
║                                                               ║
║ Saved to tasks.json:                                         ║
║   • F1: [Description]                                        ║
║   • F2: [Description]                                        ║
║                                                               ║
║ Saved to roadmap.md:                                         ║
║   • [Title] - [Brief description]                            ║
╠══════════════════════════════════════════════════════════════╣
║ NEXT STEPS:                                                   ║
║   • Merge: gh pr merge [NUMBER] --squash                     ║
║   • Future items will be available in next wave              ║
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

All GitHub operations use `"${CLAUDE_PROJECT_DIR}/.claude/scripts/pr-review-operations.sh"`:

```bash
# Get PR status
bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/pr-review-operations.sh" status [pr_number]

# Get all review comments
bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/pr-review-operations.sh" comments [pr_number]

# Get files changed
bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/pr-review-operations.sh" files [pr_number]

# Analyze PR scope
bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/pr-review-operations.sh" scope [pr_number]

# Categorize comments
bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/pr-review-operations.sh" categorize '[comments_json]'

# Reply to inline comment
bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/pr-review-operations.sh" reply-inline [pr] [comment_id] "[body]"

# Generate summary
bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/pr-review-operations.sh" summary [pr] [addressed] [replies]

# Mark PR ready (v4.9.0)
gh pr ready [pr_number]

# Re-request review (v4.9.0)
gh pr edit [pr_number] --add-reviewer "[reviewer]"
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

### Re-Request Failed (v4.9.0)
```
IF reviewer re-request fails:
  Log warning
  PR is still marked as ready
  Report in summary for manual follow-up
```

## Dependencies

**Required:**
- `gh` CLI installed and authenticated
- On a branch with an open PR (or provide PR number)
- `.claude/agents/pr-review-discovery.md`
- `.claude/agents/pr-review-implementation.md`
- `.claude/scripts/pr-review-operations.sh`

**No MCP server required** - all operations use native Bash tool with shell scripts.

---

## Changelog

### v4.9.0
- Added finalizeReviewResponse with gh pr ready integration
- Added automatic reviewer re-request functionality
- Added coverage analysis to discovery context
- Added --re-request flag parameter
- Enhanced completion report with coverage status

### v3.0
- Discovery-first architecture
- Native subagents + scripts
