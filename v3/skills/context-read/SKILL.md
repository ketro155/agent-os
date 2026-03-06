---
name: context-read
description: Retrieves offloaded context outputs from the scratch directory by ID or symlink. Use when you see "[Output offloaded]" pointer messages or need to view full agent output that was compressed for token efficiency. Use when user says "read output", "show offloaded", "context-read", or "view agent output". NOT for searching content across outputs (use /context-search). NOT for viewing statistics (use /context-stats).
version: 1.1.0
metadata:
  author: Agent OS
  category: context-management
---

# Context Read Skill

Retrieves offloaded outputs from the scratch directory. When subagent outputs exceed 512B, they are automatically offloaded to preserve context tokens.

## Usage

```
/context-read                # List available outputs (last 20)
/context-read <output_id>    # Read specific output by ID
/context-read LATEST         # Read most recent output
/context-read LATEST_phase2  # Read most recent output from phase2-implementation agent
```

## Instructions

1. **Parse the argument** to get the output ID
2. **Determine the file path**:
   - If `LATEST`: Read `.agent-os/scratch/tool_outputs/LATEST.txt`
   - If `LATEST_<type>`: Read `.agent-os/scratch/tool_outputs/LATEST_<type>.txt`
   - Otherwise: Read `.agent-os/scratch/tool_outputs/<output_id>.txt`
3. **Check if file exists** - if not, list available outputs from index
4. **Read and display the content**

## Implementation

Execute this bash command to read the output:

```bash
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
OUTPUT_ID="$1"  # Replace with actual argument
OUTPUTS_DIR="$PROJECT_DIR/.agent-os/scratch/tool_outputs"

# List mode: no argument provided
if [ -z "$OUTPUT_ID" ]; then
  echo "Available outputs (last 20):"
  echo ""
  if [ -f "$OUTPUTS_DIR/../index.jsonl" ]; then
    tail -20 "$OUTPUTS_DIR/../index.jsonl" | jq -r '.id + " (" + .agent_type + ", " + (.size | tostring) + " bytes, " + .created_at + ")"'
  else
    echo "No outputs found. Index file does not exist."
  fi
  exit 0
fi

# Read mode: resolve file path
if [[ "$OUTPUT_ID" == LATEST* ]]; then
  FILE="$OUTPUTS_DIR/${OUTPUT_ID}.txt"
else
  FILE="$OUTPUTS_DIR/${OUTPUT_ID}.txt"
fi

if [ -f "$FILE" ]; then
  cat "$FILE"
else
  echo "Output not found: $OUTPUT_ID"
  echo ""
  echo "Available outputs:"
  tail -10 "$OUTPUTS_DIR/../index.jsonl" 2>/dev/null | jq -r '.id + " (" + .agent_type + ", " + (.size | tostring) + " bytes, " + .created_at + ")"'
fi
```

## List Mode Response Format

When invoked without arguments, display the available outputs list:
```
Available outputs (last 20):

phase2_20260112_143022_1768209940_exit0 (phase2-implementation, 2048 bytes, 2026-01-12T14:30:22Z)
phase2_20260112_150415_1768209941_exit0 (phase2-implementation, 1536 bytes, 2026-01-12T15:04:15Z)
...
```

## Response Format

After reading the file:
1. Display the full content to the user
2. Note the agent type and timestamp if available from the filename
3. If the output shows errors/failures, offer to help debug

## Example

User: `/context-read phase2_20260112_143022_1768209940_exit1`

Response:
```
## Offloaded Output: phase2_20260112_143022_1768209940_exit1

[Full content of the file displayed here]

---
This output is from a phase2-implementation agent that failed (exit code 1).
Would you like me to analyze the failure and suggest fixes?
```

## Changelog

### v1.1.0 (2026-02-09)
- Added LATEST symlink support for quick access to most recent output
- Added agent-type filtered LATEST (e.g., LATEST_phase2)
- Added list mode when invoked without arguments

### v1.0.0 (2026-01-10)
- Initial context-read skill
- Read offloaded outputs by ID
- Display with agent type and error detection
