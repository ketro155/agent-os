# Task JSON Format Patterns

Canonical patterns for machine-readable task tracking alongside markdown. JSON provides programmatic access while markdown remains the human-editable source of truth.

**Version**: 2.1 - Adds artifacts tracking for cross-task verification (replaces codebase-indexer).

---

## Core Principles

1. **Markdown is Source of Truth**: Human edits go to tasks.md
2. **JSON is Generated**: tasks.json is auto-generated from markdown
3. **Metadata Preserved**: JSON stores additional metadata not in markdown
4. **Bidirectional Sync**: Changes sync from markdown to JSON (not reverse)
5. **Parallel-Aware**: JSON includes dependency graph and execution waves (v2.0)
6. **Artifact Tracking**: JSON records outputs (files, functions, exports) for cross-task verification (v2.1)

---

## File Locations

```
.agent-os/tasks/[spec-name]/
├── tasks.md          # Human-readable, editable (source of truth)
└── tasks.json        # Machine-readable (auto-generated)
```

---

## JSON Schema

### tasks.json Structure (v2.1)

```json
{
  "$schema": "https://agent-os.dev/schemas/tasks-v2.1.json",
  "version": "2.1",
  "spec": "feature-name",
  "spec_path": ".agent-os/specs/feature-name/",
  "created": "2025-12-08T10:00:00Z",
  "updated": "2025-12-08T14:30:00Z",
  "execution_strategy": {
    "mode": "parallel_waves",
    "waves": [
      {
        "wave_id": 1,
        "tasks": ["1", "2"],
        "rationale": "No shared file dependencies, independent components",
        "estimated_duration_minutes": 45
      },
      {
        "wave_id": 2,
        "tasks": ["3"],
        "rationale": "Depends on auth middleware from task 1",
        "estimated_duration_minutes": 60
      }
    ],
    "estimated_parallel_speedup": 1.4,
    "max_concurrent_workers": 2,
    "total_sequential_minutes": 150,
    "total_parallel_minutes": 105
  },
  "tasks": [
    {
      "id": "1",
      "type": "parent",
      "description": "Implement authentication endpoints",
      "status": "pass",
      "subtasks": ["1.1", "1.2", "1.3"],
      "progress_percent": 100,
      "started_at": "2025-12-08T10:30:00Z",
      "completed_at": "2025-12-08T14:00:00Z",
      "parallelization": {
        "wave": 1,
        "can_parallel_with": ["2"],
        "blocked_by": [],
        "blocks": ["3"],
        "shared_files": ["src/auth/middleware.ts"],
        "isolation_score": 0.85
      },
      "artifacts": {
        "files_modified": ["src/auth/middleware.ts"],
        "files_created": ["src/auth/login.ts", "src/auth/token.ts", "tests/auth/login.test.ts"],
        "functions_created": ["login", "validateToken", "refreshToken", "hashPassword"],
        "exports_added": ["login", "validateToken", "refreshToken", "hashPassword", "AuthError"],
        "test_files": ["tests/auth/login.test.ts", "tests/auth/token.test.ts"]
      }
    },
    {
      "id": "2",
      "type": "parent",
      "description": "Implement user profile UI",
      "status": "pending",
      "subtasks": ["2.1", "2.2"],
      "progress_percent": 0,
      "started_at": null,
      "completed_at": null,
      "parallelization": {
        "wave": 1,
        "can_parallel_with": ["1"],
        "blocked_by": [],
        "blocks": [],
        "shared_files": [],
        "isolation_score": 1.0
      }
    },
    {
      "id": "3",
      "type": "parent",
      "description": "Add session management",
      "status": "pending",
      "subtasks": ["3.1", "3.2"],
      "progress_percent": 0,
      "started_at": null,
      "completed_at": null,
      "parallelization": {
        "wave": 2,
        "can_parallel_with": [],
        "blocked_by": ["1"],
        "blocks": [],
        "shared_files": ["src/auth/middleware.ts"],
        "isolation_score": 0.7
      }
    },
    {
      "id": "1.1",
      "type": "subtask",
      "parent": "1",
      "description": "Create login endpoint",
      "status": "pass",
      "attempts": 1,
      "started_at": "2025-12-08T10:30:00Z",
      "completed_at": "2025-12-08T11:15:00Z",
      "duration_minutes": 45,
      "notes": null,
      "blocker": null
    },
    {
      "id": "1.2",
      "type": "subtask",
      "parent": "1",
      "description": "Implement JWT validation",
      "status": "pass",
      "attempts": 2,
      "started_at": "2025-12-08T11:20:00Z",
      "completed_at": "2025-12-08T13:00:00Z",
      "duration_minutes": 100,
      "notes": "Required JWKS endpoint fix on attempt 2",
      "blocker": null
    },
    {
      "id": "1.3",
      "type": "subtask",
      "parent": "1",
      "description": "Add session management",
      "status": "pending",
      "attempts": 0,
      "started_at": null,
      "completed_at": null,
      "duration_minutes": null,
      "notes": null,
      "blocker": null
    }
  ],
  "summary": {
    "total_tasks": 6,
    "parent_tasks": 3,
    "subtasks": 3,
    "completed": 2,
    "in_progress": 1,
    "blocked": 0,
    "pending": 3,
    "overall_percent": 33,
    "parallel_waves": 2,
    "max_parallelism": 2
  }
}
```

