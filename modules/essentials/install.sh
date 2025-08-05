#!/bin/bash

# Essential Tools module - reusing code from linux-migration-tool/migrate-to-linux.sh

# Source module framework
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/../../scripts/module-framework.sh"

# Essential packages list from migration script
ESSENTIAL_PACKAGES=(
    build-essential
    curl
    wget
    software-properties-common
    apt-transport-https
    ca-certificates
    gnupg
    lsb-release
    git
    vim
    nano
    htop
    jq
    tree
    unzip
    zip
    p7zip-full
    p7zip-rar
)

# Check if essential tools are installed
check_essentials_installed() {
    # Check if most essential packages are installed
    local missing=0
    for package in "${ESSENTIAL_PACKAGES[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package "; then
            missing=$((missing + 1))
        fi
    done
    
    # Consider installed if less than 3 packages are missing
    [ $missing -lt 3 ]
}

# Install essential tools - reusing logic from migration script
install_essentials() {
    if is_dry_run; then
        print_would_execute "apt update"
        for package in "${ESSENTIAL_PACKAGES[@]}"; do
            print_would_install "$package"
        done
        return 0
    fi
    
    # Update package lists first
    print_status "Updating package lists..."
    sudo apt update
    
    # Install all essential packages
    print_status "Installing essential build tools and utilities..."
    
    # Install packages individually for better error handling
    local failed_packages=()
    for package in "${ESSENTIAL_PACKAGES[@]}"; do
        if install_package_with_dry_run "$package" "$package"; then
            print_success "✓ $package"
        else
            print_warning "✗ $package (failed)"
            failed_packages+=("$package")
        fi
    done
    
    if [ ${#failed_packages[@]} -gt 0 ]; then
        print_warning "Some packages failed to install: ${failed_packages[*]}"
        print_status "Attempting bulk install for failed packages..."
        sudo apt install -y "${failed_packages[@]}" || print_warning "Some packages may still be missing"
    fi
    
    return 0
}

# Verify essential tools installation
verify_essentials_installation() {
    if is_dry_run; then
        for package in "${ESSENTIAL_PACKAGES[@]}"; do
            print_would_execute "$package --version || which $package"
        done
        print_success "DRY RUN: Essential tools verification would complete"
        return 0
    fi
    
    print_status "Verifying essential tools installation..."
    
    local verified=0
    local total=${#ESSENTIAL_PACKAGES[@]}
    
    for package in "${ESSENTIAL_PACKAGES[@]}"; do
        if command -v "$package" &>/dev/null || dpkg -l | grep -q "^ii  $package "; then
            verified=$((verified + 1))
        fi
    done
    
    print_success "Essential tools: $verified/$total packages available"
    
    # Test some key tools
    verify_command_available "git" "Git"
    verify_command_available "curl" "curl"
    verify_command_available "wget" "wget"
    verify_command_available "jq" "jq"
    
    return 0
}

# Show essential tools post-installation info
show_essentials_info() {
    local next_steps="1. Essential build tools are now available
2. You can now compile software from source
3. Git is ready for version control
4. Package management tools are installed
5. Archive and compression tools are available"
    
    local docs_url="https://ubuntu.com/server/docs/package-management"
    
    local config_notes="Installed packages include:
- Build tools: build-essential, git
- Network tools: curl, wget  
- Archive tools: unzip, zip, p7zip-full, p7zip-rar
- System utilities: htop, tree, jq, vim, nano
- Package management: software-properties-common, apt-transport-https"
    
    show_post_install_info "Essential Tools" "$next_steps" "$docs_url" "$config_notes"
}

# Main module execution using framework
install_essentials_module() {
    init_module "essentials" "Essential Tools"
    
    run_standard_install_flow \
        "check_essentials_installed" \
        "install_essentials" \
        "verify_essentials_installation" \
        "show_essentials_info"
}

# Execute if run directly
install_essentials_module