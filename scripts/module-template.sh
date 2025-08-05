#!/bin/bash

# Module Template - Copy and customize for new modules
# Replace MODULE_NAME, MODULE_DISPLAY_NAME, and implement the functions

# Source module framework
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/../scripts/module-framework.sh"

# Module-specific configuration
MODULE_NAME="template"
MODULE_DISPLAY_NAME="Template Module"

# Required: Check if module is already installed
check_MODULE_NAME_installed() {
    # Implement your check logic here
    # Examples:
    # command -v some_command &>/dev/null
    # dpkg -l | grep -q some_package
    # snap list some_snap 2>/dev/null | grep -q some_snap
    # [ -f /some/file/path ]
    
    return 1  # Not installed
}

# Required: Install the module
install_MODULE_NAME() {
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
verify_MODULE_NAME_installation() {
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
show_MODULE_NAME_info() {
    local next_steps="1. First step to configure
2. Second step
3. Third step"
    
    local docs_url="https://example.com/docs"
    
    local config_notes="Additional configuration notes here"
    
    show_post_install_info "$MODULE_DISPLAY_NAME" "$next_steps" "$docs_url" "$config_notes"
}

# Main module execution using framework
install_MODULE_NAME_module() {
    init_module "$MODULE_NAME" "$MODULE_DISPLAY_NAME"
    
    run_standard_install_flow \
        "check_${MODULE_NAME}_installed" \
        "install_${MODULE_NAME}" \
        "verify_${MODULE_NAME}_installation" \
        "show_${MODULE_NAME}_info"
}

# Execute if run directly
install_MODULE_NAME_module