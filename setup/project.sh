#!/bin/bash

# Agent OS Project Installation Script
# This script installs Agent OS in a project directory with embedded instructions

set -e  # Exit on error

# Version information - read from v3/settings.json as single source of truth
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_AGENT_OS="$(dirname "$SCRIPT_DIR")"

# Read version from settings.json (fallback to hardcoded if jq not available or file missing)
if command -v jq &> /dev/null && [ -f "$BASE_AGENT_OS/v3/settings.json" ]; then
    AGENT_OS_VERSION=$(jq -r '.env.AGENT_OS_VERSION // "5.2.0"' "$BASE_AGENT_OS/v3/settings.json")
else
    AGENT_OS_VERSION="5.2.0"
fi
AGENT_OS_RELEASE_DATE="2026-02-12"

# Track installation progress for cleanup
INSTALL_STARTED=false
DIRECTORIES_CREATED=()
FILES_CREATED=()

# Cleanup function for failed installations
cleanup_on_failure() {
    local exit_code=$?

    # Only cleanup if installation actually started and failed
    if [ "$INSTALL_STARTED" = true ] && [ $exit_code -ne 0 ]; then
        echo ""
        echo "⚠️  Installation failed! Cleaning up partial installation..."
        echo ""

        # Remove created files (in reverse order)
        for ((i=${#FILES_CREATED[@]}-1; i>=0; i--)); do
            if [ -f "${FILES_CREATED[$i]}" ]; then
                rm -f "${FILES_CREATED[$i]}" 2>/dev/null || true
                echo "   Removed: ${FILES_CREATED[$i]}"
            fi
        done

        # Remove created directories (in reverse order, only if empty)
        for ((i=${#DIRECTORIES_CREATED[@]}-1; i>=0; i--)); do
            if [ -d "${DIRECTORIES_CREATED[$i]}" ]; then
                rmdir "${DIRECTORIES_CREATED[$i]}" 2>/dev/null || true
            fi
        done

        echo ""
        echo "❌ Installation was rolled back. Please check the error above and try again."
        echo ""
        echo "If this problem persists, please report it at:"
        echo "https://github.com/buildermethods/agent-os/issues"
        echo ""
    fi

    # Clean up temp files if any
    rm -f /tmp/agent-os-functions-$$.sh 2>/dev/null || true
}

# Set trap to cleanup on error, interrupt, or termination
trap cleanup_on_failure EXIT INT TERM

# Helper function to track created directories
create_tracked_dir() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        DIRECTORIES_CREATED+=("$dir")
    fi
}

# Helper function to track created files
track_file() {
    local file="$1"
    FILES_CREATED+=("$file")
}

# Initialize flags
NO_BASE=false
OVERWRITE_INSTRUCTIONS=false
OVERWRITE_STANDARDS=false
CLAUDE_CODE=false
CURSOR=false
PROJECT_TYPE=""
WITH_HOOKS=false
UPGRADE=false
TARGET_DIR=""

# Legacy v2.x files to clean up when upgrading to v3
LEGACY_AGENTS=(
    "build-checker.md"
    "context-fetcher.md"
    "date-checker.md"
    "file-creator.md"
    "spec-cache-manager.md"
    "test-runner.md"
    "task-orchestrator.md"
    "codebase-indexer.md"
    "project-manager.md"
)

LEGACY_SKILLS=(
    "build-check.md"
    "test-check.md"
    "codebase-names.md"
    "systematic-debugging.md"
    "tdd.md"
    "brainstorming.md"
    "writing-plans.md"
    "session-startup.md"
    "implementation-verifier.md"
    "task-sync.md"
)

# Function to clean up legacy v2.x files
cleanup_legacy_v2_files() {
    local cleaned_count=0

    echo ""
    echo "🧹 Cleaning up legacy v2.x files..."

    # Clean up legacy agents
    if [ -d "./.claude/agents" ]; then
        for agent in "${LEGACY_AGENTS[@]}"; do
            if [ -f "./.claude/agents/${agent}" ]; then
                rm -f "./.claude/agents/${agent}"
                echo "  ✓ Removed agents/${agent}"
                cleaned_count=$((cleaned_count + 1))
            fi
        done
    fi

    # NOTE: v4.8.0+ uses skills directory - do NOT remove
    # Legacy v2.x skills were different format; v4.8.0 skills use SKILL.md in subdirectories

    # Clean up legacy phases directory (v3 uses native subagents)
    if [ -d "./.claude/commands/phases" ]; then
        local phase_count=$(find ./.claude/commands/phases -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
        if [ "$phase_count" -gt 0 ]; then
            rm -rf "./.claude/commands/phases"
            echo "  ✓ Removed commands/phases/ directory (${phase_count} files)"
            cleaned_count=$((cleaned_count + 1))
        fi
    fi

    # Clean up legacy shared modules (v3 doesn't use these)
    if [ -d "./.agent-os/shared" ]; then
        local shared_count=$(find ./.agent-os/shared -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
        if [ "$shared_count" -gt 0 ]; then
            rm -rf "./.agent-os/shared"
            echo "  ✓ Removed shared/ directory (${shared_count} files)"
            cleaned_count=$((cleaned_count + 1))
        fi
    fi

    # Clean up legacy commands that v3 doesn't use
    if [ -f "./.claude/commands/index-codebase.md" ]; then
        rm -f "./.claude/commands/index-codebase.md"
        echo "  ✓ Removed commands/index-codebase.md"
        cleaned_count=$((cleaned_count + 1))
    fi

    if [ $cleaned_count -eq 0 ]; then
        echo "  ✓ No legacy files found to clean up"
    else
        echo "  ✓ Cleaned up ${cleaned_count} legacy items"
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --no-base)
            NO_BASE=true
            shift
            ;;
        --overwrite-instructions)
            OVERWRITE_INSTRUCTIONS=true
            shift
            ;;
        --overwrite-standards)
            OVERWRITE_STANDARDS=true
            shift
            ;;
        --claude-code|--claude|--claude_code)
            CLAUDE_CODE=true
            shift
            ;;
        --cursor|--cursor-cli)
            CURSOR=true
            shift
            ;;
        --with-hooks)
            WITH_HOOKS=true
            shift
            ;;
        --upgrade)
            UPGRADE=true
            OVERWRITE_INSTRUCTIONS=true
            OVERWRITE_STANDARDS=true
            shift
            ;;
        --project-type=*)
            PROJECT_TYPE="${1#*=}"
            shift
            ;;
        --target=*)
            TARGET_DIR="${1#*=}"
            shift
            ;;
        --target)
            TARGET_DIR="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --claude-code               Add Claude Code support"
            echo "  --cursor                    Add Cursor support"
            echo "  --upgrade                   Upgrade existing installation (overwrites all files)"
            echo "  --target=PATH               Target project directory (default: current directory)"
            echo "  --with-hooks                Add additional validation hooks"
            echo "  --project-type=TYPE         Use specific project type for installation"
            echo "  --no-base                   Install from GitHub (not from a base installation)"
            echo "  --overwrite-instructions    Overwrite existing instruction files only"
            echo "  --overwrite-standards       Overwrite existing standards files only"
            echo "  -h, --help                  Show this help message"
            echo ""
            echo "Architecture:"
            echo "  Agent OS v5+ uses native Claude Code hooks, Teams integration,"
            echo "  single-source JSON tasks, and mandatory validation."
            echo ""
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo ""
echo "🚀 Agent OS Project Installation"
echo "================================"
echo ""

