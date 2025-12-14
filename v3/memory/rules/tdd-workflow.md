---
paths:
  - "src/**"
  - "lib/**"
  - "app/**"
  - "tests/**"
---

# TDD Workflow Rules

## Core Principle

**NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST**

This rule is non-negotiable. Every new function, method, or feature must follow:

## RED-GREEN-REFACTOR Cycle

### 1. RED Phase
```
1. Write a single test for desired behavior
2. Run test - it MUST FAIL
3. Verify failure is for the RIGHT reason:
   ✓ Fails because code doesn't exist
   ✓ Fails because feature not implemented
   ✗ Passes immediately (test is wrong)
   ✗ Fails due to syntax error (fix test first)
```

**If test passes immediately**: Delete it and write one that fails.

### 2. GREEN Phase
```
1. Write MINIMUM code to make test pass
2. No extra functionality
3. No "improvements" while implementing
4. Run test - it MUST PASS
5. Run related tests - all must pass
```

### 3. REFACTOR Phase
```
1. Only after tests are green
2. Remove duplication
3. Improve naming
4. Extract helpers if needed
5. Run tests after EACH change
6. Any red = revert refactor change
```

## Test Requirements

### Naming Convention
```
describe('[ComponentName]', () => {
  describe('[methodName]', () => {
    it('should [expected behavior] when [condition]', () => {
      // ...
    });
  });
});
```

### Test Structure (AAA Pattern)
```javascript
it('should return user when valid ID provided', () => {
  // Arrange
  const userId = 'user-123';
  const expectedUser = { id: userId, name: 'Test' };

  // Act
  const result = getUserById(userId);

  // Assert
  expect(result).toEqual(expectedUser);
});
```

## Common Rationalizations (All Invalid)

| Excuse | Reality |
|--------|---------|
| "I'll write tests after" | Tests after don't catch bugs |
| "This is too simple for TDD" | Simple code still needs verification |
| "TDD takes too long" | Debugging untested code takes longer |
| "I'm confident it works" | Confidence is not evidence |

## Integration with Agent OS

When implementing tasks:

1. **Before any code**: Write failing test
2. **Show test failure**: Include test output in response
3. **Minimal implementation**: Only what's needed to pass
4. **Refactor only when green**: Never with failing tests
5. **Commit after green**: Each passing test is a checkpoint
