---
description: Context-efficient debugging with session continuity and smart analysis
globs:
alwaysApply: false
version: 1.0
encoding: UTF-8
---

# Debug Issue Instructions

Debug code issues, test failures, or behavioral problems with intelligent context management.

<pre_flight_check>
  EXECUTE: @.agent-os/instructions/meta/pre-flight.md
</pre_flight_check>

<process_flow>

<step number="1" name="session_continuity_check" priority="FIRST">

### Step 1: Check for Session Continuity

Handle debugging session continuity and context restoration.

<session_restoration>
  IF --continue flag provided with debug-session-state.md:
    LOAD: Previous debugging context from state file
    RESTORE:
      - Issue description and classification
      - Files and functions already analyzed
      - Attempted fixes and results
      - Current debugging hypothesis
      - Context already loaded
    SKIP: Redundant analysis steps
    CONTINUE: From last debugging checkpoint
  ELSE:
    START: Fresh debugging session
    PROCEED: To Step 2 for issue analysis
</session_restoration>

<state_file_structure>
  debug-session-state.md contains:
    ## Issue Summary
    - Problem description and symptoms
    - Error messages and logs
    - Affected components/modules
    
    ## Analysis Progress  
    - Files examined: [list]
    - Functions analyzed: [list]
    - Context loaded: [summary]
    - Current hypothesis: [description]
    
    ## Attempted Fixes
    - Fix 1: [description] → Result: [outcome]
    - Fix 2: [description] → Result: [outcome]
    
    ## Next Steps
    - Recommended actions: [list]
    - Additional context needed: [list]
    - Alternative approaches: [list]
</state_file_structure>

<instructions>
  PRIORITY: Restore previous context efficiently
  BENEFIT: Continue complex debugging without context loss
  FALLBACK: Start fresh analysis if state file invalid
</instructions>

</step>

<step number="2" name="smart_issue_classification" priority="MANDATORY">

### Step 2: Smart Issue Classification & Minimal Context Loading

Classify the issue and load only essential context for initial analysis.

<issue_classification>
  ANALYZE: Issue description and any error messages
  CLASSIFY:
    - ERROR_TYPE: [syntax, runtime, logic, performance, integration, test_failure]
    - SCOPE: [single_file, module, cross_module, system_wide]
    - URGENCY: [blocking, degraded_function, optimization, maintenance]
    - COMPLEXITY: [simple_fix, moderate_investigation, architectural_change]
  
  SMART_FILTERING:
    IF simple syntax/import error:
      CONTEXT: Load only erroring files
    IF test failure:
      CONTEXT: Load test files + related source files
    IF performance issue:
      CONTEXT: Load profiling data + performance-critical paths
    IF integration issue:
      CONTEXT: Load interface definitions + integration points
</issue_classification>

<minimal_context_strategy>
  PHASE_1_CONTEXT (always load):
    - Error logs and stack traces
    - Directly mentioned files in error messages
    - Recent git changes (if relevant to issue timeline)
  
  PHASE_2_CONTEXT (conditional loading):
    IF Phase 1 insufficient for diagnosis:
      - Related test files
      - Function signatures from codebase-indexer
      - Spec sections for affected functionality
  
  PHASE_3_CONTEXT (progressive expansion):
    IF Phase 2 insufficient:
      - Integration patterns from standards
      - Similar implementations from codebase
      - Architectural context from project docs
</minimal_context_strategy>

<context_efficiency_rules>
  RULE_1: Never load entire codebase at once
  RULE_2: Use codebase-indexer summaries before reading full files
  RULE_3: Load context incrementally based on debugging findings
  RULE_4: Cache loaded context for entire debugging session
  RULE_5: Create session state before approaching context limits
</context_efficiency_rules>

<instructions>
  ACTION: Classify issue type and scope
  LOAD: Only Phase 1 context initially
  ANALYZE: Error patterns and symptoms
  EXPAND: Context only as needed for hypothesis testing
  BENEFIT: 70% faster initial analysis, preserved context for complex issues
</instructions>

</step>

<step number="3" name="hypothesis_driven_analysis" priority="CORE">

### Step 3: Hypothesis-Driven Analysis

Form debugging hypotheses and test them systematically with targeted context loading.

<hypothesis_formation>
  BASED_ON: Issue classification and minimal context
  GENERATE: 2-3 most likely root cause hypotheses
  PRIORITIZE: By likelihood and ease of testing
  
  HYPOTHESIS_TEMPLATE:
    - Root Cause: [specific technical cause]
    - Evidence: [symptoms that support this theory]
    - Test Method: [how to verify/disprove]
    - Context Needed: [additional files/info required]
    - Fix Complexity: [simple, moderate, complex]
</hypothesis_formation>