### Field Definitions

**Top-level fields:**

| Field | Type | Description |
|-------|------|-------------|
| `version` | string | Schema version ("2.0") |
| `spec` | string | Spec folder name |
| `spec_path` | string | Path to spec directory |
| `created` | ISO8601 | When tasks.json was created |
| `updated` | ISO8601 | Last sync timestamp |
| `execution_strategy` | object | Parallel execution plan (v2.0) |
| `tasks` | array | Task objects |
| `summary` | object | Aggregated statistics |

**Execution Strategy fields (v2.0):**

| Field | Type | Description |
|-------|------|-------------|
| `mode` | enum | "sequential", "parallel_waves", or "fully_parallel" |
| `waves` | array | Groups of tasks that can run simultaneously |
| `waves[].wave_id` | number | Wave sequence number (1-based) |
| `waves[].tasks` | array | Task IDs in this wave |
| `waves[].rationale` | string | Why these tasks can parallelize |
| `waves[].estimated_duration_minutes` | number | Max duration of tasks in wave |
| `estimated_parallel_speedup` | number | Ratio of sequential/parallel time |
| `max_concurrent_workers` | number | Maximum tasks running at once |
| `total_sequential_minutes` | number | Time if run sequentially |
| `total_parallel_minutes` | number | Time with parallel execution |

**Task fields:**

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Task identifier ("1", "1.1", "1.2") |
| `type` | enum | "parent" or "subtask" |
| `parent` | string | Parent task ID (subtasks only) |
| `description` | string | Task description from markdown |
| `status` | enum | "pending", "in_progress", "pass", "blocked" |
| `subtasks` | array | Child task IDs (parent tasks only) |
| `progress_percent` | number | Completion percentage (parent tasks only) |
| `parallelization` | object | Parallel execution metadata (v2.0, parent tasks only) |
| `attempts` | number | Number of execution attempts |
| `started_at` | ISO8601 | When task was first attempted |
| `completed_at` | ISO8601 | When task was completed |
| `duration_minutes` | number | Total time spent |
| `notes` | string | Additional context |
| `blocker` | string | Blocker description if blocked |
| `artifacts` | object | Output tracking for cross-task verification (v2.1, parent tasks only) |

**Artifacts fields (v2.1, parent tasks only):**

| Field | Type | Description |
|-------|------|-------------|
| `files_modified` | array | Files that existed and were changed |
| `files_created` | array | New files created by this task |
| `functions_created` | array | New function/method names added |
| `exports_added` | array | New exports (functions, classes, constants) |
| `test_files` | array | Test files created or modified |

**Parallelization fields (v2.0, parent tasks only):**

| Field | Type | Description |
|-------|------|-------------|
| `wave` | number | Which execution wave (1-based) |
| `can_parallel_with` | array | Task IDs safe to run simultaneously |
| `blocked_by` | array | Task IDs that must complete first |
| `blocks` | array | Task IDs waiting on this task |
| `shared_files` | array | Files this task modifies (conflict detection) |
| `isolation_score` | number | 0-1 score (1 = fully parallel-safe) |

---

## Pattern: Parse Markdown to JSON

Convert tasks.md checkbox format to JSON structure.

```javascript
// MARKDOWN_TO_JSON_PATTERN
function parseTasksMarkdown(markdownContent) {
  const tasks = [];
  const lines = markdownContent.split('\n');

  let currentParent = null;

  for (const line of lines) {
    // Match parent task: ## Task 1: Description
    const parentMatch = line.match(/^##\s+Task\s+(\d+):\s+(.+)$/);
    if (parentMatch) {
      currentParent = {
        id: parentMatch[1],
        type: 'parent',
        description: parentMatch[2].trim(),
        status: 'pending',
        subtasks: [],
        progress_percent: 0
      };
      tasks.push(currentParent);
      continue;
    }

    // Match subtask: - [x] 1.1 Description or - [ ] 1.1 Description
    const subtaskMatch = line.match(/^-\s+\[([ x])\]\s+(\d+\.\d+)\s+(.+)$/);
    if (subtaskMatch && currentParent) {
      const isComplete = subtaskMatch[1] === 'x';
      const subtask = {
        id: subtaskMatch[2],
        type: 'subtask',
        parent: currentParent.id,
        description: subtaskMatch[3].trim(),
        status: isComplete ? 'pass' : 'pending',
        attempts: isComplete ? 1 : 0,
        completed_at: isComplete ? new Date().toISOString() : null
      };

      // Check for blocker marker
      if (subtask.description.includes('⚠️')) {
        subtask.status = 'blocked';
        const blockerMatch = subtask.description.match(/⚠️\s*(.+)$/);
        if (blockerMatch) {
          subtask.blocker = blockerMatch[1];
          subtask.description = subtask.description.replace(/⚠️.*$/, '').trim();
        }
      }

      tasks.push(subtask);
      currentParent.subtasks.push(subtask.id);
    }
  }

  // Calculate parent progress
  for (const task of tasks) {
    if (task.type === 'parent') {
      const subtasks = tasks.filter(t => t.parent === task.id);
      const completed = subtasks.filter(t => t.status === 'pass').length;
      task.progress_percent = subtasks.length > 0
        ? Math.round((completed / subtasks.length) * 100)
        : 0;
      task.status = completed === subtasks.length ? 'pass'
        : completed > 0 ? 'in_progress'
        : 'pending';
    }
  }

  return tasks;
}
```

---

## Pattern: Generate JSON from Markdown

Create or update tasks.json from tasks.md.