# Change to target directory if specified
if [ -n "$TARGET_DIR" ]; then
    if [ ! -d "$TARGET_DIR" ]; then
        echo "❌ Error: Target directory does not exist: $TARGET_DIR"
        exit 1
    fi
    cd "$TARGET_DIR"
    echo "📍 Target directory: $TARGET_DIR"
fi

# Get project directory info
CURRENT_DIR=$(pwd)
PROJECT_NAME=$(basename "$CURRENT_DIR")
INSTALL_DIR="./.agent-os"

echo "📍 Installing Agent OS to this project's root directory ($PROJECT_NAME)"
echo ""

# Determine if running from base installation or GitHub
if [ "$NO_BASE" = true ]; then
    IS_FROM_BASE=false
    echo "📦 Installing directly from GitHub (no base installation)"
    # Set BASE_URL for GitHub downloads
    BASE_URL="https://raw.githubusercontent.com/buildermethods/agent-os/main"
    # Download and source functions when running from GitHub
    TEMP_FUNCTIONS="/tmp/agent-os-functions-$$.sh"
    curl -sSL "${BASE_URL}/setup/functions.sh" -o "$TEMP_FUNCTIONS"
    source "$TEMP_FUNCTIONS"
    rm "$TEMP_FUNCTIONS"
else
    IS_FROM_BASE=true
    # SCRIPT_DIR and BASE_AGENT_OS are already set at the top of the file
    # before any cd commands, so they remain valid
    echo "✓ Using Agent OS base installation at $BASE_AGENT_OS"
    # Source shared functions from base installation
    source "$BASE_AGENT_OS/setup/functions.sh"
fi

echo ""
echo "📁 Creating project directories..."
echo ""

# Mark installation as started for cleanup tracking
INSTALL_STARTED=true

# Create directories with tracking for rollback
create_tracked_dir "$INSTALL_DIR"
create_tracked_dir "$INSTALL_DIR/state"
create_tracked_dir "$INSTALL_DIR/state/recovery"
create_tracked_dir "$INSTALL_DIR/standards"
create_tracked_dir "$INSTALL_DIR/progress"
create_tracked_dir "$INSTALL_DIR/progress/archive"
# v4.10.0: Context offloading directories
create_tracked_dir "$INSTALL_DIR/scratch"
create_tracked_dir "$INSTALL_DIR/scratch/tool_outputs"
create_tracked_dir "$INSTALL_DIR/scratch/subagents"
create_tracked_dir "$INSTALL_DIR/memory"
create_tracked_dir "$INSTALL_DIR/memory/pinned"
create_tracked_dir "$INSTALL_DIR/memory/sessions"
create_tracked_dir "$INSTALL_DIR/logs"

