#!/bin/bash

# Automated end-to-end setup script
# Prerequisites:
# 1. 1Password CLI (or configured password manager) is installed and authenticated
# 2. All JSON configuration files are properly set up

set -e  # Exit on error

# Source common functions
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/common.sh"

# Track start time
START_TIME=$(date +%s)

# Run all setup scripts in order
run_automated_setup() {
    log_script_start "run-all.sh (automated)"
    
    print_status "Starting automated Linux development environment setup..."
    print_status "This will install and configure all development tools automatically."
    echo ""
    
    # Verify prerequisites
    if ! verify_prerequisites; then
        print_error "Prerequisites not met. Exiting."
        log_script_end "run-all.sh" 1
        exit 1
    fi
    
    # Get confirmation if interactive
    if [ -t 0 ] && [ -z "$SETUP_FORCE_YES" ]; then
        read -p "Do you want to proceed with automated setup? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Setup cancelled by user"
            log_script_end "run-all.sh" 0
            exit 0
        fi
    fi
    
    # Run all installations
    local scripts=(
        "install-git.sh"
        "install-node.sh"
        "install-dotnet.sh"
        "install-rider.sh"
        "install-docker.sh"
        "configure-shell.sh"
        "install-dev-tools.sh"
        "configure-git-advanced.sh"
    )
    
    local total=${#scripts[@]}
    local current=0
    
    for script in "${scripts[@]}"; do
        current=$((current + 1))
        echo ""
        print_status "[$current/$total] Running $script..."
        
        if [ -f "$SCRIPT_DIR/$script" ]; then
            if "$SCRIPT_DIR/$script"; then
                print_success "[$current/$total] $script completed successfully"
                log_info "Completed: $script"
            else
                print_error "[$current/$total] $script failed"
                log_error "Failed: $script"
                
                # Check if we should continue on error
                if [ -z "$SETUP_CONTINUE_ON_ERROR" ]; then
                    print_error "Stopping due to error. Set SETUP_CONTINUE_ON_ERROR=1 to continue."
                    log_script_end "run-all.sh" 1
                    exit 1
                fi
            fi
        else
            print_warning "[$current/$total] $script not found, skipping"
            log_warning "Script not found: $script"
        fi
    done
    
    # Run post-setup tasks
    post_setup_tasks
    
    # Calculate duration
    local END_TIME=$(date +%s)
    local DURATION=$((END_TIME - START_TIME))
    
    # Generate summary
    generate_setup_summary "$DURATION"
    
    log_script_end "run-all.sh" 0 "$DURATION"
}

# Verify prerequisites
verify_prerequisites() {
    print_status "Verifying prerequisites..."
    local prereqs_met=true
    
    # Check if running on supported OS
    if ! grep -q "$(get_setting '.system.supported_os')" /etc/os-release; then
        print_error "Unsupported OS detected"
        prereqs_met=false
    fi
    
    # Check if password manager is configured and available
    if ! is_password_manager_available; then
        local pm=$(get_password_manager)
        if [ "$pm" != "none" ]; then
            print_warning "Password manager '$pm' is not available"
            print_status "Attempting to install $pm CLI..."
            
            if install_password_manager "$pm"; then
                print_success "$pm CLI installed successfully"
            else
                print_error "Failed to install $pm CLI"
                print_status "You can continue without password manager (will use prompts/env vars)"
            fi
        fi
    fi
    
    # Check if configuration files exist
    local config_files=(
        "configs/settings.json"
        "configs/git-config.json"
    )
    
    for config in "${config_files[@]}"; do
        local config_path="$(get_root_dir)/$config"
        if [ ! -f "$config_path" ]; then
            print_error "Required configuration file not found: $config"
            prereqs_met=false
        else
            print_success "Found configuration: $config"
        fi
    done
    
    # Test password manager access (if configured)
    if is_password_manager_available; then
        print_status "Testing password manager access..."
        
        # Try to get a test secret
        local test_secret=$(get_setting '.security.secrets.github_token.path')
        if [ -n "$test_secret" ]; then
            if get_secret "$test_secret" &>/dev/null; then
                print_success "Password manager access verified"
            else
                print_warning "Could not access password manager secrets"
                print_status "You may be prompted for credentials during setup"
            fi
        fi
    fi
    
    # Check for required commands
    local required_commands=("curl" "wget" "tar" "unzip")
    for cmd in "${required_commands[@]}"; do
        if ! command_exists "$cmd"; then
            print_warning "Required command not found: $cmd"
            print_status "Installing $cmd..."
            install_package "$cmd" "$cmd"
        fi
    done
    
    $prereqs_met
}

# Post-setup tasks
post_setup_tasks() {
    print_status "Running post-setup tasks..."
    
    # Source shell configuration
    if [ -f "$HOME/.zshrc" ]; then
        print_status "Sourcing Zsh configuration..."
        export SHELL_RELOADED=1
    elif [ -f "$HOME/.bashrc" ]; then
        print_status "Sourcing Bash configuration..."
        export SHELL_RELOADED=1
    fi
    
    # Verify installations
    verify_installations
    
    # Clean up
    cleanup_temp_files
}

# Verify all installations
verify_installations() {
    print_status "Verifying installations..."
    
    local tools=(
        "git:Git"
        "gh:GitHub CLI"
        "node:Node.js"
        "npm:npm"
        "dotnet:.NET SDK"
        "docker:Docker"
        "code:VS Code"
    )
    
    for tool_info in "${tools[@]}"; do
        local cmd="${tool_info%%:*}"
        local name="${tool_info#*:}"
        
        if command_exists "$cmd"; then
            local version=$($cmd --version 2>&1 | head -n1)
            print_success "$name installed: $version"
        else
            print_warning "$name not found"
        fi
    done
}

# Clean up temporary files
cleanup_temp_files() {
    print_status "Cleaning up temporary files..."
    
    # Clean apt cache
    run_sudo apt-get clean
    
    # Remove old log files (keep last 10)
    rotate_logs
}

# Generate setup summary
generate_setup_summary() {
    local duration=$1
    local summary_file="$SETUP_LOG_DIR/setup_summary_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "Linux Development Environment Setup Summary"
        echo "=========================================="
        echo "Date: $(date)"
        echo "Duration: $((duration / 60)) minutes $((duration % 60)) seconds"
        echo ""
        
        echo "System Information:"
        echo "------------------"
        echo "OS: $(lsb_release -d | cut -f2-)"
        echo "Kernel: $(uname -r)"
        echo "User: $(whoami)"
        echo ""
        
        echo "Installed Tools:"
        echo "---------------"
        verify_installations 2>&1 | grep "installed:" | sed 's/^/  /'
        echo ""
        
        echo "Configuration:"
        echo "-------------"
        echo "  Git user: $(git config --global user.name)"
        echo "  Git email: $(git config --global user.email)"
        echo "  Default shell: $SHELL"
        echo "  Password manager: $(get_password_manager)"
        echo ""
        
        echo "Log Files:"
        echo "----------"
        echo "  Setup log: $SETUP_LOG_FILE"
        echo "  Summary: $summary_file"
        echo ""
        
        echo "Next Steps:"
        echo "-----------"
        echo "1. Restart your terminal or run: source ~/.$(basename $SHELL)rc"
        echo "2. Authenticate with GitHub: gh auth login"
        echo "3. Configure your IDE (Rider)"
        echo "4. Clone your projects and start coding!"
    } | tee "$summary_file"
    
    print_success "Setup summary saved to: $summary_file"
    
    # Also create the log summary
    create_log_summary
}

