#!/bin/bash

# Agent OS Base Installation Script
# This script installs Agent OS to the current directory as a central repository
# Other projects can then install from this base using project.sh
# Updated for v5.4.2 architecture

set -e  # Exit on error

# Version information
AGENT_OS_VERSION="5.4.2"
AGENT_OS_RELEASE_DATE="2026-02-13"

# Initialize flags
OVERWRITE_COMMANDS=false
OVERWRITE_STANDARDS=false
OVERWRITE_CONFIG=false
CLAUDE_CODE=false
CURSOR=false

# Base URL for raw GitHub content
BASE_URL="https://raw.githubusercontent.com/buildermethods/agent-os/main"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --overwrite-commands)
            OVERWRITE_COMMANDS=true
            shift
            ;;
        --overwrite-standards)
            OVERWRITE_STANDARDS=true
            shift
            ;;
        --overwrite-config)
            OVERWRITE_CONFIG=true
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
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --overwrite-commands        Overwrite existing command files"
            echo "  --overwrite-standards       Overwrite existing standards files"
            echo "  --overwrite-config          Overwrite existing config.yml"
            echo "  --claude-code               Enable Claude Code support in config"
            echo "  --cursor                    Enable Cursor support in config"
            echo "  -h, --help                  Show this help message"
            echo ""
            echo "This script installs Agent OS as a base/central installation."
            echo "Use setup/project.sh to install into individual projects."
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
echo "🚀 Agent OS Base Installation (v$AGENT_OS_VERSION)"
echo "==========================================="
echo ""

# Set installation directory to current directory
CURRENT_DIR=$(pwd)
INSTALL_DIR="$CURRENT_DIR"

echo "📍 Installing Agent OS base to: $CURRENT_DIR"
echo ""

# Create base directories
echo "📁 Creating base directories..."
mkdir -p "$INSTALL_DIR/setup"
mkdir -p "$INSTALL_DIR/standards"
mkdir -p "$INSTALL_DIR/standards/global"
mkdir -p "$INSTALL_DIR/standards/frontend"
mkdir -p "$INSTALL_DIR/standards/backend"
mkdir -p "$INSTALL_DIR/standards/testing"
mkdir -p "$INSTALL_DIR/standards/code-style"
mkdir -p "$INSTALL_DIR/v3/agents"
mkdir -p "$INSTALL_DIR/v3/agents/references"
mkdir -p "$INSTALL_DIR/v3/commands"
mkdir -p "$INSTALL_DIR/v3/hooks"
mkdir -p "$INSTALL_DIR/v3/scripts"
mkdir -p "$INSTALL_DIR/v3/memory/rules"
mkdir -p "$INSTALL_DIR/v3/schemas"
mkdir -p "$INSTALL_DIR/v3/skills/artifact-verification"
mkdir -p "$INSTALL_DIR/v3/skills/context-summary"
mkdir -p "$INSTALL_DIR/v3/skills/tdd-helper"
mkdir -p "$INSTALL_DIR/v3/skills/subtask-expansion"
mkdir -p "$INSTALL_DIR/v3/skills/log-entry"
mkdir -p "$INSTALL_DIR/v3/skills/context-read"
mkdir -p "$INSTALL_DIR/v3/skills/context-search"
mkdir -p "$INSTALL_DIR/v3/skills/context-stats"
mkdir -p "$INSTALL_DIR/v3/skills/test-guardian"
mkdir -p "$INSTALL_DIR/v3/skills/tmux-monitor"
mkdir -p "$INSTALL_DIR/v3/templates/specs"
mkdir -p "$INSTALL_DIR/v3/templates/tasks"
mkdir -p "$INSTALL_DIR/v3/templates/test-scenarios"

# Download functions.sh first and source it
echo ""
echo "📥 Downloading setup functions..."
curl -sSL "${BASE_URL}/setup/functions.sh" -o "$INSTALL_DIR/setup/functions.sh"
source "$INSTALL_DIR/setup/functions.sh"
echo "  ✓ setup/functions.sh"

