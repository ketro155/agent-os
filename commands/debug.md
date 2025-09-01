---
description: Debug issues with context-efficient analysis and session continuity support
alwaysApply: false
version: 1.0
encoding: UTF-8
---

# Debug Command

Debug code issues, test failures, or behavioral problems with intelligent context management and session continuity.

## Usage

```bash
debug [issue_description] [--continue debug-session-state.md]
```

## Examples

```bash
debug "Tests failing in auth module"
debug "Build errors after dependency update"  
debug "Performance regression in data processing"
debug --continue debug-session-state.md  # Resume previous debugging session
```

## Instructions

Execute: @.agent-os/instructions/core/debug-issue.md