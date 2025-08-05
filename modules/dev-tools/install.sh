#!/bin/bash

# Module Template - Copy and customize for new modules
# Replace dev_tools, MODULE_DISPLAY_NAME, and implement the functions

# Source module framework
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/../scripts/module-framework.sh"

# Module-specific configuration
dev_tools="dev-tools"
MODULE_DISPLAY_NAME="Development Tools"

# Required: Check if module is already installed
check_dev_tools_installed() {
    # Implement your check logic here
    # Examples:
    # command -v some_command &>/dev/null
    # dpkg -l | grep -q some_package
    # snap list some_snap 2>/dev/null | grep -q some_snap
    # [ -f /some/file/path ]
    
    return 1  # Not installed
}

# Required: Install the module
install_dev_tools() {
    # Implement your installation logic here
    # Use framework functions for common patterns:
    
    # For apt packages:
    # install_package_with_dry_run "package-name" "Display Name"
    
    # For snap packages:
    # install_snap_package "package-name" "--classic" "Display Name"
    
    # For downloads:
    # download_and_install "https://example.com/file.deb" "temp.deb" "sudo dpkg -i" "Package Name"
    
    # For npm packages:
    # install_npm_global "package-name" "Display Name"
    
    # For adding repositories:
    # add_apt_repository "https://example.com/key.gpg" "deb https://example.com/repo stable main" "/etc/apt/sources.list.d/example.list" "Example Repository"
    
    print_status "Installing $MODULE_DISPLAY_NAME..."
    # Your installation commands here
    
    return 0  # Success
}

# Optional: Verify installation
verify_dev_tools_installation() {
    # Use framework function for command verification:
    # verify_command_available "command-name" "Display Name"
    
    # Or implement custom verification:
    if is_dry_run; then
        print_would_execute "verification commands here"
        print_success "DRY RUN: $MODULE_DISPLAY_NAME verification would complete"
        return 0
    fi
    
    # Your verification logic here
    print_success "$MODULE_DISPLAY_NAME verification completed"
    return 0
}

# Optional: Show post-installation information
show_dev_tools_info() {
    local next_steps="1. First step to configure
2. Second step
3. Third step"
    
    local docs_url="https://example.com/docs"
    
    local config_notes="Additional configuration notes here"
    
    show_post_install_info "$MODULE_DISPLAY_NAME" "$next_steps" "$docs_url" "$config_notes"
}

# Main module execution using framework
install_dev_tools_module() {
    init_module "$dev_tools" "$MODULE_DISPLAY_NAME"
    
    run_standard_install_flow \
        "check_${dev_tools}_installed" \
        "install_${dev_tools}" \
        "verify_${dev_tools}_installation" \
        "show_${dev_tools}_info"
}

# Execute if run directly
install_dev_tools_module