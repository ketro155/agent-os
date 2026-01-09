---
name: tdd-helper
description: When implementing features using Test-Driven Development. Guides you through RED-GREEN-REFACTOR cycle with proper test structure.
version: 1.0.0
---

# TDD Helper Skill

Guide implementation through proper Test-Driven Development cycle: RED → GREEN → REFACTOR.

## When to Use

- Starting any new feature implementation
- Fixing bugs (write failing test first)
- Refactoring existing code (ensure tests exist first)
- When `/execute-tasks` or phase2-implementation runs

## The TDD Cycle

### Phase 1: RED (Write Failing Test)

**Goal**: Write a test that fails for the right reason

```typescript
// Example: Testing a new validation function
describe('validateEmail', () => {
  it('should return true for valid email addresses', () => {
    expect(validateEmail('user@example.com')).toBe(true);
  });

  it('should return false for invalid email addresses', () => {
    expect(validateEmail('not-an-email')).toBe(false);
  });

  it('should return false for empty string', () => {
    expect(validateEmail('')).toBe(false);
  });
});
```

**Checklist**:
- [ ] Test describes expected behavior clearly
- [ ] Test covers the happy path
- [ ] Test covers edge cases
- [ ] Test FAILS when run (function doesn't exist yet)
- [ ] Failure message is clear about what's missing

**Run the test**:
```bash
npm test -- --grep "validateEmail"
```

Expected: RED (failing)

### Phase 2: GREEN (Make Test Pass)

**Goal**: Write minimal code to make the test pass

```typescript
// Minimal implementation - just enough to pass
export function validateEmail(email: string): boolean {
  if (!email) return false;
  return email.includes('@') && email.includes('.');
}
```

**Rules**:
1. Write ONLY enough code to pass the test
2. Don't optimize yet
3. Don't add features not tested
4. Copy-paste is OK temporarily

**Run the test**:
```bash
npm test -- --grep "validateEmail"
```

Expected: GREEN (passing)

### Phase 3: REFACTOR (Improve Code)

**Goal**: Improve code quality while keeping tests green

```typescript
// Refactored with proper regex
const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function validateEmail(email: string): boolean {
  if (!email) return false;
  return EMAIL_REGEX.test(email);
}
```

**Checklist**:
- [ ] Remove duplication
- [ ] Improve naming
- [ ] Extract constants
- [ ] Add types if missing
- [ ] Tests still pass

**Run the test**:
```bash
npm test -- --grep "validateEmail"
```

Expected: GREEN (still passing)

## Test Structure Guidelines

### Naming Convention

```typescript
describe('[Unit/Feature being tested]', () => {
  describe('[method or scenario]', () => {
    it('should [expected behavior] when [condition]', () => {
      // Arrange - Set up test data
      // Act - Call the function
      // Assert - Check results
    });
  });
});
```

### Arrange-Act-Assert Pattern

```typescript
it('should calculate total with tax', () => {
  // Arrange
  const items = [{ price: 100 }, { price: 50 }];
  const taxRate = 0.1;

  // Act
  const result = calculateTotal(items, taxRate);

  // Assert
  expect(result).toBe(165);
});
```

## Common Test Scenarios

| Scenario | Test For |
|----------|----------|
| Happy path | Normal, expected input |
| Empty input | `null`, `undefined`, `''`, `[]` |
| Boundary values | Min/max, zero, negative |
| Invalid input | Wrong types, malformed data |
| Error cases | Should throw or return error |
| Async operations | Promises, callbacks, timeouts |

## Integration with Agent OS

### Before Implementation

1. Read task requirements
2. Identify test scenarios
3. Write test file first
4. Commit: `test: add tests for [feature]`

### During Implementation

1. Run tests frequently
2. One test at a time
3. Commit when GREEN: `feat: implement [feature]`

### After Implementation

1. Run full test suite
2. Check coverage
3. Refactor if needed
4. Commit: `refactor: improve [feature]`

## Anti-Patterns to Avoid

1. **Writing tests after code** - Defeats the purpose
2. **Testing implementation details** - Test behavior, not internals
3. **Skipping edge cases** - They will bite you later
4. **Large test cases** - One assertion per test ideally
5. **Ignoring failing tests** - Fix or delete, never ignore

## Quick Reference Commands

```bash
# Run all tests
npm test

# Run specific test file
npm test -- path/to/test.ts

# Run tests matching pattern
npm test -- --grep "validateEmail"

# Run with coverage
npm test -- --coverage

# Watch mode (re-run on changes)
npm test -- --watch
```
