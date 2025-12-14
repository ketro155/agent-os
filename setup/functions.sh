#!/bin/bash

# Agent OS Shared Functions
# Used by both base.sh and project.sh
# Updated for v3.0.2 architecture

# Base URL for raw GitHub content
BASE_URL="https://raw.githubusercontent.com/buildermethods/agent-os/main"

# Function to copy files from source to destination
copy_file() {
    local source="$1"
    local dest="$2"
    local overwrite="$3"
    local desc="$4"

    if [ -f "$dest" ] && [ "$overwrite" = false ]; then
        echo "  ⚠️  $desc already exists - skipping"
        return 0
    else
        if [ -f "$source" ]; then
            cp "$source" "$dest"
            if [ -f "$dest" ] && [ "$overwrite" = true ]; then
                echo "  ✓ $desc (overwritten)"
            else
                echo "  ✓ $desc"
            fi
            return 0
        else
            return 1
        fi
    fi
}

# Function to download file from GitHub
download_file() {
    local url="$1"
    local dest="$2"
    local overwrite="$3"
    local desc="$4"

    if [ -f "$dest" ] && [ "$overwrite" = false ]; then
        echo "  ⚠️  $desc already exists - skipping"
        return 0
    else
        curl -s -o "$dest" "$url"
        if [ -f "$dest" ] && [ "$overwrite" = true ]; then
            echo "  ✓ $desc (overwritten)"
        else
            echo "  ✓ $desc"
        fi
        return 0
    fi
}

# Function to copy directory recursively
copy_directory() {
    local source="$1"
    local dest="$2"
    local overwrite="$3"

    if [ ! -d "$source" ]; then
        return 1
    fi

    mkdir -p "$dest"

    # Copy all files and subdirectories
    find "$source" -type f | while read -r file; do
        relative_path="${file#$source/}"
        dest_file="$dest/$relative_path"
        dest_dir=$(dirname "$dest_file")
        mkdir -p "$dest_dir"

        if [ -f "$dest_file" ] && [ "$overwrite" = false ]; then
            echo "  ⚠️  $relative_path already exists - skipping"
        else
            cp "$file" "$dest_file"
            if [ "$overwrite" = true ] && [ -f "$dest_file" ]; then
                echo "  ✓ $relative_path (overwritten)"
            else
                echo "  ✓ $relative_path"
            fi
        fi
    done
}

# Function to convert command file to Cursor .mdc format
convert_to_cursor_rule() {
    local source="$1"
    local dest="$2"

    if [ -f "$dest" ]; then
        echo "  ⚠️  $(basename $dest) already exists - skipping"
    else
        # Create the front-matter and append original content
        cat > "$dest" << EOF
---
alwaysApply: false
---

EOF
        cat "$source" >> "$dest"
        echo "  ✓ $(basename $dest)"
    fi
}

