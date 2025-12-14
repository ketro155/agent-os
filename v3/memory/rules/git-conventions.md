---
paths:
  - ".git/**"
  - "**/*"
---

# Git Conventions

## Branch Naming

### Feature Branches
```
feature/SPEC-NAME-brief-description
```
Examples:
- `feature/auth-system-jwt-login`
- `feature/dashboard-analytics-charts`

### Fix Branches
```
fix/ISSUE-ID-brief-description
```
Examples:
- `fix/GH-123-login-timeout`
- `fix/validation-error-handling`

## Commit Messages

### Format
```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types
- `feat`: New feature
- `fix`: Bug fix
- `refactor`: Code change that neither fixes a bug nor adds a feature
- `test`: Adding or updating tests
- `docs`: Documentation only changes
- `chore`: Build process or auxiliary tool changes

### Examples
```
feat(auth): add JWT token validation

Implement validateToken function with:
- Token signature verification
- Expiration checking
- Payload extraction

Closes #123
```

```
fix(api): handle null response from external service

Add null check before processing response to prevent
TypeError when external service returns empty response.

Fixes #456
```

## Commit Frequency

### During Task Execution
- Commit after each **subtask completion**
- Commit after **each green test** (TDD)
- Commit after **significant refactoring**

### Commit Checklist (Pre-commit hook enforces these)
- [ ] Build passes
- [ ] Tests pass
- [ ] Types check (TypeScript)
- [ ] No in_progress tasks without completion

## Pull Request Format

### Title
```
[SPEC-NAME] Brief description of changes
```

### Body Template
```markdown
## Summary
- What was implemented
- Key decisions made

## Changes
- List of significant changes

## Testing
- How to test the changes
- Test coverage information

## Checklist
- [ ] Tests pass
- [ ] Build succeeds
- [ ] Documentation updated
- [ ] Spec requirements met
```

## Protected Operations

The following require explicit confirmation:
- Force push (`git push --force`)
- Reset to remote (`git reset --hard origin/main`)
- Branch deletion (`git branch -D`)
- History rewriting (`git rebase -i`)

## Hooks Integration

Pre-commit validation (automatic):
1. Build check
2. Type check (TypeScript)
3. Lint check
4. Test execution
5. Tasks.json validation

If any check fails, commit is blocked with explanation.
