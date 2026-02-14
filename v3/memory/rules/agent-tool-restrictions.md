# Agent Tool Restrictions (v5.4.0)

> Standardized approach for restricting agent capabilities through tool access control.
> Ensures consistent security posture across all Agent OS agents.

## Overview

Agent OS uses **four complementary mechanisms** for tool access control:

| Mechanism | Type | Purpose | When to Use |
|-----------|------|---------|-------------|
| `tools:` | Positive list | Define available tools | **Always** - primary restriction |
| `disallowedTools:` | Negative list | Defense-in-depth | Security-critical agents only |
| `Task(types)` | Spawn restriction | Limit spawnable agent types | Orchestrators with `Task` tool (v4.12.0) |
| `teammate_restrictions` | Team restriction | Limit spawnable teammate types | Team leads with `TeamCreate` tool (v5.1.0) |

## Primary Mechanism: `tools:` (Positive List)

The `tools:` field in agent YAML frontmatter specifies **exactly which tools** the agent can use.

```yaml
---
name: my-agent
tools: Read, Grep, Glob  # Only these three tools are available
---
```

### Rules

1. **Always specify `tools:`** - Every agent must declare its tool requirements
2. **Principle of least privilege** - Only include tools the agent actually needs
3. **No wildcards** - Each tool must be explicitly listed

### Common Tool Sets by Agent Type

| Agent Type | Typical Tools | Notes |
|------------|---------------|-------|
| Read-only analysis | `Read, Grep, Glob` | Cannot modify filesystem |
| Implementation | `Read, Edit, Write, Bash, Grep, Glob` | Full development access |
| Orchestration | `Read, Bash, Grep, Glob, Task` | Spawns subagents |
| Team lead | `Read, Bash, TeamCreate, TeamDelete, SendMessage, TaskCreate, TaskUpdate, TaskList` | Coordinates teammates |
| Lightweight teammate | `Read, Bash, SendMessage` | Minimal tools for single purpose |
| Implementation teammate | `Read, Edit, Write, Bash, Grep, Glob, TodoWrite, SendMessage, TaskUpdate, TaskList, TaskGet` | Full dev + team tools (v5.2.0) |
| Semantic reviewer | `Read, Grep, Glob, SendMessage, TaskList, TaskGet` | Read-only + team coordination (v5.4.0) |
| Browser automation | `Read, Write, mcp__claude-in-chrome__*` | Chrome MCP tools |

## Secondary Mechanism: `disallowedTools:` (Defense-in-Depth)

The `disallowedTools:` field provides **additional security hardening** for agents that must never have certain capabilities, regardless of configuration errors.

```yaml
---
name: security-critical-agent
tools: Read, Grep
disallowedTools:
  - Write
  - Edit
  - Bash
  - NotebookEdit
---
```

### When to Use `disallowedTools:`

Use defense-in-depth ONLY when:

1. **Security-critical agents** - Agents that process untrusted input (e.g., PR review comments)
2. **Classification agents** - Agents that categorize data but should never modify it
3. **Analysis agents** - Agents that inspect code but should never change it

### Defense-in-Depth Agents

The following agents use both `tools:` and `disallowedTools:`:

| Agent | Purpose | `tools:` | `disallowedTools:` |
|-------|---------|----------|-------------------|
| `comment-classifier` | Classify PR comments | `Read` | `Write, Edit, Bash, NotebookEdit` |
| `future-classifier` | Classify future work items | `Read, Glob, Grep` | `Write, Edit, Bash, NotebookEdit` |
| `roadmap-integrator` | Determine roadmap placement | `Read, Grep` | `Write, Edit, Bash, NotebookEdit` |
| `code-reviewer` | Real-time semantic review | `Read, Grep, Glob, SendMessage, TaskList, TaskGet` | `Write, Edit, Bash, NotebookEdit` |

### Why Both?

