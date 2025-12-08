# Shape Spec

## Quick Navigation
- [Description](#description)
- [Parameters](#parameters)
- [Dependencies](#dependencies)
- [Task Tracking](#task-tracking)
- [Core Instructions](#core-instructions)
- [State Management](#state-management)
- [Error Handling](#error-handling)

## Description
Lightweight specification shaping phase that explores and refines a feature concept before full specification writing. This command helps validate ideas, explore approaches, and establish clear scope before committing to detailed documentation.

**Use this command when:**
- You have a rough idea but need to explore feasibility
- Multiple approaches are viable and you need trade-off analysis
- The scope is unclear and needs boundary definition
- You want quick validation before investing in full spec creation

**After shaping, run:** `/create-spec` to generate the full specification documents.

## Parameters
- `feature_concept` (required): Initial feature idea, problem statement, or rough description
- `exploration_depth` (optional): "quick" (15 min), "standard" (30 min), or "deep" (1+ hour) - defaults to "standard"

## Dependencies
**Required State Files:**
- `.agent-os/product/mission-lite.md` (read for alignment checking)
- `.agent-os/product/tech-stack.md` (read for technical feasibility)

**Expected Directories:**
- `.agent-os/product/` (product documentation)

**Creates:**
- `.agent-os/specs/shaped/YYYY-MM-DD-concept-name.md` (shaped spec summary)

## Task Tracking
**IMPORTANT: Use Claude's TodoWrite tool throughout execution:**
```javascript
// Example todos for this command workflow
const todos = [
  { content: "Understand the feature concept", status: "pending", activeForm: "Understanding the feature concept" },
  { content: "Check product alignment", status: "pending", activeForm: "Checking product alignment" },
  { content: "Explore technical feasibility", status: "pending", activeForm: "Exploring technical feasibility" },
  { content: "Identify approach options", status: "pending", activeForm: "Identifying approach options" },
  { content: "Analyze trade-offs", status: "pending", activeForm: "Analyzing trade-offs" },
  { content: "Define scope boundaries", status: "pending", activeForm: "Defining scope boundaries" },
  { content: "Create shaped spec summary", status: "pending", activeForm: "Creating shaped spec summary" },
  { content: "Get user validation", status: "pending", activeForm: "Getting user validation" }
];
// Update status to "in_progress" when starting each task
// Mark as "completed" immediately after finishing
```

## For Claude Code
When executing this command:
1. **Initialize TodoWrite** with the workflow steps above for visibility
2. Follow the embedded instructions below completely
3. Use brainstorming skill for approach exploration
4. Keep output concise - this is shaping, not full specification
5. **Update TodoWrite** status throughout execution
6. End with clear recommendation for next steps

---

## SECTION: Core Instructions
<!-- BEGIN EMBEDDED CONTENT -->

# Specification Shaping Workflow

## Overview

Shape-spec is a lightweight, exploratory phase that transforms rough ideas into validated concepts ready for full specification. It emphasizes:

- **Speed over comprehensiveness** - Get quick answers, not complete documentation
- **Exploration over commitment** - Try multiple approaches before deciding
- **Validation over assumption** - Confirm feasibility before investing time

## Process Flow

### Step 1: Concept Understanding

Gather the initial feature concept from the user and establish baseline understanding.

**Questions to Extract:**
```
1. What problem does this solve?
2. Who benefits from this feature?
3. What does "done" look like?
```

**Output Format:**
```markdown
## Concept: [Feature Name]

**Problem Statement:** [1-2 sentences]
**Target Users:** [Who benefits]
**Success Criteria:** [What "done" looks like]
```

**Rules:**
- Ask ONE question at a time (don't overwhelm)
- Provide multiple-choice options when possible
- Accept any level of detail from user

### Step 2: Product Alignment Check

Verify the concept aligns with product mission and roadmap.

**Instructions:**
```
ACTION: Read mission-lite.md (if not in context)
CHECK: Does this feature align with core mission?
CHECK: Does this fit within current roadmap priorities?

IF misaligned:
  WARN: "This feature may not align with [specific concern]"
  ASK: "Should we proceed anyway or adjust the concept?"
  WAIT: For user response
```

**Alignment Questions:**
- Does this support the core product mission?
- Is this the right time for this feature?
- Are there dependencies that need to ship first?

### Step 3: Technical Feasibility Scan

Quick assessment of technical viability using existing tech stack.

**Instructions:**
```
ACTION: Read tech-stack.md (if not in context)
SCAN: Can this be built with current stack?
IDENTIFY: Any new technologies needed?
ESTIMATE: Rough complexity (Low/Medium/High)
```

**Feasibility Output:**
```markdown
## Technical Feasibility

**Stack Compatibility:** [Yes/Partial/No]
**New Dependencies:** [None/List]
**Complexity Estimate:** [Low/Medium/High]
**Concerns:** [Any technical red flags]
```

### Step 4: Approach Exploration (brainstorming skill)

Use the brainstorming skill to explore 2-3 viable approaches.

**Instructions:**
```
ACTION: Invoke brainstorming skill
GENERATE: 2-3 distinct approaches
FOR EACH approach:
  - Name it clearly
  - Summarize in 2-3 sentences
  - List key trade-offs
  - Note complexity level

PRESENT: Comparison table
RECOMMEND: One approach with reasoning
```

**Approach Template:**
```markdown
## Approaches Considered

### Approach A: [Name]
[2-3 sentence description]
- **Pros:** [advantages]
- **Cons:** [disadvantages]
- **Complexity:** [Low/Medium/High]

### Approach B: [Name]
[2-3 sentence description]
- **Pros:** [advantages]
- **Cons:** [disadvantages]
- **Complexity:** [Low/Medium/High]

### Recommendation
**Chosen:** [Approach A or B]
**Rationale:** [Why this fits best]
```

### Step 5: Scope Definition

Establish clear boundaries for what's in and out of scope.

**Instructions:**
```
ASK: "Based on our discussion, here's what I understand is in scope:
     [list items]

     And explicitly OUT of scope:
     [list items]

     Is this accurate?"

WAIT: For user confirmation
ADJUST: Based on feedback
```

**Scope Template:**
```markdown
## Scope Boundaries

### In Scope
1. [Core functionality 1]
2. [Core functionality 2]
3. [Core functionality 3]

### Out of Scope
- [Excluded item 1]
- [Excluded item 2]

### Future Considerations
- [Item that could be added later]
```

### Step 6: Risk Identification

Quick scan for potential blockers or risks.

**Risk Categories:**
- **Technical:** Can we build this?
- **Resource:** Do we have time/people?
- **Dependencies:** What else needs to happen first?
- **User:** Will users actually want this?

**Risk Template:**
```markdown
## Identified Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| [Risk 1] | Low/Med/High | Low/Med/High | [How to address] |
```

### Step 7: Create Shaped Spec Summary

Generate a concise summary document capturing all shaping decisions.

**Instructions:**
```
ACTION: Create directory if not exists
PATH: .agent-os/specs/shaped/
FILE: YYYY-MM-DD-[concept-name].md

CONTENT: Use template below
```

**Shaped Spec Template:**
```markdown
# Shaped Spec: [Feature Name]

> Created: [CURRENT_DATE]
> Status: Shaped (Ready for full specification)

## Summary

**Problem:** [1-2 sentences]
**Solution:** [1-2 sentences]
**Target Users:** [Who benefits]

## Chosen Approach

**Approach:** [Name]
**Rationale:** [Why this approach]
**Complexity:** [Low/Medium/High]

## Scope

### In Scope
- [Item 1]
- [Item 2]

### Out of Scope
- [Item 1]
- [Item 2]

## Technical Notes

**Stack Compatibility:** [Yes/Partial/No]
**New Dependencies:** [None or list]
**Key Considerations:** [Any technical notes]

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| [Risk] | [Impact] | [Mitigation] |

## Next Steps

- [ ] Run `/create-spec` to generate full specification
- [ ] [Any pre-requisites identified]

---
*This shaped spec was created to validate the concept before full specification.*
*Run `/create-spec [feature-name]` to continue.*
```

### Step 8: User Validation

Present the shaped spec summary and confirm readiness for full specification.

**Instructions:**
```
DISPLAY: "I've shaped the specification for [feature name].

Summary:
- Problem: [brief]
- Approach: [chosen approach]
- Scope: [X items in scope, Y excluded]
- Complexity: [Low/Medium/High]

The shaped spec has been saved to:
.agent-os/specs/shaped/YYYY-MM-DD-[concept-name].md

Ready to proceed with full specification?
- Reply 'yes' or run /create-spec to generate full documentation
- Reply 'adjust' to modify the shaping
- Reply 'hold' to save and revisit later"

WAIT: For user response
```

## Exploration Depth Modes

### Quick Mode (15 min)
- Skip detailed trade-off analysis
- Single recommended approach
- Minimal risk assessment
- Abbreviated shaped spec

### Standard Mode (30 min) - Default
- Full process as documented above
- 2-3 approaches explored
- Complete risk identification
- Full shaped spec document

### Deep Mode (1+ hour)
- Extended brainstorming with multiple iterations
- Technical proof-of-concept exploration
- Stakeholder consideration
- Detailed implementation notes
- Architecture sketches (ASCII/Mermaid)

<!-- END EMBEDDED CONTENT -->

---

## SECTION: State Management

**Shaped specs location:** `.agent-os/specs/shaped/`

**File naming:** `YYYY-MM-DD-concept-name.md`

**State tracking:**
```json
{
  "shaping": {
    "concept": "feature-name",
    "started_at": "timestamp",
    "depth_mode": "standard",
    "status": "in_progress|completed|held"
  }
}
```

---

## SECTION: Error Handling

### Shape-spec Specific Error Handling

| Error | Recovery |
|-------|----------|
| Missing product files | Proceed with reduced context, note limitations |
| User abandons mid-shaping | Save partial progress to shaped/ folder |
| Concept too vague | Ask clarifying questions, offer examples |
| Multiple features detected | Split into separate shaping sessions |
| Technical infeasibility | Document blockers, suggest alternatives |

## Subagent Integration

This command primarily uses:
- **brainstorming skill** - For approach exploration and trade-off analysis
- **Native Explore agent** - For reading product documentation

No specialized subagents required - this is a lightweight command.
