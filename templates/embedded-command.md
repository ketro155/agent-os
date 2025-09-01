---
id: command-name
version: 2.0.0
description: What this command does
metadata:
  author: system
  category: [workflow|analysis|development|infrastructure]
  complexity: [simple|moderate|complex]
  migrated_from:
    command: path/to/old/command.md
    instructions: [path/to/instruction1.md, path/to/instruction2.md]
    
dependencies:
  subagents: []
  external_tools: []
  embedded_standards: []
  
configuration:
  cacheable: true
  timeout: 300
  parallel_safe: false
  
hooks:
  session_start: optional
  pre_execution: optional  
  post_execution: optional
  error_handling: optional
  
cross_references:
  meta_instructions: [pre-flight, post-flight]
  utilities: [spec-validation]
  standards: [code-style, best-practices]
  
language_support:
  patterns: 
    js: ["function", "export", "class", "const.*=.*=>"]
    ts: ["function", "export", "class", "interface", "type", "const.*=.*=>"]
    py: ["def ", "class ", "import ", "from "]
    rb: ["def ", "class ", "module "]
    go: ["func ", "type ", "interface "]
    rs: ["fn ", "struct ", "impl ", "trait "]
    java: ["public ", "private ", "protected ", "class ", "interface "]
    cs: ["public ", "private ", "protected ", "class ", "interface "]

resolution_strategy:
  pre_flight: embedded  # How to handle pre-flight references
  post_flight: embedded # How to handle post-flight references
  validation: hook      # How to handle validation references
  cross_refs: inline    # How to handle cross-references
---

# Command Name

## Overview
Brief description of what this command accomplishes.

## Prerequisites
- List any requirements
- Environment setup needed
- Dependencies that must be installed

## Workflow

### Phase 1: Initialization
Step-by-step instructions...

### Phase 2: Execution  
Main workflow logic...

### Phase 3: Validation
Verification and cleanup...

## Error Handling
What to do when things go wrong.

## Examples
Common usage patterns.

## Troubleshooting
Known issues and solutions.