```
┌─────────────────────────────────────────────────────────────────────┐
│                    DEFENSE-IN-DEPTH RATIONALE                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Scenario: Configuration error grants Write to classifier          │
│                                                                     │
│  Without disallowedTools:                                          │
│    tools: Read, Write  ← Bug allows Write                          │
│    → Agent CAN write files (security breach)                       │
│                                                                     │
│  With disallowedTools:                                             │
│    tools: Read, Write  ← Same bug                                  │
│    disallowedTools: Write, Edit, Bash                              │
│    → Write is BLOCKED despite being in tools (defense succeeds)    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Decision Tree

```
                        ┌─────────────────────────┐
                        │  Creating new agent?    │
                        └───────────┬─────────────┘
                                    │
                                    ▼
                        ┌─────────────────────────┐
                        │  Step 1: Define tools:  │
                        │  (ALWAYS required)      │
                        └───────────┬─────────────┘
                                    │
                                    ▼
                    ┌───────────────────────────────────┐
                    │  Does agent process untrusted    │
                    │  input (PR comments, external    │
                    │  data, user-provided content)?   │
                    └───────────────────────────────────┘
                           │                    │
                          YES                   NO
                           │                    │
                           ▼                    ▼
             ┌──────────────────────┐    ┌─────────────────┐
             │  Is agent read-only │    │  Done.          │
             │  (should NEVER      │    │  Only tools:    │
             │  modify files)?     │    │  is needed.     │
             └──────────────────────┘    └─────────────────┘
                    │            │
                   YES           NO
                    │            │
                    ▼            ▼
        ┌─────────────────┐  ┌─────────────────┐
        │  Add defense:   │  │  Done.          │
        │  disallowedTools│  │  Only tools:    │
        │  Write, Edit,   │  │  is needed.     │
        │  Bash, Notebook │  └─────────────────┘
        └─────────────────┘
```

## Examples

### Example 1: Standard Implementation Agent

```yaml
---
name: phase2-implementation
description: TDD implementation agent
tools: Read, Edit, Write, Bash, Grep, Glob, TodoWrite
---
```

**Rationale**: Implementation agents need full filesystem access. No defense-in-depth needed because they're expected to modify files.

### Example 2: Security-Critical Classifier

```yaml
---
name: comment-classifier
description: Classify PR review comments
tools: Read
model: haiku
disallowedTools:
  - Write
  - Edit
  - Bash
  - NotebookEdit
---
```

**Rationale**: Processes external PR comments (potential attack vector). Must never modify files, so defense-in-depth prevents configuration errors from causing security breaches.

### Example 3: Orchestration Agent

```yaml
---
name: wave-orchestrator
description: Orchestrates wave task execution
tools: Read, Bash, Grep, Glob, TodoWrite, Task, TaskOutput
---
```

**Rationale**: Orchestrators spawn subagents but don't directly implement. Bash is needed for validation commands. No defense-in-depth because it doesn't process untrusted external input.

## Anti-Patterns

### DON'T: Use disallowedTools without tools

```yaml
# BAD - No positive list
---
name: my-agent
disallowedTools:
  - Write
  - Edit
---
```

### DON'T: Add disallowedTools for non-security agents

```yaml
# BAD - Unnecessary defense-in-depth
---
name: phase2-implementation
tools: Read, Edit, Write, Bash
disallowedTools:
  - NotebookEdit  # Pointless - not a security concern
---
```

### DON'T: Include tool in both lists

```yaml
# BAD - Contradictory configuration
---
name: my-agent
tools: Read, Write, Grep
disallowedTools:
  - Write  # Why is Write in both?
