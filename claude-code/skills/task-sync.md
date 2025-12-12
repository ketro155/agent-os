---
name: task-sync
description: Auto-invoke to synchronize tasks.json with tasks.md. Triggers when task checkboxes are modified, before commits, or when drift is detected. Maintains cross-task verification integrity.
allowed-tools:
  - Read
  - Write
  - Grep
  - Glob
  - Bash
---

# Task Sync Skill

## Purpose

Synchronize `tasks.json` with `tasks.md` (source of truth) to ensure accurate task tracking, artifact recording, and cross-task verification for Agent OS v2.1+.

**Problem This Solves:** Without active syncing, `tasks.json` can drift from `tasks.md` when:
- Tasks are executed outside `/execute-tasks` command
- Phase 2 update steps are skipped
- Manual edits are made to `tasks.md`

---

## When to Invoke

This skill should auto-invoke when:
- Task checkboxes are modified in `tasks.md` (detected via file changes)
- Before git commits that touch spec/task files
- At session startup (via session-startup skill)
- Before generating PRs (via Phase 3 gate)
- User explicitly requests sync

---

## Sync Protocol

### Step 1: Locate Task Files

```
ACTION: Find tasks.md and tasks.json for the target spec

SEARCH PATHS (in order):
  1. .agent-os/specs/[spec-name]/tasks.md  (preferred v2.0+ location)
  2. .agent-os/tasks/[spec-name]/tasks.md  (legacy location)

IF tasks.md not found:
  ERROR: "Cannot sync - tasks.md not found for spec: [spec-name]"
  HALT: Sync not possible

IF tasks.json not found:
  NOTE: "tasks.json missing - will create from tasks.md"
  SET: mode = "create"
ELSE:
  SET: mode = "sync"
```

### Step 2: Parse Source of Truth (tasks.md)

```
ACTION: Parse tasks.md to extract task statuses

PATTERN MATCHING:
  Parent tasks:  "- [x] N. Description" or "- [ ] N. Description"
  Subtasks:      "- [x] N.M Description" or "  - [x] N.M Description"

EXTRACT for each task:
  - id: Task number (e.g., "1", "1.2", "1.3")
  - type: "parent" or "subtask"
  - description: Task text
  - status: "pass" if [x], "pending" if [ ]
  - parent: Parent task ID (for subtasks)

CALCULATE:
  - completed_count: Number of tasks with [x]
  - total_count: Total tasks
  - progress_percent: (completed / total) * 100
```

### Step 3: Load Existing Metadata (if tasks.json exists)

```
IF mode == "sync":
  ACTION: Read tasks.json

  PRESERVE these fields from existing JSON:
    - started_at (when task began)
    - completed_at (when task finished)
    - duration_minutes (how long it took)
    - attempts (number of tries)
    - notes (implementation notes)
    - artifacts (v2.1 - files, exports created)
    - parallelization (v2.0 - wave assignments)

  REASON: Metadata is valuable context that shouldn't be lost during sync
```

### Step 4: Detect Drift

```
ACTION: Compare parsed MD status with JSON status

FOR each task in parsed_tasks:
  FIND: Corresponding task in tasks.json (by id)

  IF status differs:
    ADD: To drift_list
    NOTE: "[task_id]: MD=[status] vs JSON=[status]"

DRIFT SUMMARY:
  total_drift = len(drift_list)

  IF total_drift > 0:
    DISPLAY:
      "⚠️ Drift Detected: [total_drift] tasks out of sync
       ─────────────────────────────────────────
       [list first 5 drift items]
       ─────────────────────────────────────────"
```

### Step 5: Merge and Sync

