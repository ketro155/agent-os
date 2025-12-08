# Input Validation Standards

## Context

Guidelines for validating data at system boundaries to ensure data integrity and security.

## Validation Principles

### Validate at Boundaries
- API endpoints receiving external data
- User input from forms
- Data from external services
- File uploads and imports

### Trust Internal Code
- Don't re-validate data that's already been validated
- Trust type system guarantees
- Trust framework-provided validations

### Fail Early
- Validate before processing
- Return all validation errors at once (not one at a time)
- Provide clear, actionable error messages

## Validation Types

### Type Validation
```typescript
// Use TypeScript/schema validators
const userSchema = z.object({
  name: z.string().min(1).max(100),
  email: z.string().email(),
  age: z.number().int().min(0).max(150)
});

type User = z.infer<typeof userSchema>;
```

### Business Rule Validation
```typescript
function validateOrder(order: Order): ValidationResult {
  const errors: string[] = [];

  if (order.items.length === 0) {
    errors.push('Order must contain at least one item');
  }

  if (order.total < 0) {
    errors.push('Order total cannot be negative');
  }

  return errors.length > 0
    ? { valid: false, errors }
    : { valid: true };
}
```

### Security Validation
- Sanitize HTML to prevent XSS
- Parameterize queries to prevent SQL injection
- Validate file types and sizes for uploads
- Rate limit to prevent abuse

## Validation Patterns

### Schema-Based Validation
```typescript
// Define schema once, use everywhere
const createUserSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8).regex(/[A-Z]/).regex(/[0-9]/),
  name: z.string().min(2).max(50)
});

// In API handler
app.post('/users', async (req, res) => {
  const result = createUserSchema.safeParse(req.body);
  if (!result.success) {
    return res.status(400).json({ errors: result.error.flatten() });
  }
  // result.data is typed and validated
  await createUser(result.data);
});
```

### Form Validation (Frontend)
```typescript
// Validate on submit, show inline errors
function handleSubmit(data: FormData) {
  const errors = validateForm(data);
  if (Object.keys(errors).length > 0) {
    setFieldErrors(errors);
    return;
  }
  submitForm(data);
}
```

### API Response Validation
```typescript
// Validate external API responses
const apiResponseSchema = z.object({
  data: z.array(itemSchema),
  meta: z.object({
    total: z.number(),
    page: z.number()
  })
});

async function fetchItems(): Promise<ItemsResponse> {
  const response = await api.get('/items');
  return apiResponseSchema.parse(response.data);
}
```

## Error Messages

### User-Facing Messages
- Clear and helpful
- Non-technical language
- Suggest how to fix
- Localized if needed

```typescript
// Good
"Email address is invalid. Please enter a valid email like name@example.com"

// Bad
"Validation error: email field failed regex match"
```

### Developer Messages
- Include field name and value (sanitized)
- Reference validation rule that failed
- Include context for debugging

## Common Validations

### Email
```typescript
z.string().email()
// or
/^[^\s@]+@[^\s@]+\.[^\s@]+$/
```

### Password
```typescript
z.string()
  .min(8, 'Password must be at least 8 characters')
  .regex(/[A-Z]/, 'Password must contain uppercase letter')
  .regex(/[a-z]/, 'Password must contain lowercase letter')
  .regex(/[0-9]/, 'Password must contain number')
```

### URL
```typescript
z.string().url()
// or for more control
z.string().refine(url => {
  try {
    new URL(url);
    return true;
  } catch {
    return false;
  }
})
```

### Date Range
```typescript
z.object({
  startDate: z.date(),
  endDate: z.date()
}).refine(
  data => data.endDate > data.startDate,
  { message: 'End date must be after start date' }
)
```
