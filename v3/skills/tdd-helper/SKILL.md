---
name: tdd-helper
description: Guides implementation through the Test-Driven Development RED-GREEN-REFACTOR cycle with proper test structure, naming conventions, and anti-pattern avoidance. Use when starting new feature implementation, fixing bugs test-first, or refactoring existing code. Use when user says "help with TDD", "red green refactor", "write tests first", or "test-driven development guide". NOT for classifying test failures (use /test-guardian).
version: 2.0.0
metadata:
  author: Agent OS
  category: testing
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

## Test Runner Auto-Detection

Detect the project's test runner before running commands:

| Signal | Runner | Command |
|--------|--------|---------|
| `vitest.config.*` or `vitest` in package.json | Vitest | `npx vitest run` |
| `jest.config.*` or `jest` in package.json | Jest | `npx jest` |
| `.mocharc.*` or `mocha` in package.json | Mocha | `npx mocha` |
| `playwright.config.*` | Playwright | `npx playwright test` |
| None detected | Fallback | `npm test` |

See `references/tdd-implementation-guide.md` for full runner detection logic and configuration patterns.

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

### Commit Conventions by TDD Phase

| TDD Phase | Commit Prefix | Example |
|-----------|---------------|---------|
| RED (failing test) | `test:` | `test: add validation tests for email input` |
| GREEN (make pass) | `feat:` or `fix:` | `feat: implement email validation` |
| REFACTOR (improve) | `refactor:` | `refactor: extract email regex to constant` |

### Subtask Execution Awareness

- **Sequential** (≤4 subtasks): Execute one at a time, commit after each
- **Batched** (>4 subtasks): Group related RED-GREEN pairs, commit per pair
- **Parallel groups**: Each teammate handles independent task; coordinate via SendMessage

### Context Pressure Response

When context offloading exceeds ~100KB (check via `/context-stats`), invoke `/context-summary` to compress before continuing TDD cycles. This prevents context loss during long implementation sessions.

### Cross-References

- Full TDD workflow rules: `rules/tdd-workflow.md`
- Runner detection and test patterns: `references/tdd-implementation-guide.md`
- Test failure classification: `/test-guardian`

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
