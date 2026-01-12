---
name: context-read
description: Retrieve offloaded output by ID. Use when you see "[Output offloaded → /context-read ID]" messages.
version: 1.0.0
---

# Context Read Skill

Retrieves offloaded outputs from the scratch directory. When subagent outputs exceed 512B, they are automatically offloaded to preserve context tokens.

## Usage

```
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

if [ "$OUTPUT_ID" = "LATEST" ]; then
  FILE="$PROJECT_DIR/.agent-os/scratch/tool_outputs/LATEST.txt"
elif [[ "$OUTPUT_ID" == LATEST_* ]]; then
  FILE="$PROJECT_DIR/.agent-os/scratch/tool_outputs/${OUTPUT_ID}.txt"
else
  FILE="$PROJECT_DIR/.agent-os/scratch/tool_outputs/${OUTPUT_ID}.txt"
fi

if [ -f "$FILE" ]; then
  cat "$FILE"
else
  echo "Output not found: $OUTPUT_ID"
  echo ""
  echo "Available outputs:"
  jq -r '.id + " (" + .agent_type + ", " + (.size | tostring) + " bytes, " + .created_at + ")"' "$PROJECT_DIR/.agent-os/scratch/index.jsonl" 2>/dev/null | tail -10
fi
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