# Configure tools and project type based on installation type
if [ "$IS_FROM_BASE" = true ]; then
    # Auto-enable tools based on base config if no flags provided
    if [ "$CLAUDE_CODE" = false ]; then
        # Check if claude_code is enabled in base config
        if grep -q "claude_code:" "$BASE_AGENT_OS/config.yml" && \
           grep -A1 "claude_code:" "$BASE_AGENT_OS/config.yml" | grep -q "enabled: true"; then
            CLAUDE_CODE=true
            echo "  ✓ Auto-enabling Claude Code support (from Agent OS config)"
        fi
    fi

    if [ "$CURSOR" = false ]; then
        # Check if cursor is enabled in base config
        if grep -q "cursor:" "$BASE_AGENT_OS/config.yml" && \
           grep -A1 "cursor:" "$BASE_AGENT_OS/config.yml" | grep -q "enabled: true"; then
            CURSOR=true
            echo "  ✓ Auto-enabling Cursor support (from Agent OS config)"
        fi
    fi

    # Read project type from config or use flag
    if [ -z "$PROJECT_TYPE" ] && [ -f "$BASE_AGENT_OS/config.yml" ]; then
        # Try to read default_project_type from config
        PROJECT_TYPE=$(grep "^default_project_type:" "$BASE_AGENT_OS/config.yml" | cut -d' ' -f2 | tr -d ' ')
        if [ -z "$PROJECT_TYPE" ]; then
            PROJECT_TYPE="default"
        fi
    elif [ -z "$PROJECT_TYPE" ]; then
        PROJECT_TYPE="default"
    fi

    echo ""
    echo "📦 Using project type: $PROJECT_TYPE"

    # Determine source paths based on project type
    INSTRUCTIONS_SOURCE=""
    STANDARDS_SOURCE=""

    if [ "$PROJECT_TYPE" = "default" ]; then
        INSTRUCTIONS_SOURCE="$BASE_AGENT_OS/instructions"
        STANDARDS_SOURCE="$BASE_AGENT_OS/standards"
    else
        # Look up project type in config
        if grep -q "^  $PROJECT_TYPE:" "$BASE_AGENT_OS/config.yml"; then
            # Extract paths for this project type
            INSTRUCTIONS_PATH=$(awk "/^  $PROJECT_TYPE:/{f=1} f&&/instructions:/{print \$2; exit}" "$BASE_AGENT_OS/config.yml")
            STANDARDS_PATH=$(awk "/^  $PROJECT_TYPE:/{f=1} f&&/standards:/{print \$2; exit}" "$BASE_AGENT_OS/config.yml")

            # Expand tilde in paths
            INSTRUCTIONS_SOURCE=$(eval echo "$INSTRUCTIONS_PATH")
            STANDARDS_SOURCE=$(eval echo "$STANDARDS_PATH")

            # Check if paths exist
            if [ ! -d "$INSTRUCTIONS_SOURCE" ] || [ ! -d "$STANDARDS_SOURCE" ]; then
                echo "  ⚠️  Project type '$PROJECT_TYPE' paths not found, falling back to default instructions and standards"
                INSTRUCTIONS_SOURCE="$BASE_AGENT_OS/instructions"
                STANDARDS_SOURCE="$BASE_AGENT_OS/standards"
            fi
        else
            echo "  ⚠️  Project type '$PROJECT_TYPE' not found in config, using default instructions and standards"
            INSTRUCTIONS_SOURCE="$BASE_AGENT_OS/instructions"
            STANDARDS_SOURCE="$BASE_AGENT_OS/standards"
        fi
    fi

    # Copy only standards from determined sources (instructions are now embedded in commands)
    echo ""
    echo "📥 Installing standards files to $INSTALL_DIR/standards/"
    copy_directory "$STANDARDS_SOURCE" "$INSTALL_DIR/standards" "$OVERWRITE_STANDARDS"
    
    # Note: Instructions are now embedded in commands, no need to copy separately
else
    # Running directly from GitHub - download from GitHub
    if [ -z "$PROJECT_TYPE" ]; then
        PROJECT_TYPE="default"
    fi

    echo "📦 Using project type: $PROJECT_TYPE (default when installing from GitHub)"

    # Install instructions and standards from GitHub (no commands folder needed)
    install_from_github "$INSTALL_DIR" "$OVERWRITE_INSTRUCTIONS" "$OVERWRITE_STANDARDS" false
fi

