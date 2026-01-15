# E2E Test Fixtures (v4.11.0)

> Reusable setup sequences for E2E test scenarios.
> Fixtures eliminate duplication and ensure consistent test state.

## Overview

E2E fixtures are **reusable setup sequences** that bring the application to a known state before test execution. They're the E2E equivalent of unit test `beforeEach` setup.

```
┌─────────────────────────────────────────────────────────────────────┐
│                        TEST EXECUTION FLOW                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   Scenario: "User can update profile"                               │
│   required_fixtures: ["login"]                                      │
│                                                                     │
│   ┌─────────────────┐      ┌─────────────────┐     ┌────────────┐  │
│   │  Run "login"    │  →   │  Run Scenario   │  →  │  Verify    │  │
│   │  Fixture        │      │  Steps          │     │  Outcome   │  │
│   └─────────────────┘      └─────────────────┘     └────────────┘  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Fixture Structure

### JSON Schema

```json
{
  "fixture_name": {
    "description": "string - Human-readable purpose",
    "steps": [
      {
        "action": "navigate|type|click|verify|wait|select|scroll",
        "target": "string - URL or semantic description",
        "selector": "string - Element selector (for interactive actions)",
        "value": "string - Input value (for type/select)",
        "expected": "string - Expected state (for verify)",
        "duration": "number - Milliseconds (for wait)"
      }
    ],
    "success_indicator": "string - How to verify fixture succeeded",
    "timeout_ms": "number - Max execution time (default: 30000)",
    "on_failure": "abort|skip - Behavior when fixture fails"
  }
}
```

### Action Types

| Action | Required Fields | Optional Fields | Description |
|--------|-----------------|-----------------|-------------|
| `navigate` | `target` | - | Navigate to URL or path |
| `type` | `selector`, `value` | `clear` | Enter text into input |
| `click` | `selector` | `wait_after` | Click an element |
| `verify` | `expected` | `selector` | Verify page state |
| `wait` | `duration` | - | Wait for milliseconds |
| `select` | `selector`, `value` | - | Select dropdown option |
| `scroll` | `selector` | `direction` | Scroll element into view |

## Common Fixtures

### Login Fixture (Template)

```json
{
  "login": {
    "description": "Authenticate as test user",
    "steps": [
      {
        "action": "navigate",
        "target": "/login"
      },
      {
        "action": "type",
        "selector": "[data-testid='email-input']",
        "value": "test@example.com",
        "clear": true
      },
      {
        "action": "type",
        "selector": "[data-testid='password-input']",
        "value": "TestPassword123!"
      },
      {
        "action": "click",
        "selector": "[data-testid='login-button']"
      },
      {
        "action": "wait",
        "duration": 2000
      },
      {
        "action": "verify",
        "expected": "Dashboard visible or user menu present"
      }
    ],
    "success_indicator": "User menu or dashboard element visible",
    "timeout_ms": 15000,
    "on_failure": "abort"
  }
}
```

### Navigation Fixtures

```json
{
  "go_to_settings": {
    "description": "Navigate to user settings page",
    "steps": [
      {
        "action": "click",
        "selector": "[data-testid='user-menu']"
      },
      {
        "action": "click",
        "selector": "[data-testid='settings-link']"
      },
      {
        "action": "verify",
        "expected": "Settings page visible"
      }
    ],
    "success_indicator": "Settings form visible",
    "timeout_ms": 10000,
    "on_failure": "abort"
  },

  "add_item_to_cart": {
    "description": "Add first available product to cart",
    "steps": [
      {
        "action": "navigate",
        "target": "/products"
      },
      {
        "action": "click",
        "selector": "[data-testid='product-card']:first-child [data-testid='add-to-cart']"
      },
      {
        "action": "verify",
        "expected": "Cart badge shows 1"
      }
    ],
    "success_indicator": "Cart count incremented",
    "timeout_ms": 10000,
    "on_failure": "abort"
  }
}
```

### Data Setup Fixture

```json
{
  "seed_test_data": {
    "description": "Ensure test data exists via API",
    "steps": [
      {
        "action": "navigate",
        "target": "/api/test/seed"
      },
      {
        "action": "verify",
        "expected": "JSON response with success: true"
      }
    ],
    "success_indicator": "API returns success",
    "timeout_ms": 30000,
    "on_failure": "abort"
  }
}
```

## Directory Structure

```
.agent-os/test-plans/${SPEC_NAME}/
├── test-plan.json           # Main test plan with scenario list
├── test-plan.md             # Auto-generated markdown
└── fixtures/
    ├── _shared.json         # Common fixtures (login, navigation)
    ├── auth.json            # Authentication-specific fixtures
    ├── checkout.json        # Checkout flow fixtures
    └── admin.json           # Admin panel fixtures
