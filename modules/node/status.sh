#!/bin/bash

# Node.js module status checking script

# Source common functions
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/../../scripts/common.sh"

# Check if Node.js module is installed and return detailed status
check_node_status() {
    local status="{}"
    
    # Check if Node.js is installed
    if command_exists node; then
        local node_version=$(node --version 2>/dev/null)
        local node_major=$(echo "$node_version" | sed 's/v\([0-9]*\).*/\1/')
        status=$(echo "$status" | jq --arg v "$node_version" --argjson major "$node_major" '
            .node.installed = true | 
            .node.version = $v |
            .node.major_version = $major')
        
        # Check if it's LTS version
        if [ "$node_major" -ge 18 ]; then
            status=$(echo "$status" | jq '.node.is_lts = true')
        else
            status=$(echo "$status" | jq '.node.is_lts = false')
        fi
    else
        status=$(echo "$status" | jq '.node.installed = false | .node.version = null')
    fi
    
    # Check if npm is installed
    if command_exists npm; then
        local npm_version=$(npm --version 2>/dev/null)
        status=$(echo "$status" | jq --arg v "$npm_version" '.npm.installed = true | .npm.version = $v')
        
        # Check npm configuration
        local npm_user=$(npm whoami 2>/dev/null || echo "")
        local npm_registry=$(npm config get registry 2>/dev/null || echo "")
        status=$(echo "$status" | jq --arg user "$npm_user" --arg registry "$npm_registry" '
            .npm.user = $user |
            .npm.registry = $registry')
        
        # Test npm connectivity
        if npm ping &>/dev/null; then
            status=$(echo "$status" | jq '.npm.connectivity = true')
        else
            status=$(echo "$status" | jq '.npm.connectivity = false')
        fi
    else
        status=$(echo "$status" | jq '.npm.installed = false | .npm.version = null')
    fi
    
    # Check TypeScript
    if command_exists tsc; then
        local ts_version=$(tsc --version 2>/dev/null | sed 's/Version //')
        status=$(echo "$status" | jq --arg v "$ts_version" '.typescript.installed = true | .typescript.version = $v')
    else
        status=$(echo "$status" | jq '.typescript.installed = false | .typescript.version = null')
    fi
    
    # Check other global tools
    local tools=("ts-node" "nodemon" "prettier" "eslint")
    for tool in "${tools[@]}"; do
        if command_exists "$tool"; then
            local tool_version=$($tool --version 2>/dev/null | head -n1 || echo "unknown")
            status=$(echo "$status" | jq --arg tool "$tool" --arg v "$tool_version" '.global_tools[$tool] = $v')
        else
            status=$(echo "$status" | jq --arg tool "$tool" '.global_tools[$tool] = null')
        fi
    done
    
    # Overall module status
    local node_ok=$(echo "$status" | jq -r '.node.installed // false')
    local npm_ok=$(echo "$status" | jq -r '.npm.installed // false')
    local ts_ok=$(echo "$status" | jq -r '.typescript.installed // false')
    
    if [ "$node_ok" = "true" ] && [ "$npm_ok" = "true" ] && [ "$ts_ok" = "true" ]; then
        status=$(echo "$status" | jq '.module_status = "installed"')
    elif [ "$node_ok" = "true" ] && [ "$npm_ok" = "true" ]; then
        status=$(echo "$status" | jq '.module_status = "partial"')
    else
        status=$(echo "$status" | jq '.module_status = "not_installed"')
    fi
    
    echo "$status"
}

# Return simple boolean for basic check
is_node_installed() {
    command_exists node && command_exists npm && command_exists tsc
}

# Get installation summary
get_node_summary() {
    local status=$(check_node_status)
    local module_status=$(echo "$status" | jq -r '.module_status')
    local node_version=$(echo "$status" | jq -r '.node.version // "unknown"')
    local npm_version=$(echo "$status" | jq -r '.npm.version // "unknown"')
    local ts_version=$(echo "$status" | jq -r '.typescript.version // "unknown"')
    
    case $module_status in
        "installed")
            echo "✅ Node.js $node_version, npm $npm_version, TypeScript $ts_version"
            ;;
        "partial")
            echo "⚠️  Node.js $node_version, npm $npm_version (TypeScript missing)"
            ;;
        "not_installed")
            echo "❌ Node.js module not installed"
            ;;
    esac
}

# Run health checks
run_health_checks() {
    local module_config="$SCRIPT_DIR/module.json"
    local checks=$(jq -r '.health_checks[]?' "$module_config" 2>/dev/null)
    
    if [ -n "$checks" ]; then
        echo "Running health checks..."
        
        echo "$checks" | jq -c '.' | while read -r check; do
            local name=$(echo "$check" | jq -r '.name')
            local command=$(echo "$check" | jq -r '.command')
            local expected=$(echo "$check" | jq -r '.expected_pattern // .expected_output // ""')
            
            echo -n "  $name: "
            
            local output
            if output=$(eval "$command" 2>&1); then
                if [ -n "$expected" ] && ! echo "$output" | grep -qE "$expected"; then
                    echo "❌ FAIL (unexpected output: $output)"
                else
                    echo "✅ PASS"
                fi
            else
                echo "❌ FAIL (command failed)"
            fi
        done
    fi
}

# Main function for CLI usage
main() {
    case "${1:-status}" in
        "status"|"check")
            check_node_status | jq .
            ;;
        "installed")
            if is_node_installed; then
                echo "true"
                exit 0
            else
                echo "false"
                exit 1
            fi
            ;;
        "summary")
            get_node_summary
            ;;
        "health")
            run_health_checks
            ;;
        *)
            echo "Usage: $0 [status|installed|summary|health]"
            echo "  status    - Show detailed status (default)"
            echo "  installed - Return true/false if fully installed"
            echo "  summary   - Show human-readable summary"
            echo "  health    - Run health checks"
            ;;
    esac
}

# Run main function if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi