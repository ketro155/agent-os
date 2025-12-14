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

```bash
# Get all review comments (inline code comments)
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments --jq '.[] | {id, path, line, body, user: .user.login, created_at, in_reply_to_id}'

# Get review bodies (general review comments)
gh api repos/{owner}/{repo}/pulls/{pr_number}/reviews --jq '.[] | select(.state != "APPROVED" and .body != "") | {id, body, user: .user.login, state, submitted_at}'
```

IF no comments AND no review bodies with feedback:
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

**Step 2.2: Create Prioritized Todo List**

```javascript
// Sort: CRITICAL → HIGH → MEDIUM → LOW → INFO
const todos = comments
  .filter(c => c.category !== 'QUESTION') // Questions handled separately
  .sort((a, b) => priorityOrder[a.category] - priorityOrder[b.category])
  .map(c => ({
    content: `[${c.category}] ${summarize(c.body)} (${c.path}:${c.line})`,
    status: "pending",
    activeForm: `Addressing ${c.category.toLowerCase()} in ${c.path}`
  }));
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
║ NEXT STEPS:                                                   ║
║                                                               ║
║ Wait for re-review, then either:                             ║
║   • Run /pr-review-cycle again (if more feedback)            ║
║   • Merge: gh pr merge [NUMBER] --squash                     ║
║   • Continue to next wave                                     ║
╚══════════════════════════════════════════════════════════════╝
```

---

## GitHub CLI Reference

### Check PR Status
```bash
gh pr view [NUMBER] --json state,reviewDecision,title,url
```

### Get Review Comments (Inline)
```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments
```

### Get Reviews (General Comments)
```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/reviews
```

### Reply to Comment
```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments/{comment_id}/replies \
  -X POST -f body="Reply text"
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
