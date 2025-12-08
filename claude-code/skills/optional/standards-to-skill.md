---
name: standards-to-skill
description: "Template and guide for converting standards documents into Claude Code skills. Use this when you need to create a skill from an existing standard, or when building new standards that should also be skills."
allowed-tools: Read, Write, Glob
---

# Standards-to-Skill Converter

Transform standards documentation into Claude Code skills for better discoverability and automatic invocation.

## When to Use This Skill

Claude should invoke this skill when:
- User asks to "make a standard a skill"
- Converting existing standards to be auto-invoked
- Creating new standards that warrant automatic application
- Optimizing how standards are surfaced during development

## Skill Template

Use this template when converting a standard to a skill:

```markdown
---
name: {{standard-name}}
description: "{{Brief description of when to apply this standard}}. Auto-invoke when {{trigger conditions}}."
allowed-tools: {{Relevant tools for this standard}}
---

# {{Standard Name}} Skill

{{One sentence summary of what this standard ensures}}

**Core Principle:** {{KEY PRINCIPLE IN CAPS}}

## When to Use This Skill

Claude should invoke this skill:
- **When {{condition 1}}**
- **When {{condition 2}}**
- **During {{workflow phase}}**

**Not for:** {{What this skill doesn't cover}}

## Standards Application

### {{Category 1}}

{{Content from original standard}}

### {{Category 2}}

{{Content from original standard}}

## Quick Reference

{{Condensed checklist or table of key rules}}

## Integration Notes

- Complements: {{Related skills/standards}}
- Conflicts with: {{Any conflicting approaches, if applicable}}
```

## Conversion Process

### Step 1: Analyze the Standard

```
READ: Original standard document
IDENTIFY:
  - Core principles (what MUST be followed)
  - Trigger conditions (when to apply)
  - Key rules (specific guidelines)
  - Examples (how to apply correctly)
```

### Step 2: Define Trigger Conditions

Determine when Claude should auto-invoke this skill:

**Good Triggers:**
- "When writing React components" → react-patterns
- "When designing API endpoints" → api-design
- "When writing tests" → test-patterns
- "When handling errors" → error-handling

**Bad Triggers (too broad):**
- "When writing code" → applies to everything
- "Always" → no discrimination

### Step 3: Extract Key Content

```
FROM standard:
  KEEP: Actionable rules and patterns
  KEEP: Examples that clarify application
  KEEP: Common mistakes to avoid

  REMOVE: Verbose explanations
  REMOVE: Historical context (unless relevant)
  REMOVE: Rarely-applicable edge cases
```

### Step 4: Create Skill File

```
PATH: .claude/skills/{{standard-name}}.md
      OR
PATH: .claude/skills/optional/{{standard-name}}.md (for specialized standards)

CONTENT: Use template above
```

### Step 5: Validate Skill

```
CHECK: YAML frontmatter is valid
CHECK: Description explains when to use
CHECK: allowed-tools matches what skill needs
CHECK: Content is actionable, not just informational
```

## Example Conversions

### Example 1: API Design Standard → Skill

**Original:** `standards/backend/api-design.md` (comprehensive reference)

**Skill Version:** `skills/api-design.md`
```markdown
---
name: api-design
description: "RESTful API design patterns. Auto-invoke when creating or modifying API endpoints, routes, or controllers."
allowed-tools: Read, Write, Grep
---

# API Design Skill

Ensures consistent, RESTful API design across all endpoints.

**Core Principle:** RESOURCES, NOT ACTIONS

## When to Use This Skill

Claude should invoke this skill:
- **When creating new API endpoints**
- **When modifying existing routes**
- **When reviewing API responses**

## Quick Reference

| Action | HTTP Method | URL Pattern | Response |
|--------|-------------|-------------|----------|
| List | GET | /resources | 200 + array |
| Read | GET | /resources/:id | 200 + object |
| Create | POST | /resources | 201 + object |
| Update | PUT/PATCH | /resources/:id | 200 + object |
| Delete | DELETE | /resources/:id | 204 |

[... condensed content ...]
```

### Example 2: Test Patterns Standard → Skill

**Original:** `standards/testing/test-patterns.md`

**Skill Version:** `skills/test-patterns.md`
```markdown
---
name: test-patterns
description: "Testing conventions and patterns. Auto-invoke when writing tests, creating test files, or reviewing test coverage."
allowed-tools: Read, Write, Bash
---

# Test Patterns Skill

Ensures consistent, reliable test code across the project.

**Core Principle:** TEST BEHAVIOR, NOT IMPLEMENTATION

[... condensed content ...]
```

## When NOT to Convert

Some standards work better as reference documents:
- **Tech stack** - Reference only, doesn't need auto-invoke
- **Project conventions** - Too project-specific
- **Deployment guides** - Procedural, not pattern-based

## Skill Placement

```
.claude/skills/
├── build-check.md           # Core - always needed
├── test-check.md            # Core - always needed
├── codebase-names.md        # Core - prevents hallucination
├── api-design.md            # From standards/backend/api-design.md
├── react-patterns.md        # From standards/frontend/react-patterns.md
└── optional/
    ├── database.md          # Specialized - from standards/backend/database.md
    └── styling.md           # Specialized - from standards/frontend/styling.md
```

## Output Format

When converting, provide:

```markdown
## Conversion Summary

**Source:** `standards/[path]/[name].md`
**Target:** `.claude/skills/[name].md` or `.claude/skills/optional/[name].md`

**Trigger Conditions:**
- [When this skill should auto-invoke]

**Key Content Preserved:**
- [What was kept from original]

**Content Removed/Condensed:**
- [What was trimmed for skill format]

**Created File:**
[Show the generated skill content]
```

## Integration with Agent OS

Skills created from standards should:
1. Reference the original standard for complete documentation
2. Use consistent naming (`standards/backend/api-design.md` → `api-design` skill)
3. Be added to installer if broadly applicable
4. Be placed in `optional/` if specialized

## Maintenance

When updating standards:
1. Check if a corresponding skill exists
2. Update skill with relevant changes
3. Keep skill concise even if standard expands
4. Version note in skill if breaking changes
