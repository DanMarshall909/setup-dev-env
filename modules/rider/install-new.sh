#!/bin/bash

# JetBrains Rider module installation script (refactored with framework)

# Source module framework
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/../../scripts/module-framework.sh"

# Module-specific functions
check_rider_installed() {
    snap list rider 2>/dev/null | grep -q rider || command -v rider &>/dev/null
}

install_rider_ide() {
    # Try snap installation first
    if install_snap_package "rider" "--classic" "JetBrains Rider"; then
        return 0
    fi
    
    # Fallback to Toolbox method
    print_status "Attempting JetBrains Toolbox installation..."
    local toolbox_url="https://download.jetbrains.com/toolbox/jetbrains-toolbox-1.28.1.15219.tar.gz"
    
    download_and_install "$toolbox_url" "toolbox.tar.gz" \
        "tar -xzf %s && sudo mv jetbrains-toolbox-*/jetbrains-toolbox /usr/local/bin/" \
        "JetBrains Toolbox"
}

verify_rider_installation() {
    if is_dry_run; then
        print_would_execute "snap list rider"
        print_success "DRY RUN: Rider installation would be verified"
        return 0
    fi
    
    if check_rider_installed; then
        if snap list rider 2>/dev/null | grep -q rider; then
            local version=$(snap list rider | grep rider | awk '{print $2}')
            print_success "JetBrains Rider installed via snap: $version"
        else
            print_success "JetBrains Rider installed"
        fi
        
        verify_command_available "rider" "Rider command"
        return 0
    else
        print_error "JetBrains Rider verification failed"
        return 1
    fi
}

show_rider_info() {
    local next_steps="1. Launch Rider from applications menu or run: rider
2. Sign in with your JetBrains account
3. Activate your license (30-day trial available)
4. Configure plugins and settings"
    
    local docs_url="https://www.jetbrains.com/help/rider/"
    
    local config_notes="Consider installing .NET SDK for full functionality:
Run: ./setup.sh dotnet"
    
    show_post_install_info "JetBrains Rider" "$next_steps" "$docs_url" "$config_notes"
}

# Main module execution using framework
install_rider_module() {
    init_module "rider" "JetBrains Rider"
    
    run_standard_install_flow \
        "check_rider_installed" \
        "install_rider_ide" \
        "verify_rider_installation" \
        "show_rider_info"
}

# Execute if run directly
install_rider_module