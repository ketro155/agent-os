# Error Handling Standards

## Context

Guidelines for consistent error handling, logging, and recovery across the application.

## Error Handling Principles

### Fail Fast
- Validate inputs early
- Throw errors as soon as problems are detected
- Don't silently swallow errors

### Explicit Over Implicit
- Always handle known error cases explicitly
- Don't rely on catch-all handlers for expected errors
- Document error conditions in function signatures

### Informative Errors
- Include context in error messages
- Provide actionable information
- Log enough detail for debugging

## Error Types

### Operational Errors
Expected errors from normal operation:
- Network failures
- Invalid user input
- Resource not found
- Permission denied

**Handling:** Graceful recovery, user-friendly messages

### Programmer Errors
Bugs in the code:
- Null reference errors
- Type errors
- Logic errors

**Handling:** Log, alert, potentially restart process

## Error Handling Patterns

### Try-Catch Blocks
```typescript
async function fetchUser(id: string): Promise<User> {
  try {
    const response = await api.get(`/users/${id}`);
    return response.data;
  } catch (error) {
    if (error instanceof NotFoundError) {
      throw new UserNotFoundError(id);
    }
    logger.error('Failed to fetch user', { userId: id, error });
    throw new ServiceError('Unable to fetch user', { cause: error });
  }
}
```

### Error Boundaries (UI)
- Wrap major sections with error boundaries
- Provide fallback UI for crashed components
- Log errors for debugging
- Allow recovery when possible

### Result Types (Alternative)
```typescript
type Result<T, E = Error> =
  | { success: true; data: T }
  | { success: false; error: E };

function parseConfig(json: string): Result<Config, ParseError> {
  try {
    return { success: true, data: JSON.parse(json) };
  } catch (e) {
    return { success: false, error: new ParseError(e.message) };
  }
}
```

## Logging Standards

### Log Levels
- **ERROR**: System failures, requires immediate attention
- **WARN**: Potential issues, recoverable problems
- **INFO**: Important events, state changes
- **DEBUG**: Detailed diagnostic information

### Structured Logging
```typescript
logger.error('Payment failed', {
  userId: user.id,
  amount: payment.amount,
  error: error.message,
  stack: error.stack,
  requestId: context.requestId
});
```

### What to Log
- All errors with full context
- Security events (login, permission changes)
- Business events (orders, transactions)
- Performance anomalies

### What NOT to Log
- Sensitive data (passwords, tokens, PII)
- Excessive debug info in production
- Normal successful operations (unless auditing)

## Recovery Strategies

### Retry Logic
```typescript
async function withRetry<T>(
  fn: () => Promise<T>,
  maxRetries: number = 3,
  delay: number = 1000
): Promise<T> {
  for (let i = 0; i < maxRetries; i++) {
    try {
      return await fn();
    } catch (error) {
      if (i === maxRetries - 1) throw error;
      await sleep(delay * Math.pow(2, i)); // Exponential backoff
    }
  }
  throw new Error('Unreachable');
}
```

### Circuit Breaker
- Track failure rates
- Open circuit after threshold
- Fail fast while open
- Periodically test recovery

### Graceful Degradation
- Provide reduced functionality when services fail
- Cache fallbacks for unavailable data
- Queue operations for later retry