---
```

## Tertiary Mechanism: `Task(agent_type)` Spawn Restrictions (v4.12.0)

The `Task(types)` syntax restricts which agent types an orchestrator can spawn via the `Task` tool. This applies the principle of least privilege to agent spawning.

```yaml
---
name: my-orchestrator
tools: Read, Bash, Task(worker-a, worker-b)  # Can ONLY spawn worker-a and worker-b
---
```

### When to Use

Use `Task(types)` when an agent has `Task` in its tools list and only spawns specific agent types.

### Current Spawn Restrictions

| Agent | Allowed Spawns | Rationale |
|-------|---------------|-----------|
| `execute-spec-orchestrator` | `Task(wave-lifecycle-agent)` | Only spawns wave agents |
| `wave-orchestrator` | `Task(phase2-implementation, subtask-group-worker, code-validator)` | Spawns implementation workers + deep reviewer |
| `wave-lifecycle-agent` | `Task(wave-orchestrator, phase3-delivery, general-purpose)` | Spawns orchestrator for execution, delivery for PR, general-purpose for review/E2E |
| `phase1-discovery` | `Task(Explore)` | Read-only codebase exploration |
| `pr-review-discovery` | `Task(comment-classifier, Explore)` | Classification and exploration |
| `test-discovery` | `Task(Explore)` | Read-only test pattern exploration |

### Current Teammate Restrictions (v5.1.0)

| Agent (Team Lead) | Allowed Teammates | Rationale |
|-------------------|-------------------|-----------|
| `wave-orchestrator` | `phase2-implementation`, `subtask-group-worker`, `code-reviewer` | Wave task execution + semantic review |
| `execute-spec-orchestrator` | `review-watcher` | PR review polling |

### Anti-Pattern: Unrestricted Task

```yaml
# BAD - Can spawn ANY agent type
---
name: my-orchestrator
tools: Read, Task
---

# GOOD - Restricted to known spawns
---
name: my-orchestrator
tools: Read, Task(specific-worker)
---
```

## Quaternary Mechanism: `teammate_restrictions` Convention (v5.1.0)

The `teammate_restrictions` convention documents which agent types a team lead may spawn as teammates. This mirrors `Task(types)` but applies to `TeamCreate` + teammate spawning.

```markdown
## Teammate Restrictions
teammate_restrictions: [phase2-implementation, subtask-group-worker]
```

### When to Use

Use `teammate_restrictions` when an agent uses `TeamCreate` and spawns teammates. Document this in the agent body (not frontmatter — it's advisory, not enforced by tooling).

### Example: Review Watcher Teammate

```yaml
---
name: review-watcher
description: Lightweight PR review poll agent
tools: Read, Bash, SendMessage
model: haiku
---
```

**Rationale**: Minimal tool set — only needs to read PR status (Bash for script execution), and notify the team lead (SendMessage). Cannot modify files, cannot spawn subagents. The `haiku` model keeps token cost low for this polling-only task.

## Model Strategy (v5.4.0)

Agent OS uses a **three-tier model assignment**:

| Tier | Model | When to Use | Agents |
|------|-------|-------------|--------|
| **Full** | Opus 4.6 (inherit default) | Complex reasoning, multi-step logic, critical decisions | 13 agents + code-validator |
| **Fast analysis** | Sonnet | Real-time semantic review, moderate reasoning | code-reviewer |
| **Lightweight** | Haiku | Simple classification, polling, low token overhead | 5 agents |

### Decision Tree

```
┌────────────────────────────────────────┐
│  Does the agent perform complex        │
│  reasoning or multi-step decisions?    │
└──────────────┬─────────────────────────┘
               │
          YES  │  NO
               │
               ▼
┌──────────────────────┐    ┌─────────────────────────────────┐
│  Use Opus (default)  │    │  Does it need moderate reasoning │
│  No model: override  │    │  with fast turnaround?           │
└──────────────────────┘    └──────────────┬──────────────────┘
                                      YES  │  NO
                                           │
                                    ┌──────┴──────┐
                                    │             │
                                    ▼             ▼
                              ┌──────────┐  ┌─────────────────────────┐
                              │ Sonnet   │  │  Is it a simple         │
                              │ model:   │  │  classifier or poller?  │
                              │ sonnet   │  └──────────┬──────────────┘
                              └──────────┘        YES  │  NO
                                                       │
                                                ┌──────┴──────┐
                                                │             │
                                                ▼             ▼
                                          ┌──────────┐  ┌──────────────┐
                                          │ Haiku    │  │ Opus         │
                                          │ model:   │  │ (default)    │
                                          │ haiku    │  └──────────────┘
                                          └──────────┘