# Function to install from GitHub (v3.0.2 structure)
# This function downloads the core Agent OS files from the GitHub repository
install_from_github() {
    local target_dir="$1"
    local overwrite_inst="$2"
    local overwrite_std="$3"
    local include_commands="${4:-true}"  # Default to true for base installations

    # Create standards directories (v3 structure)
    mkdir -p "$target_dir/standards"
    mkdir -p "$target_dir/standards/global"
    mkdir -p "$target_dir/standards/frontend"
    mkdir -p "$target_dir/standards/backend"
    mkdir -p "$target_dir/standards/testing"
    mkdir -p "$target_dir/standards/code-style"

    # Download standards - Global
    echo ""
    echo "📥 Downloading standards files to $target_dir/standards/"
    echo "  📂 Global standards:"
    for file in coding-style conventions error-handling tech-stack validation; do
        download_file "${BASE_URL}/standards/global/${file}.md" \
            "$target_dir/standards/global/${file}.md" \
            "$overwrite_std" \
            "standards/global/${file}.md"
    done

    # Download standards - Frontend
    echo ""
    echo "  📂 Frontend standards:"
    for file in react-patterns styling; do
        download_file "${BASE_URL}/standards/frontend/${file}.md" \
            "$target_dir/standards/frontend/${file}.md" \
            "$overwrite_std" \
            "standards/frontend/${file}.md"
    done

    # Download standards - Backend
    echo ""
    echo "  📂 Backend standards:"
    for file in api-design database; do
        download_file "${BASE_URL}/standards/backend/${file}.md" \
            "$target_dir/standards/backend/${file}.md" \
            "$overwrite_std" \
            "standards/backend/${file}.md"
    done

    # Download standards - Testing
    echo ""
    echo "  📂 Testing standards:"
    download_file "${BASE_URL}/standards/testing/test-patterns.md" \
        "$target_dir/standards/testing/test-patterns.md" \
        "$overwrite_std" \
        "standards/testing/test-patterns.md"

    # Download standards - Code Style
    echo ""
    echo "  📂 Code style standards:"
    for file in javascript-style html-style css-style; do
        download_file "${BASE_URL}/standards/code-style/${file}.md" \
            "$target_dir/standards/code-style/${file}.md" \
            "$overwrite_std" \
            "standards/code-style/${file}.md"
    done

    # Download root-level standards files
    echo ""
    echo "  📂 Root standards:"
    for file in best-practices code-style tech-stack codebase-reference; do
        download_file "${BASE_URL}/standards/${file}.md" \
            "$target_dir/standards/${file}.md" \
            "$overwrite_std" \
            "standards/${file}.md"
    done

    # Download commands (only if requested)
    if [ "$include_commands" = true ]; then
        echo ""
        echo "📥 Downloading command files to $target_dir/commands/"
        mkdir -p "$target_dir/commands"

        # All v3.0.2 commands
        for cmd in plan-product shape-spec create-spec create-tasks execute-tasks analyze-product index-codebase debug pr-review-cycle; do
            download_file "${BASE_URL}/commands/${cmd}.md" \
                "$target_dir/commands/${cmd}.md" \
                "$overwrite_std" \
                "commands/${cmd}.md"
        done
    fi

    # Download shared modules (v2 compatibility)
    echo ""
    echo "📥 Downloading shared modules to $target_dir/shared/"
    mkdir -p "$target_dir/shared"
    for shared in error-recovery state-patterns progress-log task-json context-summary parallel-execution; do
        download_file "${BASE_URL}/shared/${shared}.md" \
            "$target_dir/shared/${shared}.md" \
            "$overwrite_std" \
            "shared/${shared}.md"
    done
}