# Download project.sh
echo ""
echo "📥 Downloading project setup script..."
curl -sSL "${BASE_URL}/setup/project.sh" -o "$INSTALL_DIR/setup/project.sh"
chmod +x "$INSTALL_DIR/setup/project.sh"
echo "  ✓ setup/project.sh"


# Download standards - organized by category
echo ""
echo "📥 Downloading standards..."
echo "  📂 Global:"
for file in coding-style conventions error-handling tech-stack validation; do
    download_file "${BASE_URL}/standards/global/${file}.md" \
        "$INSTALL_DIR/standards/global/${file}.md" \
        "$OVERWRITE_STANDARDS" \
        "standards/global/${file}.md"
done

echo ""
echo "  📂 Frontend:"
for file in react-patterns styling; do
    download_file "${BASE_URL}/standards/frontend/${file}.md" \
        "$INSTALL_DIR/standards/frontend/${file}.md" \
        "$OVERWRITE_STANDARDS" \
        "standards/frontend/${file}.md"
done

echo ""
echo "  📂 Backend:"
for file in api-design database; do
    download_file "${BASE_URL}/standards/backend/${file}.md" \
        "$INSTALL_DIR/standards/backend/${file}.md" \
        "$OVERWRITE_STANDARDS" \
        "standards/backend/${file}.md"
done

echo ""
echo "  📂 Testing:"
download_file "${BASE_URL}/standards/testing/test-patterns.md" \
    "$INSTALL_DIR/standards/testing/test-patterns.md" \
    "$OVERWRITE_STANDARDS" \
    "standards/testing/test-patterns.md"

echo ""
echo "  📂 Code Style:"
for file in javascript-style html-style css-style; do
    download_file "${BASE_URL}/standards/code-style/${file}.md" \
        "$INSTALL_DIR/standards/code-style/${file}.md" \
        "$OVERWRITE_STANDARDS" \
        "standards/code-style/${file}.md"
done

echo ""
echo "  📂 Root Standards:"
for file in best-practices code-style tech-stack codebase-reference; do
    download_file "${BASE_URL}/standards/${file}.md" \
        "$INSTALL_DIR/standards/${file}.md" \
        "$OVERWRITE_STANDARDS" \
        "standards/${file}.md"
done


# Download v3 architecture files
echo ""
echo "📥 Downloading v3 architecture files..."
echo "  📂 Commands:"
for cmd in plan-product shape-spec create-spec create-tasks execute-tasks analyze-product debug pr-review-cycle; do
    download_file "${BASE_URL}/v3/commands/${cmd}.md" \
        "$INSTALL_DIR/v3/commands/${cmd}.md" \
        "$OVERWRITE_COMMANDS" \
        "v3/commands/${cmd}.md"
done

echo ""
echo "  📂 Agents:"
for agent in phase1-discovery phase2-implementation phase3-delivery wave-orchestrator subtask-group-worker pr-review-discovery pr-review-implementation future-classifier comment-classifier roadmap-integrator git-workflow project-manager execute-spec-orchestrator wave-lifecycle-agent test-discovery test-executor test-reporter review-watcher code-reviewer code-validator; do
    download_file "${BASE_URL}/v3/agents/${agent}.md" \
        "$INSTALL_DIR/v3/agents/${agent}.md" \
        "$OVERWRITE_COMMANDS" \
        "v3/agents/${agent}.md"
done
echo ""
echo "  📂 Agent References:"
for ref in tdd-implementation-guide wave-team-protocol wave-verification-reference; do
    download_file "${BASE_URL}/v3/agents/references/${ref}.md" \
        "$INSTALL_DIR/v3/agents/references/${ref}.md" \
        "$OVERWRITE_COMMANDS" \
        "v3/agents/references/${ref}.md"
done