```

## Using Fixtures in Scenarios

### Reference by Name

```json
{
  "id": "S-PROFILE-UPDATE",
  "name": "User can update profile information",
  "entry_criteria": {
    "description": "User is logged in and on profile page",
    "required_fixtures": ["login", "go_to_settings"]
  },
  "steps": [ ... ]
}
```

### Fixture Chaining

Fixtures can require other fixtures:

```json
{
  "checkout_ready": {
    "description": "User logged in with item in cart",
    "depends_on": ["login", "add_item_to_cart"],
    "steps": [
      {
        "action": "navigate",
        "target": "/checkout"
      },
      {
        "action": "verify",
        "expected": "Checkout page with item visible"
      }
    ],
    "success_indicator": "Checkout form visible with cart items"
  }
}
```

**Execution order**: `login` → `add_item_to_cart` → `checkout_ready`

## Selector Priority

When writing fixture selectors, follow this priority order:

| Priority | Selector Type | Example | Stability |
|----------|--------------|---------|-----------|
| 1 | `data-testid` | `[data-testid='login-btn']` | Most stable |
| 2 | `aria-label` | `[aria-label='Submit form']` | Stable |
| 3 | Semantic | `button[type='submit']` | Moderate |
| 4 | CSS class | `.btn-primary` | Least stable |

**Rule**: Always prefer `data-testid` for fixture reliability.

## Best Practices

### DO

- **Keep fixtures atomic** - Each fixture should do ONE thing
- **Use descriptive names** - `login_as_admin` not `setup1`
- **Include success indicators** - How to know the fixture worked
- **Set appropriate timeouts** - Login needs more time than navigation
- **Use data-testid selectors** - Most stable across refactors

### DON'T

- **Don't chain too deeply** - Max 3 fixture dependencies
- **Don't include test assertions** - Fixtures setup, scenarios verify
- **Don't hardcode sensitive data** - Use environment variables
- **Don't modify production data** - Fixtures should be safe to run repeatedly

## Fixture Failure Handling

| `on_failure` | Behavior | When to Use |
|--------------|----------|-------------|
| `abort` | Stop all tests | Critical fixtures (login, data setup) |
| `skip` | Skip dependent scenarios | Optional fixtures (feature flags) |

```json
{
  "login": {
    "on_failure": "abort",
    "reason": "Cannot test authenticated features without login"
  },
  "enable_beta_feature": {
    "on_failure": "skip",
    "reason": "Beta features may not be available"
  }
}
```

## Debugging Fixtures

### Enable Verbose Logging

```bash
# Run fixtures with debug output
E2E_DEBUG=true npm run test:e2e -- --fixture-only
```

### Common Issues

| Issue | Symptom | Solution |
|-------|---------|----------|
| Selector not found | Timeout waiting for element | Verify data-testid exists |
| Flaky timing | Sometimes passes, sometimes fails | Add explicit waits |
| State pollution | Tests affect each other | Reset state in fixture |
| Auth expired | Fixture passes but scenario fails | Extend session timeout |

## Complete Example

### `fixtures/_shared.json`

```json
{
  "login": {
    "description": "Authenticate as standard test user",
    "steps": [
      { "action": "navigate", "target": "/login" },
      { "action": "type", "selector": "[data-testid='email-input']", "value": "${TEST_USER_EMAIL}", "clear": true },
      { "action": "type", "selector": "[data-testid='password-input']", "value": "${TEST_USER_PASSWORD}" },
      { "action": "click", "selector": "[data-testid='login-button']" },
      { "action": "wait", "duration": 2000 },
      { "action": "verify", "expected": "Dashboard or user menu visible" }
    ],
    "success_indicator": "[data-testid='user-menu'] visible",
    "timeout_ms": 15000,
    "on_failure": "abort"
  },

  "logout": {
    "description": "Sign out current user",
    "steps": [
      { "action": "click", "selector": "[data-testid='user-menu']" },
      { "action": "click", "selector": "[data-testid='logout-button']" },
      { "action": "verify", "expected": "Login page visible" }
    ],
    "success_indicator": "[data-testid='login-form'] visible",
    "timeout_ms": 10000,
    "on_failure": "skip"
  }
}
```

---

## Changelog

### v4.11.0 (2026-01-15)
- Initial fixture format documentation
- Action type reference
- Selector priority guidance
- Failure handling options
- Common fixture templates
