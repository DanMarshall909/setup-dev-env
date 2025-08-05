#!/bin/bash

# Claude Code module status checking script

# Source common functions
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/../../scripts/common.sh"

# Check if Claude Code module is installed and return detailed status
check_claude_status() {
    local status="{}"
    
    # Check if Claude Code CLI is installed
    if command_exists claude-code; then
        local claude_version=$(claude-code --version 2>/dev/null | head -n1)
        status=$(echo "$status" | jq --arg v "$claude_version" '.claude_code.installed = true | .claude_code.version = $v')
        
        # Check authentication status
        if claude-code auth status &>/dev/null; then
            local auth_info=$(claude-code auth status 2>/dev/null || echo "authenticated")
            status=$(echo "$status" | jq --arg auth "$auth_info" '.claude_code.authenticated = true | .claude_code.auth_info = $auth')
        else
            status=$(echo "$status" | jq '.claude_code.authenticated = false | .claude_code.auth_info = null')
        fi
        
        # Check configuration
        local config_file="$HOME/.claude/config.json"
        if [ -f "$config_file" ]; then
            local model=$(jq -r '.default_model // "unknown"' "$config_file" 2>/dev/null)
            local features=$(jq -r '.features | keys | join(", ")' "$config_file" 2>/dev/null || echo "unknown")
            status=$(echo "$status" | jq --arg model "$model" --arg features "$features" '
                .claude_code.config_exists = true |
                .claude_code.default_model = $model |
                .claude_code.enabled_features = $features')
        else
            status=$(echo "$status" | jq '.claude_code.config_exists = false')
        fi
    else
        # Check if installed via npm but not in PATH
        if npm list -g @anthropic/claude-code >/dev/null 2>&1; then
            local npm_version=$(npm list -g @anthropic/claude-code 2>/dev/null | grep @anthropic/claude-code | sed 's/.*@//')
            status=$(echo "$status" | jq --arg v "$npm_version" '
                .claude_code.installed = true |
                .claude_code.version = $v |
                .claude_code.in_path = false |
                .claude_code.install_method = "npm"')
        else
            status=$(echo "$status" | jq '.claude_code.installed = false | .claude_code.version = null')
        fi
    fi
    
    # Check Node.js dependency
    if command_exists node; then
        local node_version=$(node --version)
        local node_major=$(echo "$node_version" | sed 's/v\([0-9]*\).*/\1/')
        status=$(echo "$status" | jq --arg v "$node_version" --argjson major "$node_major" '
            .dependencies.node.installed = true |
            .dependencies.node.version = $v |
            .dependencies.node.major_version = $major')
        
        if [ "$node_major" -ge 18 ]; then
            status=$(echo "$status" | jq '.dependencies.node.meets_requirement = true')
        else
            status=$(echo "$status" | jq '.dependencies.node.meets_requirement = false')
        fi
    else
        status=$(echo "$status" | jq '.dependencies.node.installed = false')
    fi
    
    # Overall module status
    local claude_ok=$(echo "$status" | jq -r '.claude_code.installed // false')
    local node_ok=$(echo "$status" | jq -r '.dependencies.node.meets_requirement // false')
    local auth_ok=$(echo "$status" | jq -r '.claude_code.authenticated // false')
    
    if [ "$claude_ok" = "true" ] && [ "$node_ok" = "true" ] && [ "$auth_ok" = "true" ]; then
        status=$(echo "$status" | jq '.module_status = "installed"')
    elif [ "$claude_ok" = "true" ] && [ "$node_ok" = "true" ]; then
        status=$(echo "$status" | jq '.module_status = "partial"')
    elif [ "$claude_ok" = "true" ]; then
        status=$(echo "$status" | jq '.module_status = "dependency_missing"')
    else
        status=$(echo "$status" | jq '.module_status = "not_installed"')
    fi
    
    echo "$status"
}

# Return simple boolean for basic check
is_claude_installed() {
    (command_exists claude-code || npm list -g @anthropic/claude-code >/dev/null 2>&1) && 
    command_exists node
}

# Get installation summary
get_claude_summary() {
    local status=$(check_claude_status)
    local module_status=$(echo "$status" | jq -r '.module_status')
    local claude_version=$(echo "$status" | jq -r '.claude_code.version // "unknown"')
    local authenticated=$(echo "$status" | jq -r '.claude_code.authenticated // false')
    
    case $module_status in
        "installed")
            if [ "$authenticated" = "true" ]; then
                echo "✅ Claude Code $claude_version (authenticated)"
            else
                echo "✅ Claude Code $claude_version (not authenticated)"
            fi
            ;;
        "partial")
            echo "⚠️  Claude Code $claude_version (not authenticated)"
            ;;
        "dependency_missing")
            echo "⚠️  Claude Code installed but Node.js dependency missing"
            ;;
        "not_installed")
            echo "❌ Claude Code not installed"
            ;;
    esac
}

# Check feature availability
check_feature_status() {
    local config_file="$HOME/.claude/config.json"
    
    if [ ! -f "$config_file" ]; then
        echo "No configuration file found"
        return 1
    fi
    
    echo "Feature Status:"
    echo "=============="
    
    local features=$(jq -r '.features // {} | to_entries[] | "\(.key):\(.value)"' "$config_file" 2>/dev/null)
    
    if [ -n "$features" ]; then
        while IFS=: read -r feature enabled; do
            local status_icon="❌"
            if [ "$enabled" = "true" ]; then
                status_icon="✅"
            fi
            printf "  %-20s %s\n" "$feature" "$status_icon"
        done <<< "$features"
    else
        echo "  No features configured"
    fi
}

# Main function for CLI usage
main() {
    case "${1:-status}" in
        "status"|"check")
            check_claude_status | jq .
            ;;
        "installed")
            if is_claude_installed; then
                echo "true"
                exit 0
            else
                echo "false"
                exit 1
            fi
            ;;
        "summary")
            get_claude_summary
            ;;
        "features")
            check_feature_status
            ;;
        "auth")
            if command_exists claude-code; then
                claude-code auth status
            else
                echo "Claude Code CLI not installed"
                exit 1
            fi
            ;;
        *)
            echo "Usage: $0 [status|installed|summary|features|auth]"
            echo "  status    - Show detailed status (default)"
            echo "  installed - Return true/false if fully installed"
            echo "  summary   - Show human-readable summary"
            echo "  features  - Show enabled/disabled features"
            echo "  auth      - Show authentication status"
            ;;
    esac
}

# Run main function if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi