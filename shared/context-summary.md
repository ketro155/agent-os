# Context Summary Patterns

Pre-computed context summaries for efficient task execution. Instead of loading full specs during execution, generate summaries at task creation time that contain only what each task needs.

**Reference**: Based on Anthropic's research on "Effective Harnesses for Long-Running Agents" - reducing per-task context overhead.

---

## Core Principles

1. **Pre-compute at Task Creation**: Generate context summaries when /create-tasks runs
2. **Task-Specific Filtering**: Each task gets only relevant context
3. **Token-Conscious**: Summaries are compressed, not full documents
4. **Update on Demand**: Regenerate if specs change significantly

---

## File Location

```
.agent-os/specs/[spec-name]/
├── spec.md                    # Full specification (source of truth)
├── tasks.md                   # Task breakdown (human readable)
├── tasks.json                 # Machine-readable tasks
└── context-summary.json       # Pre-computed context per task (NEW)
```

---

## Context Summary Schema

### context-summary.json Structure

```json
{
  "$schema": "https://agent-os.dev/schemas/context-summary-v1.json",
  "version": "1.0",
  "spec": "feature-name",
  "generated": "2025-12-08T10:00:00Z",
  "source_hashes": {
    "spec.md": "abc123",
    "technical-spec.md": "def456",
    "tasks.md": "ghi789"
  },
  "global_context": {
    "product_pitch": "One-line description from mission",
    "tech_stack": ["TypeScript", "React", "PostgreSQL"],
    "branch_name": "feature-name"
  },
  "tasks": {
    "1": {
      "summary": "Implement authentication endpoints",
      "spec_sections": ["2.1 Login Flow", "2.2 Token Management"],
      "relevant_files": ["src/auth/", "src/middleware/"],
      "codebase_refs": {
        "functions": [
          "validateCredentials(email, password): Promise<User> // src/auth/validate.ts:15",
          "generateToken(userId): string // src/auth/token.ts:42"
        ],
        "imports": [
          "import { User } from '@/types/user'",
          "import { db } from '@/lib/database'"
        ],
        "schemas": ["users table", "sessions table"]
      },
      "standards": {
        "patterns": ["Use bcrypt for password hashing", "JWT with 1hr expiry"],
        "testing": ["Unit tests for validation", "Integration test for full flow"]
      },
      "dependencies": [],
      "estimated_tokens": 850
    },
    "1.1": {
      "summary": "Write failing tests for login endpoint",
      "parent": "1",
      "spec_sections": ["2.1.1 Login Request", "2.1.2 Login Response"],
      "relevant_files": ["tests/auth/login.test.ts"],
      "codebase_refs": {
        "functions": [],
        "imports": ["import { describe, it, expect } from 'vitest'"]
      },
      "standards": {
        "patterns": ["TDD RED phase - tests must fail initially"],
        "testing": ["Test invalid credentials", "Test missing fields", "Test success case"]
      },
      "dependencies": [],
      "estimated_tokens": 400
    }
  },
  "metadata": {
    "total_tasks": 8,
    "total_estimated_tokens": 5200,
    "average_tokens_per_task": 650
  }
}
```

---

## Pattern: Generate Context Summary

Run this after create-tasks completes to pre-compute context.

```javascript
// GENERATE_CONTEXT_SUMMARY_PATTERN
async function generateContextSummary(specFolder) {
  const summaryPath = `${specFolder}/context-summary.json`;

  // 1. Load source documents
  const spec = readFileSync(`${specFolder}/spec.md`, 'utf8');
  const techSpec = readFileSync(`${specFolder}/sub-specs/technical-spec.md`, 'utf8');
  const tasksJson = JSON.parse(readFileSync(`${specFolder}/tasks.json`, 'utf8'));

  // 2. Load codebase references if available
  let codebaseRefs = null;
  if (existsSync('.agent-os/codebase/functions.md')) {
    codebaseRefs = {
      functions: readFileSync('.agent-os/codebase/functions.md', 'utf8'),
      imports: readFileSync('.agent-os/codebase/imports.md', 'utf8')
    };
  }

  // 3. Load relevant standards
  const standards = loadRelevantStandards(techSpec);

  // 4. Extract global context
  const globalContext = {
    product_pitch: extractProductPitch(spec),
    tech_stack: extractTechStack(techSpec),
    branch_name: deriveBranchName(specFolder)
  };

  // 5. Generate per-task context
  const taskContexts = {};

  for (const task of tasksJson.tasks) {
    taskContexts[task.id] = generateTaskContext(task, {
      spec,
      techSpec,
      codebaseRefs,
      standards
    });
  }

  // 6. Calculate source hashes (for invalidation)
  const sourceHashes = {
    'spec.md': hashContent(spec),
    'technical-spec.md': hashContent(techSpec),
    'tasks.md': hashContent(readFileSync(`${specFolder}/tasks.md`, 'utf8'))
  };

  // 7. Build summary object
  const contextSummary = {
    version: '1.0',
    spec: basename(specFolder),
    generated: new Date().toISOString(),
    source_hashes: sourceHashes,
    global_context: globalContext,
    tasks: taskContexts,
    metadata: calculateMetadata(taskContexts)
  };

  // 8. Write atomically
  const tempPath = `${summaryPath}.tmp`;
  writeFileSync(tempPath, JSON.stringify(contextSummary, null, 2));
  renameSync(tempPath, summaryPath);

  return contextSummary;
}
```

