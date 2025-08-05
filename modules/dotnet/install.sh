#!/bin/bash

# .NET SDK module installation script - reusing code from scripts/install-dotnet.sh

# Source module framework
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/../../scripts/module-framework.sh"

# Check if .NET is already installed
check_dotnet_installed() {
    command -v dotnet &>/dev/null
}

# Install .NET SDK - reusing logic from scripts/install-dotnet.sh
install_dotnet() {
    if is_dry_run; then
        print_would_execute "wget Microsoft package configuration"
        print_would_execute "dpkg -i packages-microsoft-prod.deb"
        print_would_install "dotnet-sdk-8.0" ".NET 8 SDK"
        print_would_execute "dotnet --version"
        return 0
    fi
    
    # Download and install Microsoft package repository
    print_status "Adding Microsoft package repository..."
    local temp_deb="packages-microsoft-prod.deb"
    local ubuntu_version=$(lsb_release -rs)
    local repo_url="https://packages.microsoft.com/config/ubuntu/${ubuntu_version}/packages-microsoft-prod.deb"
    
    download_and_install "$repo_url" "$temp_deb" "sudo dpkg -i" "Microsoft package repository"
    
    # Update package list and install .NET SDK
    update_repositories
    install_package_with_dry_run "dotnet-sdk-8.0" ".NET 8 SDK"
    
    return 0
}

# Verify .NET installation
verify_dotnet_installation() {
    if is_dry_run; then
        print_would_execute "dotnet --version"
        print_would_execute "dotnet --list-sdks"
        print_success "DRY RUN: .NET verification would complete"
        return 0
    fi
    
    # Verify dotnet command
    if verify_command_available "dotnet" ".NET CLI"; then
        # Show installed SDKs
        print_status "Installed .NET SDKs:"
        dotnet --list-sdks
        return 0
    else
        return 1
    fi
}

# Show .NET post-installation info
show_dotnet_info() {
    local next_steps="1. Create a new project: dotnet new console -n MyApp
2. Navigate to project: cd MyApp
3. Run the project: dotnet run
4. Install packages: dotnet add package PackageName
5. Build for production: dotnet publish -c Release"
    
    local docs_url="https://docs.microsoft.com/en-us/dotnet/"
    
    local config_notes=".NET SDK includes the runtime and development tools.
Global tools can be installed with: dotnet tool install -g <tool-name>
Create different project types with: dotnet new <template>"
    
    show_post_install_info ".NET SDK" "$next_steps" "$docs_url" "$config_notes"
}

# Main module execution using framework
install_dotnet_module() {
    init_module "dotnet" ".NET SDK"
    
    run_standard_install_flow \
        "check_dotnet_installed" \
        "install_dotnet" \
        "verify_dotnet_installation" \
        "show_dotnet_info"
}

# Execute if run directly
install_dotnet_module