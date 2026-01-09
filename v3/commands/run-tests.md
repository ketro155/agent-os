# Run Tests

## Quick Navigation
- [Description](#description)
- [Parameters](#parameters)
- [Dependencies](#dependencies)
- [Task Tracking](#task-tracking)
- [Core Instructions](#core-instructions)

## Description

Execute browser tests from a test plan using Chrome MCP tools. Captures evidence (screenshots, console logs, network requests, GIFs) and generates comprehensive reports with highlighted failures.

**Key Features:**
- Executes tests via Chrome browser automation
- Smart prerequisite handling (skip dependent tests if prerequisite fails)
- Full evidence capture for debugging
- Read-only execution (never modifies source code)
- Continues all tests even on individual failures

## Parameters

- `plan_name` (required): Name of the test plan folder
- `scenarios` (optional): Specific scenario IDs (comma-separated) or "all" (default: "all")

## Dependencies

**Required:**
- `.agent-os/test-plans/[plan-name]/test-plan.json`
- Chrome browser with Claude in Chrome extension connected

**Creates:**
- `.agent-os/test-reports/[plan-name]-[timestamp]/test-report.json`
- `.agent-os/test-reports/[plan-name]-[timestamp]/test-report.md` (auto-generated)
- `.agent-os/test-reports/[plan-name]-[timestamp]/evidence/` (screenshots, logs, GIFs)

## Task Tracking

**IMPORTANT: Use Claude's TodoWrite tool throughout execution:**
```javascript
const todos = [
  { content: "Validate test plan exists", status: "pending", activeForm: "Validating test plan exists" },
  { content: "Initialize Chrome browser session", status: "pending", activeForm: "Initializing Chrome browser session" },
  { content: "Build execution order from dependencies", status: "pending", activeForm: "Building execution order from dependencies" },
  { content: "Execute test scenarios", status: "pending", activeForm: "Executing test scenarios" },
  { content: "Generate test report", status: "pending", activeForm: "Generating test report" },
  { content: "Present results summary", status: "pending", activeForm: "Presenting results summary" }
];
```

---

## SECTION: Core Instructions

### Step 0: Pre-flight Checks

#### 0.1 Verify Test Plan Exists

```bash
PLAN_STATUS=$(bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/test-operations.sh" plan-status "${planName}")

if echo "$PLAN_STATUS" | jq -e '.error' > /dev/null 2>&1; then
  echo "Test plan not found: ${planName}"
  echo "Run /create-test-plan first to create a test plan."
  exit 1
fi

BASE_URL=$(echo "$PLAN_STATUS" | jq -r '.base_url')
TOTAL_SCENARIOS=$(echo "$PLAN_STATUS" | jq -r '.total_scenarios')
```

#### 0.2 Verify Chrome MCP Available

```javascript
// Check if Chrome MCP is available
const tabContext = await mcp__claude-in-chrome__tabs_context_mcp({
  createIfEmpty: true
});

if (!tabContext || tabContext.error) {
  throw new Error("Chrome MCP not available. Ensure the Claude in Chrome extension is installed and connected.");
}
```

#### 0.3 Initialize Report

```bash
REPORT_RESULT=$(bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/test-operations.sh" init-report "${planName}")

REPORT_PATH=$(echo "$REPORT_RESULT" | jq -r '.report_path')
REPORT_FILE=$(echo "$REPORT_RESULT" | jq -r '.report_file')

echo "Report initialized: ${REPORT_PATH}"
```

### Step 1: Initialize Browser Session

```javascript
// Get or create tab context
const context = await mcp__claude-in-chrome__tabs_context_mcp({
  createIfEmpty: true
});

// Create dedicated test tab
const testTab = await mcp__claude-in-chrome__tabs_create_mcp();
const tabId = testTab.tabId;

// Navigate to base URL
await mcp__claude-in-chrome__navigate({
  tabId: tabId,
  url: baseUrl
});

// Wait for initial load
await mcp__claude-in-chrome__computer({
  action: "wait",
  duration: 2,
  tabId: tabId
});

// Take initial screenshot
await mcp__claude-in-chrome__computer({
  action: "screenshot",
  tabId: tabId
});
```

### Step 2: Build Execution Order

```bash
EXEC_ORDER=$(bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/test-operations.sh" execution-order "${planName}")

EXECUTION_ORDER=$(echo "$EXEC_ORDER" | jq -r '.execution_order[]')
PREREQUISITES=$(echo "$EXEC_ORDER" | jq -r '.prerequisites')
```

The execution order ensures:
1. Prerequisites run first
2. Dependent scenarios run after their dependencies
3. Independent scenarios can run in any order

### Step 3: Execute Scenarios

For each scenario in execution order:

```javascript
const prerequisiteResults = {}; // Track which prerequisites passed

for (const scenarioId of executionOrder) {
  // 3.1 Check if prerequisites passed
  const prereqCheck = await Bash({
    command: `bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/test-operations.sh" check-prerequisites "${reportFile}" "${scenarioId}"`
  });

  const prereqStatus = JSON.parse(prereqCheck);

  if (!prereqStatus.can_execute) {
    // Skip this scenario - prerequisite failed
    const blockedBy = prereqStatus.blocking_failures[0];

    await Bash({
      command: `bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/test-operations.sh" skip-scenario "${reportFile}" "${scenarioId}" "${blockedBy}"`
    });

    console.log(`⏭️ Skipped ${scenarioId}: Prerequisite ${blockedBy} failed`);
    continue;
  }

  // 3.2 Get scenario details from test plan
  const scenario = getScenarioFromPlan(planFile, scenarioId);

  // 3.3 Invoke test-executor agent
  console.log(`🧪 Executing ${scenarioId}: ${scenario.name}`);

  const startTime = Date.now();

  const result = await Task({
    subagent_type: "test-executor",
    prompt: `Execute browser test scenario.

Input:
${JSON.stringify({
  scenario: scenario,
  tab_id: tabId,
  base_url: baseUrl,
  evidence_folder: `${reportPath}/evidence/${scenarioId}/`,
  fixtures_to_run: scenario.entry_criteria?.required_fixtures || []
}, null, 2)}

Execute all steps and return structured result.
Never modify source code - this is read-only testing.`
  });

  const duration = Date.now() - startTime;

  // 3.4 Update report with result
  if (result.status === "passed") {
    await Bash({
      command: `bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/test-operations.sh" update-scenario "${reportFile}" "${scenarioId}" "passed" "${duration}"`
    });
    console.log(`✅ Passed: ${scenarioId} (${formatDuration(duration)})`);

    // Track prerequisite success
    if (scenario.is_prerequisite) {
      prerequisiteResults[scenarioId] = "passed";
    }
  } else {
    // Failed scenario
    await Bash({
      command: `bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/test-operations.sh" update-scenario "${reportFile}" "${scenarioId}" "failed" "${duration}" "${result.failure_message}"`
    });

    // Add failure details
    const failureJson = JSON.stringify({
      scenario_id: scenarioId,
      scenario_name: scenario.name,
      failure_type: result.status,
      failure_step: result.failed_step_id,
      failure_message: result.failure_message,
      is_prerequisite: scenario.is_prerequisite || false,
      evidence: result.evidence
    });

    await Bash({
      command: `bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/test-operations.sh" add-failure "${reportFile}" '${failureJson}'`
    });

    console.log(`❌ Failed: ${scenarioId} - ${result.failure_message}`);

    // Track prerequisite failure
    if (scenario.is_prerequisite) {
      prerequisiteResults[scenarioId] = "failed";
    }
  }

  // 3.5 Update evidence counts
  if (result.evidence?.screenshots) {
    await Bash({
      command: `bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/test-operations.sh" update-evidence "${reportFile}" "screenshots" "${result.evidence.screenshots.length}"`
    });
  }
}
```

### Step 4: Generate Final Report

```javascript
// Finalize the report
await Bash({
  command: `bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/test-operations.sh" finalize-report "${reportFile}"`
});

// Invoke test-reporter agent for enhanced report
const reportResult = await Task({
  subagent_type: "test-reporter",
  prompt: `Generate final test report.

Input:
{
  "plan_name": "${planName}",
  "plan_path": "${planFile}",
  "report_path": "${reportFile}",
  "results": ${JSON.stringify(allResults)},
  "evidence_folder": "${reportPath}/evidence/",
  "execution_start": "${executionStart}",
  "execution_end": "${new Date().toISOString()}"
}

Organize failures prominently and calculate statistics.`
});
```

### Step 5: Present Results Summary

```markdown
## Test Execution Complete

**Plan**: ${planName}
**Executed**: ${timestamp}
**Duration**: ${duration}

### Results Summary

| Status | Count |
|--------|-------|
| Passed | ${passed} ✅ |
| Failed | ${failed} ❌ |
| Skipped | ${skipped} ⏭️ |
| **Pass Rate** | ${passRate}% |

${failed > 0 ? `
### ❌ Failures

${failures.map(f => `
#### ${f.scenario_id}: ${f.scenario_name}
**Failed Step**: ${f.failure_step}
**Error**: ${f.failure_message}
**Evidence**: [Screenshot](${f.evidence.screenshot})
${f.blocked_scenarios?.length > 0 ? `**Blocked**: ${f.blocked_scenarios.join(', ')}` : ''}
`).join('\n')}
` : ''}

${skipped > 0 ? `
### ⏭️ Skipped Scenarios

These were skipped because a prerequisite failed:
${skippedList}
` : ''}

### Reports

- **Full Report**: \`${reportFile}\`
- **Evidence**: \`${reportPath}/evidence/\`

### Next Steps

${failed > 0 ? `
1. Review failures above - check screenshots and console logs
2. Create specifications for fixes: \`/create-spec "Fix [issue]"\`
3. Re-run tests after fixes: \`/run-tests ${planName}\`
` : `
All tests passed! You can:
- Run these tests again after changes: \`/run-tests ${planName}\`
- Create more comprehensive tests: \`/create-test-plan\`
`}
```

---

## Error Handling

### Chrome MCP Not Available

```markdown
❌ Chrome MCP not available

The Chrome extension is not connected. Please:
1. Install the "Claude in Chrome" extension
2. Make sure Chrome is running
3. Click the extension icon to connect
4. Try running the tests again
```

### Test Plan Not Found

```markdown
❌ Test plan not found: ${planName}

Available test plans:
${availablePlans}

Create a new test plan:
\`/create-test-plan\`
```

### Browser Tab Lost

If the browser tab is closed during execution:

```javascript
// Check if tab still exists
try {
  await mcp__claude-in-chrome__computer({
    action: "screenshot",
    tabId: tabId
  });
} catch (e) {
  // Tab lost, create new one
  const newTab = await mcp__claude-in-chrome__tabs_create_mcp();
  tabId = newTab.tabId;

  // Navigate back to base URL
  await mcp__claude-in-chrome__navigate({
    tabId: tabId,
    url: baseUrl
  });

  console.log("⚠️ Browser tab was closed. Created new tab and resumed.");
}
```

---

## Important Notes

1. **Never modify source code** - This is read-only testing
2. **Continue on failure** - Complete all tests, report all failures at end
3. **Skip on prerequisite failure** - Don't waste time on tests that can't pass
4. **Capture everything** - Screenshots, console, network logs for debugging
5. **Wait after navigation** - Pages need time to load (1-2 seconds minimum)

---

## Example Execution

```
$ /run-tests auth-feature-tests

🧪 Initializing browser session...
📍 Base URL: http://localhost:3000

🧪 Executing S1: User can log in with valid credentials
   Step S1.1: Navigate to /login ✓
   Step S1.2: Enter email ✓
   Step S1.3: Enter password ✓
   Step S1.4: Click login button ✓
   Step S1.5: Verify dashboard ✓
✅ Passed: S1 (15.2s)

🧪 Executing S2: User can view profile settings
   Step S2.1: Click profile menu ✓
   Step S2.2: Click settings ✓
   Step S2.3: Verify settings page ✓
✅ Passed: S2 (8.4s)

🧪 Executing S3: User can change password
   Step S3.1: Click change password ✓
   Step S3.2: Enter current password ✓
   Step S3.3: Enter new password ✓
   Step S3.4: Confirm new password ✓
   Step S3.5: Click save ❌ Button not found
❌ Failed: S3 - Element not found: save button

📊 Results: 2 passed, 1 failed, 0 skipped (66% pass rate)
📁 Report: .agent-os/test-reports/auth-feature-tests-20250109-103045/
```
