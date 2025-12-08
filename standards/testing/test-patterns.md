# Testing Standards

## Context

Testing patterns, conventions, and best practices for reliable test suites.

## Test Organization

### File Structure
```
tests/
├── unit/                 # Unit tests
│   ├── services/
│   └── utils/
├── integration/          # Integration tests
│   ├── api/
│   └── database/
├── e2e/                  # End-to-end tests
│   └── flows/
├── fixtures/             # Test data
└── helpers/              # Test utilities
```

### Naming Conventions
```
user-service.test.ts      # Unit test
user-api.integration.ts   # Integration test
checkout-flow.e2e.ts      # E2E test
```

## Test Structure

### AAA Pattern
```typescript
describe('UserService', () => {
  describe('createUser', () => {
    it('should create a user with valid data', async () => {
      // Arrange
      const userData = { name: 'John', email: 'john@example.com' };
      const mockRepo = { save: jest.fn().mockResolvedValue({ id: '1', ...userData }) };
      const service = new UserService(mockRepo);

      // Act
      const result = await service.createUser(userData);

      // Assert
      expect(result.id).toBe('1');
      expect(mockRepo.save).toHaveBeenCalledWith(userData);
    });
  });
});
```

### Descriptive Test Names
```typescript
// Good - describes behavior
it('should throw ValidationError when email is invalid')
it('should return empty array when no users match filter')
it('should retry 3 times before failing')

// Bad - vague
it('works correctly')
it('handles error')
it('test createUser')
```

## Unit Testing

### What to Test
- Business logic functions
- Data transformations
- Validation logic
- Edge cases

### What NOT to Unit Test
- Framework code
- Simple getters/setters
- Third-party libraries
- Database queries (use integration tests)

### Mocking
```typescript
// Mock dependencies, not the system under test
const mockEmailService = {
  send: jest.fn().mockResolvedValue(true)
};

const service = new NotificationService(mockEmailService);

await service.notifyUser(user);

expect(mockEmailService.send).toHaveBeenCalledWith({
  to: user.email,
  subject: expect.stringContaining('Welcome')
});
```

## Integration Testing

### API Tests
```typescript
describe('POST /api/users', () => {
  it('should create user and return 201', async () => {
    const response = await request(app)
      .post('/api/users')
      .send({ name: 'John', email: 'john@example.com' })
      .expect(201);

    expect(response.body.data).toMatchObject({
      name: 'John',
      email: 'john@example.com'
    });
  });

  it('should return 400 for invalid email', async () => {
    const response = await request(app)
      .post('/api/users')
      .send({ name: 'John', email: 'invalid' })
      .expect(400);

    expect(response.body.error.code).toBe('VALIDATION_ERROR');
  });
});
```

### Database Tests
```typescript
describe('UserRepository', () => {
  beforeEach(async () => {
    await db.migrate.latest();
    await db.seed.run();
  });

  afterEach(async () => {
    await db.migrate.rollback();
  });

  it('should find user by email', async () => {
    const user = await repo.findByEmail('existing@example.com');
    expect(user).not.toBeNull();
    expect(user.name).toBe('Existing User');
  });
});
```

## E2E Testing

### User Flows
```typescript
describe('Checkout Flow', () => {
  it('should complete purchase successfully', async () => {
    // Login
    await page.goto('/login');
    await page.fill('[name="email"]', 'user@example.com');
    await page.fill('[name="password"]', 'password');
    await page.click('button[type="submit"]');

    // Add to cart
    await page.goto('/products/1');
    await page.click('button:has-text("Add to Cart")');

    // Checkout
    await page.goto('/cart');
    await page.click('button:has-text("Checkout")');
    await page.fill('[name="card"]', '4242424242424242');
    await page.click('button:has-text("Pay")');

    // Verify
    await expect(page).toHaveURL('/order/confirmation');
    await expect(page.locator('.order-status')).toHaveText('Confirmed');
  });
});
```

## Test Data

### Factories
```typescript
// factories/user.ts
export const createUser = (overrides = {}) => ({
  id: faker.string.uuid(),
  name: faker.person.fullName(),
  email: faker.internet.email(),
  createdAt: new Date(),
  ...overrides
});

// Usage
const user = createUser({ role: 'admin' });
```

### Fixtures
```typescript
// fixtures/users.ts
export const adminUser = {
  id: '1',
  name: 'Admin User',
  email: 'admin@example.com',
  role: 'admin'
};

export const regularUser = {
  id: '2',
  name: 'Regular User',
  email: 'user@example.com',
  role: 'user'
};
```

## Coverage Guidelines

### Targets
- Unit tests: 80%+ coverage
- Critical paths: 100% coverage
- New code: Must have tests

### What Coverage Doesn't Tell You
- Quality of assertions
- Edge case coverage
- Real-world scenarios
- Performance issues

## Best Practices

### Independence
- Tests should not depend on each other
- Clean up after each test
- Use fresh data for each test

### Speed
- Unit tests: < 10ms each
- Integration tests: < 1s each
- E2E tests: < 30s each

### Reliability
- No flaky tests (fix or remove)
- Deterministic results
- No external dependencies in unit tests
- Use timeouts appropriately

### Maintainability
- DRY test setup with helpers
- Clear failure messages
- Update tests when requirements change
