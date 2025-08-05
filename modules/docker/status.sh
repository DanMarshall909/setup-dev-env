#!/bin/bash

# Docker module status script

# Source common functions
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/../../scripts/common.sh"

check_docker_status() {
    local command="$1"
    
    case "$command" in
        "installed")
            # Return 0 if installed, 1 if not
            command -v docker &>/dev/null
            ;;
        "summary")
            # Short status for module listing
            if command -v docker &>/dev/null; then
                local version=$(docker --version 2>/dev/null | head -n1 || echo "unknown")
                echo "✅ Docker $version"
            else
                echo "❌ Docker not installed"
            fi
            ;;
        "status")
            # Detailed JSON status
            local installed=false
            local version="unknown"
            local command_available=false
            
            if command -v docker &>/dev/null; then
                installed=true
                command_available=true
                version=$(docker --version 2>/dev/null | head -n1 || echo "unknown")
            fi
            
            cat << EOFSTATUS
{
  "name": "docker",
  "installed": $installed,
  "version": "$version",
  "command_available": $command_available
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
    check_docker_status "${1:-summary}"
fi
