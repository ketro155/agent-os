# Error Handling Standards (v4.9.0)

> Standardized error handling across all Agent OS agents. Provides consistent error classification, reporting, and recovery patterns.

## Error Tier Classification

All errors MUST be classified into one of three tiers:

```typescript
enum ErrorTier {
  TRANSIENT = "TRANSIENT",    // Temporary, retry may succeed
  RECOVERABLE = "RECOVERABLE", // Requires intervention but not fatal
  FATAL = "FATAL"             // Cannot proceed, abort operation
}
```

### Tier Definitions

| Tier | Retry? | Continue? | User Action | Examples |
|------|--------|-----------|-------------|----------|
| TRANSIENT | Yes (3x) | After retry | Wait/retry | Network timeout, rate limit, file lock |
| RECOVERABLE | No | Partial | Intervene | Missing file, config error, test failure |
| FATAL | No | No | Abort | Auth failure, corrupt data, schema mismatch |

## AgentError Interface

All agent errors must conform to this interface:

```typescript
interface AgentError {
  // Core fields (required)
  code: string;           // Error code from ERROR_CATALOG (e.g., "E001")
  tier: ErrorTier;        // Classification tier
  message: string;        // Human-readable message
  
  // Context fields (required for debugging)
  agent: string;          // Agent name (e.g., "phase2-implementation")
  operation: string;      // What operation failed (e.g., "test_execution")
  timestamp: string;      // ISO 8601 timestamp
  
  // Recovery fields (optional)
  retryable: boolean;     // Whether retry makes sense
  retry_count?: number;   // Current retry attempt (if applicable)
  max_retries?: number;   // Maximum retry attempts allowed
  
  // Diagnostic fields (optional)
  details?: Record<string, unknown>;  // Additional context
  stack?: string;         // Stack trace if available
  cause?: AgentError;     // Nested error for error chains
}
```

## ERROR_CATALOG

Centralized error definitions for consistency:

