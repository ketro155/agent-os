#!/bin/bash

# Agent OS Shared Functions
# Used by both base.sh and project.sh
# Updated for v5.3.0 architecture

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

# Function to install from GitHub (standards + commands)
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
        echo "📥 Downloading command files to $target_dir/v3/commands/"
        mkdir -p "$target_dir/v3/commands"

        # All v4 commands from v3/ directory
        for cmd in plan-product shape-spec create-spec create-tasks execute-tasks analyze-product debug pr-review-cycle; do
            download_file "${BASE_URL}/v3/commands/${cmd}.md" \
                "$target_dir/v3/commands/${cmd}.md" \
                "$overwrite_std" \
                "v3/commands/${cmd}.md"
        done
    fi
}

# Function to install v3 files from GitHub
# This downloads the native v5 architecture files (hooks, scripts, agents, etc.)
install_v3_from_github() {
    local overwrite="$1"

    echo ""
    echo "📥 Downloading v5 architecture files from GitHub..."

    # Create directories
    mkdir -p "./.claude/commands"
    mkdir -p "./.claude/agents"
    mkdir -p "./.claude/hooks"
    mkdir -p "./.claude/scripts"
    mkdir -p "./.claude/rules"
    mkdir -p "./.claude/skills/artifact-verification"
    mkdir -p "./.claude/skills/context-summary"
    mkdir -p "./.claude/skills/tdd-helper"
    mkdir -p "./.claude/skills/subtask-expansion"
    mkdir -p "./.claude/skills/log-entry"
    mkdir -p "./.claude/skills/context-read"
    mkdir -p "./.claude/skills/context-search"
    mkdir -p "./.claude/skills/context-stats"
    mkdir -p "./.claude/templates/specs"
    mkdir -p "./.claude/templates/tasks"
    mkdir -p "./.claude/templates/test-scenarios"
    mkdir -p "./.agent-os/schemas"

    # Download commands
    echo ""
    echo "  📂 Commands:"
    for cmd in plan-product shape-spec create-spec create-tasks analyze-product debug pr-review-cycle; do
        download_file "${BASE_URL}/v3/commands/${cmd}.md" \
            "./.claude/commands/${cmd}.md" \
            "$overwrite" \
            "commands/${cmd}.md"
    done
    download_file "${BASE_URL}/v3/commands/execute-tasks.md" \
        "./.claude/commands/execute-tasks.md" \
        "$overwrite" \
        "commands/execute-tasks.md"
    for cmd in execute-spec create-test-plan run-tests; do
        download_file "${BASE_URL}/v3/commands/${cmd}.md" \
            "./.claude/commands/${cmd}.md" \
            "$overwrite" \
            "commands/${cmd}.md"
    done

    # Download agents (18 agents)
    echo ""
    echo "  📂 Agents:"
    for agent in phase1-discovery phase2-implementation phase3-delivery wave-orchestrator subtask-group-worker pr-review-discovery pr-review-implementation future-classifier comment-classifier roadmap-integrator git-workflow project-manager execute-spec-orchestrator wave-lifecycle-agent test-discovery test-executor test-reporter review-watcher; do
        download_file "${BASE_URL}/v3/agents/${agent}.md" \
            "./.claude/agents/${agent}.md" \
            "$overwrite" \
            "agents/${agent}.md"
    done

    # Download hooks (9 hooks)
    echo ""
    echo "  📂 Hooks:"
    for hook in session-start session-end post-file-change pre-commit-gate subagent-start subagent-stop setup task-completed teammate-idle; do
        download_file "${BASE_URL}/v3/hooks/${hook}.sh" \
            "./.claude/hooks/${hook}.sh" \
            "$overwrite" \
            "hooks/${hook}.sh"
        chmod +x "./.claude/hooks/${hook}.sh" 2>/dev/null || true
    done

    # Download scripts
    echo ""
    echo "  📂 Scripts:"
    for script in task-operations.sh pr-review-operations.sh branch-setup.sh execute-spec-operations.sh test-operations.sh redact-secrets.sh; do
        download_file "${BASE_URL}/v3/scripts/${script}" \
            "./.claude/scripts/${script}" \
            "$overwrite" \
            "scripts/${script}"
        chmod +x "./.claude/scripts/${script}" 2>/dev/null || true
    done
    for script in json-to-markdown.js test-plan-to-markdown.js test-report-to-markdown.js ast-verify.ts wave-parallel.ts verification-loop.ts e2e-utils.ts test-patterns.ts compute-waves.ts migrate-v3-to-v4.js; do
        download_file "${BASE_URL}/v3/scripts/${script}" \
            "./.claude/scripts/${script}" \
            "$overwrite" \
            "scripts/${script}"
    done

    # Download memory/rules
    echo ""
    echo "  📂 Memory:"
    download_file "${BASE_URL}/v3/memory/CLAUDE.md" \
        "./.claude/CLAUDE.md" \
        "$overwrite" \
        "CLAUDE.md"
    download_file "${BASE_URL}/v3/memory/ENV-VARS.md" \
        "./.claude/ENV-VARS.md" \
        "$overwrite" \
        "ENV-VARS.md"
    for rule in tdd-workflow git-conventions execute-tasks error-handling verification-loop e2e-integration agent-tool-restrictions e2e-fixtures e2e-batch-checkpoint teams-integration; do
        download_file "${BASE_URL}/v3/memory/rules/${rule}.md" \
            "./.claude/rules/${rule}.md" \
            "$overwrite" \
            "rules/${rule}.md"
    done

    # Download skills
    echo ""
    echo "  📂 Skills:"
    for skill in artifact-verification context-summary tdd-helper subtask-expansion log-entry context-read context-search context-stats; do
        download_file "${BASE_URL}/v3/skills/${skill}/SKILL.md" \
            "./.claude/skills/${skill}/SKILL.md" \
            "$overwrite" \
            "skills/${skill}/SKILL.md"
    done

    # Download templates
    echo ""
    echo "  📂 Templates:"
    for template in feature bugfix refactor integration; do
        download_file "${BASE_URL}/v3/templates/specs/${template}.md" \
            "./.claude/templates/specs/${template}.md" \
            "$overwrite" \
            "templates/specs/${template}.md"
    done
    for template in api-endpoint react-component bugfix refactor; do
        download_file "${BASE_URL}/v3/templates/tasks/${template}.json" \
            "./.claude/templates/tasks/${template}.json" \
            "$overwrite" \
            "templates/tasks/${template}.json"
    done
    for template in authentication form-validation crud-operations; do
        download_file "${BASE_URL}/v3/templates/test-scenarios/${template}.json" \
            "./.claude/templates/test-scenarios/${template}.json" \
            "$overwrite" \
            "templates/test-scenarios/${template}.json"
    done

    # Download settings
    echo ""
    echo "  📂 Settings:"
    download_file "${BASE_URL}/v3/settings.json" \
        "./.claude/settings.json" \
        "$overwrite" \
        "settings.json"

    # Download schemas
    echo ""
    echo "  📂 Schemas:"
    for schema in tasks-v3.json tasks-v4.json execute-spec-v1.json; do
        download_file "${BASE_URL}/v3/schemas/${schema}" \
            "./.agent-os/schemas/${schema}" \
            "$overwrite" \
            "schemas/${schema}"
    done
}

