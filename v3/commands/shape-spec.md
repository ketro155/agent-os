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
| **Explore Agent** | `Task` with `subagent_type='Explore'` | Deep codebase analysis (autonomous) |
| **User Decisions** | `AskUserQuestion` | Structured decision points (blocking) |
| **Brainstorming** | `brainstorming` skill | Approach exploration and trade-offs |

### Tool Handoff Pattern

```
Explore Agent (autonomous) → AskUserQuestion (decision) → Continue
```

- **Explore**: Gathers context without user interaction
- **AskUserQuestion**: Presents findings, gets user decision
- Never mix autonomous exploration with user interaction in same step

## Workflow

### 1. Enter Planning Mode

```
ACTION: EnterPlanMode
PURPOSE: Signal exploration phase, restrict to read-only tools
```

### 2. Concept Understanding

Ask user clarifying questions using `AskUserQuestion` for structured choices or freeform for open-ended questions:

**For problem framing (freeform is often better):**
- What problem does this solve?
- Who benefits?
- What does "done" look like?

**For scoped decisions (use AskUserQuestion):**
```javascript
AskUserQuestion({
  questions: [{
    question: "What type of feature is this?",
    header: "Type",
    multiSelect: false,
    options: [
      { label: "New Feature", description: "Adding new functionality to the product" },
      { label: "Enhancement", description: "Improving existing functionality" },
      { label: "Integration", description: "Connecting with external systems" },
      { label: "Refactor", description: "Restructuring without changing behavior" }
    ]
  }]
})
```

### 2.5 Correctness Framing (MANDATORY)

> **Core Principle**: Options scaffold thinking, freeform forces specificity, push back if vague.

```
MANDATORY: Before proceeding to codebase exploration, capture initial correctness framing.
This ensures the user articulates concrete, testable statements of what "correct" means.
```

**STEP A — What "Correct" Looks Like (AskUserQuestion → Freeform Deepening):**
```javascript
AskUserQuestion({
  questions: [{
    question: "What does 'correct' look like when this feature is complete?",
    header: "Correctness",
    multiSelect: false,
    options: [
      { label: "User can do something new", description: "A specific action or workflow becomes possible that wasn't before" },
      { label: "Something broken gets fixed", description: "A specific error, failure, or frustration goes away" },
      { label: "Something slow gets faster", description: "A measurable quantity (speed, throughput, efficiency) improves" },
      { label: "Something manual becomes automatic", description: "A manual step or workaround is eliminated" }
    ]
  }]
})
```
```
THEN — Freeform deepening based on selection:
  "User can do something new" → "Describe the specific action. What does the user DO, and what do they SEE?
     Example: 'A user clicks reset password, receives an email within 1 minute, clicks the link, enters a new password, and can immediately log in.'"
  "Something broken gets fixed" → "Describe the broken scenario today. What triggers it, what goes wrong?
     Example: 'When a user submits the form with special characters, the page shows a 500 error.'"
  "Something slow gets faster" → "What's slow, how slow is it now, and how fast should it be?
     Example: 'Dashboard load takes 12 seconds; should be under 3 seconds.'"
  "Something manual becomes automatic" → "Walk me through the current manual process step by step.
     Example: 'Admin manually exports CSV, opens in Excel, runs formula, copies result back.'"

IMPORTANT: Push back if the deepening answer is still vague.
  "That helps me understand the direction, but I need something concrete enough to test.
   Can you complete this sentence: 'A tester would verify this by ___'?"
```

**STEP B — What "Wrong" Looks Like (AskUserQuestion → Freeform Deepening):**
```javascript
AskUserQuestion({
  questions: [{
    question: "What would make someone say 'this is NOT what I asked for'?",
    header: "Failure",
    multiSelect: false,
    options: [
      { label: "Wrong results", description: "Feature works but produces incorrect output or data" },
      { label: "Broken workflow", description: "Feature exists but the user can't complete their task" },
      { label: "Performance regression", description: "Feature works but makes something else slower or worse" },
      { label: "Missing edge case", description: "Feature works for the common case but fails on important variations" }
    ]
  }]
})
```
```
THEN — Freeform deepening:
  "Describe a specific scenario for this failure. What would the user do, and what would go wrong?
   Example: 'User resets password successfully but the old password still works — both passwords are valid.'"
```

**STEP C — Trade-off Priority (AskUserQuestion):**
```javascript
AskUserQuestion({
  questions: [{
    question: "When these qualities conflict, which matters MOST for this feature?",
    header: "Priority",
    multiSelect: false,
    options: [
      { label: "Correctness first", description: "It must be right, even if it's slower or harder to use" },
      { label: "Speed first", description: "It must be fast/responsive, even if edge cases are deferred" },
      { label: "Completeness first", description: "It must handle all cases, even if initial delivery takes longer" },
      { label: "Simplicity first", description: "It must be easy to use/maintain, even if less powerful" }
    ]
  }]
})
```

**Output**: Store the three answers (correctness definition, failure definition, trade-off priority) as structured output that flows into `/create-spec` via the shaped spec.

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

### 5. Technical Feasibility (v4.9)

> **Explore-Based Analysis**: Use the Explore agent to perform deep feasibility analysis.

```
READ: .agent-os/product/tech-stack.md
ASSESS: Stack compatibility, new dependencies, complexity
ANALYZE: Use Explore agent for thorough feasibility check
```

**Feasibility Analysis Function:**
```javascript
const analyzeFeasibility = async (concept) => {
  const analysis = await Task({
    subagent_type: 'Explore',
    prompt: `Analyze technical feasibility of: "${concept}"
             
             Check:
             1. Do required APIs/libraries exist?
             2. Are there blocking technical constraints?
             3. What's the estimated complexity?
             4. Are there similar implementations to reference?
             5. What new dependencies would be needed?
             6. Does this fit the existing architecture?
             
             Return JSON:
             {
               "feasible": boolean,
               "confidence": "HIGH"|"MEDIUM"|"LOW",
               "blockers": ["list of blocking issues"],
               "enablers": ["existing code/patterns that help"],
               "similar_implementations": ["reference implementations"],
               "new_dependencies": ["required new packages"],
               "estimated_complexity": "LOW"|"MEDIUM"|"HIGH",
               "architecture_fit": "natural"|"moderate_effort"|"significant_changes",
               "recommendation": "Proceed / Needs adjustment / Not recommended",
               "reasoning": "1-2 sentence explanation"
             }`
  });
  
  return JSON.parse(analysis);
};
```

**Feasibility Report:**
```markdown
## Feasibility Analysis

**Status**: [Feasible / Needs Adjustment / Not Recommended]
**Confidence**: [HIGH / MEDIUM / LOW]
**Estimated Complexity**: [LOW / MEDIUM / HIGH]

### Blockers
- [Blocking issue if any]

### Enablers
- [Existing pattern that helps]
- [Reference implementation found]

### New Dependencies
- [Package needed]

### Architecture Fit
[How well this fits existing architecture]

### Recommendation
[Final recommendation with reasoning]
```

**Integration with Workflow:**
```
AFTER tech-stack assessment:
  feasibility = await analyzeFeasibility(concept)
  
  IF NOT feasibility.feasible:
    WARN: "Concept may not be feasible"
    DISPLAY: blockers and recommendation
    ASK: "Continue shaping or adjust concept?"
  
  IF feasibility.confidence === "LOW":
    INFORM: "Feasibility uncertain - consider prototyping first"
  
  STORE: feasibility results for shaped spec output
```


### 6. Approach Exploration (USER DECISION POINT)

**Phase A: Generate approaches (autonomous)**
Use brainstorming skill to:
- Generate 2-3 approaches
- Analyze trade-offs
- Identify recommended approach

**Phase B: Get user selection (AskUserQuestion)**
```javascript
AskUserQuestion({
  questions: [{
    question: "Which implementation approach do you prefer?",
    header: "Approach",
    multiSelect: false,
    options: [
      {
        label: "Approach A (Recommended)",
        description: "[Brief summary of recommended approach with key trade-off]"
      },
      {
        label: "Approach B",
        description: "[Brief summary with key trade-off]"
      },
      {
        label: "Approach C",
        description: "[Brief summary with key trade-off]"
      }
    ]
  }]
})
```

> **Handoff**: Brainstorming generates options → AskUserQuestion gets decision → Continue with chosen approach

### 7. Scope Definition (USER DECISION POINT)

**Use AskUserQuestion with multi-select for scope confirmation:**

```javascript
AskUserQuestion({
  questions: [
    {
      question: "Which items should be IN SCOPE for this feature?",
      header: "In Scope",
      multiSelect: true,
      options: [
        { label: "[Suggested item 1]", description: "Core requirement" },
        { label: "[Suggested item 2]", description: "Based on exploration findings" },
        { label: "[Suggested item 3]", description: "Enhancement opportunity" },
        { label: "[Suggested item 4]", description: "Edge case handling" }
      ]
    },
    {
      question: "Confirm items to EXCLUDE from scope?",
      header: "Out of Scope",
      multiSelect: true,
      options: [
        { label: "[Excluded item 1]", description: "Future enhancement" },
        { label: "[Excluded item 2]", description: "Out of current timeline" },
        { label: "[Excluded item 3]", description: "Separate feature" }
      ]
    }
  ]
})
```

**OUTPUT after user selection:**
```
- In Scope: [user-confirmed list]
- Out of Scope: [user-confirmed list]
```

### 8. Create Shaped Spec

```
WRITE: .agent-os/specs/shaped/YYYY-MM-DD-[concept-name].md

TEMPLATE:
# Shaped Spec: [Name]
> Status: Ready for /create-spec

## Summary
## Correctness Framing
### What "Correct" Looks Like
### What "Wrong" Looks Like
### Trade-off Priority
## Chosen Approach
## Scope
## Technical Notes
## Risks
## Next Steps
```

### 8.5 Memory Layer Integration (v4.9.1)

After shaped spec is created, evaluate logging opportunity:

```
EVALUATE logging opportunity:

IF approach selection involved significant trade-offs:
  SUGGEST: /log-entry decision
  CONTENT:
    - Title: "Approach selection for [concept-name]"
    - Context: What problem this solves
    - Options: The approaches considered
    - Decision: Which approach was chosen
    - Rationale: Key trade-off that drove the decision
    - Consequences: What this enables/limits

IF feasibility analysis revealed architectural insights:
  SUGGEST: /log-entry insight
  CONTENT:
    - Title: "Architecture fit analysis for [concept-name]"
    - What existing patterns enable this
    - What constraints were discovered
```

**Example prompt to user:**
```
Approach "B: Event-driven" was selected over "A: Polling" due to scalability
requirements. Would you like to log this decision for future reference?

> /log-entry decision
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
