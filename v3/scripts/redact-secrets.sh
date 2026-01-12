#!/bin/bash
# Agent OS v4.10.0 - Secret Redaction Utility
# Redacts sensitive data from text input
# Inspired by FewWord's security patterns

# Usage: echo "text" | redact-secrets.sh
# Or: redact-secrets.sh < file.txt

# Redaction patterns (order matters - more specific first)
sed -E \
  -e 's/AKIA[0-9A-Z]{16}/[REDACTED:AWS_ACCESS_KEY]/g' \
  -e 's/[A-Za-z0-9/+=]{40}([^A-Za-z0-9/+=]|$)/[REDACTED:AWS_SECRET_KEY]\1/g' \
  -e 's/ghp_[A-Za-z0-9]{36}/[REDACTED:GITHUB_PAT]/g' \
  -e 's/gho_[A-Za-z0-9]{36}/[REDACTED:GITHUB_OAUTH]/g' \
  -e 's/github_pat_[A-Za-z0-9_]{22,}/[REDACTED:GITHUB_PAT_NEW]/g' \
  -e 's/ghs_[A-Za-z0-9]{36}/[REDACTED:GITHUB_APP]/g' \
  -e 's/ghr_[A-Za-z0-9]{36}/[REDACTED:GITHUB_REFRESH]/g' \
  -e 's/sk-[A-Za-z0-9]{48}/[REDACTED:OPENAI_KEY]/g' \
  -e 's/sk-ant-api[A-Za-z0-9-]{90,}/[REDACTED:ANTHROPIC_KEY]/g' \
  -e 's/xoxb-[0-9]{10,13}-[0-9]{10,13}-[A-Za-z0-9]{24}/[REDACTED:SLACK_BOT]/g' \
  -e 's/xoxp-[0-9]{10,13}-[0-9]{10,13}-[A-Za-z0-9]{24}/[REDACTED:SLACK_USER]/g' \
  -e 's/AIza[A-Za-z0-9_-]{35}/[REDACTED:GOOGLE_API_KEY]/g' \
  -e 's/ya29\.[A-Za-z0-9_-]{100,}/[REDACTED:GOOGLE_OAUTH]/g' \
  -e 's/npm_[A-Za-z0-9]{36}/[REDACTED:NPM_TOKEN]/g' \
  -e 's/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[REDACTED:UUID]/g' \
  -e 's/-----BEGIN (RSA |EC |OPENSSH |)PRIVATE KEY-----/[REDACTED:PRIVATE_KEY_START]/g' \
  -e 's/-----END (RSA |EC |OPENSSH |)PRIVATE KEY-----/[REDACTED:PRIVATE_KEY_END]/g' \
  -e 's/(password|passwd|pwd|secret|token|apikey|api_key|auth)(["\x27]?\s*[:=]\s*["\x27]?)[^\s"\x27,;]{8,}/\1\2[REDACTED]/gi' \
  -e 's/Bearer [A-Za-z0-9._-]{20,}/Bearer [REDACTED:BEARER_TOKEN]/g'
