#!/bin/bash

# Agent OS Base Installation Script
# This script installs Agent OS to the current directory as a central repository
# Other projects can then install from this base using project.sh
# Updated for v3.8.1 architecture

set -e  # Exit on error

# Version information
AGENT_OS_VERSION="3.8.2"
AGENT_OS_RELEASE_DATE="2025-12-25"

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
mkdir -p "$INSTALL_DIR/commands"
mkdir -p "$INSTALL_DIR/standards"
mkdir -p "$INSTALL_DIR/standards/global"
mkdir -p "$INSTALL_DIR/standards/frontend"
mkdir -p "$INSTALL_DIR/standards/backend"
mkdir -p "$INSTALL_DIR/standards/testing"
mkdir -p "$INSTALL_DIR/standards/code-style"
mkdir -p "$INSTALL_DIR/shared"
mkdir -p "$INSTALL_DIR/claude-code/agents"
mkdir -p "$INSTALL_DIR/claude-code/skills"
mkdir -p "$INSTALL_DIR/claude-code/skills/optional"
mkdir -p "$INSTALL_DIR/v3/agents"
mkdir -p "$INSTALL_DIR/v3/commands"
mkdir -p "$INSTALL_DIR/v3/hooks"
mkdir -p "$INSTALL_DIR/v3/scripts"
mkdir -p "$INSTALL_DIR/v3/memory/rules"
mkdir -p "$INSTALL_DIR/v3/schemas"

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

# Download commands (v2/v3 shared commands)
echo ""
echo "📥 Downloading commands..."
for cmd in plan-product shape-spec create-spec create-tasks execute-tasks analyze-product index-codebase debug pr-review-cycle; do
    download_file "${BASE_URL}/commands/${cmd}.md" \
        "$INSTALL_DIR/commands/${cmd}.md" \
        "$OVERWRITE_COMMANDS" \
        "commands/${cmd}.md"
done

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

# Download shared modules (v2 compatibility)
echo ""
echo "📥 Downloading shared modules..."
for shared in error-recovery state-patterns progress-log task-json context-summary parallel-execution; do
    download_file "${BASE_URL}/shared/${shared}.md" \
        "$INSTALL_DIR/shared/${shared}.md" \
        "$OVERWRITE_STANDARDS" \
        "shared/${shared}.md"
done

# Download Claude Code agents (v2 - only those that still exist)
echo ""
echo "📥 Downloading Claude Code agents..."
for agent in git-workflow project-manager; do
    download_file "${BASE_URL}/claude-code/agents/${agent}.md" \
        "$INSTALL_DIR/claude-code/agents/${agent}.md" \
        "$OVERWRITE_COMMANDS" \
        "claude-code/agents/${agent}.md"
done

# Download Claude Code skills (v2)
echo ""
echo "📥 Downloading Claude Code skills (Tier 1)..."
for skill in build-check test-check codebase-names systematic-debugging tdd brainstorming writing-plans session-startup implementation-verifier task-sync pr-review-handler; do
    download_file "${BASE_URL}/claude-code/skills/${skill}.md" \
        "$INSTALL_DIR/claude-code/skills/${skill}.md" \
        "$OVERWRITE_COMMANDS" \
        "claude-code/skills/${skill}.md"
done

echo ""
echo "📥 Downloading Claude Code skills (Tier 2 - Optional)..."
for skill in code-review verification skill-creator mcp-builder standards-to-skill; do
    download_file "${BASE_URL}/claude-code/skills/optional/${skill}.md" \
        "$INSTALL_DIR/claude-code/skills/optional/${skill}.md" \
        "$OVERWRITE_COMMANDS" \
        "claude-code/skills/optional/${skill}.md"
done

# Download v3 architecture files
echo ""
echo "📥 Downloading v3 architecture files..."
echo "  📂 v3 Commands:"
for cmd in execute-tasks shape-spec debug; do
    download_file "${BASE_URL}/v3/commands/${cmd}.md" \
        "$INSTALL_DIR/v3/commands/${cmd}.md" \
        "$OVERWRITE_COMMANDS" \
        "v3/commands/${cmd}.md"
done

echo ""
echo "  📂 v3 Agents:"
for agent in phase1-discovery phase2-implementation phase3-delivery; do
    download_file "${BASE_URL}/v3/agents/${agent}.md" \
        "$INSTALL_DIR/v3/agents/${agent}.md" \
        "$OVERWRITE_COMMANDS" \
        "v3/agents/${agent}.md"
done

echo ""
echo "  📂 v3 Hooks:"
for hook in session-start session-end post-file-change pre-commit-gate; do
    download_file "${BASE_URL}/v3/hooks/${hook}.sh" \
        "$INSTALL_DIR/v3/hooks/${hook}.sh" \
        "$OVERWRITE_COMMANDS" \
        "v3/hooks/${hook}.sh"
    chmod +x "$INSTALL_DIR/v3/hooks/${hook}.sh" 2>/dev/null || true
done

echo ""
echo "  📂 v3 Scripts:"
download_file "${BASE_URL}/v3/scripts/task-operations.sh" \
    "$INSTALL_DIR/v3/scripts/task-operations.sh" \
    "$OVERWRITE_COMMANDS" \
    "v3/scripts/task-operations.sh"
chmod +x "$INSTALL_DIR/v3/scripts/task-operations.sh" 2>/dev/null || true
download_file "${BASE_URL}/v3/scripts/json-to-markdown.js" \
    "$INSTALL_DIR/v3/scripts/json-to-markdown.js" \
    "$OVERWRITE_COMMANDS" \
    "v3/scripts/json-to-markdown.js"

echo ""
echo "  📂 v3 Memory:"
download_file "${BASE_URL}/v3/memory/CLAUDE.md" \
    "$INSTALL_DIR/v3/memory/CLAUDE.md" \
    "$OVERWRITE_COMMANDS" \
    "v3/memory/CLAUDE.md"
for rule in tdd-workflow git-conventions execute-tasks; do
    download_file "${BASE_URL}/v3/memory/rules/${rule}.md" \
        "$INSTALL_DIR/v3/memory/rules/${rule}.md" \
        "$OVERWRITE_COMMANDS" \
        "v3/memory/rules/${rule}.md"
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
echo "For v3 architecture (recommended):"
echo "   $PROJECT_SCRIPT --claude-code --v3"
echo ""
echo "For v2 architecture (legacy):"
echo "   $PROJECT_SCRIPT --claude-code --v2"
echo ""
echo "--------------------------------"
echo ""
echo "📍 Base installation structure:"
echo "   $INSTALL_DIR/commands/              - Command templates (9 commands)"
echo "   $INSTALL_DIR/standards/             - Development standards (organized by category)"
echo "   $INSTALL_DIR/shared/                - Shared modules (v2 compatibility)"
echo "   $INSTALL_DIR/claude-code/agents/    - Claude Code agents (2 agents)"
echo "   $INSTALL_DIR/claude-code/skills/    - Claude Code skills (11 default + 5 optional)"
echo "   $INSTALL_DIR/v3/                    - v3 architecture files"
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
