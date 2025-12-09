# Execute Tasks - Phase 0: Session Startup

Pre-flight checks and session initialization. Loaded only at session start.

---

## Phase 0: Session Startup (Pre-Flight Check)

### Step 0: Session Startup Protocol
The session-startup skill auto-invokes to verify environment and load cross-session context.

**Instructions:**
```
ACTION: session-startup skill auto-invokes
PURPOSE: Verify environment and establish session context
PROTOCOL:
  1. Directory verification (confirm project root)
  2. Progress context load (read recent progress entries)
  3. Git state review (branch, uncommitted changes)
  4. Task status check (current spec progress)
  5. Environment health (dev server, config files)
  6. Session focus confirmation (confirm task selection)

WAIT: For startup protocol completion
OUTPUT: Session startup summary with suggested task

IF startup fails:
  DISPLAY: Error details and recovery suggestions
  HALT: Do not proceed until environment verified
```

**Benefits:**
- Cross-session context automatically loaded
- Unresolved blockers highlighted before work begins
- Environment issues caught early
- Task selection informed by progress history

**See**: `.claude/skills/session-startup.md` for full protocol details

---

## Phase Completion

After Phase 0 completes:
1. Environment verified
2. Progress context loaded
3. Task selection confirmed
4. Ready to proceed to Phase 1

**Next Phase**: Load `execute-phase1.md` for task discovery and setup
