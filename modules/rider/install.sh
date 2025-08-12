#!/bin/bash

# JetBrains Rider module installation script

# Source common functions
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/../../scripts/common.sh"

install_rider_module() {
    print_status "Installing JetBrains Rider module..."
    log_script_start "rider/install.sh"
    
    # Check if already installed
    if check_rider_installed; then
        print_warning "JetBrains Rider is already installed"
        verify_rider_installation
        log_script_end "rider/install.sh" 0
        return 0
    fi
    
    # Install Rider
    install_rider_ide
    
    # Verify installation
    verify_rider_installation
    
    # Show post-installation info
    show_rider_info
    
    log_script_end "rider/install.sh" 0
}

check_rider_installed() {
    # Check via snap first
    if snap list rider 2>/dev/null | grep -q rider; then
        return 0
    fi
    
    # Check if rider command exists
    if command -v rider &>/dev/null; then
        return 0
    fi
    
    return 1
}

install_rider_ide() {
    print_status "Installing JetBrains Rider..."
    
    if is_dry_run; then
        print_would_execute "Download and install JetBrains Toolbox"
        print_would_execute "sudo snap install rider --classic (fallback)"
        return 0
    fi
    
    # Try Toolbox first (more reliable)
    print_status "Attempting JetBrains Toolbox installation (primary method)..."
    if install_rider_toolbox_method; then
        return 0
    fi
    
    # Fallback to snap if Toolbox fails
    print_warning "Toolbox installation failed, trying snap as fallback..."
    install_rider_snap_method
}

install_rider_snap_method() {
    print_status "Installing JetBrains Rider via snap..."
    
    if is_dry_run; then
        print_would_execute "sudo snap install rider --classic"
        return 0
    fi
    
    # Ensure snap is available
    if ! command_exists snap; then
        print_status "Installing snap package manager..."
        install_package "snapd" "Snap"
        
        # Snap requires a restart of systemd services
        print_status "Enabling snap services..."
        sudo systemctl enable snapd
        sudo systemctl start snapd
        
        # Create snap symlink if needed
        if [ ! -L /snap ]; then
            sudo ln -s /var/lib/snapd/snap /snap
        fi
    fi
    
    # Install Rider via snap with timeout
    if timeout 300 sudo snap install rider --classic; then
        print_success "JetBrains Rider installed successfully via snap"
        return 0
    else
        print_error "Failed to install JetBrains Rider via snap (timeout or error)"
        return 1
    fi
}

install_rider_toolbox_method() {
    print_status "Installing JetBrains Toolbox..."
    
    if is_dry_run; then
        print_would_execute "Download JetBrains Toolbox from official website"
        print_would_execute "Install Toolbox and use it to install Rider"
        return 0
    fi
    
    # Download and install Toolbox - updated URL to latest stable version
    local toolbox_url="https://download.jetbrains.com/toolbox/jetbrains-toolbox-2.5.1.34629.tar.gz"
    local temp_dir=$(mktemp -d)
    
    print_status "Downloading JetBrains Toolbox..."
    # Try curl first, then wget
    if curl -fsSL "$toolbox_url" -o "$temp_dir/toolbox.tar.gz" || wget -q "$toolbox_url" -O "$temp_dir/toolbox.tar.gz"; then
        cd "$temp_dir"
        tar -xzf toolbox.tar.gz
        
        # Find the extracted directory
        local toolbox_dir=$(find . -maxdepth 1 -type d -name "jetbrains-toolbox-*" | head -n1)
        
        if [ -n "$toolbox_dir" ]; then
            # Move to opt and create symlink
            if [ -w /opt ]; then
                mv "$toolbox_dir" /opt/jetbrains-toolbox
            else
                sudo mv "$toolbox_dir" /opt/jetbrains-toolbox
            fi
            
            if [ -w /usr/local/bin ]; then
                ln -sf /opt/jetbrains-toolbox/jetbrains-toolbox /usr/local/bin/jetbrains-toolbox
            else
                sudo ln -sf /opt/jetbrains-toolbox/jetbrains-toolbox /usr/local/bin/jetbrains-toolbox
            fi
            
            print_success "JetBrains Toolbox installed"
            print_status "Launch Toolbox to install Rider: jetbrains-toolbox"
        else
            print_error "Failed to extract JetBrains Toolbox"
            return 1
        fi
    else
        print_error "Failed to download JetBrains Toolbox"
        return 1
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
}

verify_rider_installation() {
    print_status "Verifying JetBrains Rider installation..."
    
    if is_dry_run; then
        print_would_execute "snap list rider"
        print_would_execute "rider --version (if available)"
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
        
        # Check if rider command is available
        if command -v rider &>/dev/null; then
            print_success "Rider command available in PATH"
        else
            print_warning "Rider command not found in PATH (may require login/logout)"
        fi
    else
        print_error "JetBrains Rider verification failed"
        return 1
    fi
}

show_rider_info() {
    if is_dry_run; then
        print_would_configure "JetBrains Rider" "post-installation setup information"
        return 0
    fi
    
    print_status "JetBrains Rider Installation Complete!"
    echo ""
    echo "Next steps:"
    echo "1. Launch Rider from applications menu or run: rider"
    echo "2. Sign in with your JetBrains account"
    echo "3. Activate your license (30-day trial available)"
    echo "4. Configure plugins and settings"
    echo ""
    echo "Useful resources:"
    echo "- Documentation: https://www.jetbrains.com/help/rider/"
    echo "- Plugins: https://plugins.jetbrains.com/rider"
    echo "- Keyboard shortcuts: https://www.jetbrains.com/help/rider/Reference_Keymap_Rider_Default.html"
    echo ""
    
    # Check for .NET SDK
    if ! command -v dotnet &>/dev/null; then
        print_warning "Consider installing .NET SDK for full functionality:"
        print_status "Run: ./setup.sh dotnet"
    fi
}

# Main execution
install_rider_module