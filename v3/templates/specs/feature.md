# Spec Requirements Document

> Spec: [SPEC_NAME]
> Created: [DATE]
> Type: Feature

## Overview

[1-2 sentence description of the new capability and its purpose]

## Definition of Correctness

### Problem Statement
**Problem**: [Concrete description of what's broken, missing, or slow today]
**Who is affected**: [User types and how often they encounter this]
**Current workaround**: [How users handle this today, or "none — they can't"]

### Correctness Criteria (Allowed Claims)
Each statement must be specific, observable, and bounded.

1. [Subject] can [action] and [observable result within constraint]
2. [Subject] can [action] and [observable result within constraint]
3. [Subject] can [action] and [observable result within constraint]

### Failure Modes
If any of these occur, the feature has failed.

1. [Specific failure scenario that would make a user say "this is broken"]
2. [Specific failure scenario]

### Trade-off Priority
When implementation forces a trade-off: **[Priority] wins over [Deprioritized]**.
Example: "Accuracy wins over speed — better to show a loading state than stale data."

### Verification Method
| Criterion | How to Verify | Pass/Fail Boundary |
|-----------|---------------|-------------------|
| [Claim 1] | [Specific test or check] | [What "pass" means] |
| [Claim 2] | [Specific test or check] | [What "pass" means] |

## User Stories

### Story 1: [Primary Use Case]

As a **[user type]**, I want to **[action/capability]**, so that **[benefit/value]**.

**Workflow:**
1. [Step 1]
2. [Step 2]
3. [Step 3]

**Acceptance Criteria:**
- [ ] [Criterion 1]
- [ ] [Criterion 2]
- [ ] [Criterion 3]

### Story 2: [Secondary Use Case] (optional)

As a **[user type]**, I want to **[action]**, so that **[benefit]**.

## Spec Scope

1. **[Feature Component 1]** - [One sentence description]
2. **[Feature Component 2]** - [One sentence description]
3. **[Feature Component 3]** - [One sentence description]

## Out of Scope

- [Explicitly excluded functionality 1]
- [Explicitly excluded functionality 2]
- Future enhancements deferred to v2

## Technical Considerations

- **Architecture Impact**: [How this affects existing architecture]
- **Data Model**: [New tables/fields if applicable]
- **API Changes**: [New endpoints if applicable]
- **Performance**: [Expected load/response time requirements]

## Expected Deliverable

### Functional Outcomes
1. [User can... — maps to Correctness Criteria #N]
2. [System does... — maps to Correctness Criteria #N]

### Verification Checklist
- [ ] All Correctness Criteria verified (see Definition of Correctness)
- [ ] No Failure Modes triggered during testing
- [ ] Trade-off decisions align with stated priority
- [ ] E2E test covers critical path from Criteria #1

## Dependencies

- [Prerequisite spec or component]
- [Required external service or library]

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| [Risk 1] | Low/Med/High | Low/Med/High | [Mitigation strategy] |

---

*Template version: 1.0.0 - Use this for new capabilities and features*