---

## Pattern: Generate Task-Specific Context

Extract only what a specific task needs.

```javascript
// GENERATE_TASK_CONTEXT_PATTERN
function generateTaskContext(task, sources) {
  const { spec, techSpec, codebaseRefs, standards } = sources;

  // 1. Find relevant spec sections by keyword matching
  const specSections = findRelevantSections(spec, task.description);

  // 2. Identify files likely to be modified
  const relevantFiles = identifyRelevantFiles(task, techSpec);

  // 3. Filter codebase refs to relevant files only
  const filteredRefs = {
    functions: [],
    imports: [],
    schemas: []
  };

  if (codebaseRefs) {
    filteredRefs.functions = filterFunctionsByFiles(
      codebaseRefs.functions,
      relevantFiles
    );
    filteredRefs.imports = extractRelevantImports(
      codebaseRefs.imports,
      relevantFiles
    );
  }

  // 4. Select applicable standards
  const applicableStandards = selectStandardsForTask(task, standards);

  // 5. Determine dependencies
  const dependencies = task.parent
    ? [task.parent]
    : [];

  // 6. Estimate token count
  const estimatedTokens = estimateTokens({
    specSections,
    filteredRefs,
    applicableStandards
  });

  return {
    summary: task.description,
    parent: task.parent || undefined,
    spec_sections: specSections,
    relevant_files: relevantFiles,
    codebase_refs: filteredRefs,
    standards: applicableStandards,
    dependencies: dependencies,
    estimated_tokens: estimatedTokens
  };
}
```

---

## Pattern: Load Task Context for Worker

When spawning a worker, load only that task's context.

```javascript
// LOAD_TASK_CONTEXT_PATTERN
function loadTaskContext(specFolder, taskId) {
  const summaryPath = `${specFolder}/context-summary.json`;

  // 1. Load summary
  const summary = JSON.parse(readFileSync(summaryPath, 'utf8'));

  // 2. Check if regeneration needed (source files changed)
  if (sourcesHaveChanged(specFolder, summary.source_hashes)) {
    // Regenerate (could be async in background)
    regenerateContextSummary(specFolder);
    // Reload
    summary = JSON.parse(readFileSync(summaryPath, 'utf8'));
  }

  // 3. Get task-specific context
  const taskContext = summary.tasks[taskId];
  if (!taskContext) {
    throw new Error(`Task ${taskId} not found in context summary`);
  }

  // 4. Include global context
  return {
    global: summary.global_context,
    task: taskContext,
    estimated_tokens: taskContext.estimated_tokens + 200 // global overhead
  };
}
```

---

## Pattern: Format Context for Worker Prompt

Convert context summary into worker-ready prompt section.

```javascript
// FORMAT_WORKER_CONTEXT_PATTERN
function formatWorkerContext(context) {
  const { global, task } = context;

  let prompt = '';

  // Global context (brief)
  prompt += `## Project Context\n`;
  prompt += `- **Product**: ${global.product_pitch}\n`;
  prompt += `- **Stack**: ${global.tech_stack.join(', ')}\n`;
  prompt += `- **Branch**: ${global.branch_name}\n\n`;

  // Task-specific context
  prompt += `## Task Context\n`;
  prompt += `**Summary**: ${task.summary}\n\n`;

  if (task.spec_sections.length > 0) {
    prompt += `### Relevant Spec Sections\n`;
    task.spec_sections.forEach(section => {
      prompt += `- ${section}\n`;
    });
    prompt += `\n`;
  }

  if (task.relevant_files.length > 0) {
    prompt += `### Files to Modify/Create\n`;
    task.relevant_files.forEach(file => {
      prompt += `- ${file}\n`;
    });
    prompt += `\n`;
  }

  // Codebase references (critical for avoiding name errors)
  if (task.codebase_refs.functions.length > 0) {
    prompt += `### Existing Functions to Use\n`;
    prompt += `**IMPORTANT: Use these exact names**\n\`\`\`\n`;
    task.codebase_refs.functions.forEach(fn => {
      prompt += `${fn}\n`;
    });
    prompt += `\`\`\`\n\n`;
  }

  if (task.codebase_refs.imports.length > 0) {
    prompt += `### Import Paths\n\`\`\`typescript\n`;
    task.codebase_refs.imports.forEach(imp => {
      prompt += `${imp}\n`;
    });
    prompt += `\`\`\`\n\n`;
  }

  // Standards
  if (task.standards.patterns.length > 0) {
    prompt += `### Patterns to Follow\n`;
    task.standards.patterns.forEach(pattern => {
      prompt += `- ${pattern}\n`;
    });
    prompt += `\n`;
  }

  if (task.standards.testing.length > 0) {
    prompt += `### Testing Requirements\n`;
    task.standards.testing.forEach(test => {
      prompt += `- ${test}\n`;
    });
    prompt += `\n`;
  }

  return prompt;
}
```

---

## Pattern: Invalidation Check

Determine if context summary needs regeneration.

```javascript
// CONTEXT_INVALIDATION_PATTERN
function sourcesHaveChanged(specFolder, storedHashes) {
  const filesToCheck = [
    'spec.md',
    'sub-specs/technical-spec.md',
    'tasks.md'
  ];

  for (const file of filesToCheck) {
    const filepath = `${specFolder}/${file}`;
    if (!existsSync(filepath)) continue;

    const currentHash = hashContent(readFileSync(filepath, 'utf8'));
    const storedHash = storedHashes[file];

    if (currentHash !== storedHash) {
      return true; // Source changed, regenerate
    }
  }

  return false; // No changes, summary is valid
}

