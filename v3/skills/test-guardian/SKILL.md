---
name: test-guardian
description: Analyzes test failures and classifies them as FLAKY, BROKEN, or NEW based on historical test results, then recommends retry, fix, or quarantine actions. Use when tests fail during Phase 2 implementation, E2E scenarios fail intermittently, or you suspect flakiness. Use when user says "classify test failure", "is this test flaky", "analyze failing tests", or "test guardian".
version: 1.0.0
context: fork
metadata:
  author: Agent OS
  category: testing
---

# Test Guardian Skill (v5.0.1)

> **Note**: `context: fork` is a Claude Code extension that isolates this skill's execution context.

> **"Not all red tests are created equal."**
>
> Classifies test failures to prevent wasted agent time on flaky tests
> and ensure genuine failures get proper attention.

## When to Invoke

Use `/test-guardian` when:
- Test execution fails during Phase 2 implementation
- E2E scenarios fail intermittently
- You suspect a test is flaky rather than genuinely broken

## Input

Invoke with the path to test results or a test failure message:

```
/test-guardian [test-output-or-path]
```

## Classification Protocol

### Step 1: Gather Test History

```javascript
// Read test results directory for this spec
const testResultsDir = '.agent-os/test-results/';
const specDirs = fs.readdirSync(testResultsDir).filter(d =>
  fs.statSync(path.join(testResultsDir, d)).isDirectory()
);

// Collect historical results
const history = {};
for (const dir of specDirs) {
  const resultsPath = path.join(testResultsDir, dir, 'results.json');
  if (fs.existsSync(resultsPath)) {
    const results = JSON.parse(fs.readFileSync(resultsPath, 'utf-8'));
    for (const scenario of results.scenarios || []) {
      if (!history[scenario.scenario_id]) {
        history[scenario.scenario_id] = [];
      }
      history[scenario.scenario_id].push({
        status: scenario.status,
        error: scenario.error,
        date: results.completed_at || dir
      });
    }
  }
}
```

### Step 2: Classify Each Failure

```javascript
function classifyFailure(scenarioId, currentError, history) {
  const pastResults = history[scenarioId] || [];

  // NEW: No history at all — this is a new test
  if (pastResults.length === 0) {
    return {
      classification: "NEW",
      confidence: "high",
      reasoning: "No previous test history found",
      recommendation: "FIX — This is a genuine new failure"
    };
  }

  // Count pass/fail ratio
  const passCount = pastResults.filter(r => r.status === 'passed').length;
  const failCount = pastResults.filter(r => r.status === 'failed').length;
  const totalRuns = pastResults.length;
  const failRate = failCount / totalRuns;

  // FLAKY: Fails sometimes, passes sometimes (20-80% fail rate)
  if (failRate > 0.2 && failRate < 0.8 && totalRuns >= 3) {
    return {
      classification: "FLAKY",
      confidence: failRate > 0.4 ? "high" : "medium",
      reasoning: `Failed ${failCount}/${totalRuns} times (${(failRate * 100).toFixed(0)}% fail rate)`,
      recommendation: "RETRY — This test is flaky. Retry up to 2 times before investigating.",
      retry_count: 2
    };
  }

  // BROKEN: Consistently fails (>80% fail rate)
  if (failRate >= 0.8) {
    // Check if the error message is the same
    const sameError = pastResults
      .filter(r => r.status === 'failed')
      .every(r => r.error === currentError);

    return {
      classification: "BROKEN",
      confidence: sameError ? "high" : "medium",
      reasoning: `Failed ${failCount}/${totalRuns} times with ${sameError ? 'consistent' : 'varying'} errors`,
      recommendation: "FIX — This test is consistently broken. Fix the underlying issue.",
      same_error_pattern: sameError
    };
  }

  // NEW failure pattern: Previously passing, now failing
  if (failRate <= 0.2 && passCount > 0) {
    return {
      classification: "NEW",
      confidence: "high",
      reasoning: `Previously passing (${passCount}/${totalRuns}), now failing`,
      recommendation: "FIX — Recent regression detected. Check latest code changes."
    };
  }

  // Default: Treat as NEW
  return {
    classification: "NEW",
    confidence: "low",
    reasoning: "Insufficient history for confident classification",
    recommendation: "FIX — Investigate the failure"
  };
}
```

### Step 3: Generate Report

```javascript
function generateReport(failures, classifications) {
  const report = {
    timestamp: new Date().toISOString(),
    total_failures: failures.length,
    by_classification: {
      FLAKY: classifications.filter(c => c.classification === 'FLAKY').length,
      BROKEN: classifications.filter(c => c.classification === 'BROKEN').length,
      NEW: classifications.filter(c => c.classification === 'NEW').length
    },
    recommendations: {
      retry: classifications
        .filter(c => c.recommendation.startsWith('RETRY'))
        .map(c => c.scenario_id),
      fix: classifications
        .filter(c => c.recommendation.startsWith('FIX'))
        .map(c => c.scenario_id),
      quarantine: classifications
        .filter(c => c.classification === 'BROKEN' && c.confidence === 'high')
        .map(c => c.scenario_id)
    },
    details: classifications
  };

  return report;
}
```

## Output Format

```json
{
  "timestamp": "2026-02-09T...",
  "total_failures": 5,
  "by_classification": {
    "FLAKY": 2,
    "BROKEN": 1,
    "NEW": 2
  },
  "recommendations": {
    "retry": ["S3", "S7"],
    "fix": ["S1", "S4", "S5"],
    "quarantine": ["S5"]
  },
  "details": [
    {
      "scenario_id": "S3",
      "classification": "FLAKY",
      "confidence": "high",
      "reasoning": "Failed 3/8 times (38% fail rate)",
      "recommendation": "RETRY — This test is flaky. Retry up to 2 times before investigating."
    }
  ]
}
```

## Action Matrix

| Classification | Confidence | Action |
|---------------|------------|--------|
| FLAKY | High | RETRY (2x), then skip if still fails |
| FLAKY | Medium | RETRY (1x), then investigate |
| BROKEN | High | QUARANTINE — move to known-broken list |
| BROKEN | Medium | FIX — investigate root cause |
| NEW | High | FIX — recent regression |
| NEW | Low | FIX — investigate the failure |

## Integration

This skill is invoked by Phase 2 implementation agents when test failures occur.
It can also be invoked manually via `/test-guardian` for ad-hoc analysis.

---

## Changelog

### v5.0.1 (2026-02-09)
- Initial test-guardian skill
- FLAKY/BROKEN/NEW classification
- History-based analysis
- Action matrix with confidence levels