# Main execution
main() {
    # Check for command line options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force|-f)
                export SETUP_FORCE_YES=1
                shift
                ;;
            --continue-on-error|-c)
                export SETUP_CONTINUE_ON_ERROR=1
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    run_automated_setup
}

# Show help
show_help() {
    cat << EOF
Automated Linux Development Environment Setup

Usage: $0 [OPTIONS]

Options:
    --force, -f              Skip confirmation prompt
    --continue-on-error, -c  Continue setup even if a script fails
    --help, -h               Show this help message

Prerequisites:
    1. Password manager CLI installed and authenticated (optional)
    2. Configuration files in configs/ directory
    3. Internet connection

Environment Variables:
    SETUP_FORCE_YES=1          Skip confirmation prompt
    SETUP_CONTINUE_ON_ERROR=1  Continue on script failures
    GITHUB_TOKEN              GitHub personal access token (if not using password manager)

Examples:
    # Run with confirmation
    ./scripts/run-all.sh
    
    # Run without confirmation
    ./scripts/run-all.sh --force
    
    # Continue even if something fails
    ./scripts/run-all.sh --continue-on-error
    
    # Non-interactive with environment variables
    SETUP_FORCE_YES=1 GITHUB_TOKEN=ghp_xxx ./scripts/run-all.sh
EOF
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi