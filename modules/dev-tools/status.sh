#!/bin/bash

# Development Tools module status script

# Source common functions
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/../../scripts/common.sh"

DEV_TOOL_COMMANDS=(
    "ripgrep:rg"
    "fd-find:fd"
    "bat:bat"
    "fzf:fzf"
    "tldr:tldr"
    "ncdu:ncdu"
    "duf:duf"
    "httpie:http"
    "jless:jless"
    "yq:yq"
)

missing_dev_tools() {
    local spec name command_name
    for spec in "${DEV_TOOL_COMMANDS[@]}"; do
        name="${spec%%:*}"
        command_name="${spec#*:}"
        if ! command -v "$command_name" &>/dev/null; then
            echo "$name"
        fi
    done
}

check_dev_tools_status() {
    local command="$1"
    
    case "$command" in
        "installed")
            [ -z "$(missing_dev_tools)" ]
            ;;
        "summary")
            local missing
            missing=$(missing_dev_tools | tr '\n' ' ')
            if [ -z "$missing" ]; then
                echo "✅ Development Tools (${#DEV_TOOL_COMMANDS[@]}/${#DEV_TOOL_COMMANDS[@]} tools)"
            else
                echo "❌ Development Tools missing: $missing"
            fi
            ;;
        "status")
            local tools_status="{}"
            local missing_json="[]"
            local installed=true
            local missing_count=0
            local spec name command_name

            for spec in "${DEV_TOOL_COMMANDS[@]}"; do
                name="${spec%%:*}"
                command_name="${spec#*:}"
                local tool_installed=false
                if command -v "$command_name" &>/dev/null; then
                    tool_installed=true
                else
                    installed=false
                    missing_count=$((missing_count + 1))
                    missing_json=$(echo "$missing_json" | jq --arg name "$name" '. + [$name]')
                fi
                tools_status=$(echo "$tools_status" | jq --arg name "$name" --arg command "$command_name" --argjson installed "$tool_installed" '.[$name] = {"command": $command, "installed": $installed}')
            done

            local installed_count=$((${#DEV_TOOL_COMMANDS[@]} - missing_count))
            local module_status="installed"
            if [ "$installed" != "true" ]; then
                module_status="partial"
            fi
            
            cat << EOFSTATUS
{
  "name": "dev-tools",
  "installed": $installed,
  "module_status": "$module_status",
  "installed_count": $installed_count,
  "total_count": ${#DEV_TOOL_COMMANDS[@]},
  "tools": $tools_status,
  "missing_tools": $missing_json
}
EOFSTATUS
            ;;
        *)
            echo "Usage: $0 {installed|summary|status}"
            exit 1
            ;;
    esac
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    check_dev_tools_status "${1:-summary}"
fi