# Handle Claude Code installation for project
if [ "$CLAUDE_CODE" = true ]; then
    echo ""
    if [ "$UPGRADE" = true ]; then
        echo "📥 Upgrading Claude Code support..."
    else
        echo "📥 Installing Claude Code support..."
    fi

    # Determine overwrite setting for Claude Code files
    OVERWRITE_CLAUDE="false"
    if [ "$UPGRADE" = true ] || [ "$OVERWRITE_INSTRUCTIONS" = true ]; then
        OVERWRITE_CLAUDE="true"
    fi

    echo "  📦 Using v4 architecture (native hooks, single-source JSON)"

    # Clean up legacy v2.x files during upgrade
    if [ "$UPGRADE" = true ]; then
        cleanup_legacy_v2_files
    fi

    echo ""

    create_tracked_dir "./.claude"
    create_tracked_dir "./.claude/commands"
    create_tracked_dir "./.claude/agents"
    create_tracked_dir "./.claude/hooks"
    create_tracked_dir "./.claude/scripts"
    create_tracked_dir "./.claude/rules"
    create_tracked_dir "./.claude/skills"
    create_tracked_dir "./.claude/skills/artifact-verification"
    create_tracked_dir "./.claude/skills/context-summary"
    create_tracked_dir "./.claude/skills/tdd-helper"
    create_tracked_dir "./.claude/skills/subtask-expansion"
    create_tracked_dir "./.claude/skills/log-entry"
    # v4.10.0: Context offloading skills
    create_tracked_dir "./.claude/skills/context-read"
    create_tracked_dir "./.claude/skills/context-search"
    create_tracked_dir "./.claude/skills/context-stats"
    create_tracked_dir "./.claude/templates"
    create_tracked_dir "./.claude/templates/specs"
    create_tracked_dir "./.claude/templates/tasks"
    create_tracked_dir "./.claude/templates/test-scenarios"

    if [ "$IS_FROM_BASE" = true ]; then
        # Install commands
        echo "  📂 Commands:"
        for cmd in plan-product shape-spec create-spec create-tasks analyze-product debug; do
            if [ -f "$BASE_AGENT_OS/v3/commands/${cmd}.md" ]; then
                copy_file "$BASE_AGENT_OS/v3/commands/${cmd}.md" "./.claude/commands/${cmd}.md" "$OVERWRITE_CLAUDE" "commands/${cmd}.md"
            fi
        done
        if [ -f "$BASE_AGENT_OS/v3/commands/execute-tasks.md" ]; then
            copy_file "$BASE_AGENT_OS/v3/commands/execute-tasks.md" "./.claude/commands/execute-tasks.md" "$OVERWRITE_CLAUDE" "commands/execute-tasks.md"
        fi
        if [ -f "$BASE_AGENT_OS/v3/commands/pr-review-cycle.md" ]; then
            copy_file "$BASE_AGENT_OS/v3/commands/pr-review-cycle.md" "./.claude/commands/pr-review-cycle.md" "$OVERWRITE_CLAUDE" "commands/pr-review-cycle.md"
        fi
        if [ -f "$BASE_AGENT_OS/v3/commands/execute-spec.md" ]; then
            copy_file "$BASE_AGENT_OS/v3/commands/execute-spec.md" "./.claude/commands/execute-spec.md" "$OVERWRITE_CLAUDE" "commands/execute-spec.md"
        fi
        # Browser testing commands (v4.6)
        if [ -f "$BASE_AGENT_OS/v3/commands/create-test-plan.md" ]; then
            copy_file "$BASE_AGENT_OS/v3/commands/create-test-plan.md" "./.claude/commands/create-test-plan.md" "$OVERWRITE_CLAUDE" "commands/create-test-plan.md"
        fi
        if [ -f "$BASE_AGENT_OS/v3/commands/run-tests.md" ]; then
            copy_file "$BASE_AGENT_OS/v3/commands/run-tests.md" "./.claude/commands/run-tests.md" "$OVERWRITE_CLAUDE" "commands/run-tests.md"
        fi

        # Install agents (phase subagents + utility agents)
        echo ""
        echo "  📂 Agents:"
        for agent in phase1-discovery phase2-implementation phase3-delivery wave-orchestrator subtask-group-worker pr-review-discovery pr-review-implementation future-classifier comment-classifier roadmap-integrator git-workflow project-manager execute-spec-orchestrator wave-lifecycle-agent test-discovery test-executor test-reporter review-watcher; do
            if [ -f "$BASE_AGENT_OS/v3/agents/${agent}.md" ]; then
                copy_file "$BASE_AGENT_OS/v3/agents/${agent}.md" "./.claude/agents/${agent}.md" "$OVERWRITE_CLAUDE" "agents/${agent}.md"
            fi
        done

        # Install hooks (mandatory validation + subagent lifecycle v4.8.0)
        echo ""
        echo "  📂 Hooks:"
        for hook in session-start session-end post-file-change pre-commit-gate subagent-start subagent-stop setup task-completed; do
            if [ -f "$BASE_AGENT_OS/v3/hooks/${hook}.sh" ]; then
                copy_file "$BASE_AGENT_OS/v3/hooks/${hook}.sh" "./.claude/hooks/${hook}.sh" "$OVERWRITE_CLAUDE" "hooks/${hook}.sh"
                chmod +x "./.claude/hooks/${hook}.sh"
            fi
        done

        # Install scripts
        echo ""
        echo "  📂 Scripts:"
        if [ -f "$BASE_AGENT_OS/v3/scripts/task-operations.sh" ]; then
            copy_file "$BASE_AGENT_OS/v3/scripts/task-operations.sh" "./.claude/scripts/task-operations.sh" "$OVERWRITE_CLAUDE" "scripts/task-operations.sh"
            chmod +x "./.claude/scripts/task-operations.sh"
        fi
        if [ -f "$BASE_AGENT_OS/v3/scripts/pr-review-operations.sh" ]; then
            copy_file "$BASE_AGENT_OS/v3/scripts/pr-review-operations.sh" "./.claude/scripts/pr-review-operations.sh" "$OVERWRITE_CLAUDE" "scripts/pr-review-operations.sh"
            chmod +x "./.claude/scripts/pr-review-operations.sh"
        fi
        if [ -f "$BASE_AGENT_OS/v3/scripts/json-to-markdown.js" ]; then
            copy_file "$BASE_AGENT_OS/v3/scripts/json-to-markdown.js" "./.claude/scripts/json-to-markdown.js" "$OVERWRITE_CLAUDE" "scripts/json-to-markdown.js"
        fi
        if [ -f "$BASE_AGENT_OS/v3/scripts/branch-setup.sh" ]; then
            copy_file "$BASE_AGENT_OS/v3/scripts/branch-setup.sh" "./.claude/scripts/branch-setup.sh" "$OVERWRITE_CLAUDE" "scripts/branch-setup.sh"
            chmod +x "./.claude/scripts/branch-setup.sh"
        fi
        if [ -f "$BASE_AGENT_OS/v3/scripts/execute-spec-operations.sh" ]; then
            copy_file "$BASE_AGENT_OS/v3/scripts/execute-spec-operations.sh" "./.claude/scripts/execute-spec-operations.sh" "$OVERWRITE_CLAUDE" "scripts/execute-spec-operations.sh"
            chmod +x "./.claude/scripts/execute-spec-operations.sh"
        fi
        # Browser testing scripts (v4.6)
        if [ -f "$BASE_AGENT_OS/v3/scripts/test-operations.sh" ]; then
            copy_file "$BASE_AGENT_OS/v3/scripts/test-operations.sh" "./.claude/scripts/test-operations.sh" "$OVERWRITE_CLAUDE" "scripts/test-operations.sh"
            chmod +x "./.claude/scripts/test-operations.sh"
        fi
        if [ -f "$BASE_AGENT_OS/v3/scripts/test-plan-to-markdown.js" ]; then
            copy_file "$BASE_AGENT_OS/v3/scripts/test-plan-to-markdown.js" "./.claude/scripts/test-plan-to-markdown.js" "$OVERWRITE_CLAUDE" "scripts/test-plan-to-markdown.js"
        fi
        if [ -f "$BASE_AGENT_OS/v3/scripts/test-report-to-markdown.js" ]; then
            copy_file "$BASE_AGENT_OS/v3/scripts/test-report-to-markdown.js" "./.claude/scripts/test-report-to-markdown.js" "$OVERWRITE_CLAUDE" "scripts/test-report-to-markdown.js"
        fi
        # v4.9.0 scripts
        if [ -f "$BASE_AGENT_OS/v3/scripts/ast-verify.ts" ]; then
            copy_file "$BASE_AGENT_OS/v3/scripts/ast-verify.ts" "./.claude/scripts/ast-verify.ts" "$OVERWRITE_CLAUDE" "scripts/ast-verify.ts"
        fi
        if [ -f "$BASE_AGENT_OS/v3/scripts/wave-parallel.ts" ]; then
            copy_file "$BASE_AGENT_OS/v3/scripts/wave-parallel.ts" "./.claude/scripts/wave-parallel.ts" "$OVERWRITE_CLAUDE" "scripts/wave-parallel.ts"
        fi
        # v4.9.0 Ralph Wiggum verification loop
        if [ -f "$BASE_AGENT_OS/v3/scripts/verification-loop.ts" ]; then
            copy_file "$BASE_AGENT_OS/v3/scripts/verification-loop.ts" "./.claude/scripts/verification-loop.ts" "$OVERWRITE_CLAUDE" "scripts/verification-loop.ts"
        fi
        # v4.10.0 Secret redaction utility
        if [ -f "$BASE_AGENT_OS/v3/scripts/redact-secrets.sh" ]; then
            copy_file "$BASE_AGENT_OS/v3/scripts/redact-secrets.sh" "./.claude/scripts/redact-secrets.sh" "$OVERWRITE_CLAUDE" "scripts/redact-secrets.sh"
            chmod +x "./.claude/scripts/redact-secrets.sh"
        fi
        # v4.11.0 E2E utilities and test pattern discovery
        if [ -f "$BASE_AGENT_OS/v3/scripts/e2e-utils.ts" ]; then
            copy_file "$BASE_AGENT_OS/v3/scripts/e2e-utils.ts" "./.claude/scripts/e2e-utils.ts" "$OVERWRITE_CLAUDE" "scripts/e2e-utils.ts"
        fi
        if [ -f "$BASE_AGENT_OS/v3/scripts/test-patterns.ts" ]; then
            copy_file "$BASE_AGENT_OS/v3/scripts/test-patterns.ts" "./.claude/scripts/test-patterns.ts" "$OVERWRITE_CLAUDE" "scripts/test-patterns.ts"
        fi
        # v5.0.0 Dependency-first tasks: topological sort and migration
        if [ -f "$BASE_AGENT_OS/v3/scripts/compute-waves.ts" ]; then
            copy_file "$BASE_AGENT_OS/v3/scripts/compute-waves.ts" "./.claude/scripts/compute-waves.ts" "$OVERWRITE_CLAUDE" "scripts/compute-waves.ts"
        fi
        if [ -f "$BASE_AGENT_OS/v3/scripts/migrate-v3-to-v4.js" ]; then
            copy_file "$BASE_AGENT_OS/v3/scripts/migrate-v3-to-v4.js" "./.claude/scripts/migrate-v3-to-v4.js" "$OVERWRITE_CLAUDE" "scripts/migrate-v3-to-v4.js"
        fi

        # Install memory/rules
        echo ""
        echo "  📂 Memory:"
        if [ -f "$BASE_AGENT_OS/v3/memory/CLAUDE.md" ]; then
            copy_file "$BASE_AGENT_OS/v3/memory/CLAUDE.md" "./.claude/CLAUDE.md" "$OVERWRITE_CLAUDE" "CLAUDE.md"
        fi
        # v4.11.0: Environment variables documentation
        if [ -f "$BASE_AGENT_OS/v3/memory/ENV-VARS.md" ]; then
            copy_file "$BASE_AGENT_OS/v3/memory/ENV-VARS.md" "./.claude/ENV-VARS.md" "$OVERWRITE_CLAUDE" "ENV-VARS.md"
        fi
        for rule in tdd-workflow git-conventions execute-tasks error-handling verification-loop e2e-integration agent-tool-restrictions e2e-fixtures e2e-batch-checkpoint teams-integration; do
            if [ -f "$BASE_AGENT_OS/v3/memory/rules/${rule}.md" ]; then
                copy_file "$BASE_AGENT_OS/v3/memory/rules/${rule}.md" "./.claude/rules/${rule}.md" "$OVERWRITE_CLAUDE" "rules/${rule}.md"
            fi
        done

        # Install skills (v4.9.0 - hot-reloadable patterns, v4.10.0 - context offloading)
        echo ""
        echo "  📂 Skills:"
        for skill in artifact-verification context-summary tdd-helper subtask-expansion log-entry context-read context-search context-stats; do
            if [ -f "$BASE_AGENT_OS/v3/skills/${skill}/SKILL.md" ]; then
                copy_file "$BASE_AGENT_OS/v3/skills/${skill}/SKILL.md" "./.claude/skills/${skill}/SKILL.md" "$OVERWRITE_CLAUDE" "skills/${skill}/SKILL.md"
            fi
        done

        # Install templates (v4.9.0)
        echo ""
        echo "  📂 Templates:"
        # Spec templates
        for template in feature bugfix refactor integration; do
            if [ -f "$BASE_AGENT_OS/v3/templates/specs/${template}.md" ]; then
                copy_file "$BASE_AGENT_OS/v3/templates/specs/${template}.md" "./.claude/templates/specs/${template}.md" "$OVERWRITE_CLAUDE" "templates/specs/${template}.md"
            fi
        done
        # Task templates
        for template in api-endpoint react-component bugfix refactor; do
            if [ -f "$BASE_AGENT_OS/v3/templates/tasks/${template}.json" ]; then
                copy_file "$BASE_AGENT_OS/v3/templates/tasks/${template}.json" "./.claude/templates/tasks/${template}.json" "$OVERWRITE_CLAUDE" "templates/tasks/${template}.json"
            fi
        done
        # Test scenario templates
        for template in authentication form-validation crud-operations; do
            if [ -f "$BASE_AGENT_OS/v3/templates/test-scenarios/${template}.json" ]; then
                copy_file "$BASE_AGENT_OS/v3/templates/test-scenarios/${template}.json" "./.claude/templates/test-scenarios/${template}.json" "$OVERWRITE_CLAUDE" "templates/test-scenarios/${template}.json"
            fi
        done

        # Install settings.json
        echo ""
        echo "  📂 Settings:"
        if [ -f "$BASE_AGENT_OS/v3/settings.json" ]; then
            copy_file "$BASE_AGENT_OS/v3/settings.json" "./.claude/settings.json" "$OVERWRITE_CLAUDE" "settings.json"
        fi

        # Install schema
        echo ""
        echo "  📂 Schemas:"
        create_tracked_dir "./.agent-os/schemas"
        if [ -f "$BASE_AGENT_OS/v3/schemas/tasks-v3.json" ]; then
            copy_file "$BASE_AGENT_OS/v3/schemas/tasks-v3.json" "./.agent-os/schemas/tasks-v3.json" "$OVERWRITE_CLAUDE" "schemas/tasks-v3.json"
        fi
        if [ -f "$BASE_AGENT_OS/v3/schemas/execute-spec-v1.json" ]; then
            copy_file "$BASE_AGENT_OS/v3/schemas/execute-spec-v1.json" "./.agent-os/schemas/execute-spec-v1.json" "$OVERWRITE_CLAUDE" "schemas/execute-spec-v1.json"
        fi
        # v5.0.0 tasks v4.0 schema
        if [ -f "$BASE_AGENT_OS/v3/schemas/tasks-v4.json" ]; then
            copy_file "$BASE_AGENT_OS/v3/schemas/tasks-v4.json" "./.agent-os/schemas/tasks-v4.json" "$OVERWRITE_CLAUDE" "schemas/tasks-v4.json"
        fi

    else
        # GitHub installation
        install_v3_from_github "$OVERWRITE_CLAUDE"
    fi
