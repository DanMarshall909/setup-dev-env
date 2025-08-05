#!/bin/bash

# .NET SDK installation script

# Source common functions
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/common.sh"

install_dotnet() {
    print_status "Installing .NET SDK..."
    log_script_start "install-dotnet.sh"
    
    # Install Microsoft package repository
    print_status "Adding Microsoft package repository..."
    wget https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
    sudo dpkg -i packages-microsoft-prod.deb
    rm packages-microsoft-prod.deb
    
    # Update and install
    update_repositories
    install_package "dotnet-sdk-8.0" ".NET 8 SDK"
    
    # Show version
    print_success ".NET SDK installation complete:"
    dotnet --version
    dotnet --list-sdks
    
    log_script_end "install-dotnet.sh" 0
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_dotnet
fi