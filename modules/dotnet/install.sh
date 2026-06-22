#!/bin/bash

# .NET SDK module installation script - reusing code from scripts/install-dotnet.sh

# Source module framework
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/../../scripts/module-framework.sh"

# Always run the installer so apt can install newer SDK feature bands over time.
check_dotnet_current() {
    return 1
}

# Install .NET SDK - reusing logic from scripts/install-dotnet.sh
install_dotnet() {
    if is_dry_run; then
        print_would_execute "wget Microsoft package configuration"
        print_would_execute "dpkg -i packages-microsoft-prod.deb"
        print_would_execute "apt-cache search --names-only '^dotnet-sdk-[0-9]+\\.[0-9]+$'"
        print_would_install "latest dotnet-sdk-* package" "latest .NET SDK"
        print_would_execute "dotnet --version"
        return 0
    fi
    
    # Download and install Microsoft package repository
    print_status "Adding Microsoft package repository..."
    local temp_deb="packages-microsoft-prod.deb"
    local ubuntu_version
    ubuntu_version=$(get_ubuntu_compatible_version)
    if [ -z "$ubuntu_version" ]; then
        print_error "Could not determine Ubuntu-compatible version for Microsoft package repository"
        return 1
    fi
    local repo_url="https://packages.microsoft.com/config/ubuntu/${ubuntu_version}/packages-microsoft-prod.deb"
    
    if ! download_and_install "$repo_url" "$temp_deb" "sudo dpkg -i" "Microsoft package repository"; then
        return 1
    fi
    
    # Update package list and install the newest SDK package available in Microsoft's repo
    update_repositories || return 1
    local dotnet_sdk_package
    dotnet_sdk_package=$(get_latest_dotnet_sdk_package) || return 1
    install_or_upgrade_package "$dotnet_sdk_package" "latest .NET SDK ($dotnet_sdk_package)" || return 1
    
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
        "check_dotnet_current" \
        "install_dotnet" \
        "verify_dotnet_installation" \
        "show_dotnet_info"
}

# Execute if run directly
install_dotnet_module