<targeted_investigation>
  FOR each hypothesis (highest priority first):
    LOAD_CONTEXT: Only files/sections needed to test this hypothesis
    ANALYZE: Evidence for/against hypothesis
    TEST: Apply minimal test changes if safe
    DOCUMENT: Findings and evidence
    
    IF hypothesis confirmed:
      PROCEED: To Step 4 (Resolution)
    ELSE:
      NEXT: Try next hypothesis
      
    IF context approaching limits:
      CREATE: debug-session-state.md
      RECOMMEND: Continue in new session
</targeted_investigation>

<smart_context_usage>
  CONTEXT_BUDGET_TRACKING:
    - Monitor context usage throughout analysis
    - Prioritize most critical files for full loading
    - Use summaries and grep results when possible
    - Reserve context for solution implementation
  
  CONTEXT_SHARING:
    - Reuse context between hypothesis tests
    - Cache function signatures and patterns
    - Share loaded specs across related investigations
</smart_context_usage>

<instructions>
  STRATEGY: Test hypotheses systematically with minimal context
  MONITORING: Track context usage to prevent exhaustion
  EFFICIENCY: Load context incrementally based on findings
  ESCALATION: Create session state if investigation becomes complex
</instructions>

</step>

<step number="4" name="context_aware_resolution" priority="SOLUTION">

### Step 4: Context-Aware Resolution

Apply fixes using existing context and established patterns, with session handoff if needed.

<resolution_strategies>
  IMMEDIATE_FIXES (use cached context):
    - Apply common fix patterns from codebase-indexer
    - Use spec requirements for compliance corrections
    - Reference successful implementations for consistency
    - Leverage standards for style/pattern conformance
  
  CONTEXT_EXPANSION_FIXES (load additional context if needed):
    - Load related modules for integration fixes
    - Access test patterns for comprehensive testing
    - Reference architectural patterns for complex changes
  
  SESSION_HANDOFF (if context limits approached):
    - Document current debugging state in debug-session-state.md
    - Include specific fix recommendations
    - Provide context preservation instructions
    - Create clear next steps for new session
</resolution_strategies>

<fix_application>
  VALIDATION_FIRST:
    - Ensure fix aligns with specifications
    - Check against existing codebase patterns
    - Validate impact on related functionality
  
  IMPLEMENTATION:
    - Apply fix with appropriate error handling
    - Update related tests if necessary
    - Maintain consistency with project standards
    - Document reasoning in code comments
  
  VERIFICATION:
    - Run relevant tests to confirm fix
    - Check for regressions in related areas
    - Validate against original issue symptoms
</fix_application>

<session_state_creation>
  IF context usage > 80% of limit:
    CREATE: debug-session-state.md with:
      - Complete issue analysis summary
      - Confirmed root cause and evidence
      - Partial implementation status
      - Recommended completion steps
      - Critical context references
      - Test validation requirements
</session_state_creation>

<instructions>
  PRIORITY: Apply fixes using existing context first
  EXPANSION: Load additional context only if essential for solution
  HANDOFF: Create detailed session state if context limits approached
  VALIDATION: Test fixes thoroughly before marking complete
  BENEFIT: Efficient resolution with seamless session continuity
</instructions>

</step>

<step number="5" name="debugging_summary_and_prevention" priority="FINAL">

### Step 5: Summary and Prevention Recommendations

Document debugging outcomes and suggest prevention measures.

<debugging_summary>
  DOCUMENT:
    - Root cause identification and evidence
    - Resolution approach and implementation
    - Context efficiency metrics (files loaded, time taken)
    - Session continuity usage (if applicable)
  
  LESSONS_LEARNED:
    - Patterns that led to the issue
    - Detection methods for similar issues
    - Prevention strategies for the future
    - Architectural improvements to consider
</debugging_summary>

<prevention_recommendations>
  IMMEDIATE_IMPROVEMENTS:
    - Test coverage gaps revealed by debugging
    - Code patterns that should be standardized
    - Documentation updates needed
  
  LONG_TERM_IMPROVEMENTS:
    - Architectural changes to prevent issue class
    - Monitoring/alerting for early detection
    - Development process improvements
</prevention_recommendations>

<session_cleanup>
  IF debug-session-state.md was created and used:
    ARCHIVE: State file to .debug-sessions/ directory
    CLEAN: Temporary debugging files
    PRESERVE: Important context discoveries in codebase index
</session_cleanup>

<instructions>
  ACTION: Summarize debugging process and outcomes
  DOCUMENT: Prevention strategies and lessons learned
  CLEANUP: Session state files and temporary debugging artifacts
  BENEFIT: Improved debugging efficiency over time, reduced recurring issues
</instructions>

</step>

</process_flow>

<post_flight_check>
  EXECUTE: @.agent-os/instructions/meta/post-flight.md
</post_flight_check>