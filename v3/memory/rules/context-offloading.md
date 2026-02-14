---
paths:
  - ".agent-os/scratch/**"
  - ".agent-os/metrics/**"
---

# Context Offloading (v4.10.0)

> **"Why waste time say lot word when few word do trick?"**
>
> Detailed reference for context offloading. Loaded when working with scratch directory.
> See CLAUDE.md for overview.

## How It Works

Agent OS automatically offloads large outputs to preserve context tokens:

| Output Size | Behavior |
|-------------|----------|
| **< 512B** | Displayed inline (no change) |
| **512B - 4KB** | Compact pointer (~35 tokens) |
| **> 4KB** | Pointer + failure preview (for debugging) |

## Automatic Features

- **Tiered offloading**: Large outputs stored in `.agent-os/scratch/tool_outputs/`
- **Secret redaction**: AWS keys, GitHub tokens, API keys automatically redacted
- **Smart retention**: Failures kept 48h, successes 24h (for debugging)
- **LATEST symlinks**: Quick access to most recent outputs
- **Token statistics**: Track context savings per session
- **LRU eviction**: Auto-cleanup at 250MB scratch limit

## Context Management Skills

| Skill | Invocation | Purpose |
|-------|------------|---------|
| context-read | `/context-read <id>` | Retrieve offloaded output |
| context-search | `/context-search <term>` | Search across outputs |
| context-stats | `/context-stats` | View token savings |

## Example Workflow

When you see: `[Output offloaded: 45KB → /context-read phase2_20260112_143022_exit1]`

1. Use `/context-read phase2_20260112_143022_exit1` to view full content
2. Use `/context-read LATEST` for most recent output
3. Use `/context-search TypeError` to find errors across all outputs

## Configuration

```bash
AGENT_OS_INLINE_MAX=512        # Inline display threshold (bytes)
AGENT_OS_PREVIEW_MIN=4096      # Preview trigger for failures (bytes)
AGENT_OS_SUCCESS_RETENTION=24  # Hours to keep success outputs
AGENT_OS_FAILURE_RETENTION=48  # Hours to keep failure outputs
AGENT_OS_SCRATCH_MAX_MB=250    # LRU eviction threshold (MB)
```

## Agent Metrics (v4.8.0+)

Subagent lifecycle is tracked in `.agent-os/metrics/`:
- `agents.jsonl` - Start/stop events with duration, exit codes, bytes offloaded
- `transcripts/` - Saved agent transcripts (last 20 kept)

## Context Statistics (v4.10.0)

Token savings tracked in `.agent-os/scratch/session_stats.json`:
- `bytes_offloaded` - Total bytes saved from context
- `offload_count` - Number of outputs offloaded
- `estimated_tokens_saved` - Approximate token savings (~4 chars/token)

## Scratch Directory Structure

```
.agent-os/scratch/
├── tool_outputs/        # Offloaded command outputs
│   ├── LATEST.txt       # Most recent output symlink
│   └── LATEST_*.txt     # Per-agent-type symlinks
├── index.jsonl          # Output manifest
└── session_stats.json   # Token savings tracking
```

---

## Changelog

### v4.10.0 (2026-01-12)
- Initial context offloading system
- Tiered offloading, secret redaction, LRU eviction
- Context management skills (read, search, stats)
