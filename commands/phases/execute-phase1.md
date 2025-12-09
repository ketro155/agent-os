# Execute Tasks - Phase 1: Task Discovery and Setup

Task assignment, context gathering, and environment preparation. Loaded after Phase 0 completes.

---

## Phase 1: Task Discovery and Setup

### Step 1: Task Assignment
Identify which tasks to execute from the spec, defaulting to the next uncompleted parent task.

**Task Selection Logic:**
- **Explicit**: User specifies exact task(s) to execute
- **Implicit**: Find next uncompleted task in tasks.json

**Instructions:**
```
1. LOAD: tasks.json from spec folder (not tasks.md)
2. FIND: Next uncompleted parent task if not specified
3. EXTRACT: Task details including subtasks
4. CONFIRM: Task selection with user
```

### Step 1.5: Single-Task Enforcement (STRICT)

Based on Anthropic's research, single-task focus dramatically improves completion rate.

**Scope Detection:**
```
COUNT: Number of parent tasks selected for this session

IF parent_task_count == 1:
  PROCEED: Single task mode (optimal)
  MODE: "direct" (no orchestrator needed)

IF parent_task_count > 1:
  DISPLAY:
    "⚠️  Multiple Task Warning
     ─────────────────────────────────────────
     You've selected [count] parent tasks for this session.

     Research strongly recommends single-task focus:
     • Higher completion rate (73% vs 41%)
     • Better code quality
     • Cleaner context retention

     Single-task mode is the DEFAULT and RECOMMENDED approach.
     ─────────────────────────────────────────"

  ASK: "How would you like to proceed?"
  OPTIONS:
    1. Single task - Focus on [first_task_id] only (RECOMMENDED)
    2. Orchestrated - Use task-orchestrator for multiple tasks
    3. Override - Execute all in current session (not recommended)

  IF user selects option 1 (single task):
    SET: tasks_to_execute = [first_task]
    SET: execution_mode = "direct"
    PROCEED: With single task

  IF user selects option 2 (orchestrated):
    SET: tasks_to_execute = all_requested_tasks
    SET: execution_mode = "orchestrated"
    ACTION: Invoke task-orchestrator subagent
    DELEGATE: All execution to orchestrator
    SKIP: Phases 1-3 (orchestrator handles)

  IF user selects option 3 (override):
    LOG: scope_override entry to progress log
    SET: tasks_to_execute = all_requested_tasks
    SET: execution_mode = "direct_multi"
    WARN: "Proceeding with multiple tasks. Context may fill."
    PROCEED: With all tasks (user chose to override)
```

### Step 2: Get Current Date and Initialize Cache
Use the current date from environment context.

**Instructions:**
```
ACTION: Get today's date from environment context
NOTE: Claude Code provides "Today's date: YYYY-MM-DD" in every session
STORE: Date for cache metadata and file naming
```

### Step 3: Load Pre-computed Context (NEW)

Use context-summary.json instead of full spec discovery.

**Instructions:**
```
ACTION: Check for context-summary.json in spec folder
IF exists AND valid:
  LOAD: Context summary (lightweight)
  EXTRACT: Global context for session
  CACHE: In session-cache.json
  SKIP: Full spec discovery (Step 3-old)
ELSE:
  FALLBACK: Generate context summary now
  OR: Use original Explore agent discovery
```

**Context Summary Benefits:**
- ~73% reduction in context tokens
- Pre-computed, no discovery overhead
- Task-specific filtering already done

### Step 3-Alternative: Specification Discovery (Fallback)
Only use if context-summary.json doesn't exist.

```
ACTION: Use native Explore agent
REQUEST: "Perform specification discovery for project"
STORE: Spec index in session-cache.json
NOTE: This is slower than pre-computed summary
```

### Step 4: Initial Context Analysis
Load core documents for task understanding.

**Instructions:**
```
IF using context-summary.json:
  USE: global_context from summary
  SKIP: Document loading (already summarized)

ELSE (fallback):
  ACTION: Use Explore agent via Task tool to:
    - Get product pitch from mission-lite.md
    - Get spec summary from spec-lite.md
    - Get technical approach from technical-spec.md
  CACHE: In session-cache.json
```

### Step 5: Development Server Check
Check for running development server.

**Instructions:**
```
IF server_running on common ports (3000, 5173, 8000, 8080):
  ASK: "Development server detected. Shut down before proceeding?"
  WAIT: For user response
ELSE:
  PROCEED: Immediately
```

### Step 6: Git Branch Management
Set up or switch to correct feature branch.

**Instructions:**
```
ACTION: Use git-workflow subagent via Task tool
REQUEST: "Check and manage branch for spec: [SPEC_FOLDER]
          - Create branch if needed
          - Switch to correct branch
          - Handle any uncommitted changes"
WAIT: For branch setup completion
```

**Branch Naming:**
- Source: spec folder name
- Format: exclude date prefix
- Example: folder `2025-03-15-password-reset` → branch `password-reset`

### Step 6.5: Log Session Start
Log to persistent progress log.

**Instructions:**
```
ACTION: Append to progress log
ENTRY_TYPE: session_started
DATA:
  spec: [SPEC_FOLDER_NAME]
  focus_task: [SELECTED_TASK_ID]
  execution_mode: [direct|orchestrated|direct_multi]
  context: [BRIEF_CONTEXT]

FILE: .agent-os/progress/progress.json
PATTERN: Use PROGRESS_APPEND_PATTERN from @shared/progress-log.md
```

---

## Phase 1 Completion

After Phase 1 completes:
- Task(s) assigned and confirmed
- Execution mode determined (direct/orchestrated)
- Context loaded (from summary or discovery)
- Git branch set up
- Session start logged

**Branch Decision:**

```
IF execution_mode == "orchestrated":
  ACTION: Invoke task-orchestrator subagent
  DELEGATE: Phases 2 and 3 to orchestrator
  WAIT: For orchestrator completion
  SKIP: To Phase 3 completion steps

ELSE (direct modes):
  PROCEED: To Phase 2
  LOAD: execute-phase2.md for task execution
```

**Next Phase**: Load `execute-phase2.md` for task execution loop (if direct mode)