```

### Current Model Assignments

| Agent | Model | Rationale |
|-------|-------|-----------|
| `comment-classifier` | haiku | Simple classification, defense-in-depth |
| `future-classifier` | haiku | Simple classification, defense-in-depth |
| `roadmap-integrator` | haiku | Simple scoring/placement |
| `review-watcher` | haiku | Single-purpose polling loop |
| `code-reviewer` | sonnet | Real-time semantic review, moderate reasoning (v5.4.0) |
| `code-validator` | Opus 4.6 | Deep cross-task analysis, complex reasoning (v5.4.0) |
| All other agents (13) | Opus 4.6 | Complex reasoning, multi-step logic |

### Fast Mode

Opus 4.6 supports **fast mode** (`/fast` toggle in Claude Code) for 2.5x faster output at premium pricing. This is useful for long-running workflows like `/execute-tasks` but is a user-level toggle, not an agent-level setting.

## Validation Checklist

When creating or reviewing an agent:

- [ ] `tools:` is defined (required)
- [ ] Tools follow principle of least privilege
- [ ] If agent processes untrusted input AND is read-only → add `disallowedTools:`
- [ ] `disallowedTools:` includes: Write, Edit, Bash, NotebookEdit
- [ ] No tool appears in both lists
- [ ] If agent uses `Task` → restrict with `Task(specific-types)` (v4.12.0)
- [ ] If agent spawns teammates → document `teammate_restrictions` in body (v5.1.0)
- [ ] Implementation teammates (`subtask-group-worker`, `phase2-implementation`) have team tools but note: `subtask-group-worker` intentionally has NO `memory: project` (lightweight, stateless) (v5.2.0)
- [ ] Model assignment follows three-tier strategy: Opus for reasoning, Sonnet for fast analysis, Haiku for classifiers/pollers (v5.4.0)

---

## Changelog

### v5.4.0 (2026-02-13)
- Expanded model strategy to three-tier (Opus + Sonnet + Haiku)
- Added code-reviewer to defense-in-depth agents table
- Added "Semantic reviewer" to Common Tool Sets table
- Updated wave-orchestrator spawn restrictions to include code-validator
- Updated wave-orchestrator teammate restrictions to include code-reviewer
- Added code-reviewer (Sonnet) and code-validator (Opus) to model assignments
- Updated decision tree with Sonnet branch
- Updated validation checklist for three-tier model strategy

### v5.3.0 (2026-02-12)
- Added Model Strategy section with two-tier assignment (Opus + Haiku)
- Added model decision tree and current assignments table
- Added fast mode documentation
- Added validation checklist item for model assignment

### v5.2.0 (2026-02-12)
- Added "Implementation teammate" entry to Common Tool Sets table
- Added validation checklist note: subtask-group-worker has team tools but no `memory: project`

### v5.1.0 (2026-02-09)
- Added `teammate_restrictions` convention for team lead agents
- Added review-watcher agent example (tools: Read, Bash, SendMessage; model: haiku)
- Added teammate restrictions table for wave-orchestrator and execute-spec-orchestrator
- Updated overview to four complementary mechanisms
- Updated common tool sets table with team lead and lightweight teammate types
- Updated validation checklist with teammate_restrictions check

### v4.12.0 (2026-02-06)
- Added `Task(agent_type)` spawn restriction mechanism
- Documented current spawn restrictions for 6 orchestrators
- Updated overview to three complementary mechanisms
- Added validation checklist item for Task restrictions

### v4.11.0 (2026-01-15)
- Initial standardized documentation
- Decision tree for when to use each mechanism
- Examples and anti-patterns
- Validation checklist