# Function to install v3 files from GitHub
# This downloads the native v3 architecture files (hooks, scripts, agents, etc.)
install_v3_from_github() {
    local overwrite="$1"

    echo ""
    echo "📥 Downloading v3 architecture files from GitHub..."

    # Create v3 directories
    mkdir -p "./.claude/commands"
    mkdir -p "./.claude/agents"
    mkdir -p "./.claude/hooks"
    mkdir -p "./.claude/scripts"
    mkdir -p "./.claude/rules"
    mkdir -p "./.agent-os/schemas"

    # Download v3 commands (simplified versions)
    echo ""
    echo "  📂 Commands (v3 - simplified):"
    # Most commands use the standard versions
    for cmd in plan-product shape-spec create-spec create-tasks analyze-product debug pr-review-cycle; do
        download_file "${BASE_URL}/commands/${cmd}.md" \
            "./.claude/commands/${cmd}.md" \
            "$overwrite" \
            "commands/${cmd}.md"
    done
    # v3-specific execute-tasks
    download_file "${BASE_URL}/v3/commands/execute-tasks.md" \
        "./.claude/commands/execute-tasks.md" \
        "$overwrite" \
        "commands/execute-tasks.md (v3)"

    # Download v3 agents (phase subagents)
    echo ""
    echo "  📂 Agents (v3 - phase subagents):"
    for agent in phase1-discovery phase2-implementation phase3-delivery; do
        download_file "${BASE_URL}/v3/agents/${agent}.md" \
            "./.claude/agents/${agent}.md" \
            "$overwrite" \
            "agents/${agent}.md"
    done
    # Also include git-workflow from v2 (still useful)
    download_file "${BASE_URL}/claude-code/agents/git-workflow.md" \
        "./.claude/agents/git-workflow.md" \
        "$overwrite" \
        "agents/git-workflow.md"

    # Download v3 hooks
    echo ""
    echo "  📂 Hooks (v3 - mandatory validation):"
    for hook in session-start session-end post-file-change pre-commit-gate; do
        download_file "${BASE_URL}/v3/hooks/${hook}.sh" \
            "./.claude/hooks/${hook}.sh" \
            "$overwrite" \
            "hooks/${hook}.sh"
        chmod +x "./.claude/hooks/${hook}.sh" 2>/dev/null || true
    done

    # Download v3 scripts
    echo ""
    echo "  📂 Scripts (v3 - task operations):"
    download_file "${BASE_URL}/v3/scripts/task-operations.sh" \
        "./.claude/scripts/task-operations.sh" \
        "$overwrite" \
        "scripts/task-operations.sh"
    chmod +x "./.claude/scripts/task-operations.sh" 2>/dev/null || true
    download_file "${BASE_URL}/v3/scripts/json-to-markdown.js" \
        "./.claude/scripts/json-to-markdown.js" \
        "$overwrite" \
        "scripts/json-to-markdown.js"

    # Download v3 memory/rules
    echo ""
    echo "  📂 Memory (v3 - native memory hierarchy):"
    download_file "${BASE_URL}/v3/memory/CLAUDE.md" \
        "./.claude/CLAUDE.md" \
        "$overwrite" \
        "CLAUDE.md"
    for rule in tdd-workflow git-conventions execute-tasks; do
        download_file "${BASE_URL}/v3/memory/rules/${rule}.md" \
            "./.claude/rules/${rule}.md" \
            "$overwrite" \
            "rules/${rule}.md"
    done

    # Download v3 settings
    echo ""
    echo "  📂 Settings (v3 - hooks configuration):"
    download_file "${BASE_URL}/v3/settings.json" \
        "./.claude/settings.json" \
        "$overwrite" \
        "settings.json"

    # Download v3 schema
    echo ""
    echo "  📂 Schemas:"
    download_file "${BASE_URL}/v3/schemas/tasks-v3.json" \
        "./.agent-os/schemas/tasks-v3.json" \
        "$overwrite" \
        "schemas/tasks-v3.json"
}

# Function to install v2 agents from GitHub
install_v2_agents_from_github() {
    local overwrite="$1"

    echo ""
    echo "  📂 Agents (v2):"
    mkdir -p "./.claude/agents"

    # Only the agents that still exist in v3.0.2
    for agent in git-workflow project-manager; do
        download_file "${BASE_URL}/claude-code/agents/${agent}.md" \
            "./.claude/agents/${agent}.md" \
            "$overwrite" \
            "agents/${agent}.md"
    done
}

# Function to install v2 skills from GitHub
install_v2_skills_from_github() {
    local overwrite="$1"
    local full_skills="$2"

    echo ""
    echo "  📂 Skills (Tier 1 - Default):"
    mkdir -p "./.claude/skills"

    for skill in build-check test-check codebase-names systematic-debugging tdd brainstorming writing-plans session-startup implementation-verifier task-sync pr-review-handler; do
        download_file "${BASE_URL}/claude-code/skills/${skill}.md" \
            "./.claude/skills/${skill}.md" \
            "$overwrite" \
            "skills/${skill}.md"
    done

    # Install optional Tier 2 skills if requested
    if [ "$full_skills" = true ]; then
        echo ""
        echo "  📂 Skills (Tier 2 - Optional):"
        mkdir -p "./.claude/skills/optional"
        for skill in code-review verification skill-creator mcp-builder standards-to-skill; do
            download_file "${BASE_URL}/claude-code/skills/optional/${skill}.md" \
                "./.claude/skills/optional/${skill}.md" \
                "$overwrite" \
                "skills/optional/${skill}.md"
        done
    fi
}
