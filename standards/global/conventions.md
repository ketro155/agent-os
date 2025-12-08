# Project Conventions

## Context

Naming and structural patterns that ensure consistency across the codebase.

## Naming Patterns

### Directory Structure
```
src/
├── components/     # UI components
├── services/       # Business logic services
├── utils/          # Utility functions
├── types/          # Type definitions
├── hooks/          # Custom hooks (React/Vue)
├── stores/         # State management
├── api/            # API layer
└── config/         # Configuration files
```

### File Naming
- **Components**: PascalCase matching export name (`UserProfile.tsx`)
- **Utilities**: kebab-case describing functionality (`format-date.ts`)
- **Tests**: Same name with `.test` or `.spec` suffix (`user-profile.test.ts`)
- **Types**: kebab-case with `.types` suffix (`user.types.ts`)

### Export Patterns
- One primary export per file
- Use named exports for utilities
- Use default exports for components/pages
- Re-export from index files for cleaner imports

## Code Patterns

### Error Handling
```typescript
// Preferred: Explicit error handling
try {
  const result = await riskyOperation();
  return result;
} catch (error) {
  logger.error('Operation failed', { error, context });
  throw new CustomError('Operation failed', { cause: error });
}
```

### Async Operations
- Always use async/await over raw promises
- Handle errors at appropriate boundaries
- Use Promise.all for parallel operations
- Avoid mixing async patterns

### Data Validation
- Validate at system boundaries (API endpoints, user input)
- Trust internal code and framework guarantees
- Use type system for compile-time validation
- Use runtime validation for external data

## Git Conventions

### Branch Naming
- Feature: `feature/[ticket-id]-short-description`
- Bug fix: `fix/[ticket-id]-short-description`
- Hotfix: `hotfix/[ticket-id]-description`

### Commit Messages
- Use imperative mood: "Add feature" not "Added feature"
- First line: 50 chars max summary
- Body: Wrap at 72 chars, explain "why" not "what"
- Reference ticket numbers when applicable

## Documentation

### README Requirements
- Project description and purpose
- Installation instructions
- Development setup
- Key commands and scripts
- Architecture overview for complex projects

### Code Documentation
- Document public APIs
- Explain complex algorithms
- Note non-obvious behaviors
- Keep documentation close to code
