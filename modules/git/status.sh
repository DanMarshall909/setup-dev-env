#!/bin/bash

# Git module status checking script

# Source common functions
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/../../scripts/common.sh"

# Check if Git module is installed and return detailed status
check_git_status() {
    local status="{}"
    
    # Check if Git is installed
    if command_exists git; then
        local git_version=$(git --version 2>/dev/null | head -n1)
        status=$(echo "$status" | jq --arg v "$git_version" '.git.installed = true | .git.version = $v')
        
        # Check Git configuration
        local git_name=$(git config --global user.name 2>/dev/null || echo "")
        local git_email=$(git config --global user.email 2>/dev/null || echo "")
        local git_editor=$(git config --global core.editor 2>/dev/null || echo "")
        
        status=$(echo "$status" | jq --arg name "$git_name" --arg email "$git_email" --arg editor "$git_editor" '
            .git.config = {
                "user_name": $name,
                "user_email": $email,
                "editor": $editor
            }')
    else
        status=$(echo "$status" | jq '.git.installed = false | .git.version = null')
    fi
    
    # Check if GitHub CLI is installed
    if command_exists gh; then
        local gh_version=$(gh --version 2>/dev/null | head -n1)
        status=$(echo "$status" | jq --arg v "$gh_version" '.github_cli.installed = true | .github_cli.version = $v')
        
        # Check GitHub CLI authentication
        if gh auth status &>/dev/null; then
            local gh_user=$(gh api user --jq '.login' 2>/dev/null || echo "unknown")
            status=$(echo "$status" | jq --arg user "$gh_user" '.github_cli.authenticated = true | .github_cli.user = $user')
        else
            status=$(echo "$status" | jq '.github_cli.authenticated = false | .github_cli.user = null')
        fi
    else
        status=$(echo "$status" | jq '.github_cli.installed = false | .github_cli.version = null')
    fi
    
    # Overall module status
    local git_ok=$(echo "$status" | jq -r '.git.installed // false')
    local gh_ok=$(echo "$status" | jq -r '.github_cli.installed // false')
    
    if [ "$git_ok" = "true" ] && [ "$gh_ok" = "true" ]; then
        status=$(echo "$status" | jq '.module_status = "installed"')
    elif [ "$git_ok" = "true" ]; then
        status=$(echo "$status" | jq '.module_status = "partial"')
    else
        status=$(echo "$status" | jq '.module_status = "not_installed"')
    fi
    
    echo "$status"
}

# Return simple boolean for basic check
is_git_installed() {
    command_exists git && command_exists gh
}

# Get installation summary
get_git_summary() {
    local status=$(check_git_status)
    local module_status=$(echo "$status" | jq -r '.module_status')
    
    case $module_status in
        "installed")
            echo "✅ Git and GitHub CLI installed and configured"
            ;;
        "partial")
            echo "⚠️  Git installed, GitHub CLI missing"
            ;;
        "not_installed")
            echo "❌ Git module not installed"
            ;;
    esac
}

# Main function for CLI usage
main() {
    case "${1:-status}" in
        "status"|"check")
            check_git_status | jq .
            ;;
        "installed")
            if is_git_installed; then
                echo "true"
                exit 0
            else
                echo "false"
                exit 1
            fi
            ;;
        "summary")
            get_git_summary
            ;;
        *)
            echo "Usage: $0 [status|installed|summary]"
            echo "  status    - Show detailed status (default)"
            echo "  installed - Return true/false if fully installed"
            echo "  summary   - Show human-readable summary"
            ;;
    esac
}

# Run main function if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi