# Create Test Plan (v4.9.0)

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
- **v4.9.0**: Auto-detect base URL from project configuration
- **v4.9.0**: Negative test scenario generation

## Parameters

- `target` (optional): What to test - can be:
  - Spec folder path (e.g., `.agent-os/specs/auth-feature/`)
  - Feature name (e.g., "user login")
  - Page URL or route (e.g., "/dashboard")
  - Workflow description (e.g., "checkout flow")
  - "app" for whole application smoke testing

- `--include-negative` (optional): Generate negative test scenarios (default: true for regression/full)
- `--parallel` (optional): Enable parallel scenario execution

## Dependencies

**Reads (if available):**
- `.agent-os/specs/[spec]/spec.md` (when testing a spec)
- `.agent-os/product/tech-stack.md` (for context)
- Source files related to the target feature
- `package.json` (for detectBaseUrl)
- `vite.config.*`, `next.config.*` (for detectBaseUrl)

**Creates:**
- `.agent-os/test-plans/[plan-name]/test-plan.json` (source of truth)
- `.agent-os/test-plans/[plan-name]/test-plan.md` (auto-generated via hook)

## Task Tracking

**IMPORTANT: Use Claude's TodoWrite tool throughout execution:**
```javascript
const todos = [
  { content: "Detect base URL from project config", status: "pending", activeForm: "Detecting base URL from project config" },
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

### Step 0: Detect Base URL (v4.9.0)

> **NEW in v4.9.0**: Automatically detect the base URL from project configuration

```javascript
/**
 * Detect base URL from project configuration files
 * Priority: package.json scripts > vite.config > next.config > defaults
 */
function detectBaseUrl() {
  let detectedUrl = null;
  let detectedSource = null;
  
  // 1. Check package.json for dev server configuration
  const packageJson = Read({ file_path: "package.json" });
  if (packageJson) {
    const pkg = JSON.parse(packageJson);
    
    // Check scripts for port hints
    const devScript = pkg.scripts?.dev || pkg.scripts?.start || "";
    
    // Parse --port flag
    const portMatch = devScript.match(/--port[=\s](\d+)/);
    if (portMatch) {
      detectedUrl = `http://localhost:${portMatch[1]}`;
      detectedSource = "package.json scripts";
    }
    
    // Check for proxy configuration
    if (pkg.proxy) {
      detectedUrl = pkg.proxy;
      detectedSource = "package.json proxy";
    }
  }
  
  // 2. Check vite.config.ts/js
  const viteConfig = Glob({ pattern: "vite.config.{ts,js,mts,mjs}" });
  if (viteConfig.length > 0) {
    const configContent = Read({ file_path: viteConfig[0] });
    
    // Parse server.port
    const portMatch = configContent.match(/port:\s*(\d+)/);
    if (portMatch) {
      detectedUrl = `http://localhost:${portMatch[1]}`;
      detectedSource = "vite.config";
    }
    
    // Default Vite port
    if (!detectedUrl && configContent.includes("defineConfig")) {
      detectedUrl = "http://localhost:5173";
      detectedSource = "vite.config (default)";
    }
  }
  
  // 3. Check next.config.js
  const nextConfig = Glob({ pattern: "next.config.{js,mjs,ts}" });
  if (nextConfig.length > 0) {
    detectedUrl = "http://localhost:3000";
    detectedSource = "next.config (default)";
  }
  
  // 4. Check for .env files
  const envFiles = Glob({ pattern: ".env*" });
  for (const envFile of envFiles) {
    const envContent = Read({ file_path: envFile });
    const portMatch = envContent.match(/PORT=(\d+)/);
    if (portMatch) {
      detectedUrl = `http://localhost:${portMatch[1]}`;
      detectedSource = envFile;
      break;
    }
  }
  
  // 5. Default fallback
  if (!detectedUrl) {
    detectedUrl = "http://localhost:3000";
    detectedSource = "default";
  }
  
  return {
    url: detectedUrl,
    source: detectedSource,
    alternatives: [
      "http://localhost:3000",
      "http://localhost:5173",
      "http://localhost:8080",
      "http://localhost:4200"
    ]
  };
}
```

### Step 1: Gather Test Target Information

Use AskUserQuestion to clarify the testing scope:

```javascript
// First, detect base URL
const detectedBase = detectBaseUrl();

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
      question: `Detected base URL: ${detectedBase.url} (from ${detectedBase.source}). Use this?`,
      header: "Base URL",
      multiSelect: false,
      options: [
        { label: `${detectedBase.url} (Detected)`, description: `Auto-detected from ${detectedBase.source}` },
        ...detectedBase.alternatives.map(url => ({
          label: url,
          description: url === "http://localhost:3000" ? "React/Next.js default" :
                       url === "http://localhost:5173" ? "Vite default" :
                       url === "http://localhost:8080" ? "Spring/Java default" :
                       "Angular default"
        })),
        { label: "Custom URL", description: "Enter a custom URL" }
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
    },
    {
      question: "Include negative test scenarios?",  // v4.9.0
      header: "Negative Tests",
      multiSelect: false,
      options: [
        { label: "Yes (Recommended)", description: "Generate invalid input, missing field, and boundary tests" },
        { label: "No", description: "Only generate positive test scenarios" }
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
  "base_url": "${baseUrl}",
  "include_negative_tests": ${includeNegativeTests}
}

${targetType === 'spec' ? `Spec path: ${targetValue}` : ''}
${targetType === 'feature' ? `Feature name: ${targetValue}` : ''}

Additional context:
- Auth required: ${authRequired}
- Setup steps: ${setupSteps.join(', ')}

Return structured discovery results with:
- fixtures (reusable setup sequences)
- discovered_scenarios (with entry_criteria)
- negative_scenarios (if include_negative_tests is true)
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
      critical: isCriticalStep(hint),
      selectors: inferSelectors(hint)  // v4.9.0: Add selector patterns
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
    } else if (step.action === 'verify_error') {  // v4.9.0
      step.expected_error = scenario.expected_error || inferExpected(hint);
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

  // Positive tests before negative tests (v4.9.0)
  const positives = sorted.filter(s => s.test_type !== 'negative');
  const negatives = sorted.filter(s => s.test_type === 'negative');

  return [...prereqs.map(s => s.id), ...positives.map(s => s.id), ...negatives.map(s => s.id)];
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
| Base URL | ${baseUrl} (detected from ${detectedSource}) |
| Scope | ${scope} |
| Total Scenarios | ${totalScenarios} |
| Positive Tests | ${positiveCount} |
| Negative Tests | ${negativeCount} |

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

### Negative Test Coverage (v4.9.0)
| Type | Count |
|------|-------|
| Invalid Input | ${invalidInputCount} |
| Missing Field | ${missingFieldCount} |
| Boundary | ${boundaryCount} |

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

Run with parallel execution (v4.9.0):
\`\`\`
/run-tests ${planName} --parallel
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

## Changelog

### v4.9.0
- Added detectBaseUrl function for automatic base URL detection
- Added negative test scenario generation support
- Added --include-negative and --parallel parameters
- Updated discovery agent invocation with include_negative_tests
- Added negative test coverage to summary output

### v4.8.0
- Initial create-test-plan command
