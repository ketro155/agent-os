#!/bin/bash
# Agent OS v3.0 - PR Review Operations Script
# Handles GitHub API operations for /pr-review-cycle command
# Called by pr-review-discovery and pr-review-implementation agents

set -e

COMMAND="${1:-help}"
shift || true

# Get owner/repo from git remote
get_repo_info() {
  gh repo view --json owner,name --jq '"\(.owner.login)/\(.name)"' 2>/dev/null
}

# Determine PR number from current branch or parameter
get_pr_number() {
  local pr_num="$1"

  if [ -n "$pr_num" ]; then
    echo "$pr_num"
  else
    gh pr view --json number --jq '.number' 2>/dev/null
  fi
}

case "$COMMAND" in

  # Get PR status and review decision
  status)
    PR_NUMBER=$(get_pr_number "$1")

    if [ -z "$PR_NUMBER" ]; then
      echo '{"error": "No PR found for current branch. Provide PR number or create a PR first."}'
      exit 1
    fi

    gh pr view "$PR_NUMBER" --json number,state,title,url,headRefName,baseRefName,reviewDecision,isDraft,mergeable
    ;;

  # Get all review comments from all three GitHub endpoints
  comments)
    PR_NUMBER=$(get_pr_number "$1")
    REPO_INFO=$(get_repo_info)

    if [ -z "$PR_NUMBER" ] || [ -z "$REPO_INFO" ]; then
      echo '{"error": "Could not determine PR number or repo info"}'
      exit 1
    fi

    # Create temp files for each endpoint
    INLINE_FILE=$(mktemp)
    REVIEWS_FILE=$(mktemp)
    CONVERSATION_FILE=$(mktemp)

    # 1. Inline code comments (attached to specific lines)
    gh api "repos/$REPO_INFO/pulls/$PR_NUMBER/comments" \
      --jq '[.[] | {
        id: .id,
        type: "inline",
        path: .path,
        line: (.line // .original_line),
        diff_hunk: .diff_hunk,
        body: .body,
        user: .user.login,
        created_at: .created_at,
        in_reply_to_id: .in_reply_to_id
      }]' 2>/dev/null > "$INLINE_FILE" || echo "[]" > "$INLINE_FILE"

    # 2. Formal review submissions (approve/request changes with body)
    gh api "repos/$REPO_INFO/pulls/$PR_NUMBER/reviews" \
      --jq '[.[] | select(.state != "APPROVED" or .body != "") | {
        id: .id,
        type: "review",
        state: .state,
        body: .body,
        user: .user.login,
        submitted_at: .submitted_at
      }]' 2>/dev/null > "$REVIEWS_FILE" || echo "[]" > "$REVIEWS_FILE"

    # 3. Conversation comments (general PR thread - common for bots)
    gh api "repos/$REPO_INFO/issues/$PR_NUMBER/comments" \
      --jq '[.[] | {
        id: .id,
        type: "conversation",
        body: .body,
        user: .user.login,
        created_at: .created_at
      }]' 2>/dev/null > "$CONVERSATION_FILE" || echo "[]" > "$CONVERSATION_FILE"

    # Combine all comments
    jq -s '{
      inline: .[0],
      reviews: .[1],
      conversation: .[2],
      total: ((.[0] | length) + (.[1] | length) + (.[2] | length))
    }' "$INLINE_FILE" "$REVIEWS_FILE" "$CONVERSATION_FILE"

    # Cleanup
    rm -f "$INLINE_FILE" "$REVIEWS_FILE" "$CONVERSATION_FILE"
    ;;

  # Get files changed in the PR
  files)
    PR_NUMBER=$(get_pr_number "$1")

    if [ -z "$PR_NUMBER" ]; then
      echo '{"error": "No PR found"}'
      exit 1
    fi

    gh pr diff "$PR_NUMBER" --name-only | jq -R -s -c 'split("\n") | map(select(length > 0))'
    ;;

  # Get the full diff for context
  diff)
    PR_NUMBER=$(get_pr_number "$1")
    FILE_PATH="$2"

    if [ -z "$PR_NUMBER" ]; then
      echo '{"error": "No PR found"}'
      exit 1
    fi

    if [ -n "$FILE_PATH" ]; then
      gh pr diff "$PR_NUMBER" -- "$FILE_PATH"
    else
      gh pr diff "$PR_NUMBER"
    fi
    ;;

  # Categorize comments by priority
  # NOTE: This is the FALLBACK method. Primary classification uses LLM (comment-classifier agent)
  # Enhanced to detect Claude Code reviewer section headers and severity markers
  categorize)
    COMMENTS_JSON="$1"

    if [ -z "$COMMENTS_JSON" ]; then
      echo '{"error": "Usage: pr-review-operations.sh categorize <comments_json>"}'
      exit 1
    fi

    echo "$COMMENTS_JSON" | jq '
      # Claude Code reviewer section header patterns (comprehensive)
      # These override keyword-based categorization when present
      def detect_section_category:
        . as $body |
        # Critical/Blocking issues - multiple variations
        if ($body | test("Critical Issues|Must Fix|Blocking|Blockers|Critical Bugs|Security Issues|\\*\\*CRITICAL\\*\\*|🔴\\s*Critical"; "i")) then
          { category: "SECURITY", priority: 1, source: "claude_section" }
        # Should fix before merge (high priority) - expanded patterns
        elif ($body | test("Should Fix Before Merge|Recommended.*Fix|Fix Before Merge|Important Issues|High Priority|\\*\\*HIGH\\*\\*|🟠\\s*High"; "i")) then
          { category: "HIGH", priority: 2, source: "claude_section" }
        # Future waves / deferred items - CAPTURE these (comprehensive)
        elif ($body | test("Can Be Addressed in Future|Future Waves|Address Later|Future Considerations|Backlog|Tech Debt|Out of Scope|Future Improvements|Potential Enhancements|Beyond Scope|For Future|Consider for v2|Post-MVP|Phase 2|Nice-to-Have|Deferred|Low Priority Items"; "i")) then
          { category: "FUTURE", priority: 6, source: "claude_section" }
        # Nice to have / optional / suggestions
        elif ($body | test("Nice to Have|Optional|Consider for Future|Low Priority|Minor Issues|Minor Suggestions|Nitpicks|Style Suggestions|\\*\\*LOW\\*\\*|🟡\\s*Low|⚪\\s*Info"; "i")) then
          { category: "SUGGESTION", priority: 5, source: "claude_section" }
        # Medium priority
        elif ($body | test("Medium Priority|\\*\\*MEDIUM\\*\\*|🟡\\s*Medium"; "i")) then
          { category: "MISSING", priority: 3, source: "claude_section" }
        # Approved with notes
        elif ($body | test("APPROVE|LGTM|Looks Good|Ship It|Ready to Merge|✅|👍"; "i")) then
          { category: "PRAISE", priority: 7, source: "claude_section" }
        # Code quality sections
        elif ($body | test("Code Quality|Testing|Documentation|Test Coverage"; "i")) then
          { category: "STYLE", priority: 4, source: "claude_section" }
        else
          null
        end;

      # Keyword-based categorization (fallback)
      def categorize_by_keywords:
        . as $body |
        if ($body | test("security|vulnerability|unsafe|injection|XSS|SQL|CSRF|auth"; "i")) then
          { category: "SECURITY", priority: 1, source: "keyword" }
        elif ($body | test("bug|broken|doesn.t work|error|crash|exception|fail"; "i")) then
          { category: "BUG", priority: 2, source: "keyword" }
        elif ($body | test("incorrect|wrong|should be|logic error|off.by.one"; "i")) then
          { category: "LOGIC", priority: 2, source: "keyword" }
        elif ($body | test("missing|add|implement|include|need|require"; "i")) then
          { category: "MISSING", priority: 3, source: "keyword" }
        elif ($body | test("performance|slow|optimize|cache|memory|leak"; "i")) then
          { category: "PERF", priority: 3, source: "keyword" }
        elif ($body | test("naming|format|style|convention|lint|indent"; "i")) then
          { category: "STYLE", priority: 4, source: "keyword" }
        elif ($body | test("comment|document|explain|unclear|confusing"; "i")) then
          { category: "DOCS", priority: 4, source: "keyword" }
        elif ($body | test("\\?$"; "m")) then
          { category: "QUESTION", priority: 5, source: "keyword" }
        elif ($body | test("consider|might|could|optional|alternative"; "i")) then
          { category: "SUGGESTION", priority: 5, source: "keyword" }
        elif ($body | test("great|nice|good|excellent|well done|lgtm"; "i")) then
          { category: "PRAISE", priority: 6, source: "keyword" }
        else
          { category: "OTHER", priority: 5, source: "keyword" }
        end;

      # Main categorization: section headers take precedence over keywords
      def categorize_body:
        . as $body |
        (detect_section_category) as $section_cat |
        if $section_cat != null then
          $section_cat
        else
          categorize_by_keywords
        end;

      . | map(. + ((.body // "") | categorize_body)) | sort_by(.priority)
    '
    ;;

  # Reply to an inline code comment
  reply-inline)
    PR_NUMBER="$1"
    COMMENT_ID="$2"
    REPLY_BODY="$3"
    REPO_INFO=$(get_repo_info)

    if [ -z "$PR_NUMBER" ] || [ -z "$COMMENT_ID" ] || [ -z "$REPLY_BODY" ]; then
      echo '{"error": "Usage: pr-review-operations.sh reply-inline <pr_number> <comment_id> <reply_body>"}'
      exit 1
    fi

    gh api "repos/$REPO_INFO/pulls/$PR_NUMBER/comments/$COMMENT_ID/replies" \
      -X POST -f body="$REPLY_BODY" \
      --jq '{success: true, id: .id}'
    ;;

  # Reply to a conversation comment
  reply-conversation)
    COMMENT_ID="$1"
    REPLY_BODY="$2"
    REPO_INFO=$(get_repo_info)

    if [ -z "$COMMENT_ID" ] || [ -z "$REPLY_BODY" ]; then
      echo '{"error": "Usage: pr-review-operations.sh reply-conversation <comment_id> <reply_body>"}'
      exit 1
    fi

    # For issue comments, we add a new comment (can't directly reply)
    PR_NUMBER=$(gh pr view --json number --jq '.number' 2>/dev/null)

    gh api "repos/$REPO_INFO/issues/$PR_NUMBER/comments" \
      -X POST -f body="$REPLY_BODY" \
      --jq '{success: true, id: .id}'
    ;;

  # Get PR scope analysis (files by module/area)
  scope)
    PR_NUMBER=$(get_pr_number "$1")

    if [ -z "$PR_NUMBER" ]; then
      echo '{"error": "No PR found"}'
      exit 1
    fi

    FILES=$(gh pr diff "$PR_NUMBER" --name-only 2>/dev/null || echo "")

    if [ -z "$FILES" ]; then
      echo '{"error": "Could not get PR files"}'
      exit 1
    fi

    echo "$FILES" | jq -R -s -c '
      split("\n") | map(select(length > 0)) |
      {
        files: .,
        count: length,
        modules: (
          map(split("/")[0:2] | join("/")) |
          group_by(.) |
          map({module: .[0], files: length}) |
          sort_by(-.files)
        ),
        file_types: (
          map(split(".")[-1]) |
          group_by(.) |
          map({extension: .[0], count: length}) |
          sort_by(-.count)
        ),
        has_tests: any(test("test|spec"; "i")),
        has_src: any(startswith("src/")),
        has_config: any(test("config|\\.(json|yaml|yml|toml)$"; "i"))
      }
    '
    ;;

  # Generate summary for completed review cycle
  summary)
    PR_NUMBER=$(get_pr_number "$1")
    COMMENTS_ADDRESSED="$2"
    REPLIES_POSTED="$3"

    if [ -z "$PR_NUMBER" ]; then
      echo '{"error": "No PR found"}'
      exit 1
    fi

    PR_INFO=$(gh pr view "$PR_NUMBER" --json number,title,url,headRefName)
    COMMIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

    echo "$PR_INFO" | jq \
      --arg comments "${COMMENTS_ADDRESSED:-0}" \
      --arg replies "${REPLIES_POSTED:-0}" \
      --arg commit "$COMMIT_SHA" \
      '. + {
        comments_addressed: ($comments | tonumber),
        replies_posted: ($replies | tonumber),
        commit: $commit,
        timestamp: (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
      }'
    ;;

  # Check if Claude Code bot has reviewed the PR
  # Usage: pr-review-operations.sh bot-reviewed [pr_number]
  # Returns: {"reviewed": true/false, "review_decision": "APPROVED"|"CHANGES_REQUESTED"|null}
  bot-reviewed)
    PR_NUMBER=$(get_pr_number "$1")
    REPO_INFO=$(get_repo_info)

    if [ -z "$PR_NUMBER" ] || [ -z "$REPO_INFO" ]; then
      echo '{"error": "Could not determine PR number or repo info"}'
      exit 1
    fi

    # Get all reviews and filter for bot reviews
    # Claude Code bot username patterns: "claude-code[bot]", "claude[bot]", or contains "claude"
    BOT_REVIEWS=$(gh api "repos/$REPO_INFO/pulls/$PR_NUMBER/reviews" \
      --jq '[.[] | select(.user.login | test("claude|Claude"; "i"))]' 2>/dev/null || echo "[]")

    BOT_REVIEW_COUNT=$(echo "$BOT_REVIEWS" | jq 'length')

    if [ "$BOT_REVIEW_COUNT" = "0" ] || [ -z "$BOT_REVIEW_COUNT" ]; then
      # No formal review - check conversation comments (bots often use these)
      BOT_COMMENTS=$(gh api "repos/$REPO_INFO/issues/$PR_NUMBER/comments" \
        --jq '[.[] | select(.user.login | test("claude|Claude"; "i"))]' 2>/dev/null || echo "[]")

      BOT_COMMENT_COUNT=$(echo "$BOT_COMMENTS" | jq 'length')

      if [ "$BOT_COMMENT_COUNT" = "0" ] || [ -z "$BOT_COMMENT_COUNT" ]; then
        echo '{
          "reviewed": false,
          "review_decision": null,
          "bot_user": null,
          "message": "No Claude Code bot review or comments found"
        }'
        exit 0
      fi

      # Bot has commented but not formally reviewed
      LATEST_COMMENT=$(echo "$BOT_COMMENTS" | jq 'sort_by(.created_at) | last')
      BOT_USER=$(echo "$LATEST_COMMENT" | jq -r '.user.login')
      COMMENT_TIME=$(echo "$LATEST_COMMENT" | jq -r '.created_at')

      echo '{
        "reviewed": true,
        "review_type": "comment",
        "review_decision": null,
        "bot_user": "'"$BOT_USER"'",
        "comment_time": "'"$COMMENT_TIME"'",
        "message": "Bot has commented on PR (no formal review submission)"
      }'
      exit 0
    fi

    # Bot has formal review - get the latest one
    LATEST_REVIEW=$(echo "$BOT_REVIEWS" | jq 'sort_by(.submitted_at) | last')
    REVIEW_STATE=$(echo "$LATEST_REVIEW" | jq -r '.state')
    BOT_USER=$(echo "$LATEST_REVIEW" | jq -r '.user.login')
    SUBMITTED_AT=$(echo "$LATEST_REVIEW" | jq -r '.submitted_at')

    # Map GitHub review state to our decision format
    case "$REVIEW_STATE" in
      APPROVED)
        DECISION="APPROVED"
        ;;
      CHANGES_REQUESTED)
        DECISION="CHANGES_REQUESTED"
        ;;
      COMMENTED)
        DECISION="PENDING"
        ;;
      DISMISSED)
        DECISION="DISMISSED"
        ;;
      *)
        DECISION="PENDING"
        ;;
    esac

    echo '{
      "reviewed": true,
      "review_type": "formal",
      "review_decision": "'"$DECISION"'",
      "review_state": "'"$REVIEW_STATE"'",
      "bot_user": "'"$BOT_USER"'",
      "submitted_at": "'"$SUBMITTED_AT"'",
      "review_count": '"$BOT_REVIEW_COUNT"'
    }'
    ;;

  help|*)
    cat << 'EOF'
Agent OS v4.4.1 PR Review Operations

Usage: pr-review-operations.sh <command> [args]

Commands:
  status [pr_number]                     Get PR status and review decision
  comments [pr_number]                   Get all review comments (3 endpoints)
  files [pr_number]                      Get files changed in the PR
  diff [pr_number] [file_path]           Get PR diff (optionally for specific file)
  categorize <comments_json>             Categorize comments by priority
  reply-inline <pr> <comment_id> <body>  Reply to inline code comment
  reply-conversation <id> <body>         Reply to conversation comment
  scope [pr_number]                      Analyze PR scope (modules, file types)
  summary <pr> <addressed> <replies>     Generate review cycle summary
  bot-reviewed [pr_number]               Check if Claude Code bot has reviewed

Examples:
  pr-review-operations.sh status
  pr-review-operations.sh comments 123
  pr-review-operations.sh scope 123
  pr-review-operations.sh categorize '[{"body":"fix the bug"}]'
  pr-review-operations.sh reply-inline 123 456789 "Fixed in this commit"
  pr-review-operations.sh bot-reviewed 123
EOF
    ;;
esac
