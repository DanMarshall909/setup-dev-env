#!/bin/bash

# JetBrains Rider module status script

# Source common functions
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/../../scripts/common.sh"

check_rider_status() {
    local command="$1"
    
    case "$command" in
        "installed")
            # Return 0 if installed, 1 if not
            if snap list rider 2>/dev/null | grep -q rider; then
                return 0
            elif command -v rider &>/dev/null; then
                return 0
            else
                return 1
            fi
            ;;
        "summary")
            # Short status for module listing
            if snap list rider 2>/dev/null | grep -q rider; then
                local version=$(snap list rider 2>/dev/null | grep rider | awk '{print $2}')
                echo "✅ JetBrains Rider $version (snap)"
            elif command -v rider &>/dev/null; then
                echo "✅ JetBrains Rider (installed)"
            else
                echo "❌ JetBrains Rider not installed"
            fi
            ;;
        "status")
            # Detailed JSON status
            local installed=false
            local version="unknown"
            local install_method="none"
            local command_available=false
            
            if snap list rider 2>/dev/null | grep -q rider; then
                installed=true
                version=$(snap list rider 2>/dev/null | grep rider | awk '{print $2}')
                install_method="snap"
            elif command -v rider &>/dev/null; then
                installed=true
                install_method="manual"
                command_available=true
            fi
            
            if command -v rider &>/dev/null; then
                command_available=true
            fi
            
            local config_dir=""
            if [ -d "$HOME/.config/JetBrains" ]; then
                config_dir=$(find "$HOME/.config/JetBrains" -name "Rider*" -type d | head -n1)
            fi
            
            cat << EOF
{
  "name": "rider",
  "installed": $installed,
  "version": "$version",
  "install_method": "$install_method",
  "command_available": $command_available,
  "config_directory": "$config_dir",
  "snap_installed": $(snap list rider 2>/dev/null | grep -q rider && echo true || echo false),
  "toolbox_available": $(command -v jetbrains-toolbox &>/dev/null && echo true || echo false)
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
    check_rider_status "${1:-summary}"
fi