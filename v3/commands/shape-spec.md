# Shape Spec

Lightweight specification shaping phase that explores and refines a feature concept before full specification writing.

## Usage

```
/shape-spec [feature_concept] [--depth=quick|standard|deep]
```

## Parameters

- `feature_concept` (required): Feature idea, problem statement, or rough description
- `--depth` (optional): Exploration depth - `quick` (15 min), `standard` (30 min), `deep` (1+ hour)

## Native Integration

This command uses Claude Code's native capabilities:

| Feature | Tool | Purpose |
|---------|------|---------|
| **Planning Mode** | `EnterPlanMode` / `ExitPlanMode` | Formal exploration with read-only restriction |
| **Explore Agent** | `Task` with `subagent_type='Explore'` | Deep codebase analysis |
| **Brainstorming** | `brainstorming` skill | Approach exploration and trade-offs |

## Workflow

### 1. Enter Planning Mode

```
ACTION: EnterPlanMode
PURPOSE: Signal exploration phase, restrict to read-only tools
```

### 2. Concept Understanding

Ask user clarifying questions (one at a time):
- What problem does this solve?
- Who benefits?
- What does "done" look like?

### 3. Product Alignment

```
READ: .agent-os/product/mission-lite.md
CHECK: Does feature align with mission?
WARN: If misaligned, ask user to confirm or adjust
```

### 4. Codebase Exploration

```
ACTION: Task tool with subagent_type='Explore'
THOROUGHNESS: Based on --depth parameter
  - quick → "quick"
  - standard → "medium"
  - deep → "very thorough"

PROMPT: "Explore codebase for implementing [CONCEPT]:
        - Existing patterns
        - Integration points
        - Potential conflicts
        - Reusable components"
```

### 5. Technical Feasibility

```
READ: .agent-os/product/tech-stack.md
ASSESS: Stack compatibility, new dependencies, complexity
INCORPORATE: Explore agent results
```

### 6. Approach Exploration

Use brainstorming skill:
- Generate 2-3 approaches
- Analyze trade-offs
- Recommend one approach with rationale

### 7. Scope Definition

```
ASK: Confirm in-scope and out-of-scope items
OUTPUT:
  - In Scope: [list]
  - Out of Scope: [list]
```

### 8. Create Shaped Spec

```
WRITE: .agent-os/specs/shaped/YYYY-MM-DD-[concept-name].md

TEMPLATE:
# Shaped Spec: [Name]
> Status: Ready for /create-spec

## Summary
## Chosen Approach
## Scope
## Technical Notes
## Risks
## Next Steps
```

### 9. Exit Planning Mode

```
ACTION: ExitPlanMode
DISPLAY: Summary and next steps
```

## Explore Thoroughness Mapping

| Depth | Thoroughness | Time | Best For |
|-------|--------------|------|----------|
| `quick` | `quick` | ~15 min | Known patterns, fast validation |
| `standard` | `medium` | ~30 min | Balanced exploration (default) |
| `deep` | `very thorough` | 1+ hour | Complex features, unknown territory |

## Creates

- `.agent-os/specs/shaped/YYYY-MM-DD-[concept-name].md`

## Next Step

Run `/create-spec [concept-name]` to generate full specification.
