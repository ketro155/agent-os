# Run Tests (v4.9.0)

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
- **v4.9.0**: Parallel scenario execution with --parallel flag
- **v4.9.0**: Headless mode support with --headless flag

## Parameters

- `plan_name` (required): Name of the test plan folder
- `scenarios` (optional): Specific scenario IDs (comma-separated) or "all" (default: "all")
- `--parallel` (optional): Execute independent scenarios in parallel (v4.9.0)
- `--headless` (optional): Run tests in headless browser mode (v4.9.0)
- `--workers=N` (optional): Number of parallel workers (default: 3, max: 5)

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
3. Independent scenarios can run in any order (or parallel in v4.9.0)

### Step 3: Execute Scenarios

#### Sequential Execution (Default)

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

    console.log(`Skipped ${scenarioId}: Prerequisite ${blockedBy} failed`);
    continue;
  }

  // 3.2 Get scenario details from test plan
  const scenario = getScenarioFromPlan(planFile, scenarioId);

  // 3.3 Invoke test-executor agent
  console.log(`Executing ${scenarioId}: ${scenario.name}`);

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
  // ... (same as before)
}
```

#### Parallel Execution (v4.9.0)

When `--parallel` flag is set:

```javascript
/**
 * Execute scenarios in parallel groups
 * Groups are formed by dependency analysis - scenarios with no mutual dependencies run together
 */
async function executeScenarios(
  scenarios: Scenario[],
  options: { parallel: boolean, workers: number, headless: boolean }
): Promise<ScenarioResult[]> {
  const { parallel = false, workers = 3, headless = false } = options;
  
  if (!parallel) {
    // Sequential execution (existing behavior)
    return executeSequential(scenarios);
  }
  
  // Group scenarios by dependency level
  const groups = groupByDependencyLevel(scenarios);
  const results: ScenarioResult[] = [];
  
  // Create worker pool
  const workerTabs: number[] = [];
  for (let i = 0; i < workers; i++) {
    const tab = await mcp__claude-in-chrome__tabs_create_mcp();
    workerTabs.push(tab.tabId);
  }
  
  // Execute each group
  for (const group of groups) {
    console.log(`\nExecuting group with ${group.length} scenarios in parallel...`);
    
    // Split group into chunks for workers
    const chunks = chunkArray(group, workers);
    
    // Spawn parallel executors
    const groupPromises = group.map((scenario, index) => {
      const workerTab = workerTabs[index % workers];
      
      return Task({
        subagent_type: "test-executor",
        run_in_background: true,  // v4.9.0: Parallel execution
        prompt: `Execute browser test scenario in parallel.

Input:
${JSON.stringify({
  scenario: scenario,
  tab_id: workerTab,
  base_url: baseUrl,
  evidence_folder: `${reportPath}/evidence/${scenario.id}/`,
  fixtures_to_run: scenario.entry_criteria?.required_fixtures || [],
  parallel_mode: true
}, null, 2)}

Execute all steps and return structured result.
Never modify source code - this is read-only testing.`
      });
    });
    
    // Wait for all parallel executions
    const groupResults = await Promise.all(
      groupPromises.map(async (agentId) => {
        return TaskOutput({ task_id: agentId, block: true });
      })
    );
    
    results.push(...groupResults);
    
    // Check for prerequisite failures before next group
    const failedPrereqs = groupResults.filter(
      r => r.status === 'failed' && scenarios.find(s => s.id === r.scenario_id)?.is_prerequisite
    );
    
    if (failedPrereqs.length > 0) {
      console.log(`Prerequisite failures detected, skipping dependent scenarios...`);
      // Skip scenarios that depend on failed prerequisites
    }
  }
  
  // Cleanup worker tabs
  for (const tabId of workerTabs) {
    // Close tab or reuse for next test run
  }
  
  return results;
}

/**
 * Group scenarios by dependency level for parallel execution
 * Level 0: No dependencies (can run first, in parallel)
 * Level 1: Depends only on level 0 scenarios
 * Level N: Depends on level N-1 scenarios
 */
function groupByDependencyLevel(scenarios: Scenario[]): Scenario[][] {
  const levels: Map<string, number> = new Map();
  const groups: Scenario[][] = [];
  
  // Prerequisites are always level 0
  scenarios.filter(s => s.is_prerequisite).forEach(s => levels.set(s.id, 0));
  
  // Calculate levels for all scenarios
  function getLevel(scenario: Scenario): number {
    if (levels.has(scenario.id)) {
      return levels.get(scenario.id)!;
    }
    
    const deps = scenario.entry_criteria?.depends_on || [];
    if (deps.length === 0) {
      levels.set(scenario.id, 0);
      return 0;
    }
    
    const maxDepLevel = Math.max(
      ...deps.map(depId => {
        const depScenario = scenarios.find(s => s.id === depId);
        return depScenario ? getLevel(depScenario) : 0;
      })
    );
    
    const level = maxDepLevel + 1;
    levels.set(scenario.id, level);
    return level;
  }
  
  scenarios.forEach(s => getLevel(s));
  
  // Group by level
  const maxLevel = Math.max(...levels.values());
  for (let i = 0; i <= maxLevel; i++) {
    const levelScenarios = scenarios.filter(s => levels.get(s.id) === i);
    if (levelScenarios.length > 0) {
      groups.push(levelScenarios);
    }
  }
  
  return groups;
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
  "execution_end": "${new Date().toISOString()}",
  "execution_mode": "${parallel ? 'parallel' : 'sequential'}",
  "workers_used": ${parallel ? workers : 1}
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
**Mode**: ${parallel ? `Parallel (${workers} workers)` : 'Sequential'}

### Results Summary

| Status | Count |
|--------|-------|
| Passed | ${passed} |
| Failed | ${failed} |
| Skipped | ${skipped} |
| **Pass Rate** | ${passRate}% |

${parallel ? `
### Parallel Execution Stats (v4.9.0)

| Metric | Value |
|--------|-------|
| Workers Used | ${workers} |
| Dependency Groups | ${groupCount} |
| Actual Duration | ${actualDuration} |
| Sequential Estimate | ${sequentialEstimate} |
| **Speedup** | ${speedup}x |
` : ''}

${failed > 0 ? `
### Failures

${failures.map(f => `
#### ${f.scenario_id}: ${f.scenario_name}
**Failed Step**: ${f.failure_step}
**Error**: ${f.failure_message}
**Evidence**: [Screenshot](${f.evidence.screenshot})
${f.blocked_scenarios?.length > 0 ? `**Blocked**: ${f.blocked_scenarios.join(', ')}` : ''}
`).join('\n')}
` : ''}

${skipped > 0 ? `
### Skipped Scenarios

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
Chrome MCP not available

The Chrome extension is not connected. Please:
1. Install the "Claude in Chrome" extension
2. Make sure Chrome is running
3. Click the extension icon to connect
4. Try running the tests again
```

### Test Plan Not Found

```markdown
Test plan not found: ${planName}

Available test plans:
${availablePlans}

Create a new test plan:
\`/create-test-plan\`
```

### Browser Tab Lost (Parallel Mode)

In parallel mode, worker tabs are managed separately:

```javascript
// Check if worker tab still exists
async function ensureWorkerTab(workerId, workerTabs) {
  const tabId = workerTabs[workerId];
  
  try {
    await mcp__claude-in-chrome__computer({
      action: "screenshot",
      tabId: tabId
    });
    return tabId;
  } catch (e) {
    // Tab lost, create new one
    const newTab = await mcp__claude-in-chrome__tabs_create_mcp();
    workerTabs[workerId] = newTab.tabId;
    console.log(`Worker ${workerId} tab recreated`);
    return newTab.tabId;
  }
}
```

---

## Important Notes

1. **Never modify source code** - This is read-only testing
2. **Continue on failure** - Complete all tests, report all failures at end
3. **Skip on prerequisite failure** - Don't waste time on tests that can't pass
4. **Capture everything** - Screenshots, console, network logs for debugging
5. **Wait after navigation** - Pages need time to load (1-2 seconds minimum)
6. **Parallel limits** - Max 5 workers to avoid browser instability (v4.9.0)
7. **Group dependencies** - Only scenarios at the same dependency level run in parallel (v4.9.0)

---

## Changelog

### v4.9.0
- Added --parallel flag for parallel scenario execution
- Added --headless flag for headless browser mode
- Added --workers=N parameter for controlling parallelism
- Added executeScenarios function with parallel support
- Added groupByDependencyLevel for dependency-aware parallelism
- Added parallel execution stats to report summary

### v4.8.0
- Initial run-tests command