```typescript
const ERROR_CATALOG = {
  // ═══════════════════════════════════════════════════════════════════
  // TRANSIENT ERRORS (E0xx) - Retry may succeed
  // ═══════════════════════════════════════════════════════════════════
  
  E001: {
    tier: ErrorTier.TRANSIENT,
    code: "E001",
    name: "NETWORK_TIMEOUT",
    message: "Network request timed out",
    retryable: true,
    max_retries: 3,
    retry_delay_ms: 1000
  },
  E002: {
    tier: ErrorTier.TRANSIENT,
    code: "E002",
    name: "RATE_LIMITED",
    message: "API rate limit exceeded",
    retryable: true,
    max_retries: 3,
    retry_delay_ms: 5000
  },
  E003: {
    tier: ErrorTier.TRANSIENT,
    code: "E003",
    name: "FILE_LOCKED",
    message: "File is locked by another process",
    retryable: true,
    max_retries: 5,
    retry_delay_ms: 500
  },
  E004: {
    tier: ErrorTier.TRANSIENT,
    code: "E004",
    name: "GIT_CONFLICT",
    message: "Git operation encountered a temporary conflict",
    retryable: true,
    max_retries: 2,
    retry_delay_ms: 2000
  },
  E005: {
    tier: ErrorTier.TRANSIENT,
    code: "E005",
    name: "SUBPROCESS_TIMEOUT",
    message: "Subprocess execution timed out",
    retryable: true,
    max_retries: 2,
    retry_delay_ms: 3000
  },
  
  // ═══════════════════════════════════════════════════════════════════
  // RECOVERABLE ERRORS (E1xx) - Intervention required but not fatal
  // ═══════════════════════════════════════════════════════════════════
  
  E100: {
    tier: ErrorTier.RECOVERABLE,
    code: "E100",
    name: "FILE_NOT_FOUND",
    message: "Required file not found",
    retryable: false,
    recovery: "Check path exists or create missing file"
  },
  E101: {
    tier: ErrorTier.RECOVERABLE,
    code: "E101",
    name: "TEST_FAILURE",
    message: "Test execution failed",
    retryable: false,
    recovery: "Fix failing tests before proceeding"
  },
  E102: {
    tier: ErrorTier.RECOVERABLE,
    code: "E102",
    name: "BUILD_FAILURE",
    message: "Build process failed",
    retryable: false,
    recovery: "Fix build errors before proceeding"
  },
  E103: {
    tier: ErrorTier.RECOVERABLE,
    code: "E103",
    name: "VALIDATION_ERROR",
    message: "Input validation failed",
    retryable: false,
    recovery: "Fix validation errors in input"
  },
  E104: {
    tier: ErrorTier.RECOVERABLE,
    code: "E104",
    name: "MISSING_DEPENDENCY",
    message: "Required dependency not available",
    retryable: false,
    recovery: "Install missing dependency"
  },
  E105: {
    tier: ErrorTier.RECOVERABLE,
    code: "E105",
    name: "ARTIFACT_NOT_FOUND",
    message: "Predecessor artifact not found",
    retryable: false,
    recovery: "Complete predecessor task first"
  },
  E106: {
    tier: ErrorTier.RECOVERABLE,
    code: "E106",
    name: "CONFIG_ERROR",
    message: "Configuration is invalid or missing",
    retryable: false,
    recovery: "Fix configuration file"
  },
  E107: {
    tier: ErrorTier.RECOVERABLE,
    code: "E107",
    name: "MERGE_CONFLICT",
    message: "Git merge conflict requires resolution",
    retryable: false,
    recovery: "Resolve merge conflicts manually"
  },
  E108: {
    tier: ErrorTier.RECOVERABLE,
    code: "E108",
    name: "PR_REVIEW_PENDING",
    message: "PR requires review before proceeding",
    retryable: false,
    recovery: "Wait for PR review or request review"
  },
  E109: {
    tier: ErrorTier.RECOVERABLE,
    code: "E109",
    name: "TASK_BLOCKED",
    message: "Task blocked by unresolved dependency",
    retryable: false,
    recovery: "Complete blocking task first"
  },
  
  // ═══════════════════════════════════════════════════════════════════
  // FATAL ERRORS (E2xx) - Cannot proceed, abort operation
  // ═══════════════════════════════════════════════════════════════════
  
  E200: {
    tier: ErrorTier.FATAL,
    code: "E200",
    name: "AUTH_FAILURE",
    message: "Authentication failed",
    retryable: false,
    abort: true
  },
  E201: {
    tier: ErrorTier.FATAL,
    code: "E201",
    name: "PROTECTED_BRANCH",
    message: "Cannot modify protected branch",
    retryable: false,
    abort: true
  },
  E202: {
    tier: ErrorTier.FATAL,
    code: "E202",
    name: "SCHEMA_MISMATCH",
    message: "Data schema incompatible",
    retryable: false,
    abort: true
  },
  E203: {
    tier: ErrorTier.FATAL,
    code: "E203",
    name: "CORRUPT_DATA",
    message: "Data corruption detected",
    retryable: false,
    abort: true
  },
  E204: {
    tier: ErrorTier.FATAL,
    code: "E204",
    name: "RESOURCE_EXHAUSTED",
    message: "System resources exhausted",
    retryable: false,
    abort: true
  },
  E205: {
    tier: ErrorTier.FATAL,
    code: "E205",
    name: "PERMISSION_DENIED",
    message: "Operation not permitted",
    retryable: false,
    abort: true
  },
  E206: {
    tier: ErrorTier.FATAL,
    code: "E206",
    name: "INVALID_STATE",
    message: "System in invalid state",
    retryable: false,
    abort: true
  }
};
```

## handleError Function

Standardized error handling across all agents:

```javascript
/**
 * Handle errors consistently across agents
 * @param {Object} params - Error parameters
 * @param {string} params.code - Error code from ERROR_CATALOG
 * @param {string} params.agent - Name of the agent handling the error
 * @param {string} params.operation - Operation that failed
 * @param {Object} params.details - Additional error context
 * @param {Error} params.cause - Original error if wrapping
 * @returns {AgentError} Structured error object
 */
function handleError({ code, agent, operation, details = {}, cause = null }) {
  const catalogEntry = ERROR_CATALOG[code] || ERROR_CATALOG.E206;
  
  const error = {
    code: catalogEntry.code,
    tier: catalogEntry.tier,
    message: catalogEntry.message,
    agent: agent,
    operation: operation,
    timestamp: new Date().toISOString(),
    retryable: catalogEntry.retryable,
    max_retries: catalogEntry.max_retries,
    details: details,
    ...(cause && { cause: cause })
  };
  
  // Log based on tier
  switch (catalogEntry.tier) {
    case ErrorTier.TRANSIENT:
      console.log(`[${agent}] TRANSIENT: ${catalogEntry.name} - ${operation}`);
      break;
    case ErrorTier.RECOVERABLE:
      console.warn(`[${agent}] RECOVERABLE: ${catalogEntry.name} - ${operation}`);
      if (catalogEntry.recovery) {
        console.warn(`  Recovery: ${catalogEntry.recovery}`);
      }
      break;
    case ErrorTier.FATAL:
      console.error(`[${agent}] FATAL: ${catalogEntry.name} - ${operation}`);
      console.error(`  Aborting operation.`);
      break;
  }
  
  return error;
}
```