echo ""
echo "  📂 v3 Hooks:"
for hook in session-start session-end post-file-change pre-commit-gate subagent-start subagent-stop setup task-completed teammate-idle; do
    download_file "${BASE_URL}/v3/hooks/${hook}.sh" \
        "$INSTALL_DIR/v3/hooks/${hook}.sh" \
        "$OVERWRITE_COMMANDS" \
        "v3/hooks/${hook}.sh"
    chmod +x "$INSTALL_DIR/v3/hooks/${hook}.sh" 2>/dev/null || true
done

echo ""
echo "  📂 v3 Scripts:"
for script in task-operations.sh pr-review-operations.sh branch-setup.sh execute-spec-operations.sh test-operations.sh redact-secrets.sh code-review-ops.sh test-skill-triggers.sh; do
    download_file "${BASE_URL}/v3/scripts/${script}" \
        "$INSTALL_DIR/v3/scripts/${script}" \
        "$OVERWRITE_COMMANDS" \
        "v3/scripts/${script}"
    chmod +x "$INSTALL_DIR/v3/scripts/${script}" 2>/dev/null || true
done
for script in json-to-markdown.js test-plan-to-markdown.js test-report-to-markdown.js ast-verify.ts wave-parallel.ts verification-loop.ts e2e-utils.ts test-patterns.ts compute-waves.ts migrate-v3-to-v4.js; do
    download_file "${BASE_URL}/v3/scripts/${script}" \
        "$INSTALL_DIR/v3/scripts/${script}" \
        "$OVERWRITE_COMMANDS" \
        "v3/scripts/${script}"
done

echo ""
echo "  📂 v3 Memory:"
download_file "${BASE_URL}/v3/memory/CLAUDE.md" \
    "$INSTALL_DIR/v3/memory/CLAUDE.md" \
    "$OVERWRITE_COMMANDS" \
    "v3/memory/CLAUDE.md"
download_file "${BASE_URL}/v3/memory/ENV-VARS.md" \
    "$INSTALL_DIR/v3/memory/ENV-VARS.md" \
    "$OVERWRITE_COMMANDS" \
    "v3/memory/ENV-VARS.md"
for rule in tdd-workflow git-conventions execute-tasks error-handling verification-loop e2e-integration agent-tool-restrictions e2e-fixtures e2e-batch-checkpoint teams-integration context-offloading; do
    download_file "${BASE_URL}/v3/memory/rules/${rule}.md" \
        "$INSTALL_DIR/v3/memory/rules/${rule}.md" \
        "$OVERWRITE_COMMANDS" \
        "v3/memory/rules/${rule}.md"
done

echo ""
echo "  📂 v3 Skills:"
for skill in artifact-verification context-summary tdd-helper subtask-expansion log-entry context-read context-search context-stats test-guardian tmux-monitor; do
    download_file "${BASE_URL}/v3/skills/${skill}/SKILL.md" \
        "$INSTALL_DIR/v3/skills/${skill}/SKILL.md" \
        "$OVERWRITE_COMMANDS" \
        "v3/skills/${skill}/SKILL.md"
done

echo ""
echo "  📂 v3 Templates:"
for template in feature bugfix refactor integration; do
    download_file "${BASE_URL}/v3/templates/specs/${template}.md" \
        "$INSTALL_DIR/v3/templates/specs/${template}.md" \
        "$OVERWRITE_COMMANDS" \
        "v3/templates/specs/${template}.md"
done
for template in api-endpoint react-component bugfix refactor; do
    download_file "${BASE_URL}/v3/templates/tasks/${template}.json" \
        "$INSTALL_DIR/v3/templates/tasks/${template}.json" \
        "$OVERWRITE_COMMANDS" \
        "v3/templates/tasks/${template}.json"
done
for template in authentication form-validation crud-operations; do
    download_file "${BASE_URL}/v3/templates/test-scenarios/${template}.json" \
        "$INSTALL_DIR/v3/templates/test-scenarios/${template}.json" \
        "$OVERWRITE_COMMANDS" \
        "v3/templates/test-scenarios/${template}.json"
done

echo ""
echo "  📂 v3 Settings & Schema:"
download_file "${BASE_URL}/v3/settings.json" \
    "$INSTALL_DIR/v3/settings.json" \
    "$OVERWRITE_COMMANDS" \
    "v3/settings.json"
download_file "${BASE_URL}/v3/schemas/tasks-v3.json" \
    "$INSTALL_DIR/v3/schemas/tasks-v3.json" \
    "$OVERWRITE_COMMANDS" \
    "v3/schemas/tasks-v3.json"
download_file "${BASE_URL}/v3/schemas/tasks-v4.json" \
    "$INSTALL_DIR/v3/schemas/tasks-v4.json" \
    "$OVERWRITE_COMMANDS" \
    "v3/schemas/tasks-v4.json"
download_file "${BASE_URL}/v3/schemas/execute-spec-v1.json" \
    "$INSTALL_DIR/v3/schemas/execute-spec-v1.json" \
    "$OVERWRITE_COMMANDS" \
    "v3/schemas/execute-spec-v1.json"

# Download config.yml
echo ""
echo "📥 Downloading configuration..."
download_file "${BASE_URL}/config.yml" \
    "$INSTALL_DIR/config.yml" \
    "$OVERWRITE_CONFIG" \
    "config.yml"

# Handle Claude Code configuration
if [ "$CLAUDE_CODE" = true ]; then
    if [ -f "$INSTALL_DIR/config.yml" ]; then
        sed -i.bak '/claude_code:/,/enabled:/ s/enabled: false/enabled: true/' "$INSTALL_DIR/config.yml" && rm "$INSTALL_DIR/config.yml.bak" 2>/dev/null || true
        echo "  ✓ Claude Code enabled in configuration"
    fi
fi

# Handle Cursor configuration
if [ "$CURSOR" = true ]; then
    if [ -f "$INSTALL_DIR/config.yml" ]; then
        sed -i.bak '/cursor:/,/enabled:/ s/enabled: false/enabled: true/' "$INSTALL_DIR/config.yml" && rm "$INSTALL_DIR/config.yml.bak" 2>/dev/null || true
        echo "  ✓ Cursor enabled in configuration"
    fi
fi

# Success message
echo ""
echo "✅ Agent OS v$AGENT_OS_VERSION base installation completed!"
echo ""

# Dynamic project installation command
PROJECT_SCRIPT="$INSTALL_DIR/setup/project.sh"
echo "--------------------------------"
echo ""
echo "To install Agent OS in a project, run:"
echo ""
echo "   cd <project-directory>"
echo "   $PROJECT_SCRIPT --claude-code"
echo ""
echo "--------------------------------"
echo ""
echo "📍 Base installation structure:"
echo "   $INSTALL_DIR/v3/commands/           - Command templates (8 commands)"
echo "   $INSTALL_DIR/v3/agents/             - Agent templates (20 agents + 3 references)"
echo "   $INSTALL_DIR/v3/hooks/              - Native hooks (9 hooks)"
echo "   $INSTALL_DIR/v3/scripts/            - Utility scripts (19 scripts)"
echo "   $INSTALL_DIR/v3/memory/             - Memory templates + rules (13 files)"
echo "   $INSTALL_DIR/v3/skills/             - Hot-reloadable skills (10 skills)"
echo "   $INSTALL_DIR/v3/templates/          - Spec, task, test templates"
echo "   $INSTALL_DIR/standards/             - Development standards"
echo "   $INSTALL_DIR/config.yml             - Configuration"
echo "   $INSTALL_DIR/setup/project.sh       - Project installation script"

echo ""
echo "--------------------------------"
echo ""
echo "Next steps:"
echo ""
echo "1. (Optional) Customize standards in $INSTALL_DIR/standards/"
echo ""
echo "2. (Optional) Configure project types in $INSTALL_DIR/config.yml"
echo ""
echo "3. Navigate to a project and run: $PROJECT_SCRIPT --claude-code"
echo ""
echo "--------------------------------"
echo ""
echo "Refer to the official Agent OS docs at:"
echo "https://buildermethods.com/agent-os"
echo ""
echo "Keep building! 🚀"
echo ""
