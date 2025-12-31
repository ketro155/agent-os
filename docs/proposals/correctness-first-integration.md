# Correctness-First Integration Proposal

> **Source**: [Defining "Correctness" Before Building Agents](https://www.youtube.com/watch?v=mnWMTzkjWmk)
> **Date**: 2025-12-31
> **Status**: Proposal

## Executive Summary

This proposal integrates the "correctness is upstream of architecture" philosophy into Agent OS's spec shaping and task execution workflows. The core insight: **you cannot improve what you cannot measure, and you cannot build reliable AI agents without explicit definitions of "correct"**.

---

## Core Concepts from Source Material

### 1. The Ambiguity Problem
Humans navigate vague objectives through social nuance; AI systems cannot. When "correctness" is undefined, systems optimize for proxy metrics and inevitably disappoint.

### 2. First-Order vs Second-Order Decisions
- **First-order** (answer first): What is the output? How do we know if it's correct?
- **Second-order** (answer later): RAG vs fine-tuning, agent count, context strategy

### 3. Competing Requirements
Quality is a bundle of trade-offs that must be debated *before* implementation:
- Truthfulness vs Helpfulness
- Tone vs Precision
- Speed vs Cost vs Completeness
- Confidence vs Uncertainty Disclosure

### 4. Calibrated Uncertainty
Systems need explicit failure modes:
- When to say "I don't know"
- Confidence thresholds for assertions
- Penalty structures (cost of wrong vs cost of silence)

### 5. Provenance and Evidence
Every output is a *claim* requiring evidence. Traceability matters.

---

## Integration Points in Agent OS

### A. Shape-Spec Command (Highest Impact)

**Current State**: `shape-spec` asks clarifying questions but doesn't enforce explicit correctness definitions.

**Proposed Enhancement**: Add a mandatory "Correctness Framework" section before spec approval.

```markdown
## Correctness Framework

### Success Definition
> What does "done" look like in concrete, testable terms?

1. [MEASURABLE_OUTCOME_1]
2. [MEASURABLE_OUTCOME_2]

### Competing Requirements (Prioritized)

| Requirement A | vs | Requirement B | Priority |
|---------------|-----|---------------|----------|
| Speed | vs | Accuracy | Accuracy wins |
| Helpful response | vs | Honest uncertainty | Honest uncertainty wins |
| Feature completeness | vs | Simplicity | [USER_DECIDES] |

### Failure Modes

**Acceptable failures:**
- [What outcomes are "wrong but tolerable"?]

**Unacceptable failures:**
- [What outcomes are "catastrophic"?]

### Confidence Thresholds

- **High confidence required for**: [e.g., financial calculations, user data]
- **Medium confidence acceptable for**: [e.g., suggestions, recommendations]
- **"I don't know" preferred when**: [e.g., ambiguous requirements, missing data]

### Verification Method
> How will we *prove* the feature works correctly?

- [ ] Automated tests (unit/integration)
- [ ] Manual verification checklist
- [ ] User acceptance testing
- [ ] Performance benchmarks
- [ ] Security audit
```

### B. Create-Spec Command

**Current State**: "Expected Deliverable" section is prose-based and focuses on browser-testable outcomes.

**Proposed Enhancement**: Structured acceptance criteria with explicit correctness dimensions.

```markdown
## Acceptance Criteria

### Functional Correctness
| Criterion | Verification | Pass Condition |
|-----------|--------------|----------------|
| User can reset password | Automated test | Reset email sent within 30s |
| Token expires after 24h | Unit test | 401 returned for expired tokens |

### Non-Functional Correctness
| Dimension | Target | Measurement |
|-----------|--------|-------------|
| Performance | < 200ms response | Load test p95 |
| Accessibility | WCAG 2.1 AA | axe-core audit |
| Security | No token leakage | Security review |

### Edge Cases & Uncertainty Handling
| Scenario | Expected Behavior | Rationale |
|----------|-------------------|-----------|
| Invalid email format | Show validation error | Fail fast |
| Email service down | Queue + retry | Graceful degradation |
| Unknown error | Generic message + log | Don't expose internals |
```

### C. Create-Tasks Command

**Current State**: Tasks have status tracking and artifact verification but no explicit correctness criteria per task.

**Proposed Enhancement**: Add `correctness_criteria` field to task schema.

```json
{
  "id": "1",
  "description": "Implement password reset endpoint",
  "status": "pending",
  "correctness_criteria": {
    "functional": [
      "Returns 200 for valid email",
      "Returns 400 for invalid email format",
      "Returns 200 (not 404) for unknown email (security)"
    ],
    "non_functional": [
      "Response time < 200ms",
      "No email enumeration vulnerability"
    ],
    "uncertainty_handling": {
      "email_service_unavailable": "Queue request, return 202",
      "rate_limit_exceeded": "Return 429 with retry-after"
    }
  }
}
```

### D. Execute-Tasks (Phase 2 TDD Agent)

**Current State**: TDD cycle (RED → GREEN → REFACTOR) with artifact verification.

**Proposed Enhancement**: Add "Correctness Verification Checkpoint" after GREEN phase.

```markdown
## TDD Cycle Enhancement

### RED Phase
Write failing test for expected behavior

### GREEN Phase
Implement minimal code to pass test

### VERIFY Phase (NEW)
Before refactoring, verify against correctness criteria:

1. **Functional check**: Does behavior match spec exactly?
2. **Edge case check**: Are uncertainty scenarios handled?
3. **Non-functional check**: Performance/security acceptable?
4. **Provenance check**: Can we trace output to requirements?

If any check fails → return to RED phase with new test

### REFACTOR Phase
Clean up while maintaining all checks
```

### E. New: Correctness Review Agent

**Purpose**: Dedicated agent that reviews implementations against correctness criteria.

```markdown
# Agent: correctness-reviewer

## Trigger
After Phase 2 completes, before Phase 3 (delivery)

## Responsibilities
1. Compare implementation against spec's Correctness Framework
2. Verify all acceptance criteria have corresponding tests
3. Check edge case coverage
4. Validate uncertainty handling (are "I don't know" scenarios covered?)
5. Audit confidence levels in any AI-generated content

## Output
- Correctness score (0-100%)
- Gap analysis (missing criteria)
- Risk assessment (unverified claims)
- Recommendation (proceed/block/review)
```

---

## Schema Changes

### New: `correctness-framework-v1.json`

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Correctness Framework",
  "type": "object",
  "required": ["success_definition", "competing_requirements", "failure_modes"],
  "properties": {
    "success_definition": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["criterion", "measurement", "threshold"],
        "properties": {
          "criterion": { "type": "string" },
          "measurement": { "type": "string" },
          "threshold": { "type": "string" }
        }
      }
    },
    "competing_requirements": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["requirement_a", "requirement_b", "priority", "rationale"],
        "properties": {
          "requirement_a": { "type": "string" },
          "requirement_b": { "type": "string" },
          "priority": { "enum": ["a_wins", "b_wins", "context_dependent"] },
          "rationale": { "type": "string" }
        }
      }
    },
    "failure_modes": {
      "type": "object",
      "required": ["acceptable", "unacceptable"],
      "properties": {
        "acceptable": {
          "type": "array",
          "items": { "type": "string" }
        },
        "unacceptable": {
          "type": "array",
          "items": { "type": "string" }
        }
      }
    },
    "confidence_thresholds": {
      "type": "object",
      "properties": {
        "high_confidence_required": { "type": "array", "items": { "type": "string" } },
        "medium_confidence_acceptable": { "type": "array", "items": { "type": "string" } },
        "prefer_uncertainty": { "type": "array", "items": { "type": "string" } }
      }
    },
    "verification_methods": {
      "type": "array",
      "items": {
        "enum": ["automated_tests", "manual_verification", "user_acceptance", "performance_benchmark", "security_audit"]
      }
    }
  }
}
```

### Enhancement: `tasks-v4.json` (proposed)

Add to task objects:

```json
{
  "correctness_criteria": {
    "functional": ["string"],
    "non_functional": ["string"],
    "uncertainty_handling": {
      "additionalProperties": { "type": "string" }
    },
    "provenance_requirements": ["string"]
  },
  "correctness_verified": {
    "status": "pending | partial | verified | failed",
    "gaps": ["string"],
    "verified_by": "automated | manual | agent",
    "timestamp": "ISO_TIMESTAMP"
  }
}
```

---

## Implementation Roadmap

### Phase 1: Shape-Spec Enhancement
1. Add Correctness Framework section to `shape-spec.md`
2. Create `correctness-framework-v1.json` schema
3. Update brainstorming questions to include competing requirements

### Phase 2: Create-Spec Enhancement
1. Replace prose "Expected Deliverable" with structured acceptance criteria
2. Add non-functional requirements section
3. Add edge case / uncertainty handling section

### Phase 3: Task Schema Enhancement
1. Update `tasks-v3.json` → `tasks-v4.json` with correctness fields
2. Modify `create-tasks.md` to extract correctness criteria from spec
3. Update `context-summary.json` generation

### Phase 4: Execution Enhancement
1. Add VERIFY phase to TDD cycle in `phase2-implementation.md`
2. Create `correctness-reviewer` agent
3. Integrate correctness review before Phase 3

### Phase 5: Tooling
1. Correctness coverage report generation
2. Gap analysis visualization
3. Automated correctness regression testing

---

## Key Questions for the User

Before implementation, these competing requirements need explicit prioritization:

1. **Spec Detail vs Spec Speed**
   - More correctness criteria = slower spec creation
   - How much overhead is acceptable?

2. **Automation vs Manual Review**
   - Should correctness verification be fully automated?
   - Or require human sign-off?

3. **Strictness vs Flexibility**
   - Should missing correctness criteria block execution?
   - Or just warn?

4. **Scope of Uncertainty Handling**
   - Should every task define uncertainty scenarios?
   - Or only high-risk tasks?

---

## Conclusion

The video's insight—that "correctness is upstream of architecture"—maps directly to Agent OS's spec-first philosophy. By making correctness criteria explicit, measurable, and traceable throughout the pipeline, we can:

1. **Eliminate ambiguity** about what "done" means
2. **Surface trade-offs early** before implementation begins
3. **Enable calibrated uncertainty** with explicit failure modes
4. **Maintain provenance** from requirement to implementation
5. **Support multi-dimensional testing** beyond just "tests pass"

The result: More reliable AI-assisted development with explicit quality contracts.
