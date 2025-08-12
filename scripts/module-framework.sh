#!/bin/bash

# Module Framework - Common functionality for all modules
# Extracts boilerplate and provides standardized module patterns

# Source common functions
FRAMEWORK_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$FRAMEWORK_SCRIPT_DIR/common.sh"

# Standard module structure and helper functions

# Initialize a module with standard boilerplate
init_module() {
    local module_name="$1"
    local module_display_name="$2"
    
    if [ -z "$module_name" ] || [ -z "$module_display_name" ]; then
        print_error "Usage: init_module <module_name> <display_name>"
        return 1
    fi
    
    # Set global module variables
    export MODULE_NAME="$module_name"
    export MODULE_DISPLAY_NAME="$module_display_name"
    export MODULE_SCRIPT_PATH="$module_name/install.sh"
    
    print_status "Installing $module_display_name module..."
    log_script_start "$MODULE_SCRIPT_PATH"
    
    # Enhanced logging for module initialization
    if declare -f log_module_start > /dev/null 2>&1; then
        log_module_start "$module_name"
    fi
}

# Standard module completion
complete_module() {
    local exit_code=${1:-0}
    log_script_end "$MODULE_SCRIPT_PATH" "$exit_code"
    
    # Enhanced logging for module completion
    if declare -f log_module_success > /dev/null 2>&1 && declare -f log_module_failure > /dev/null 2>&1; then
        if [ "$exit_code" -eq 0 ]; then
            log_module_success "$MODULE_NAME"
        else
            log_module_failure "$MODULE_NAME" "Installation script returned exit code $exit_code"
        fi
    fi
    
    return "$exit_code"
}

# Standard already-installed check pattern
handle_already_installed() {
    local check_function="$1"
    local verify_function="$2"
    
    if "$check_function"; then
        print_warning "$MODULE_DISPLAY_NAME is already installed"
        if [ -n "$verify_function" ]; then
            "$verify_function"
        fi
        complete_module 0
        return 0
    fi
    return 1
}

# Standard installation flow
run_standard_install_flow() {
    local check_function="$1"
    local install_function="$2"
    local verify_function="$3"
    local info_function="$4"
    
    # Check if already installed
    if handle_already_installed "$check_function" "$verify_function"; then
        return 0
    fi
    
    # Run installation
    if "$install_function"; then
        print_success "$MODULE_DISPLAY_NAME installed successfully"
    else
        print_error "Failed to install $MODULE_DISPLAY_NAME"
        complete_module 1
        return 1
    fi
    
    # Verify installation
    if [ -n "$verify_function" ]; then
        if "$verify_function"; then
            print_success "$MODULE_DISPLAY_NAME verification completed"
        else
            print_warning "$MODULE_DISPLAY_NAME installation may have issues"
        fi
    fi
    
    # Show post-installation info
    if [ -n "$info_function" ]; then
        "$info_function"
    fi
    
    complete_module 0
    return 0
}

# Read module configuration
get_module_config() {
    local key="$1"
    local module_dir="${2:-$(get_current_module_dir)}"
    local config_file="$module_dir/module.json"
    
    if [ -f "$config_file" ]; then
        jq -r "$key // empty" "$config_file" 2>/dev/null
    fi
}

# Get current module directory
get_current_module_dir() {
    if [ -n "$MODULE_SCRIPT_DIR" ]; then
        echo "$MODULE_SCRIPT_DIR"
    else
        echo "$( cd "$( dirname "${BASH_SOURCE[1]}" )" &> /dev/null && pwd )"
    fi
}

# Standard verification patterns
verify_command_available() {
    local command_name="$1"
    local display_name="${2:-$command_name}"
    
    if is_dry_run; then
        print_would_execute "$command_name --version"
        return 0
    fi
    
    if command_exists "$command_name"; then
        local version=$("$command_name" --version 2>/dev/null | head -n1 || echo "unknown")
        print_success "$display_name: $version"
        return 0
    else
        print_error "$display_name verification failed - command not found"
        return 1
    fi
}

# Standard package installation with dry-run
install_package_with_dry_run() {
    local package="$1"
    local display_name="${2:-$package}"
    
    if is_dry_run; then
        print_would_install "$package" "$display_name"
        return 0
    fi
    
    install_package "$package" "$display_name"
}

# Download and install from URL pattern
download_and_install() {
    local url="$1"
    local temp_name="$2"
    local install_command="$3"
    local description="${4:-file}"
    
    if is_dry_run; then
        print_would_execute "wget $url -O /tmp/$temp_name"
        print_would_execute "$install_command /tmp/$temp_name"
        return 0
    fi
    
    print_status "Downloading $description..."
    local temp_file="/tmp/$temp_name"
    
    if wget -q "$url" -O "$temp_file"; then
        print_status "Installing $description..."
        if eval "$install_command $temp_file"; then
            print_success "$description installed successfully"
            rm -f "$temp_file"
            return 0
        else
            print_error "Failed to install $description"
            rm -f "$temp_file"
            return 1
        fi
    else
        print_error "Failed to download $description from $url"
        return 1
    fi
}

