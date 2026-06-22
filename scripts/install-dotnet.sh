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
    local ubuntu_version
    ubuntu_version=$(get_ubuntu_compatible_version)
    if [ -z "$ubuntu_version" ]; then
        print_error "Could not determine Ubuntu-compatible version for Microsoft package repository"
        log_script_end "install-dotnet.sh" 1
        return 1
    fi

    local temp_deb="/tmp/packages-microsoft-prod.deb"
    if ! wget "https://packages.microsoft.com/config/ubuntu/${ubuntu_version}/packages-microsoft-prod.deb" -O "$temp_deb"; then
        print_error "Failed to download Microsoft package repository"
        log_script_end "install-dotnet.sh" 1
        return 1
    fi
    if ! sudo dpkg -i "$temp_deb"; then
        print_error "Failed to install Microsoft package repository"
        rm -f "$temp_deb"
        log_script_end "install-dotnet.sh" 1
        return 1
    fi
    rm -f "$temp_deb"
    
    # Update and install
    update_repositories || { log_script_end "install-dotnet.sh" 1; return 1; }
    install_package "dotnet-sdk-8.0" ".NET 8 SDK" || { log_script_end "install-dotnet.sh" 1; return 1; }
    
    # Show version
    print_success ".NET SDK installation complete:"
    dotnet --version || { log_script_end "install-dotnet.sh" 1; return 1; }
    dotnet --list-sdks || { log_script_end "install-dotnet.sh" 1; return 1; }
    
    log_script_end "install-dotnet.sh" 0
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_dotnet
fi
