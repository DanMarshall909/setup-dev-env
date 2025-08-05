#!/bin/bash

# Common functions for setup scripts

# Source logging functions
COMMON_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$COMMON_SCRIPT_DIR/logging.sh"
source "$COMMON_SCRIPT_DIR/security.sh"

# Get the root directory of the setup project
get_root_dir() {
    echo "$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." &> /dev/null && pwd )"
}

# Get settings file path
get_settings_file() {
    echo "$(get_root_dir)/configs/settings.json"
}

# Read setting from JSON config
get_setting() {
    local key=$1
    local settings_file=$(get_settings_file)
    if [ -f "$settings_file" ]; then
        jq -r "$key" "$settings_file" 2>/dev/null || echo ""
    else
        echo ""
    fi
}

# Initialize colors from settings
init_colors() {
    local settings_file=$(get_settings_file)
    if [ -f "$settings_file" ] && command -v jq &> /dev/null; then
        export RED=$(get_setting '.messages.colors.red' | sed 's/\\\\033/\\033/g')
        export GREEN=$(get_setting '.messages.colors.green' | sed 's/\\\\033/\\033/g')
        export YELLOW=$(get_setting '.messages.colors.yellow' | sed 's/\\\\033/\\033/g')
        export BLUE=$(get_setting '.messages.colors.blue' | sed 's/\\\\033/\\033/g')
        export NC=$(get_setting '.messages.colors.nc' | sed 's/\\\\033/\\033/g')
    else
        # Fallback colors if settings not available
        export RED='\033[0;31m'
        export GREEN='\033[0;32m'
        export YELLOW='\033[1;33m'
        export BLUE='\033[0;34m'
        export NC='\033[0m'
    fi
}

# Initialize colors on script load
init_colors

# Get message from settings
get_message() {
    local key=$1
    shift
    local message=$(get_setting ".messages.status.$key")
    if [ -n "$message" ] && [ $# -gt 0 ]; then
        printf "$message" "$@"
    else
        echo "$message"
    fi
}

# Get prompt from settings
get_prompt() {
    local key=$1
    get_setting ".messages.prompts.$key"
}

# Function to print colored output with logging
print_status() {
    local prefix=$(get_setting '.messages.prefixes.info')
    local message="$1"
    echo -e "${BLUE}${prefix}${NC} $message"
    log_info "$message"
}

print_success() {
    local prefix=$(get_setting '.messages.prefixes.success')
    local message="$1"
    echo -e "${GREEN}${prefix}${NC} $message"
    log_info "$message"
}

print_error() {
    local prefix=$(get_setting '.messages.prefixes.error')
    local message="$1"
    echo -e "${RED}${prefix}${NC} $message"
    log_error "$message"
    
    # Pause on first error for debugging
    if [ "${PAUSE_ON_ERROR:-true}" = "true" ]; then
        echo ""
        echo -e "${YELLOW}[DEBUG]${NC} Error encountered. Pausing for investigation..."
        echo -e "${YELLOW}[DEBUG]${NC} Error details: $message"
        echo -e "${YELLOW}[DEBUG]${NC} Press Enter to continue or Ctrl+C to abort..."
        read -p ""
    fi
}

print_warning() {
    local prefix=$(get_setting '.messages.prefixes.warning')
    local message="$1"
    echo -e "${YELLOW}${prefix}${NC} $message"
    log_warning "$message"
}

# Check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Check if running on supported OS
check_supported_os() {
    local supported_os=$(get_setting '.system.supported_os')
    if ! grep -q "$supported_os" /etc/os-release; then
        print_warning "$(get_message 'continue_non_ubuntu')"
        read -p "$(get_prompt 'continue_non_ubuntu')" -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# For compatibility - redirect to new function
check_ubuntu() {
    check_supported_os
}

# Update package repositories
update_repositories() {
    print_status "$(get_message 'updating_repos')"
    local package_manager=$(get_setting '.system.package_manager')
    
    if is_dry_run; then
        print_would_execute "sudo $package_manager update"
        return 0
    fi
    
    # Capture output for error analysis
    local update_output
    if update_output=$(sudo $package_manager update 2>&1); then
        print_success "Package repositories updated successfully"
        return 0
    else
        print_error "Failed to update package repositories"
        echo ""
        echo -e "${YELLOW}[DEBUG]${NC} APT update output:"
        echo "$update_output"
        echo ""
        
        # Check for specific malformed entry errors
        if echo "$update_output" | grep -q "Malformed entry.*in list file"; then
            local malformed_file=$(echo "$update_output" | grep -o "/etc/apt/sources.list.d/[^[:space:]]*\.list" | head -1)
            if [ -n "$malformed_file" ]; then
                print_error "Malformed repository file detected: $malformed_file"
                echo -e "${YELLOW}[DEBUG]${NC} Contents of $malformed_file:"
                if [ -f "$malformed_file" ]; then
                    sudo cat "$malformed_file" | head -5
                else
                    echo "File not found"
                fi
                echo ""
            fi
        fi
        return 1
    fi
}

# Install a package if not already installed
install_package() {
    local package=$1
    local package_name=${2:-$package}  # Display name (optional)
    local package_manager=$(get_setting '.system.package_manager')
    
    log_function_start "install_package" "$package" "$package_name"
    
    if is_dry_run; then
        # In dry-run mode, simulate the check and installation
        print_would_install "$package" "$package_name"
        print_would_execute "sudo $package_manager install -y $package"
        log_package_operation "dry-run" "$package" "simulated"
        log_function_end "install_package" 0
        return 0
    fi
    
    if dpkg -l | grep -q "^ii  $package "; then
        print_warning "$(get_message 'already_installed' "$package_name")"
        log_package_operation "check" "$package" "already installed"
    else
        print_status "$(get_message 'installing' "$package_name")"
        if sudo $package_manager install -y "$package"; then
            print_success "$(get_message 'installed_successfully' "$package_name")"
            local version=$(dpkg -l | grep "^ii  $package " | awk '{print $3}')
            log_package_operation "install" "$package" "$version"
        else
            print_error "Failed to install $package_name"
            log_package_operation "install" "$package" "failed"
            log_function_end "install_package" 1
            return 1
        fi
    fi
    
    log_function_end "install_package" 0
}

# Get package info from settings
get_package_info() {
    local package_key=$1
    local info_type=$2
    get_setting ".packages.$package_key.$info_type"
}

# Get the directory where the script is located
get_script_dir() {
    echo "$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
}

# Dry-run functionality
is_dry_run() {
    [[ "${DRY_RUN:-false}" == "true" ]]
}

# Print dry-run status messages
print_dry_run_header() {
    if is_dry_run; then
        echo -e "${YELLOW}=== DRY RUN MODE - No changes will be made ===${NC}"
        echo ""
    fi
}

print_would_execute() {
    local message="$1"
    if is_dry_run; then
        echo -e "${BLUE}[DRY RUN]${NC} Would execute: $message"
        log_info "[DRY RUN] Would execute: $message"
    fi
}

print_would_install() {
    local package="$1"
    local description="${2:-$package}"
    if is_dry_run; then
        echo -e "${BLUE}[DRY RUN]${NC} Would install: $description"
        log_info "[DRY RUN] Would install: $description"
    fi
}

print_would_configure() {
    local component="$1"
    local details="$2"
    if is_dry_run; then
        echo -e "${BLUE}[DRY RUN]${NC} Would configure: $component${details:+ - $details}"
        log_info "[DRY RUN] Would configure: $component${details:+ - $details}"
    fi
}