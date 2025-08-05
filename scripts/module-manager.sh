#!/bin/bash

# Module management system with dependency resolution

# Source common functions
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/common.sh"

# Track installed modules to avoid circular dependencies
declare -A INSTALLED_MODULES
declare -A INSTALLING_MODULES

# Get modules directory
get_modules_dir() {
    echo "$(get_root_dir)/modules"
}

# List all available modules
list_modules() {
    local modules_dir=$(get_modules_dir)
    if [ -d "$modules_dir" ]; then
        find "$modules_dir" -maxdepth 1 -type d -not -path "$modules_dir" -printf '%f\n' | sort
    fi
}

# Check if module exists
module_exists() {
    local module_name=$1
    local modules_dir=$(get_modules_dir)
    [ -d "$modules_dir/$module_name" ]
}

# Get module config file path
get_module_config() {
    local module_name=$1
    local modules_dir=$(get_modules_dir)
    echo "$modules_dir/$module_name/module.json"
}

# Get module script path
get_module_script() {
    local module_name=$1
    local modules_dir=$(get_modules_dir)
    echo "$modules_dir/$module_name/install.sh"
}

# Read module configuration
read_module_config() {
    local module_name=$1
    local config_file=$(get_module_config "$module_name")
    
    if [ ! -f "$config_file" ]; then
        log_error "Module config not found: $config_file"
        return 1
    fi
    
    cat "$config_file"
}

# Get module dependencies
get_module_dependencies() {
    local module_name=$1
    local config=$(read_module_config "$module_name")
    
    if [ $? -eq 0 ]; then
        echo "$config" | jq -r '.dependencies[]? // empty' 2>/dev/null
    fi
}

# Get module description
get_module_description() {
    local module_name=$1
    local config=$(read_module_config "$module_name")
    
    if [ $? -eq 0 ]; then
        echo "$config" | jq -r '.description // "No description available"' 2>/dev/null
    else
        echo "No description available"
    fi
}

# Check if module is already installed
is_module_installed() {
    local module_name=$1
    local modules_dir=$(get_modules_dir)
    local status_script="$modules_dir/$module_name/status.sh"
    
    # Try using status script first
    if [ -f "$status_script" ]; then
        chmod +x "$status_script"
        if "$status_script" installed &>/dev/null; then
            return 0
        fi
    fi
    
    # Fallback to config check_installed command
    local config=$(read_module_config "$module_name")
    if [ $? -eq 0 ]; then
        local check_command=$(echo "$config" | jq -r '.check_installed // empty' 2>/dev/null)
        if [ -n "$check_command" ]; then
            eval "$check_command" &>/dev/null
            return $?
        fi
    fi
    
    # Fallback: check if we've recorded it as installed
    [ "${INSTALLED_MODULES[$module_name]}" = "true" ]
}

# Resolve dependencies recursively
resolve_dependencies() {
    local module_name=$1
    local -a dep_order=()
    
    _resolve_deps_recursive "$module_name" "dep_order"
    printf '%s\n' "${dep_order[@]}"
}

# Recursive dependency resolution with cycle detection
_resolve_deps_recursive() {
    local module_name=$1
    local order_array_name=$2
    
    # Check for circular dependency
    if [ "${INSTALLING_MODULES[$module_name]}" = "true" ]; then
        log_error "Circular dependency detected: $module_name"
        return 1
    fi
    
    # Mark as being processed
    INSTALLING_MODULES[$module_name]="true"
    
    # Use eval to work with the array name
    local current_array
    eval "current_array=(\"\${${order_array_name}[@]}\")"
    
    # Skip if already processed
    for installed in "${current_array[@]}"; do
        if [ "$installed" = "$module_name" ]; then
            INSTALLING_MODULES[$module_name]=""
            return 0
        fi
    done
    
    # Process dependencies first
    local dependencies=$(get_module_dependencies "$module_name")
    for dep in $dependencies; do
        if ! module_exists "$dep"; then
            log_error "Dependency not found: $dep (required by $module_name)"
            INSTALLING_MODULES[$module_name]=""
            return 1
        fi
        
        _resolve_deps_recursive "$dep" "$order_array_name"
    done
    
    # Add this module to the order using eval
    eval "${order_array_name}+=('$module_name')"
    INSTALLING_MODULES[$module_name]=""
    
    return 0
}

# Install a module and its dependencies
install_module() {
    local module_name=$1
    local force=${2:-false}
    local dry_run=${3:-false}
    
    # Set global DRY_RUN if requested
    if [[ "$dry_run" == "true" ]]; then
        export DRY_RUN=true
    fi
    
    log_function_start "install_module" "$module_name" "$force" "$dry_run"
    
    if ! module_exists "$module_name"; then
        print_error "Module not found: $module_name"
        log_error "Module not found: $module_name"
        return 1
    fi
    
    # Check if already installed (unless forced)
    if [ "$force" != "true" ] && is_module_installed "$module_name"; then
        print_success "Module '$module_name' is already installed"
        log_info "Module already installed: $module_name"
        INSTALLED_MODULES[$module_name]="true"
        return 0
    fi
    
    # Show dry-run header if in dry-run mode
    print_dry_run_header
    
    if is_dry_run; then
        print_status "DRY RUN: Planning installation of module: $module_name"
        log_system_info "Module Installation" "Dry-run planning for $module_name"
    else
        print_status "Installing module: $module_name"
        log_system_info "Module Installation" "Starting installation of $module_name"
    fi
    log_info "Starting installation of module: $module_name"
    
    # Resolve dependencies
    local install_order
    if ! install_order=$(resolve_dependencies "$module_name"); then
        print_error "Failed to resolve dependencies for module: $module_name"
        log_error "Failed to resolve dependencies for module: $module_name"
        return 1
    fi
    
    # Install in dependency order
    local total_modules=$(echo "$install_order" | wc -l)
    local current=0
    
    if is_dry_run; then
        echo -e "${BLUE}Installation order (dry-run):${NC}"
        echo "$install_order" | sed 's/^/  /'
        echo ""
    fi
    
    while IFS= read -r module; do
        current=$((current + 1))
        
        if [ "${INSTALLED_MODULES[$module]}" = "true" ]; then
            if is_dry_run; then
                print_status "[$current/$total_modules] Would skip $module (already installed)"
            else
                print_status "[$current/$total_modules] Skipping $module (already installed)"
            fi
            continue
        fi
        
        if is_dry_run; then
            print_status "[$current/$total_modules] Would install $module..."
            print_would_execute "install_single_module $module"
            INSTALLED_MODULES[$module]="true"
            print_success "[$current/$total_modules] Module '$module' would be installed successfully"
        else
            print_status "[$current/$total_modules] Installing $module..."
            
            if install_single_module "$module"; then
                INSTALLED_MODULES[$module]="true"
                print_success "[$current/$total_modules] Module '$module' installed successfully"
                log_info "Module installed successfully: $module"
            else
                print_error "[$current/$total_modules] Failed to install module: $module"
                log_error "Failed to install module: $module"
                return 1
            fi
        fi
    done <<< "$install_order"
    
    log_function_end "install_module" 0
    return 0
}

# Install a single module (no dependency resolution)
install_single_module() {
    local module_name=$1
    local module_script=$(get_module_script "$module_name")
    
    if [ ! -f "$module_script" ]; then
        log_error "Module script not found: $module_script"
        return 1
    fi
    
    # Make script executable
    chmod +x "$module_script"
    
    # Execute the module installation script
    if "$module_script"; then
        log_info "Module script executed successfully: $module_name"
        return 0
    else
        log_error "Module script failed: $module_name"
        return 1
    fi
}

# Get detailed module status
get_module_status() {
    local module_name=$1
    local modules_dir=$(get_modules_dir)
    local status_script="$modules_dir/$module_name/status.sh"
    
    if [ -f "$status_script" ]; then
        chmod +x "$status_script"
        "$status_script" summary 2>/dev/null || echo "Status check failed"
    else
        if is_module_installed "$module_name"; then
            echo "✅ $module_name (basic check)"
        else
            echo "❌ $module_name not installed"
        fi
    fi
}

# Show module information
show_module_info() {
    local module_name=$1
    
    if ! module_exists "$module_name"; then
        print_error "Module not found: $module_name"
        return 1
    fi
    
    local config=$(read_module_config "$module_name")
    local description=$(echo "$config" | jq -r '.description // "No description"')
    local version=$(echo "$config" | jq -r '.version // "unknown"')
    local category=$(echo "$config" | jq -r '.category // "uncategorized"')
    local tags=$(echo "$config" | jq -r '.tags[]?' | tr '\n' ', ' | sed 's/,$//')
    local dependencies=$(get_module_dependencies "$module_name")
    local provides=$(echo "$config" | jq -r '.provides[]?' | tr '\n' ', ' | sed 's/,$//')
    local size=$(echo "$config" | jq -r '.size_estimate // "unknown"')
    local time=$(echo "$config" | jq -r '.install_time_estimate // "unknown"')
    
    echo "Module Information: $module_name"
    echo "================================"
    echo "Description: $description"
    echo "Version: $version"
    echo "Category: $category"
    if [ -n "$tags" ]; then
        echo "Tags: $tags"
    fi
    if [ -n "$provides" ]; then
        echo "Provides: $provides"
    fi
    echo "Size estimate: $size"
    echo "Install time: $time"
    
    if [ -n "$dependencies" ]; then
        echo "Dependencies: $dependencies"
    else
        echo "Dependencies: none"
    fi
    
    echo ""
    echo "Status: $(get_module_status "$module_name")"
    
    # Show detailed status if available
    local modules_dir=$(get_modules_dir)
    local status_script="$modules_dir/$module_name/status.sh"
    if [ -f "$status_script" ]; then
        echo ""
        echo "Detailed Status:"
        echo "==============="
        chmod +x "$status_script"
        "$status_script" status 2>/dev/null | jq . 2>/dev/null || echo "Detailed status unavailable"
    fi
}

# List all modules with status
list_modules_with_status() {
    echo "Available modules:"
    echo "=================="
    
    local modules=$(list_modules)
    for module in $modules; do
        local description=$(get_module_description "$module")
        local status=$(get_module_status "$module")
        
        printf "%-15s %s\n" "$module" "$status"
        printf "%-15s %s\n" "" "$description"
        echo ""
    done
}

# Show dependency tree
show_dependency_tree() {
    local module_name=$1
    local indent=${2:-""}
    
    if ! module_exists "$module_name"; then
        print_error "Module not found: $module_name"
        return 1
    fi
    
    echo "${indent}$module_name"
    
    local dependencies=$(get_module_dependencies "$module_name")
    for dep in $dependencies; do
        show_dependency_tree "$dep" "${indent}  ├── "
    done
}

# Main function for CLI usage
main() {
    case "${1:-}" in
        "list")
            list_modules_with_status
            ;;
        "info")
            if [ -z "$2" ]; then
                print_error "Usage: $0 info <module_name>"
                exit 1
            fi
            show_module_info "$2"
            ;;
        "tree")
            if [ -z "$2" ]; then
                print_error "Usage: $0 tree <module_name>"
                exit 1
            fi
            show_dependency_tree "$2"
            ;;
        "install")
            if [ -z "$2" ]; then
                print_error "Usage: $0 install <module_name> [--force] [--dry-run]"
                exit 1
            fi
            local force=false
            local dry_run=false
            
            # Parse flags
            for arg in "$@"; do
                case "$arg" in
                    "--force"|"-f") force=true ;;
                    "--dry-run"|"-d") dry_run=true ;;
                esac
            done
            
            install_module "$2" "$force" "$dry_run"
            ;;
        "available")
            list_modules
            ;;
        *)
            echo "Module Manager"
            echo "============="
            echo "Usage: $0 <command> [arguments]"
            echo ""
            echo "Commands:"
            echo "  list                         List all modules with installation status"
            echo "  available                    List available module names only"
            echo "  info <module>                Show detailed information about a module"
            echo "  tree <module>                Show dependency tree for a module"
            echo "  install <module>             Install a module and its dependencies"
            echo "  install <module> --force     Force reinstall even if already installed"
            echo "  install <module> --dry-run   Show what would be installed without changes"
            echo "  install <module> --force --dry-run  Combine force and dry-run modes"
            ;;
    esac
}

# Run main function if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi