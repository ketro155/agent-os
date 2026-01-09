# Create Test Plan

## Quick Navigation
- [Description](#description)
- [Parameters](#parameters)
- [Dependencies](#dependencies)
- [Task Tracking](#task-tracking)
- [Core Instructions](#core-instructions)

## Description

Create a browser test plan for testing features, pages, workflows, or entire applications. Uses Claude Code's Chrome MCP capabilities to generate structured test scenarios with explicit steps, entry criteria, fixtures, and evidence configuration.

**Key Features:**
- Interactive questioning to clarify test scope
- Automatic prerequisite and dependency detection
- Fixture generation for reusable setup sequences
- Hybrid test steps (high-level + critical explicit steps)

## Parameters

- `target` (optional): What to test - can be:
  - Spec folder path (e.g., `.agent-os/specs/auth-feature/`)
  - Feature name (e.g., "user login")
  - Page URL or route (e.g., "/dashboard")
  - Workflow description (e.g., "checkout flow")
  - "app" for whole application smoke testing

## Dependencies

**Reads (if available):**
- `.agent-os/specs/[spec]/spec.md` (when testing a spec)
- `.agent-os/product/tech-stack.md` (for context)
- Source files related to the target feature

**Creates:**
- `.agent-os/test-plans/[plan-name]/test-plan.json` (source of truth)
- `.agent-os/test-plans/[plan-name]/test-plan.md` (auto-generated via hook)

## Task Tracking

**IMPORTANT: Use Claude's TodoWrite tool throughout execution:**
```javascript
const todos = [
  { content: "Gather test target information via questions", status: "pending", activeForm: "Gathering test target information via questions" },
  { content: "Analyze target and discover scenarios", status: "pending", activeForm: "Analyzing target and discovering scenarios" },
  { content: "Identify prerequisites and create fixtures", status: "pending", activeForm: "Identifying prerequisites and creating fixtures" },
  { content: "Generate detailed test steps", status: "pending", activeForm: "Generating detailed test steps" },
  { content: "Build execution order graph", status: "pending", activeForm: "Building execution order graph" },
  { content: "Create test plan files", status: "pending", activeForm: "Creating test plan files" },
  { content: "Present summary and next steps", status: "pending", activeForm: "Presenting summary and next steps" }
];
```

---

## SECTION: Core Instructions

### Step 1: Gather Test Target Information

Use AskUserQuestion to clarify the testing scope:

```javascript
AskUserQuestion({
  questions: [
    {
      question: "What would you like to test?",
      header: "Test Target",
      multiSelect: false,
      options: [
        { label: "Specific Spec", description: "Test scenarios from a spec folder" },
        { label: "Feature", description: "Test a specific feature (e.g., login, checkout)" },
        { label: "Page/Route", description: "Test a specific page or route" },
        { label: "Workflow", description: "Test an end-to-end user workflow" },
        { label: "Whole Application", description: "Generate smoke tests for entire app" }
      ]
    },
    {
      question: "What is the base URL for testing?",
      header: "Base URL",
      multiSelect: false,
      options: [
        { label: "http://localhost:3000 (Recommended)", description: "Local development server" },
        { label: "http://localhost:5173", description: "Vite dev server" },
        { label: "http://localhost:8080", description: "Alternative port" }
      ]
    },
    {
      question: "What scope of testing?",
      header: "Scope",
      multiSelect: false,
      options: [
        { label: "Smoke (Recommended)", description: "Quick critical path validation (~5-10 tests)" },
        { label: "Regression", description: "Comprehensive feature coverage (~20-50 tests)" },
        { label: "Full", description: "Exhaustive testing including edge cases (~50+ tests)" }
      ]
    }
  ]
});
```

### Step 2: Ask About Prerequisites (for workflow/app targets)

If the user selected Workflow or Whole Application:

```javascript
AskUserQuestion({
  questions: [
    {
      question: "Does this feature require user login?",
      header: "Auth Required",
      multiSelect: false,
      options: [
        { label: "Yes - Login required", description: "Create a login fixture that runs before tests" },
        { label: "No - Public pages", description: "No authentication needed" },
        { label: "Mixed - Some pages need auth", description: "Mark specific scenarios as requiring login" }
      ]
    },
    {
      question: "Are there other setup steps needed?",
      header: "Setup Steps",
      multiSelect: true,
      options: [
        { label: "None needed", description: "Tests can run independently" },
        { label: "Test data setup", description: "Need to create test users/products/etc" },
        { label: "Navigate to specific page", description: "Start from a specific location" },
        { label: "Accept cookies/GDPR", description: "Need to dismiss banners first" }
      ]
    }
  ]
});
```

### Step 3: Invoke Discovery Agent

Spawn the test-discovery agent to analyze the target:

```javascript
const discoveryResult = await Task({
  subagent_type: "test-discovery",
  prompt: `Discover testable scenarios for browser testing.

Input:
{
  "target_type": "${targetType}",
  "target_value": "${targetValue}",
  "scope": "${scope}",
  "base_url": "${baseUrl}"
}

${targetType === 'spec' ? `Spec path: ${targetValue}` : ''}
${targetType === 'feature' ? `Feature name: ${targetValue}` : ''}

Additional context:
- Auth required: ${authRequired}
- Setup steps: ${setupSteps.join(', ')}

Return structured discovery results with:
- fixtures (reusable setup sequences)
- discovered_scenarios (with entry_criteria)
- execution_order
- coverage_analysis`
});
```

### Step 4: Generate Detailed Test Steps

For each discovered scenario, expand the `steps_hint` into explicit steps:

```javascript
for (const scenario of discoveredScenarios) {
  scenario.steps = [];
  let stepNum = 1;

  for (const hint of scenario.steps_hint) {
    const step = {
      step_id: `${scenario.id}.${stepNum}`,
      action: inferAction(hint),
      description: hint,
      critical: isCriticalStep(hint)
    };

    // Add action-specific properties
    if (step.action === 'navigate') {
      step.target = inferTarget(hint);
    } else if (step.action === 'type') {
      step.selector = inferSelector(hint);
      step.value = inferValue(hint);
    } else if (step.action === 'click') {
      step.selector = inferSelector(hint);
    } else if (step.action === 'verify') {
      step.expected = inferExpected(hint);
    }

    scenario.steps.push(step);
    stepNum++;
  }
}
```

### Step 5: Build Execution Order Graph

Determine the execution order based on dependencies:

```javascript
function buildExecutionOrder(scenarios) {
  // Prerequisites first
  const prereqs = scenarios.filter(s => s.is_prerequisite);
  const nonPrereqs = scenarios.filter(s => !s.is_prerequisite);

  // Sort non-prereqs by dependency depth
  const sorted = topologicalSort(nonPrereqs, s => s.entry_criteria?.depends_on || []);

  return [...prereqs.map(s => s.id), ...sorted.map(s => s.id)];
}

// Verify no circular dependencies
function detectCircularDeps(scenarios) {
  // ... implementation
}
```

### Step 6: Create Test Plan

Generate the test plan using the operations script:

```bash
# Create the test plan
RESULT=$(bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/test-operations.sh" create-plan \
  "${planName}" \
  "${baseUrl}" \
  "${targetType}" \
  "${targetValue}" \
  "${scope}")

PLAN_PATH=$(echo "$RESULT" | jq -r '.plan_path')
PLAN_FILE=$(echo "$RESULT" | jq -r '.plan_file')
```

Then add fixtures and scenarios:

```bash
# Add fixtures
for fixture in fixtures:
  bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/test-operations.sh" add-fixture \
    "${planName}" \
    "${fixtureName}" \
    "${fixtureJson}"

# Add scenarios
for scenario in scenarios:
  bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/test-operations.sh" add-scenario \
    "${planName}" \
    "${scenarioJson}"
```

### Step 7: Present Summary

Present the test plan summary to the user:

```markdown
## Test Plan Created: ${planName}

### Overview
| Property | Value |
|----------|-------|
| Base URL | ${baseUrl} |
| Scope | ${scope} |
| Total Scenarios | ${totalScenarios} |

### Scenarios by Priority
| Priority | Count |
|----------|-------|
| Critical | ${critical} |
| High | ${high} |
| Medium | ${medium} |
| Low | ${low} |

### Prerequisites
${prereqList}

### Fixtures Created
${fixtureList}

### Execution Order
\`\`\`
${executionOrder}
\`\`\`

---

## Next Steps

Run the test plan:
\`\`\`
/run-tests ${planName}
\`\`\`

Edit the plan (if needed):
\`\`\`
${PLAN_FILE}
\`\`\`
```

---

## Error Handling

### If Target Not Found

```markdown
Could not find the specified target: "${targetValue}"

Suggestions:
- For specs: Check that the spec folder exists at `.agent-os/specs/[name]/`
- For features: Provide a more specific feature name
- For pages: Ensure the route exists in your application
```

### If No Scenarios Discovered

```markdown
No testable scenarios found for: "${targetValue}"

This might happen if:
- The target is too abstract (try being more specific)
- The codebase doesn't have UI components yet
- The spec doesn't define user-facing behaviors

Would you like to manually define scenarios instead?
```

---

## Example Output

```json
{
  "version": "1.0",
  "name": "auth-feature-tests",
  "base_url": "http://localhost:3000",
  "source": {
    "type": "feature",
    "value": "authentication",
    "scope": "regression"
  },
  "fixtures": {
    "login": {
      "description": "Authenticate as test user",
      "steps": [
        { "action": "navigate", "target": "/login" },
        { "action": "type", "selector": "email input", "value": "test@example.com" },
        { "action": "type", "selector": "password input", "value": "password123" },
        { "action": "click", "selector": "login button" },
        { "action": "verify", "expected": "Dashboard" }
      ],
      "success_indicator": "Dashboard visible"
    }
  },
  "scenarios": [
    {
      "id": "S1",
      "name": "User can log in with valid credentials",
      "is_prerequisite": true,
      "priority": "critical",
      "steps": [...]
    }
  ]
}
```
