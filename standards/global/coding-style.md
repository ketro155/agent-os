# Coding Style Standards

## Context

Global code formatting and style rules that apply across all languages and frameworks.

<conditional-block context-check="general-formatting">
IF this General Formatting section already read in current context:
  SKIP: Re-reading this section
  NOTE: "Using General Formatting rules already in context"
ELSE:
  READ: The following formatting rules

## General Formatting

### Indentation
- Use 2 spaces for indentation (never tabs)
- Maintain consistent indentation throughout files
- Align nested structures for readability

### Line Length
- Maximum 100 characters per line
- Break long lines at logical points
- Prefer readability over strict limits

### Whitespace
- One blank line between logical sections
- No trailing whitespace
- Single newline at end of file

### Naming Conventions
- **Variables/Functions**: Use snake_case or camelCase consistently per project
- **Classes/Types**: Use PascalCase (e.g., `UserProfile`, `PaymentProcessor`)
- **Constants**: Use UPPER_SNAKE_CASE (e.g., `MAX_RETRY_COUNT`)
- **Files**: Use kebab-case for file names (e.g., `user-profile.ts`)

### String Formatting
- Use single quotes for strings: `'Hello World'`
- Use double quotes when string contains single quotes
- Use template literals for interpolation and multi-line strings
</conditional-block>

## Code Comments

### When to Comment
- Add comments for non-obvious business logic
- Document complex algorithms or calculations
- Explain the "why" behind implementation choices
- Mark TODO items with context

### Comment Guidelines
- Never remove existing comments unless removing associated code
- Update comments when modifying code
- Keep comments concise and relevant
- Avoid obvious comments (e.g., `// increment counter`)

### Documentation Comments
- Use JSDoc/docstrings for public APIs
- Include parameter descriptions for complex functions
- Document return values and exceptions

## Code Organization

### File Structure
- Keep files focused on single responsibility
- Group related functionality together
- Use consistent import ordering:
  1. Standard library imports
  2. Third-party imports
  3. Local imports

### Function Length
- Functions should fit on one screen (~50 lines max)
- Extract complex logic into helper functions
- Single responsibility per function