# Snap installation pattern
install_snap_package() {
    local package="$1"
    local flags="${2:-}"
    local display_name="${3:-$package}"
    
    if is_dry_run; then
        print_would_install "snapd" "Snap package manager"
        print_would_execute "sudo snap install $package $flags"
        return 0
    fi
    
    # Ensure snap is available
    if ! command_exists snap; then
        print_status "Installing snap package manager..."
        install_package "snapd" "Snap"
        
        print_status "Enabling snap services..."
        sudo systemctl enable snapd
        sudo systemctl start snapd
        
        if [ ! -L /snap ]; then
            sudo ln -s /var/lib/snapd/snap /snap
        fi
    fi
    
    print_status "Installing $display_name via snap..."
    if sudo snap install "$package" $flags; then
        print_success "$display_name installed successfully via snap"
        return 0
    else
        print_error "Failed to install $display_name via snap"
        return 1
    fi
}

# NPM global package installation pattern
install_npm_global() {
    local package="$1"
    local display_name="${2:-$package}"
    
    if is_dry_run; then
        print_would_execute "npm install -g $package"
        return 0
    fi
    
    print_status "Installing global package: $display_name"
    if npm install -g "$package"; then
        print_success "Installed: $display_name"
        log_package_operation "install" "$package" "global"
        return 0
    else
        print_error "Failed to install: $display_name"
        log_package_operation "install" "$package" "failed"
        return 1
    fi
}

# Repository addition pattern
add_apt_repository() {
    local repo_key_url="$1"
    local repo_line="$2"
    local list_file="$3"
    local description="${4:-repository}"
    
    if is_dry_run; then
        print_would_execute "wget -qO- $repo_key_url | gpg --dearmor"
        print_would_execute "echo '$repo_line' > $list_file"
        print_would_execute "apt update"
        return 0
    fi
    
    print_status "Adding $description..."
    log_info "Adding $description repository"
    
    # Create keyrings directory if it doesn't exist
    sudo mkdir -p /etc/apt/keyrings
    
    # Remove existing repository file to avoid conflicts
    if [ -f "$list_file" ]; then
        print_status "Removing existing $description configuration..."
        sudo rm -f "$list_file"
    fi
    
    # Add GPG key with comprehensive error handling
    local keyring_file="/etc/apt/keyrings/$(basename "$list_file" .list).gpg"
    local temp_key_file="/tmp/$(basename "$list_file" .list)-key.gpg"
    
    print_status "Downloading GPG key for $description..."
    # Try with curl first, then wget
    if curl -fsSL "$repo_key_url" -o "$temp_key_file" 2>/dev/null || wget -qO "$temp_key_file" "$repo_key_url" 2>/dev/null; then
        print_status "Installing GPG key for $description..."
        
        # Check if key is already in armor format or binary
        if file "$temp_key_file" | grep -q "PGP public key"; then
            # Already in binary format
            sudo cp "$temp_key_file" "$keyring_file"
        else
            # Need to dearmor
            if sudo gpg --dearmor -o "$keyring_file" < "$temp_key_file" 2>/dev/null; then
                print_success "GPG key installed for $description"
            else
                # Try alternative method
                cat "$temp_key_file" | sudo gpg --dearmor | sudo tee "$keyring_file" > /dev/null
            fi
        fi
        
        # Set proper permissions
        sudo chmod 644 "$keyring_file"
        
        # Clean up temporary file
        rm -f "$temp_key_file"
        
        # Validate repository line format
        if [[ "$repo_line" =~ ^deb.*\[.*signed-by=.*\].*$ ]]; then
            print_status "Adding repository configuration..."
            echo "$repo_line" | sudo tee "$list_file" > /dev/null
            
            # Update package lists with detailed error handling
            print_status "Updating package lists..."
            local apt_output
            if apt_output=$(sudo apt update 2>&1); then
                print_success "$description added successfully"
                log_info "Successfully updated package lists after adding $description"
                return 0
            else
                # Check if it's just warnings or actual errors
                if echo "$apt_output" | grep -q "^E:"; then
                    print_error "$description added but apt update failed"
                    log_error_details "Repository Setup" "apt update failed after adding $description: $apt_output"
                    # Remove the problematic repository
                    sudo rm -f "$list_file"
                    return 1
                else
                    print_warning "$description added but apt update had warnings"
                    log_warning "Added $description repository with APT warnings"
                    return 0
                fi
            fi
        else
            print_error "Invalid repository line format for $description"
            log_error_details "Repository Setup" "Invalid repository line format: $repo_line"
            rm -f "$temp_key_file"
            return 1
        fi
    else
        print_error "Failed to download GPG key for $description from $repo_key_url"
        log_error_details "Repository Setup" "Failed to download GPG key from $repo_key_url"
        return 1
    fi
}

# Standard post-installation info display
show_post_install_info() {
    local module_name="$1"
    local next_steps="$2"
    local docs_url="$3"
    local config_notes="$4"
    
    if is_dry_run; then
        print_would_configure "$module_name" "post-installation information"
        return 0
    fi
    
    print_status "$module_name Installation Complete!"
    echo ""
    
    if [ -n "$next_steps" ]; then
        echo "Next steps:"
        echo "$next_steps"
        echo ""
    fi
    
    if [ -n "$docs_url" ]; then
        echo "Documentation: $docs_url"
    fi
    
    if [ -n "$config_notes" ]; then
        echo ""
        echo "Configuration notes:"
        echo "$config_notes"
    fi
    
    echo ""
}

# Export functions for use in modules
export -f init_module
export -f complete_module
export -f handle_already_installed
export -f run_standard_install_flow
export -f get_module_config
export -f get_current_module_dir
export -f verify_command_available
export -f install_package_with_dry_run
export -f download_and_install
export -f install_snap_package
export -f install_npm_global
export -f add_apt_repository
export -f show_post_install_info