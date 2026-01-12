---
name: context-search
description: Search through offloaded outputs for specific terms. Useful for finding errors, patterns, or specific content across multiple agent runs.
version: 1.0.0
---

# Context Search Skill

Searches through offloaded outputs in the scratch directory for specific terms or patterns.

## Usage

```
/context-search <pattern>           # Search for pattern in all outputs
/context-search error               # Find all errors
/context-search "TypeError"         # Find specific error types
/context-search "test.*failed"      # Regex pattern search
```

## Instructions

1. **Parse the search pattern** from arguments
2. **Search offloaded outputs** using grep
3. **Display matching results** with context
4. **Summarize findings**

## Implementation

Execute this bash command to search outputs:

```bash
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
PATTERN="$1"  # Replace with actual search pattern
OUTPUTS_DIR="$PROJECT_DIR/.agent-os/scratch/tool_outputs"

if [ ! -d "$OUTPUTS_DIR" ]; then
  echo "No offloaded outputs found."
  exit 0
fi

echo "Searching for: $PATTERN"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Search with context, showing filename
grep -r -n -i -C 2 "$PATTERN" "$OUTPUTS_DIR"/*.txt 2>/dev/null | head -100

MATCH_COUNT=$(grep -r -l -i "$PATTERN" "$OUTPUTS_DIR"/*.txt 2>/dev/null | wc -l | tr -d ' ')
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Found matches in $MATCH_COUNT file(s)"
```

## Response Format

After searching:
1. Show matching lines with filename and line numbers
2. Provide 2 lines of context around each match
3. Summarize total matches found
4. If searching for errors, offer to help fix them

## Example

User: `/context-search TypeError`

Response:
```
## Search Results: "TypeError"

### phase2_20260112_140522_exit1.txt
```
42:     TypeError: Cannot read property 'map' of undefined
43-       at UserList.render (/src/components/UserList.tsx:15)
44-       at renderWithHooks (react-dom.development.js:14985)
```

### phase2_20260112_141033_exit1.txt
```
18:     TypeError: props.data is not iterable
19-       at DataTable.tsx:22
```

---
Found matches in 2 file(s).

Both errors appear to be related to undefined data being passed to components.
Would you like me to:
1. Read the full output from either file?
2. Help fix these TypeErrors?
```
