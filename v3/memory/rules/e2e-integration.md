# E2E Test Integration (v4.11.0)

> Standardized end-to-end testing integration across Agent OS workflows.
> E2E tests complement TDD unit/integration tests with browser-level validation.

## Overview

Agent OS integrates E2E testing at three strategic points in the development lifecycle:

```
/create-spec → /create-tasks → /execute-tasks → Phase 3 → PR
     │                              │              │
     ▼                              ▼              ▼
  [Generate                   [Wave smoke      [Full E2E
   E2E Plan]                   tests]           gate]
```

## Integration Points

### 1. Create-Spec: Test Plan Generation (Step 11.75)

**When**: After spec approval, before completion
**What**: Auto-generate E2E test plan from requirements
**Blocking**: No (planning phase)

```markdown
Default behavior: Generate E2E plan (opt-out available)
Scope options:
  - Smoke: 5-10 critical path scenarios
  - Regression: 20-50 comprehensive scenarios
  - Full: 50+ exhaustive scenarios

Output: .agent-os/test-plans/${SPEC_NAME}/test-plan.json
```

**Rationale**: "Shift-left" testing - plans created when requirements are freshest.

### 2. Wave Lifecycle: Smoke Tests (READY_TO_MERGE phase)

**When**: Final wave PR approved, before merge to feature branch
**What**: Run smoke E2E tests (5-10 scenarios)
**Blocking**: Yes - failures prevent merge

```markdown
Trigger: Final wave only (wave == total_waves)
Scope: Smoke tests only (quick validation)
Purpose: Catch obvious integration regressions across waves
```

**Rationale**: Lightweight gate prevents broken merges without excessive delays.

### 3. Phase 3: Full E2E Gate (Step 3.5)

**When**: After unit tests pass, after build passes, before PR creation
**What**: Run full E2E test plan
**Blocking**: Yes - same treatment as unit test failures

```markdown
Trigger: Auto if test plan exists for spec
Scope: Full test plan (all scenarios)
On failure:
  - Return status "blocked"
  - Include failure report with screenshots
  - Agent attempts fix if < 3 failures and obvious
On success:
  - Include E2E summary in PR description
  - Continue to artifact collection
```

**Rationale**: Final quality gate ensures features work end-to-end before review.

## E2E Failure Handling

E2E failures are **hard-blocking** (same as unit tests):

```typescript
enum E2EFailureAction {
  BLOCK = "block",      // Stop and report (default)
  ATTEMPT_FIX = "fix",  // Try to fix if < 3 failures
  REPORT = "report"     // Continue but flag in PR
}

// Decision tree
if (failures.length === 0) {
  return "pass";
} else if (failures.length < 3 && canAutoFix(failures)) {
  return "fix";
} else {
  return "block";
}
```

### Failure Report Format

```json
{
  "status": "blocked",
  "gate": "e2e_validation",
  "summary": {
    "total": 15,
    "passed": 12,
    "failed": 3
  },
  "failures": [
    {
      "scenario": "User can complete checkout",
      "step": "Click 'Place Order' button",
      "error": "Element not found: [data-testid='place-order-btn']",
      "screenshot": ".agent-os/test-results/checkout-failure.png"
    }
  ],
  "recommendation": "Fix missing data-testid attribute on checkout button"
}
```

## Test Plan Lifecycle

```
┌─────────────────────────────────────────────────────────────┐
│ /create-spec                                                │
│   └── Step 11.75: Generate test-plan.json                  │
│        └── Stored in .agent-os/test-plans/${SPEC_NAME}/    │
├─────────────────────────────────────────────────────────────┤
│ /execute-tasks (multi-wave)                                 │
│   └── wave-lifecycle-agent (final wave)                    │
│        └── READY_TO_MERGE: Run smoke tests                 │
│             └── Failures block merge                        │
├─────────────────────────────────────────────────────────────┤
│ /execute-tasks → Phase 3                                   │
│   └── phase3-delivery                                       │
│        └── Step 3.5: Run full E2E plan                     │
│             └── Failures block PR creation                  │
│             └── Success → E2E summary in PR                │
└─────────────────────────────────────────────────────────────┘
```

## Directory Structure

```
.agent-os/
├── test-plans/                    # E2E test plans
│   └── ${SPEC_NAME}/
│       ├── test-plan.json         # Source of truth
│       ├── test-plan.md           # Auto-generated
│       └── fixtures/              # Reusable setup sequences
│
├── test-results/                  # E2E execution results
│   └── ${SPEC_NAME}/
│       ├── results.json           # Structured results
│       ├── report.html            # Human-readable report
│       └── evidence/              # Screenshots, GIFs, logs
│           ├── *.png
│           └── *.gif
```

## Skipping E2E Tests

E2E tests can be skipped in specific circumstances:

| Flag | When to Use | Effect |
|------|-------------|--------|
| `--skip-e2e` | Backend-only changes | Skip E2E in Phase 3 |
| `--no-e2e-plan` | create-spec flag | Don't generate E2E plan |
| No test plan exists | Spec has no UI | Auto-skip (no plan found) |

**Warning**: Skipping E2E should be explicit and justified. The workflow will log skip events:

```json
{
  "event": "e2e_skipped",
  "reason": "--skip-e2e flag",
  "spec": "backend-api-refactor",
  "timestamp": "2026-01-14T..."
}
```

## Integration with Existing Agents

### test-discovery Agent

Used by `/create-test-plan` to identify testable scenarios:

```markdown
Input: Spec requirements, feature scope
Output: Structured scenario list with:
  - Entry criteria
  - Test steps
  - Expected outcomes
  - Evidence configuration
```

### test-executor Agent

Used by `/run-tests` to execute individual scenarios:

```markdown
Tools available:
  - Chrome MCP (navigate, read_page, find, computer, form_input)
  - Evidence capture (screenshots, GIFs, console logs, network)

Selector priority (v4.9.0):
  1. data-testid
  2. aria-label
  3. Semantic selectors
  4. CSS selectors
```

### test-reporter Agent

Generates comprehensive reports from execution results:

```markdown
Output formats:
  - JSON (structured, machine-readable)
  - HTML (human-readable with screenshots)
  - Markdown (for PR description)
```

## Best Practices

### Writing E2E-Friendly Code

1. **Use data-testid attributes** for interactive elements:
   ```html
   <button data-testid="submit-order">Place Order</button>
   ```

2. **Avoid dynamic IDs** that change between renders

3. **Include aria-labels** for accessibility and test targeting

4. **Use semantic HTML** (button, input, form) over generic divs

### Test Plan Design

1. **Prioritize critical paths** - checkout flow > admin settings
2. **Include negative tests** - error handling, validation
3. **Design for independence** - each scenario should be self-contained
4. **Use fixtures** for common setup (login, navigation)

## Error Codes

| Code | Tier | Name | Description |
|------|------|------|-------------|
| E300 | RECOVERABLE | E2E_SCENARIO_FAILED | Individual scenario failed |
| E301 | RECOVERABLE | E2E_TIMEOUT | Scenario timed out |
| E302 | RECOVERABLE | E2E_ELEMENT_NOT_FOUND | Target element not found |
| E303 | FATAL | E2E_BROWSER_CRASH | Browser connection lost |
| E304 | TRANSIENT | E2E_NETWORK_ERROR | Network request failed |

---

## Changelog

### v4.11.0 (2026-01-14)
- Initial E2E integration system
- Three integration points: create-spec, wave-lifecycle, phase3
- Hard-blocking failure behavior
- Default E2E plan generation in create-spec
