#!/bin/bash

# JetBrains Rider installation script

# Source common functions
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/common.sh"

install_rider() {
    print_status "Installing JetBrains Rider..."
    log_script_start "install-rider.sh"
    
    # Install via snap (easiest method)
    if command_exists snap; then
        print_status "Installing Rider via snap..."
        sudo snap install rider --classic
    else
        # Install snap if not available
        install_package "snapd" "Snap"
        sudo snap install rider --classic
    fi
    
    print_success "JetBrains Rider installation complete"
    
    # Check if Toolbox is preferred
    print_status "For better plugin management, consider installing JetBrains Toolbox:"
    print_status "Download from: https://www.jetbrains.com/toolbox-app/"
    
    log_script_end "install-rider.sh" 0
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_rider
fi