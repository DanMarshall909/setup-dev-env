#!/bin/bash

# Test script for problematic modules only
# This script tests only the modules that are having issues

set -e

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Source common functions and module manager
source "$SCRIPT_DIR/scripts/common.sh"
source "$SCRIPT_DIR/scripts/setup-logger.sh"
source "$SCRIPT_DIR/scripts/module-manager.sh"

# Initialize comprehensive logging
init_setup_logging

# Parse dry-run flag
export DRY_RUN=false
for arg in "$@"; do
    case "$arg" in
        "--dry-run"|"-d") export DRY_RUN=true ;;
    esac
done

print_status "Testing problematic modules only"
print_status "Modules: node (npm globals), claude (CLI installation)"

# Show dry-run header if in dry-run mode
print_dry_run_header

# Check if running on supported OS
check_supported_os

# Test problematic modules only
problematic_modules=("node" "claude")
failed_modules=()
success_count=0

for module in "${problematic_modules[@]}"; do
    log_module_start "$module"
    
    if is_dry_run; then
        print_status "Would test module: $module"
    else
        print_status "Testing module: $module"
    fi
    
    if install_module "$module" false "$DRY_RUN"; then
        success_count=$((success_count + 1))
        log_module_success "$module"
        if is_dry_run; then
            print_success "Module '$module' would be installed successfully"
        else
            print_success "Module '$module' installed successfully"
        fi
    else
        log_module_failure "$module" "Installation failed"
        if is_dry_run; then
            print_error "Would fail to install module: $module"
        else
            print_error "Failed to install module: $module"
        fi
        failed_modules+=("$module")
    fi
    echo ""
done

if [ ${#failed_modules[@]} -eq 0 ]; then
    print_success "All problematic modules now working!"
else
    print_warning "Still failing modules: ${failed_modules[*]}"
fi

log_script_end "test-problematic-modules.sh" $?