## Retry Protocol

For TRANSIENT errors, implement retry with exponential backoff:

```javascript
async function withRetry(operation, options = {}) {
  const {
    agent = 'unknown',
    operationName = 'operation',
    maxRetries = 3,
    baseDelayMs = 1000,
    backoffFactor = 2
  } = options;
  
  let lastError = null;
  
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await operation();
    } catch (err) {
      lastError = err;
      const errorCode = err.code || 'E206';
      const catalogEntry = ERROR_CATALOG[errorCode];
      
      if (!catalogEntry?.retryable || attempt === maxRetries) {
        throw handleError({
          code: errorCode,
          agent: agent,
          operation: operationName,
          details: { attempts: attempt + 1, last_error: err.message }
        });
      }
      
      const delay = baseDelayMs * Math.pow(backoffFactor, attempt);
      console.log(`[${agent}] Retry ${attempt + 1}/${maxRetries} in ${delay}ms`);
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }
  throw lastError;
}
```

## Agent Error Responses

### Blocked Response Format

```json
{
  "status": "blocked",
  "task_id": "1.2",
  "error": {
    "code": "E105",
    "tier": "RECOVERABLE",
    "message": "Predecessor artifact not found",
    "agent": "phase2-implementation",
    "operation": "artifact_verification",
    "timestamp": "2026-01-10T01:00:00.000Z",
    "details": { "missing_export": "validateToken" }
  },
  "blocker": "Missing predecessor export: validateToken",
  "recovery": "Complete predecessor task first"
}
```

### Failed Response Format

```json
{
  "status": "fail",
  "task_id": "1.2",
  "error": {
    "code": "E200",
    "tier": "FATAL",
    "message": "Authentication failed",
    "agent": "git-workflow",
    "operation": "push_to_remote",
    "timestamp": "2026-01-10T01:00:00.000Z"
  },
  "notes": "GitHub authentication token expired"
}
```

## Error Mapping Utilities

```javascript
function mapErrorToCode(err) {
  const message = err.message?.toLowerCase() || '';
  
  // Network errors
  if (message.includes('timeout') || message.includes('etimedout')) return 'E001';
  if (message.includes('rate limit') || message.includes('429')) return 'E002';
  
  // File system errors
  if (message.includes('enoent') || message.includes('not found')) return 'E100';
  if (message.includes('eacces') || message.includes('permission')) return 'E205';
  if (message.includes('ebusy') || message.includes('locked')) return 'E003';
  
  // Git errors
  if (message.includes('protected branch')) return 'E201';
  if (message.includes('conflict')) return 'E107';
  if (message.includes('authentication')) return 'E200';
  
  // Test/Build errors
  if (message.includes('test') && message.includes('fail')) return 'E101';
  if (message.includes('build') && message.includes('fail')) return 'E102';
  
  return 'E206'; // Default: INVALID_STATE
}
```

## Usage in Agents

All agents should import and use standardized error handling:

```markdown
@import rules/error-handling.md

## Error Handling

This agent uses the standardized error handling from rules/error-handling.md:
- Use handleError() for all error creation
- Use withRetry() for transient operations
- Map errors using mapErrorToCode()
```

---

## Changelog

### v4.9.0 (2026-01-10)
- Initial standardized error handling system
- Three-tier error classification (TRANSIENT, RECOVERABLE, FATAL)
- ERROR_CATALOG with 20+ predefined error codes
- handleError function for consistent error creation
- withRetry utility for transient error handling
- Error mapping utilities
