---
name: brainstorming
description: Generates 2-3 structured approaches with trade-off analysis for feature design decisions. Use before AskUserQuestion in shape-spec Step 6 and create-spec Phase E. Use when user says "brainstorm approaches", "compare options", "generate alternatives", or "trade-off analysis". NOT for task breakdown (use /subtask-expansion). NOT for TDD guidance (use /tdd-helper).
version: 1.0.0
metadata:
  author: Agent OS
  category: planning
---

# Brainstorming Skill

Generate structured approaches with trade-off analysis for feature design decisions. This skill bridges autonomous approach generation to user decision via AskUserQuestion.

## When to Use

- Before AskUserQuestion in `/shape-spec` Step 6 (approach selection)
- Before AskUserQuestion in `/create-spec` Phase E (approach generation)
- When a feature has multiple viable implementation strategies
- When trade-offs between approaches need structured comparison

## Input

Provide feature context (freeform or structured):

```json
{
  "feature": "Feature name or concept",
  "constraints": ["Technical constraint 1", "Business constraint 2"],
  "tech_stack": "React + Node.js + PostgreSQL (optional)",
  "context": "Additional context about the problem space"
}
```

Or simply describe the feature and constraints in natural language.

## Process

### Step 1: Analyze Constraints

Before generating approaches, identify and categorize constraints:

```
CONSTRAINT ANALYSIS:
- Hard constraints (non-negotiable): [list]
- Soft constraints (preferences): [list]
- Trade-off dimensions: [performance, complexity, maintainability, time-to-ship, scalability]
```

All generated approaches must satisfy hard constraints. Soft constraints differentiate approaches.

### Step 2: Generate Approaches (2-3)

For each approach, produce:

```markdown
### Approach [N]: [Descriptive Name]

**Summary**: One-sentence description of the approach.

**How it works**:
1. [Key implementation step 1]
2. [Key implementation step 2]
3. [Key implementation step 3]

**Pros**:
- [Advantage 1]
- [Advantage 2]

**Cons**:
- [Disadvantage 1]
- [Disadvantage 2]

**Complexity**: LOW | MEDIUM | HIGH
**Estimated effort**: [relative to other approaches]
```

**Approach generation rules**:
- Always generate at least 2 approaches (minimum viable comparison)
- Maximum 3 approaches (decision fatigue beyond 3)
- Approaches should be genuinely different strategies, not minor variations
- One approach should be the simplest viable option
- If one approach is clearly superior, mark it as `recommended: true`

### Step 3: Present Comparison

Generate a comparison table and structured output:

**Markdown comparison table** (for display):

```markdown
| Dimension | Approach 1 | Approach 2 | Approach 3 |
|-----------|-----------|-----------|-----------|
| Complexity | LOW | MEDIUM | HIGH |
| Performance | Good | Better | Best |
| Maintainability | Best | Good | Moderate |
| Time to ship | Fastest | Moderate | Slowest |
| Scalability | Limited | Good | Best |
```

**Structured JSON** (for AskUserQuestion options):

```json
{
  "approaches": [
    {
      "name": "Approach 1: Simple X",
      "summary": "One-sentence summary",
      "pros": ["pro1", "pro2"],
      "cons": ["con1", "con2"],
      "complexity": "LOW",
      "recommended": false
    },
    {
      "name": "Approach 2: Balanced Y",
      "summary": "One-sentence summary",
      "pros": ["pro1", "pro2"],
      "cons": ["con1", "con2"],
      "complexity": "MEDIUM",
      "recommended": true
    }
  ],
  "recommendation": "Approach 2 balances [X] and [Y] for this context.",
  "ask_user": "Which approach would you like to proceed with?"
}
```

## Integration

This skill generates options; the calling command presents them via AskUserQuestion.

**In shape-spec Step 6:**
```
1. Invoke /brainstorming with feature concept + constraints
2. Receive structured approaches
3. Present via AskUserQuestion: "Which approach should we use?"
4. User selects → proceed with chosen approach
```

**In create-spec Phase E:**
```
1. Invoke /brainstorming for complex features requiring design decisions
2. Receive structured approaches
3. Present via AskUserQuestion with approach summaries as options
4. Selected approach feeds into spec's "Technical Approach" section
```

## Tips

- Focus on genuinely different strategies, not implementation details
- Include a "simplest thing that could work" option
- Be honest about trade-offs — don't oversell any approach
- If constraints make the choice obvious, say so and recommend directly

## Changelog

### v1.0.0 (2026-03-06)
- Initial brainstorming skill
- Constraint analysis, approach generation, comparison table
- Structured JSON output for AskUserQuestion integration
- Integration with shape-spec Step 6 and create-spec Phase E