function hashContent(content) {
  // Simple hash for change detection
  // In practice, use crypto.createHash('md5')
  return content.length.toString() + '-' + content.slice(0, 50).replace(/\s/g, '');
}
```

---

## Integration with create-tasks

Add context summary generation to create-tasks workflow:

```markdown
### Step 1.5: Generate Context Summary (NEW)

After creating tasks.json, pre-compute context summaries for efficient execution.

**Instructions:**
\`\`\`
ACTION: Generate context summary
PURPOSE: Pre-compute task-specific context for worker agents

WORKFLOW:
  1. Load tasks.json (just created)
  2. For each task, extract:
     - Relevant spec sections (by keyword)
     - Files likely to be modified
     - Codebase refs for those files
     - Applicable standards
  3. Calculate estimated tokens per task
  4. Write context-summary.json

BENEFITS:
  - Workers receive only relevant context
  - Reduces per-task token overhead by ~60%
  - Enables orchestrator pattern for long sessions
\`\`\`
```

---

## Integration with execute-tasks

Use context summary in task execution:

```markdown
### Step 7.3 Alternative: Load Pre-computed Context (NEW)

Instead of batched context retrieval, use pre-computed summary.

**Instructions:**
\`\`\`
IF context-summary.json exists AND is valid:
  LOAD: Task context from summary
  VERIFY: Source hashes match current files
  USE: Pre-computed context (faster, smaller)
ELSE:
  FALLBACK: Batched context retrieval (Step 7.3 original)
  GENERATE: context-summary.json for future use
\`\`\`

**Token Savings:**
- Original batched retrieval: ~3000 tokens per task
- Pre-computed summary: ~800 tokens per task
- Savings: ~73% reduction in context overhead
```

---

## Token Budget Guidelines

| Task Type | Target Tokens | Includes |
|-----------|---------------|----------|
| Simple subtask | 300-500 | Summary, 1-2 spec sections, imports |
| Implementation task | 600-900 | Summary, specs, functions, standards |
| Complex task | 900-1200 | Full context, multiple file refs |

**Total budget per worker**: ~2000 tokens for context (rest available for implementation)

---

## Validation

```javascript
// VALIDATE_CONTEXT_SUMMARY_PATTERN
function validateContextSummary(specFolder) {
  const summaryPath = `${specFolder}/context-summary.json`;
  const tasksPath = `${specFolder}/tasks.json`;

  const errors = [];

  // 1. Check summary exists
  if (!existsSync(summaryPath)) {
    errors.push('context-summary.json not found');
    return { valid: false, errors };
  }

  // 2. Load and parse
  let summary;
  try {
    summary = JSON.parse(readFileSync(summaryPath, 'utf8'));
  } catch (e) {
    errors.push(`Invalid JSON: ${e.message}`);
    return { valid: false, errors };
  }

  // 3. Check all tasks have context
  const tasks = JSON.parse(readFileSync(tasksPath, 'utf8'));
  for (const task of tasks.tasks) {
    if (!summary.tasks[task.id]) {
      errors.push(`Missing context for task ${task.id}`);
    }
  }

  // 4. Check source freshness
  if (sourcesHaveChanged(specFolder, summary.source_hashes)) {
    errors.push('Context summary is stale (sources changed)');
  }

  return {
    valid: errors.length === 0,
    errors,
    stale: errors.some(e => e.includes('stale'))
  };
}
```

---

## Usage in Commands

Reference these patterns:

```markdown
## Context Summary

Use patterns from @shared/context-summary.md:
- Generate: GENERATE_CONTEXT_SUMMARY_PATTERN
- Task context: GENERATE_TASK_CONTEXT_PATTERN
- Load for worker: LOAD_TASK_CONTEXT_PATTERN
- Format prompt: FORMAT_WORKER_CONTEXT_PATTERN
- Invalidation: CONTEXT_INVALIDATION_PATTERN

Generate after create-tasks, use during execute-tasks.
```