```
ACTION: Create merged task list

FOR each task in parsed_tasks:
  IF existing metadata found:
    MERGE:
      - Use status from tasks.md (source of truth)
      - Keep metadata from tasks.json
      - If newly completed (status changed to "pass"):
        - Set completed_at = now() if not already set
        - Calculate duration if started_at exists
  ELSE:
    CREATE: New task entry with parsed data

CALCULATE parent task status:
  FOR each parent task:
    subtasks = tasks where parent == parent_id
    completed = count(subtasks where status == "pass")
    total = count(subtasks)

    IF completed == total AND total > 0:
      parent.status = "pass"
      parent.progress_percent = 100
    ELSE IF completed > 0:
      parent.status = "in_progress"
      parent.progress_percent = round((completed / total) * 100)
    ELSE:
      parent.status = "pending"
      parent.progress_percent = 0
```

### Step 6: Calculate Summary

```
ACTION: Generate summary statistics

summary = {
  total_tasks: count(all tasks),
  parent_tasks: count(tasks where type == "parent"),
  subtasks: count(tasks where type == "subtask"),
  completed: count(tasks where status == "pass"),
  in_progress: count(tasks where status == "in_progress"),
  blocked: count(tasks where status == "blocked"),
  pending: count(tasks where status == "pending"),
  overall_percent: round((completed / total) * 100)
}

IF execution_strategy exists:
  ADD: parallel_waves, max_parallelism to summary
```

### Step 7: Write Updated tasks.json

```
ACTION: Atomic write to tasks.json

JSON structure:
{
  "version": "2.1",
  "spec": "[spec-folder-name]",
  "spec_path": ".agent-os/specs/[spec-name]/",
  "created": "[original or now]",
  "updated": "[now]",
  "execution_strategy": [preserved if exists],
  "tasks": [merged_tasks],
  "summary": [calculated_summary]
}

WRITE PROTOCOL (atomic):
  1. Write to tasks.json.tmp
  2. Verify JSON is valid
  3. Rename tasks.json.tmp → tasks.json

DISPLAY: "✅ tasks.json synced - [completed]/[total] tasks ([percent]%)"
```

---

## Output Format

### Sync Success

```
✅ Task Sync Complete
─────────────────────────────────────────────────
Spec:     [spec-name]
Mode:     [create/sync]
Tasks:    [completed]/[total] ([percent]%)
Changes:  [drift_count] tasks updated
─────────────────────────────────────────────────
```

### Sync With Drift Correction

```
✅ Task Sync Complete (Drift Corrected)
─────────────────────────────────────────────────
Spec:     [spec-name]
Tasks:    [completed]/[total] ([percent]%)

Corrected [N] tasks:
  - Task 1.2: pending → pass
  - Task 1.3: pending → pass
  - Task 2: pending → in_progress
─────────────────────────────────────────────────
```

---

## Error Handling

| Error | Recovery |
|-------|----------|
| tasks.md not found | HALT - cannot sync without source |
| tasks.json corrupted | Delete and recreate from tasks.md |
| Write permission denied | WARN user, suggest manual fix |
| Atomic write failed | Restore from .tmp if exists |

---

## Integration Points

### With session-startup
Session startup calls this skill at Step 4.5 to validate/sync before work begins.

### With execute-tasks Phase 2
After each task completion (Step 7.10), this pattern should be invoked.

### With execute-tasks Phase 3
Gate at Step 9.7 requires sync validation before git workflow.

### With git commits
Can be triggered before commits to ensure accurate task state in repo.

---

## Example Usage

```
User: The tasks.json seems out of date

[task-sync skill invokes]

Reading tasks.md... found 45 tasks
Reading tasks.json... found 45 tasks with 12 marked pass
Comparing statuses...

⚠️ Drift Detected: 8 tasks out of sync
─────────────────────────────────────────
- Task 1.5: MD=pass, JSON=pending
- Task 1.6: MD=pass, JSON=pending
- Task 1.7: MD=pass, JSON=pending
- Task 2.1: MD=pass, JSON=pending
- Task 2.2: MD=pass, JSON=pending
─────────────────────────────────────────

Syncing...

✅ Task Sync Complete (Drift Corrected)
─────────────────────────────────────────────────
Spec:     multi-format-document-support
Tasks:    20/45 (44%)

Corrected 8 tasks:
  - Tasks 1.5-1.7: pending → pass
  - Tasks 2.1-2.6: pending → pass
─────────────────────────────────────────────────
```
