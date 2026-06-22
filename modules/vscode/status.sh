#!/bin/bash

# VS Code module status script

# Source common functions
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/../../scripts/common.sh"

CORE_EXTENSIONS=(
    "ms-dotnettools.csharp"
    "esbenp.prettier-vscode"
    "ms-vscode.eslint"
    "eamodio.gitlens"
    "ms-vscode-remote.remote-ssh"
    "ms-azuretools.vscode-docker"
)

missing_vscode_extensions() {
    local extension
    if ! command -v code &>/dev/null; then
        printf '%s\n' "${CORE_EXTENSIONS[@]}"
        return
    fi

    local installed_extensions
    installed_extensions=$(code --list-extensions 2>/dev/null || true)
    for extension in "${CORE_EXTENSIONS[@]}"; do
        if ! echo "$installed_extensions" | grep -q "^$extension$"; then
            echo "$extension"
        fi
    done
}

check_vscode_status() {
    local command="$1"
    
    case "$command" in
        "installed")
            command -v code &>/dev/null && [ -z "$(missing_vscode_extensions)" ]
            ;;
        "summary")
            # Short status for module listing
            if command -v code &>/dev/null; then
                local version=$(code --version 2>/dev/null | head -n1)
                local missing
                missing=$(missing_vscode_extensions | tr '\n' ' ')
                if [ -n "$missing" ]; then
                    echo "❌ VS Code $version missing extensions: $missing"
                elif [ -n "$version" ]; then
                    echo "✅ VS Code $version"
                else
                    echo "✅ VS Code (installed)"
                fi
            else
                echo "❌ VS Code not installed"
            fi
            ;;
        "status")
            # Detailed JSON status
            local installed=false
            local version="unknown"
            local command_available=false
            local extensions_count=0
            local config_dir=""
            
            if command -v code &>/dev/null; then
                installed=true
                command_available=true
                version=$(code --version 2>/dev/null | head -n1 || echo "unknown")
                extensions_count=$(code --list-extensions 2>/dev/null | wc -l || echo 0)
            fi
            
            # Check config directory
            if [ -d "$HOME/.config/Code" ]; then
                config_dir="$HOME/.config/Code"
            fi
            
            # Get list of installed extensions
            local extensions_json="[]"
            if [ "$installed" = "true" ]; then
                local ext_list=$(code --list-extensions 2>/dev/null || echo "")
                if [ -n "$ext_list" ]; then
                    extensions_json=$(echo "$ext_list" | jq -R . | jq -s .)
                fi
            fi
            
            # Check for specific extensions we install
            local missing_extensions_json="[]"
            local core_extensions_ok=true
            local extensions_status="{}"
            for ext in "${CORE_EXTENSIONS[@]}"; do
                local ext_installed=false
                if [ "$installed" = "true" ] && code --list-extensions 2>/dev/null | grep -q "^$ext$"; then
                    ext_installed=true
                else
                    core_extensions_ok=false
                    missing_extensions_json=$(echo "$missing_extensions_json" | jq --arg ext "$ext" '. + [$ext]')
                fi
                extensions_status=$(echo "$extensions_status" | jq --arg ext "$ext" --argjson status "$ext_installed" '.[$ext] = $status')
            done

            if [ "$installed" = "true" ] && [ "$core_extensions_ok" != "true" ]; then
                installed=false
            fi
            
            cat << EOF
{
  "name": "vscode",
  "installed": $installed,
  "version": "$version",
  "command_available": $command_available,
  "config_directory": "$config_dir",
  "extensions_count": $extensions_count,
  "extensions": $extensions_json,
  "core_extensions_status": $extensions_status,
  "missing_core_extensions": $missing_extensions_json
}
EOF
            ;;
        *)
            echo "Usage: $0 {installed|summary|status}"
            exit 1
            ;;
    esac
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    check_vscode_status "${1:-summary}"
fi