```javascript
// SYNC_TASKS_PATTERN
function syncTasksToJson(specFolder) {
  const markdownPath = `${specFolder}/tasks.md`;
  const jsonPath = `${specFolder}/tasks.json`;

  // 1. Read markdown (source of truth)
  const markdownContent = readFileSync(markdownPath, 'utf8');

  // 2. Parse to task objects
  const parsedTasks = parseTasksMarkdown(markdownContent);

  // 3. Load existing JSON for metadata preservation
  let existingJson = { tasks: [] };
  if (existsSync(jsonPath)) {
    try {
      existingJson = JSON.parse(readFileSync(jsonPath, 'utf8'));
    } catch (e) {
      // Corrupted JSON, will regenerate
    }
  }

  // 4. Merge metadata from existing JSON
  for (const task of parsedTasks) {
    const existing = existingJson.tasks.find(t => t.id === task.id);
    if (existing) {
      // Preserve metadata not in markdown
      task.attempts = existing.attempts || task.attempts;
      task.started_at = existing.started_at || task.started_at;
      task.completed_at = existing.completed_at || task.completed_at;
      task.duration_minutes = existing.duration_minutes || task.duration_minutes;
      task.notes = existing.notes || task.notes;

      // Update completion time if newly completed
      if (task.status === 'pass' && !task.completed_at) {
        task.completed_at = new Date().toISOString();
      }
    }
  }

  // 5. Calculate summary
  const summary = calculateSummary(parsedTasks);

  // 6. Build final JSON
  const tasksJson = {
    version: '1.0',
    spec: basename(specFolder),
    spec_path: `.agent-os/specs/${basename(specFolder)}/`,
    created: existingJson.created || new Date().toISOString(),
    updated: new Date().toISOString(),
    tasks: parsedTasks,
    summary: summary
  };

  // 7. Write JSON (atomic)
  const tempPath = `${jsonPath}.tmp`;
  writeFileSync(tempPath, JSON.stringify(tasksJson, null, 2));
  renameSync(tempPath, jsonPath);

  return tasksJson;
}

function calculateSummary(tasks) {
  const parentTasks = tasks.filter(t => t.type === 'parent');
  const subtasks = tasks.filter(t => t.type === 'subtask');

  const completed = tasks.filter(t => t.status === 'pass').length;
  const inProgress = tasks.filter(t => t.status === 'in_progress').length;
  const blocked = tasks.filter(t => t.status === 'blocked').length;
  const pending = tasks.filter(t => t.status === 'pending').length;

  return {
    total_tasks: tasks.length,
    parent_tasks: parentTasks.length,
    subtasks: subtasks.length,
    completed: completed,
    in_progress: inProgress,
    blocked: blocked,
    pending: pending,
    overall_percent: tasks.length > 0
      ? Math.round((completed / tasks.length) * 100)
      : 0
  };
}
```

---

## Pattern: Update Task Metadata

Update JSON metadata when task status changes.

```javascript
// UPDATE_TASK_METADATA_PATTERN
function updateTaskMetadata(specFolder, taskId, metadata) {
  const jsonPath = `${specFolder}/tasks.json`;

  // 1. Load existing JSON
  const tasksJson = JSON.parse(readFileSync(jsonPath, 'utf8'));

  // 2. Find task
  const task = tasksJson.tasks.find(t => t.id === taskId);
  if (!task) {
    throw new Error(`Task ${taskId} not found`);
  }

  // 3. Update metadata
  if (metadata.status === 'in_progress' && !task.started_at) {
    task.started_at = new Date().toISOString();
    task.attempts = (task.attempts || 0) + 1;
  }

  if (metadata.status === 'pass' && !task.completed_at) {
    task.completed_at = new Date().toISOString();
    if (task.started_at) {
      const start = new Date(task.started_at);
      const end = new Date(task.completed_at);
      task.duration_minutes = Math.round((end - start) / (1000 * 60));
    }
  }

  if (metadata.notes) {
    task.notes = metadata.notes;
  }

  if (metadata.blocker) {
    task.status = 'blocked';
    task.blocker = metadata.blocker;
  }

  // 4. Record artifacts on completion (v2.1)
  if (metadata.status === 'pass' && metadata.artifacts) {
    task.artifacts = {
      files_modified: metadata.artifacts.files_modified || [],
      files_created: metadata.artifacts.files_created || [],
      functions_created: metadata.artifacts.functions_created || [],
      exports_added: metadata.artifacts.exports_added || [],
      test_files: metadata.artifacts.test_files || []
    };
  }

  // 5. Recalculate summary
  tasksJson.summary = calculateSummary(tasksJson.tasks);
  tasksJson.updated = new Date().toISOString();

  // 6. Write JSON (atomic)
  const tempPath = `${jsonPath}.tmp`;
  writeFileSync(tempPath, JSON.stringify(tasksJson, null, 2));
  renameSync(tempPath, jsonPath);

  return task;
}
```

---

## Pattern: Query Task Status

Query task status programmatically.

```javascript
// QUERY_TASKS_PATTERN
function getTaskStatus(specFolder) {
  const jsonPath = `${specFolder}/tasks.json`;
  const tasksJson = JSON.parse(readFileSync(jsonPath, 'utf8'));

  return {
    summary: tasksJson.summary,
    nextTask: getNextTask(tasksJson.tasks),
    blockedTasks: tasksJson.tasks.filter(t => t.status === 'blocked'),
    recentlyCompleted: getRecentlyCompleted(tasksJson.tasks)
  };
}

function getNextTask(tasks) {
  // Find first pending subtask
  const pending = tasks.filter(t =>
    t.type === 'subtask' && t.status === 'pending'
  );
  return pending[0] || null;
}

function getRecentlyCompleted(tasks, hours = 24) {
  const cutoff = new Date(Date.now() - hours * 60 * 60 * 1000);
  return tasks.filter(t =>
    t.status === 'pass' &&
    t.completed_at &&
    new Date(t.completed_at) > cutoff
  );
}
```

---

## Sync Triggers

Tasks.json should be synced:

1. **After /create-tasks command** - Initial generation
2. **After task status change** - When checkbox toggled in tasks.md
3. **At session startup** - Validate consistency
4. **After execute-tasks completion** - Final sync with metadata

---

## Integration with execute-tasks

Add sync points in execute-tasks:

```
Step 7.10 (Mark Task Complete):
  1. Update tasks.md checkbox to [x]
  2. SYNC: Regenerate tasks.json
  3. UPDATE: Task metadata (completed_at, duration)
  4. Log to progress log

Step 8 (Phase 3 - All tests pass):
  1. Final sync of tasks.json
  2. Verify consistency with tasks.md
```

---

## Validation

```javascript
// VALIDATE_SYNC_PATTERN
function validateTasksSync(specFolder) {
  const markdownPath = `${specFolder}/tasks.md`;
  const jsonPath = `${specFolder}/tasks.json`;

  const markdownContent = readFileSync(markdownPath, 'utf8');
  const parsedFromMd = parseTasksMarkdown(markdownContent);
  const jsonContent = JSON.parse(readFileSync(jsonPath, 'utf8'));

  const errors = [];

  // Check task count matches
  if (parsedFromMd.length !== jsonContent.tasks.length) {
    errors.push(`Task count mismatch: MD=${parsedFromMd.length}, JSON=${jsonContent.tasks.length}`);
  }

  // Check status matches for each task
  for (const mdTask of parsedFromMd) {
    const jsonTask = jsonContent.tasks.find(t => t.id === mdTask.id);
    if (!jsonTask) {
      errors.push(`Task ${mdTask.id} missing from JSON`);
    } else if (mdTask.status !== jsonTask.status) {
      // Allow JSON to have more specific status
      if (!(mdTask.status === 'pending' && jsonTask.status === 'blocked')) {
        errors.push(`Status mismatch for ${mdTask.id}: MD=${mdTask.status}, JSON=${jsonTask.status}`);
      }
    }
  }

  return {
    valid: errors.length === 0,
    errors: errors
  };
}
```

---

## Pattern: Analyze Parallel Execution (v2.0)

Analyze task dependencies and generate execution waves.