fi

# Initialize state management
echo ""
echo "📥 Initializing state management..."
cat > "$INSTALL_DIR/state/workflow.json" << 'EOF'
{
  "state_version": "1.0.0",
  "current_workflow": null,
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

# Initialize progress log (persistent cross-session memory)
echo ""
echo "📥 Initializing progress log..."
if [ ! -f "$INSTALL_DIR/progress/progress.json" ]; then
    PROGRESS_TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    cat > "$INSTALL_DIR/progress/progress.json" << EOF
{
  "version": "1.0",
  "project": "$PROJECT_NAME",
  "entries": [
    {
      "id": "entry-init-001",
      "timestamp": "$PROGRESS_TIMESTAMP",
      "type": "milestone_reached",
      "data": {
        "description": "Agent OS installed",
        "notes": "Progress logging initialized for cross-session memory"
      }
    }
  ],
  "metadata": {
    "total_entries": 1,
    "oldest_entry": "$PROGRESS_TIMESTAMP",
    "last_updated": "$PROGRESS_TIMESTAMP",
    "archived_through": null
  }
}
EOF
    echo "  ✓ Created progress log (progress.json)"

    # Generate initial markdown
    cat > "$INSTALL_DIR/progress/progress.md" << EOF
# Agent OS Progress Log

*Project: $PROJECT_NAME*
*Total entries: 1*

---

## $(date +%Y-%m-%d)

### $(date +%H:%M) - 🎯 Agent OS installed
- **Details**: Progress logging initialized for cross-session memory

---
EOF
    echo "  ✓ Created progress log (progress.md)"
else
    echo "  ✓ Progress log already exists (preserved)"
fi

# Create version tracking file
echo ""
echo "📥 Creating version tracking..."

# Determine features installed
FEATURES_ARRAY="[]"
if [ "$CLAUDE_CODE" = true ] && [ "$CURSOR" = true ]; then
    FEATURES_ARRAY='["claude-code", "cursor", "hooks"]'
elif [ "$CLAUDE_CODE" = true ]; then
    FEATURES_ARRAY='["claude-code", "hooks"]'
elif [ "$CURSOR" = true ]; then
    FEATURES_ARRAY='["cursor"]'
fi

# Architecture is always v4
ARCHITECTURE="v4"

# Get installation timestamp
INSTALL_TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

cat > "$INSTALL_DIR/version.json" << EOF
{
  "agent_os_version": "$AGENT_OS_VERSION",
  "architecture": "$ARCHITECTURE",
  "release_date": "$AGENT_OS_RELEASE_DATE",
  "installed_at": "$INSTALL_TIMESTAMP",
  "project_type": "$PROJECT_TYPE",
  "features": $FEATURES_ARRAY,
  "installation_source": "$([ "$IS_FROM_BASE" = true ] && echo "base" || echo "github")",
  "upgrade_info": {
    "last_checked": null,
    "available_version": null,
    "breaking_changes": false
  }
}
EOF
echo "  ✓ Created version tracking file (v$AGENT_OS_VERSION)"

# Handle optional hooks installation
if [ "$WITH_HOOKS" = true ]; then
    echo ""
    echo "📥 Installing validation hooks..."
    create_tracked_dir "./.claude/hooks"
    
    # Pre-write hook for JSON validation
    cat > "./.claude/hooks/pre-write.sh" << 'EOF'
#!/bin/bash
# Validates JSON state files before writing
if [[ "$1" == *".agent-os/state/"*.json ]]; then
    jq empty "$1" 2>/dev/null || {
        echo "ERROR: Invalid JSON in state file"
        exit 1
    }
fi
EOF
    
    # Post-command hook for cache cleanup
    cat > "./.claude/hooks/post-command.sh" << 'EOF'
#!/bin/bash
# Clean expired caches after command execution
find .agent-os/state -name "session-cache.json" -mmin +60 \
    -exec rm {} \; 2>/dev/null
EOF
    
    chmod +x ./.claude/hooks/*.sh
    echo "  ✓ Installed pre-write validation hook"
    echo "  ✓ Installed post-command cleanup hook"
fi

# Update .gitignore for state, cache, and progress files
# NOTE: Task files (tasks.json, tasks.md) are now tracked for PR review visibility (v3.8.2)
# Progress files remain gitignored as they are session-specific
if [ -f .gitignore ]; then
    # Check if Agent-OS section already exists
    if ! grep -q "# Agent-OS state and tracking files" .gitignore; then
        echo "" >> .gitignore
        echo "# Agent-OS state and tracking files" >> .gitignore
        echo "" >> .gitignore
        echo "# Session state (ephemeral)" >> .gitignore
        echo ".agent-os/state/session.json" >> .gitignore
        echo ".agent-os/state/session-cache.json" >> .gitignore
        echo ".agent-os/state/command-state.json" >> .gitignore
        echo ".agent-os/state/checkpoints/" >> .gitignore
        echo ".agent-os/state/recovery/" >> .gitignore
        echo ".agent-os/state/.lock" >> .gitignore
        echo ".agent-os/cache/" >> .gitignore
        echo ".agent-os/debugging/" >> .gitignore
        echo ".agent-os/metrics/" >> .gitignore
        echo ".agent-os/**/*.cache" >> .gitignore
        echo ".agent-os/**/*.tmp" >> .gitignore
        echo "" >> .gitignore
        echo "# Progress tracking (session-specific, causes merge conflicts)" >> .gitignore
        echo ".agent-os/progress/progress.json" >> .gitignore
        echo ".agent-os/progress/progress.md" >> .gitignore
        echo ".agent-os/progress/archive/" >> .gitignore
        echo "" >> .gitignore
        echo "# v4.10.0: Context offloading (ephemeral, auto-cleaned)" >> .gitignore
        echo ".agent-os/scratch/" >> .gitignore
        echo "  ✓ Updated .gitignore with state exclusions"
    fi
else
    # Create new .gitignore with Agent-OS entries
    cat > .gitignore << 'EOF'
# Agent-OS state and tracking files

# Session state (ephemeral)
.agent-os/state/session.json
.agent-os/state/session-cache.json
.agent-os/state/command-state.json
.agent-os/state/checkpoints/
.agent-os/state/recovery/
.agent-os/state/.lock
.agent-os/cache/
.agent-os/debugging/
.agent-os/metrics/
.agent-os/**/*.cache
.agent-os/**/*.tmp

# Progress tracking (session-specific, causes merge conflicts)
.agent-os/progress/progress.json
.agent-os/progress/progress.md
.agent-os/progress/archive/

# v4.10.0: Context offloading (ephemeral, auto-cleaned)
.agent-os/scratch/
EOF
    echo "  ✓ Created .gitignore with state exclusions"
fi

# Handle Cursor installation for project
if [ "$CURSOR" = true ]; then
    echo ""
    echo "📥 Installing Cursor support..."
    create_tracked_dir "./.cursor"
    create_tracked_dir "./.cursor/rules"

    echo "  📂 Rules:"

    if [ "$IS_FROM_BASE" = true ]; then
        # Convert commands from base installation to Cursor rules
        for cmd in plan-product shape-spec create-spec create-tasks execute-tasks analyze-product; do
            if [ -f "$BASE_AGENT_OS/commands/${cmd}.md" ]; then
                convert_to_cursor_rule "$BASE_AGENT_OS/commands/${cmd}.md" "./.cursor/rules/${cmd}.mdc"
            else
                echo "  ⚠️  Warning: ${cmd}.md not found in base installation"
            fi
        done
    else
        # Download from GitHub and convert when using --no-base
        echo "  Downloading and converting from GitHub..."
        for cmd in plan-product shape-spec create-spec create-tasks execute-tasks analyze-product; do
            TEMP_FILE="/tmp/${cmd}.md"
            curl -s -o "$TEMP_FILE" "${BASE_URL}/commands/${cmd}.md"
            if [ -f "$TEMP_FILE" ]; then
                convert_to_cursor_rule "$TEMP_FILE" "./.cursor/rules/${cmd}.mdc"
                rm "$TEMP_FILE"
            fi
        done
    fi
fi

# Verify installation
echo ""
echo "🔍 Verifying installation..."

VERIFICATION_PASSED=true

# Check critical files exist
if [ ! -f "$INSTALL_DIR/version.json" ]; then
    echo "  ⚠️  Warning: version.json not created"
    VERIFICATION_PASSED=false
fi

if [ ! -f "$INSTALL_DIR/state/workflow.json" ]; then
    echo "  ⚠️  Warning: workflow.json not created"
    VERIFICATION_PASSED=false
fi

if [ "$CLAUDE_CODE" = true ]; then
    # Verify at least one command exists
    if [ ! -f "./.claude/commands/execute-tasks.md" ]; then
        echo "  ⚠️  Warning: Claude Code commands not fully installed"
        VERIFICATION_PASSED=false
    fi
fi

if [ "$VERIFICATION_PASSED" = true ]; then
    echo "  ✓ All critical files verified"
fi

# Mark installation as complete (prevents cleanup on exit)
INSTALL_STARTED=false

# Success message
echo ""
echo "✅ Agent OS v$AGENT_OS_VERSION ($ARCHITECTURE architecture) has been installed in your project ($PROJECT_NAME)!"
echo ""
echo "📍 Project-level files installed to:"
echo "   .agent-os/version.json     - Installation version and metadata"
echo "   .agent-os/standards/       - Development standards"
echo "   .agent-os/state/           - State management and caching"
echo "   .agent-os/progress/        - Persistent progress log (cross-session memory)"
echo "   .agent-os/scratch/         - Context offloading (ephemeral, auto-cleaned)"
echo "   .agent-os/memory/          - Persistent storage (pinned outputs, sessions)"
echo "   .agent-os/logs/            - Semantic memory (decisions, insights)"

if [ "$CLAUDE_CODE" = true ]; then
    echo "   .agent-os/schemas/         - JSON schemas"
    echo "   .claude/CLAUDE.md          - Core memory (auto-loaded)"
    echo "   .claude/commands/          - Claude Code commands"
    echo "   .claude/agents/            - Phase subagents and utility agents"
    echo "   .claude/hooks/             - Validation + lifecycle hooks (v4.8.0)"
    echo "   .claude/scripts/           - Task operations utilities"
    echo "   .claude/rules/             - Path-specific rules (TDD, git)"
    echo "   .claude/skills/            - Hot-reloadable skills (v4.8.0)"
    echo "   .claude/settings.json      - Hooks configuration"
fi

if [ "$CURSOR" = true ]; then
    echo "   .cursor/rules/             - Cursor command rules"
fi

echo ""
echo "--------------------------------"
echo ""

echo "v5.2 Architecture Features:"
echo "  • Atomic Teammates: group-level parallelism with subtask-group-worker"
echo "  • Dynamic teammate cap based on isolation_score"
echo "  • Artifact relay protocol for cross-teammate sharing"
echo ""
echo "v5.1 Features (included):"
echo "  • Native Teams integration for wave-level peer coordination"
echo "  • Review-watcher agent for message-based PR review notification"
echo "  • Artifact broadcast protocol for sibling task sharing"
echo ""
echo "v5.0 Features (included):"
echo "  • Dependency-first tasks v4.0 with topological sort"
echo "  • Constraint validation, E2E resilience, non-blocking review"
echo ""
echo "v4.9-4.12 Features (included):"
echo "  • E2E test integration, context offloading, agent memory"
echo "  • AST verification, Ralph Wiggum verification loop"
echo "  • Setup hook, TaskCompleted hook, Task(type) spawn restrictions"
echo ""

echo "Next steps:"
echo ""

if [ "$CLAUDE_CODE" = true ]; then
    echo "Claude Code usage:"
    echo "  /plan-product      - Set the mission & roadmap for a new product"
    echo "  /analyze-product   - Set up the mission and roadmap for an existing product"
    echo "  /shape-spec        - Explore and refine a feature concept before full spec"
    echo "  /create-spec       - Create a detailed spec for a new feature"
    echo "  /execute-tasks     - Build and ship code for a new feature"
    echo "  /pr-review-cycle   - Process and address PR review feedback"
    echo ""
fi

if [ "$CURSOR" = true ]; then
    echo "Cursor usage:"
    echo "  @plan-product    - Set the mission & roadmap for a new product"
    echo "  @analyze-product - Set up the mission and roadmap for an existing product"
    echo "  @shape-spec      - Explore and refine a feature concept before full spec"
    echo "  @create-spec     - Create a detailed spec for a new feature"
    echo "  @execute-tasks   - Build and ship code for a new feature"
    echo ""
fi

echo "--------------------------------"
echo ""
echo "Refer to the official Agent OS docs at:"
echo "https://buildermethods.com/agent-os"
echo ""
echo "Keep building! 🚀"
echo ""
