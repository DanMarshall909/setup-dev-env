#!/bin/bash

# Linux Development Environment Setup Script
# Module-based setup with dependency management

set -e  # Exit on error

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Source common functions and module manager
source "$SCRIPT_DIR/scripts/common.sh"
source "$SCRIPT_DIR/scripts/module-manager.sh"

# Initialize logging
init_logging

# Main interactive setup
interactive_setup() {
    log_script_start "setup.sh (interactive)"
    print_status "Linux Development Environment Setup"
    print_status "Module-based installation with dependency management"
    
    # Check if running on supported OS
    check_supported_os
    
    # Update repositories once at the start
    update_repositories
    
    while true; do
        show_interactive_menu
        read -p "$(get_prompt 'select_option')" choice
        
        case $choice in
            "list"|"l")
                echo ""
                list_modules_with_status
                ;;
            "install"|"i")
                echo ""
                read -p "Enter module name to install: " module_name
                if [ -n "$module_name" ]; then
                    install_module "$module_name"
                fi
                ;;
            "info"|"?")
                echo ""
                read -p "Enter module name for info: " module_name
                if [ -n "$module_name" ]; then
                    show_module_info "$module_name"
                fi
                ;;
            "tree"|"t")
                echo ""
                read -p "Enter module name for dependency tree: " module_name
                if [ -n "$module_name" ]; then
                    show_dependency_tree "$module_name"
                fi
                ;;
            "all"|"a")
                install_all_modules
                ;;
            "quit"|"q"|"exit")
                print_status "Exiting setup..."
                log_script_end "setup.sh" 0
                exit 0
                ;;
            *)
                # Try to install as module name directly
                if module_exists "$choice"; then
                    install_module "$choice"
                else
                    print_error "Unknown option or module: $choice"
                fi
                ;;
        esac
        
        echo ""
        read -p "$(get_prompt 'press_enter')"
    done
}

# Show interactive menu
show_interactive_menu() {
    echo ""
    echo "Linux Development Environment Setup"
    echo "=================================="
    echo ""
    echo "Commands:"
    echo "  list   (l)  - List all available modules with status"
    echo "  install (i) - Install a specific module"
    echo "  info   (?)  - Show module information"
    echo "  tree   (t)  - Show dependency tree"
    echo "  all    (a)  - Install all modules"
    echo "  quit   (q)  - Exit setup"
    echo ""
    echo "Or type a module name directly to install it:"
    
    # Show available modules in columns
    local modules=$(list_modules)
    if [ -n "$modules" ]; then
        echo ""
        echo "Available modules:"
        printf "  %-12s %-12s %-12s %-12s\n" $(echo $modules | head -n 20)
    fi
    echo ""
}

# Install all available modules
install_all_modules() {
    print_status "Installing all modules..."
    
    local modules=$(list_modules)
    local failed_modules=()
    
    for module in $modules; do
        print_status "Installing module: $module"
        if install_module "$module"; then
            print_success "Module '$module' installed successfully"
        else
            print_error "Failed to install module: $module"
            failed_modules+=("$module")
        fi
        echo ""
    done
    
    if [ ${#failed_modules[@]} -eq 0 ]; then
        print_success "All modules installed successfully!"
    else
        print_warning "Some modules failed to install: ${failed_modules[*]}"
    fi
}

# Main function
main() {
    # Parse command line arguments
    case "${1:-}" in
        # Module management commands
        "list")
            list_modules_with_status
            ;;
        "available")
            list_modules
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
        "all")
            install_all_modules
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        "")
            # No arguments - run interactive mode
            interactive_setup
            ;;
        *)
            # Try to install as module name
            local module_name="$1"
            local force=false
            
            if [ "$2" = "--force" ] || [ "$2" = "-f" ]; then
                force=true
            fi
            
            if module_exists "$module_name"; then
                print_status "Installing module: $module_name"
                install_module "$module_name" "$force"
            else
                print_error "Unknown module: $module_name"
                echo ""
                echo "Available modules:"
                list_modules | sed 's/^/  /'
                exit 1
            fi
            ;;
    esac
}

# Show help
show_help() {
    cat << EOF
Linux Development Environment Setup

Usage: $0 [COMMAND|MODULE] [OPTIONS]

Commands:
    list                    List all modules with installation status
    available               List available module names only
    info <module>           Show detailed information about a module
    tree <module>           Show dependency tree for a module
    all                     Install all available modules
    help                    Show this help message

Module Installation:
    $0 <module_name>        Install a specific module and its dependencies
    $0 <module_name> --force Force reinstall even if already installed

Interactive Mode:
    $0                      Run interactive setup (no arguments)

Examples:
    $0                      # Interactive mode
    $0 list                 # Show all modules
    $0 git                  # Install git module
    $0 claude               # Install claude module (will install node dependency)
    $0 rider --force        # Force reinstall rider module
    $0 tree claude          # Show claude module dependencies

Available Modules:
$(list_modules | sed 's/^/    /')
EOF
}

# Run main function
main "$@"