```javascript
// ANALYZE_PARALLELIZATION_PATTERN
function analyzeParallelization(tasks, techSpec) {
  const parentTasks = tasks.filter(t => t.type === 'parent');

  // 1. Extract file dependencies from technical spec
  const taskFiles = {};
  for (const task of parentTasks) {
    taskFiles[task.id] = extractFilesForTask(task, techSpec);
  }

  // 2. Build dependency graph based on file overlaps
  const graph = {};
  for (const task of parentTasks) {
    graph[task.id] = {
      blocked_by: [],
      blocks: [],
      can_parallel_with: [],
      shared_files: taskFiles[task.id]
    };
  }

  // 3. Detect conflicts (shared file writes)
  for (let i = 0; i < parentTasks.length; i++) {
    for (let j = i + 1; j < parentTasks.length; j++) {
      const taskA = parentTasks[i];
      const taskB = parentTasks[j];

      const sharedFiles = findSharedFiles(
        taskFiles[taskA.id],
        taskFiles[taskB.id]
      );

      if (sharedFiles.length > 0) {
        // Tasks conflict - sequential execution needed
        // Earlier task blocks later task
        graph[taskB.id].blocked_by.push(taskA.id);
        graph[taskA.id].blocks.push(taskB.id);
      } else {
        // No conflict - can parallelize
        graph[taskA.id].can_parallel_with.push(taskB.id);
        graph[taskB.id].can_parallel_with.push(taskA.id);
      }
    }
  }

  // 4. Calculate isolation scores
  for (const task of parentTasks) {
    const g = graph[task.id];
    const totalOthers = parentTasks.length - 1;
    g.isolation_score = totalOthers > 0
      ? g.can_parallel_with.length / totalOthers
      : 1.0;
  }

  // 5. Generate waves using topological sort
  const waves = generateWaves(parentTasks, graph);

  // 6. Calculate speedup metrics
  const totalSequential = parentTasks.reduce(
    (sum, t) => sum + estimateTaskDuration(t), 0
  );
  const totalParallel = waves.reduce(
    (sum, wave) => sum + Math.max(...wave.tasks.map(
      id => estimateTaskDuration(parentTasks.find(t => t.id === id))
    )), 0
  );

  return {
    execution_strategy: {
      mode: waves.length === parentTasks.length ? 'sequential' : 'parallel_waves',
      waves: waves,
      estimated_parallel_speedup: totalSequential / totalParallel,
      max_concurrent_workers: Math.max(...waves.map(w => w.tasks.length)),
      total_sequential_minutes: totalSequential,
      total_parallel_minutes: totalParallel
    },
    task_parallelization: graph
  };
}

function generateWaves(tasks, graph) {
  const waves = [];
  const completed = new Set();

  while (completed.size < tasks.length) {
    // Find tasks with all dependencies satisfied
    const ready = tasks.filter(t =>
      !completed.has(t.id) &&
      graph[t.id].blocked_by.every(dep => completed.has(dep))
    );

    if (ready.length === 0) {
      throw new Error('Circular dependency detected in task graph');
    }

    const wave = {
      wave_id: waves.length + 1,
      tasks: ready.map(t => t.id),
      rationale: ready.length > 1
        ? 'No shared file dependencies between tasks'
        : graph[ready[0].id].blocked_by.length > 0
          ? `Depends on tasks: ${graph[ready[0].id].blocked_by.join(', ')}`
          : 'First wave - no dependencies',
      estimated_duration_minutes: Math.max(
        ...ready.map(t => estimateTaskDuration(t))
      )
    };

    waves.push(wave);
    ready.forEach(t => completed.add(t.id));
  }

  return waves;
}

function extractFilesForTask(task, techSpec) {
  // Extract file paths mentioned in task description or tech spec
  // This is a simplified version - real implementation would parse
  // the technical spec more thoroughly
  const files = [];
  const filePattern = /(?:src|lib|app|components|pages|api)\/[\w\-\/]+\.\w+/g;

  const matches = task.description.match(filePattern) || [];
  files.push(...matches);

  return [...new Set(files)];
}

function findSharedFiles(filesA, filesB) {
  return filesA.filter(f => filesB.includes(f));
}

function estimateTaskDuration(task) {
  // Rough estimate: 15-45 min per parent task based on subtask count
  const subtaskCount = task.subtasks?.length || 3;
  return subtaskCount * 10; // 10 min per subtask average
}
```

---

## Pattern: Query Parallel Execution Status (v2.0)

Query which tasks are ready to run in parallel.

```javascript
// QUERY_PARALLEL_STATUS_PATTERN
function getParallelStatus(specFolder) {
  const jsonPath = `${specFolder}/tasks.json`;
  const tasksJson = JSON.parse(readFileSync(jsonPath, 'utf8'));

  const { execution_strategy, tasks } = tasksJson;
  const parentTasks = tasks.filter(t => t.type === 'parent');

  // Find current wave (first wave with pending tasks)
  const completedTaskIds = new Set(
    parentTasks.filter(t => t.status === 'pass').map(t => t.id)
  );

  let currentWave = null;
  for (const wave of execution_strategy.waves) {
    const pendingInWave = wave.tasks.filter(id => !completedTaskIds.has(id));
    if (pendingInWave.length > 0) {
      currentWave = {
        ...wave,
        pending_tasks: pendingInWave,
        completed_tasks: wave.tasks.filter(id => completedTaskIds.has(id))
      };
      break;
    }
  }

  return {
    mode: execution_strategy.mode,
    current_wave: currentWave,
    total_waves: execution_strategy.waves.length,
    completed_waves: execution_strategy.waves.filter(w =>
      w.tasks.every(id => completedTaskIds.has(id))
    ).length,
    can_parallelize: currentWave?.pending_tasks.length > 1,
    tasks_ready_for_parallel: currentWave?.pending_tasks || [],
    estimated_remaining_parallel: execution_strategy.waves
      .slice(execution_strategy.waves.indexOf(currentWave))
      .reduce((sum, w) => sum + w.estimated_duration_minutes, 0)
  };
}
```

---

## Pattern: Collect Task Artifacts (v2.1)

Collect artifacts from git diff and code analysis after task completion.

```javascript
// COLLECT_ARTIFACTS_PATTERN
function collectTaskArtifacts(taskStartCommit) {
  const artifacts = {
    files_modified: [],
    files_created: [],
    functions_created: [],
    exports_added: [],
    test_files: []
  };

  // 1. Get modified and created files from git
  // git diff --name-status <start_commit> HEAD
  const diffOutput = execSync(
    `git diff --name-status ${taskStartCommit} HEAD`
  ).toString();

  for (const line of diffOutput.split('\n')) {
    if (!line.trim()) continue;
    const [status, ...pathParts] = line.split('\t');
    const filePath = pathParts.join('\t');

    if (status === 'A') {
      artifacts.files_created.push(filePath);
      if (filePath.includes('.test.') || filePath.includes('.spec.')) {
        artifacts.test_files.push(filePath);
      }
    } else if (status === 'M') {
      artifacts.files_modified.push(filePath);
      if (filePath.includes('.test.') || filePath.includes('.spec.')) {
        artifacts.test_files.push(filePath);
      }
    }
  }

  // 2. Extract exports from created files
  for (const file of artifacts.files_created) {
    if (file.endsWith('.ts') || file.endsWith('.js') || file.endsWith('.tsx') || file.endsWith('.jsx')) {
      const exports = extractExportsFromFile(file);
      artifacts.exports_added.push(...exports);
      artifacts.functions_created.push(...exports.filter(e => !e.includes('Type') && !e.includes('Interface')));
    } else if (file.endsWith('.py')) {
      const exports = extractPythonExportsFromFile(file);
      artifacts.exports_added.push(...exports);
      artifacts.functions_created.push(...exports);
    }
  }

  return artifacts;
}

function extractExportsFromFile(filePath) {
  // Use grep to find export statements
  // grep -E "export (const|function|class|type|interface)" <file>
  const exports = [];
  try {
    const content = readFileSync(filePath, 'utf8');
    const exportPattern = /export\s+(?:const|function|class|type|interface|enum)\s+(\w+)/g;
    const defaultPattern = /export\s+default\s+(?:function\s+)?(\w+)/g;

    let match;
    while ((match = exportPattern.exec(content)) !== null) {
      exports.push(match[1]);
    }
    while ((match = defaultPattern.exec(content)) !== null) {
      exports.push(match[1]);
    }
  } catch (e) {
    // File may not exist or be readable
  }
  return exports;
}

function extractPythonExportsFromFile(filePath) {
  const exports = [];
  try {
    const content = readFileSync(filePath, 'utf8');
    // Match function and class definitions
    const funcPattern = /^def\s+(\w+)\s*\(/gm;
    const classPattern = /^class\s+(\w+)/gm;

    let match;
    while ((match = funcPattern.exec(content)) !== null) {
      if (!match[1].startsWith('_')) { // Skip private functions
        exports.push(match[1]);
      }
    }
    while ((match = classPattern.exec(content)) !== null) {
      exports.push(match[1]);
    }
  } catch (e) {
    // File may not exist or be readable
  }
  return exports;
}
```

---

## Pattern: Query Predecessor Artifacts (v2.1)

Get artifacts from tasks that this task depends on.

```javascript
// QUERY_PREDECESSOR_ARTIFACTS_PATTERN
function getPredecessorArtifacts(specFolder, taskId) {
  const jsonPath = `${specFolder}/tasks.json`;
  const tasksJson = JSON.parse(readFileSync(jsonPath, 'utf8'));

  const task = tasksJson.tasks.find(t => t.id === taskId);
  if (!task || !task.parallelization) {
    return { predecessors: [], all_exports: [], all_files: [] };
  }

  const predecessorIds = task.parallelization.blocked_by || [];
  const predecessors = [];
  const allExports = [];
  const allFiles = [];

  for (const predId of predecessorIds) {
    const predTask = tasksJson.tasks.find(t => t.id === predId);
    if (predTask && predTask.artifacts) {
      predecessors.push({
        task_id: predId,
        description: predTask.description,
        artifacts: predTask.artifacts
      });
      allExports.push(...(predTask.artifacts.exports_added || []));
      allFiles.push(
        ...(predTask.artifacts.files_created || []),
        ...(predTask.artifacts.files_modified || [])
      );
    }
  }

  return {
    predecessors,
    all_exports: [...new Set(allExports)],
    all_files: [...new Set(allFiles)]
  };
}
```

---

## Pattern: Verify Predecessor Outputs (v2.1)

Verify that expected outputs from predecessor tasks actually exist.

```javascript
// VERIFY_PREDECESSOR_OUTPUTS_PATTERN
function verifyPredecessorOutputs(specFolder, taskId) {
  const { predecessors, all_exports, all_files } = getPredecessorArtifacts(specFolder, taskId);

  const verification = {
    verified: true,
    missing_files: [],
    missing_exports: [],
    warnings: []
  };

  // 1. Verify files exist
  for (const file of all_files) {
    if (!existsSync(file)) {
      verification.verified = false;
      verification.missing_files.push(file);
    }
  }

  // 2. Verify exports exist (grep for them in files)
  for (const exportName of all_exports) {
    // Quick grep to verify export exists
    try {
      const result = execSync(
        `grep -r "export.*${exportName}" --include="*.ts" --include="*.js" --include="*.py" src/ 2>/dev/null || true`
      ).toString();
      if (!result.trim()) {
        verification.warnings.push(`Export '${exportName}' not found in codebase - may need live verification`);
      }
    } catch (e) {
      verification.warnings.push(`Could not verify export '${exportName}'`);
    }
  }

  return verification;
}
```

---

## Usage in Commands

Reference these patterns:

```markdown
## Task JSON Sync

Use patterns from @shared/task-json.md:
- Parse markdown: MARKDOWN_TO_JSON_PATTERN
- Sync to JSON: SYNC_TASKS_PATTERN
- Update metadata: UPDATE_TASK_METADATA_PATTERN
- Query status: QUERY_TASKS_PATTERN
- Analyze parallelization: ANALYZE_PARALLELIZATION_PATTERN (v2.0)
- Query parallel status: QUERY_PARALLEL_STATUS_PATTERN (v2.0)
- Collect artifacts: COLLECT_ARTIFACTS_PATTERN (v2.1)
- Query predecessors: QUERY_PREDECESSOR_ARTIFACTS_PATTERN (v2.1)
- Verify outputs: VERIFY_PREDECESSOR_OUTPUTS_PATTERN (v2.1)

Sync triggers:
- After checkbox change in tasks.md
- At session startup (validation)
- After task completion (with metadata and artifacts)

Parallel execution (v2.0):
- Generate waves at create-tasks time
- Query ready tasks at execute-tasks time
- Update wave status after each task completion

Artifact tracking (v2.1):
- Collect artifacts after task completion via git diff
- Query predecessor artifacts before starting dependent tasks
- Verify predecessor outputs exist before coding
- Replaces need for separate codebase-indexer
```
