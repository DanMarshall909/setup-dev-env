#!/bin/bash

# VS Code module installation script

# Source common functions
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/../../scripts/common.sh"

install_vscode_module() {
    print_status "Installing VS Code module..."
    log_script_start "vscode/install.sh"
    
    # Check if already installed
    if check_vscode_installed; then
        print_warning "VS Code is already installed"
        verify_vscode_installation
        install_vscode_extensions
        log_script_end "vscode/install.sh" 0
        return 0
    fi
    
    # Install VS Code
    install_vscode_editor
    
    # Verify installation
    verify_vscode_installation
    
    # Install extensions
    install_vscode_extensions
    
    # Show post-installation info
    show_vscode_info
    
    log_script_end "vscode/install.sh" 0
}

check_vscode_installed() {
    # Check if code command exists
    if command -v code &>/dev/null; then
        return 0
    fi
    
    return 1
}

install_vscode_editor() {
    print_status "Installing Visual Studio Code..."
    
    if is_dry_run; then
        print_would_execute "Add Microsoft GPG key and repository"
        print_would_install "code" "VS Code"
        return 0
    fi
    
    # Install prerequisites
    install_package "wget" "wget" || true
    install_package "gpg" "GnuPG" || true
    install_package "software-properties-common" "software-properties-common" || true
    
    # Add Microsoft GPG key
    print_status "Adding Microsoft GPG key..."
    local keyring_path="/etc/apt/keyrings/packages.microsoft.gpg"
    
    # Create keyrings directory if it doesn't exist
    sudo mkdir -p /etc/apt/keyrings
    
    # Download and add Microsoft GPG key
    if wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee "$keyring_path" > /dev/null; then
        print_success "Microsoft GPG key added"
    else
        print_error "Failed to add Microsoft GPG key"
        return 1
    fi
    
    # Add VS Code repository
    print_status "Adding VS Code repository..."
    local repo_line="deb [arch=amd64,arm64,armhf signed-by=$keyring_path] https://packages.microsoft.com/repos/code stable main"
    
    if echo "$repo_line" | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null; then
        print_success "VS Code repository added"
    else
        print_error "Failed to add VS Code repository"
        return 1
    fi
    
    # Update package list
    print_status "Updating package list..."
    if sudo apt-get update; then
        print_success "Package list updated"
    else
        print_warning "Failed to update package list"
        return 1
    fi
    
    # Install VS Code
    print_status "Installing VS Code package..."
    if install_package "code" "VS Code"; then
        print_success "VS Code installed successfully"
        return 0
    else
        print_error "Failed to install VS Code"
        return 1
    fi
}

verify_vscode_installation() {
    print_status "Verifying VS Code installation..."
    
    if is_dry_run; then
        print_would_execute "code --version"
        print_success "DRY RUN: VS Code installation would be verified"
        return 0
    fi
    
    if check_vscode_installed; then
        local version=$(code --version 2>/dev/null | head -n1)
        print_success "VS Code installed: $version"
        
        # Check if code command is available
        if command -v code &>/dev/null; then
            print_success "VS Code command available in PATH"
        else
            print_warning "VS Code command not found in PATH"
        fi
    else
        print_error "VS Code verification failed"
        return 1
    fi
}

install_vscode_extensions() {
    print_status "Installing VS Code extensions..."
    
    if is_dry_run; then
        print_would_execute "code --install-extension ms-dotnettools.csharp"
        print_would_execute "code --install-extension esbenp.prettier-vscode"
        print_would_execute "code --install-extension ms-vscode.eslint"
        print_would_execute "code --install-extension eamodio.gitlens"
        print_would_execute "code --install-extension ms-vscode-remote.remote-ssh"
        print_would_execute "code --install-extension ms-azuretools.vscode-docker"
        print_success "DRY RUN: VS Code extensions would be installed"
        return 0
    fi
    
    if ! command -v code &>/dev/null; then
        print_warning "VS Code not installed, skipping extension installation"
        return 0
    fi
    
    # Define extensions to install
    local extensions=(
        "ms-dotnettools.csharp"
        "esbenp.prettier-vscode"
        "ms-vscode.eslint"
        "eamodio.gitlens"
        "ms-vscode-remote.remote-ssh"
        "ms-azuretools.vscode-docker"
    )
    
    # Install each extension
    for extension in "${extensions[@]}"; do
        print_status "Installing extension: $extension"
        
        # Check if extension is already installed
        if code --list-extensions | grep -q "^$extension$"; then
            print_warning "Extension $extension is already installed"
            continue
        fi
        
        # Install the extension with timeout
        if timeout 120 code --install-extension "$extension" --force; then
            print_success "Extension $extension installed successfully"
        else
            print_warning "Failed to install extension: $extension (timeout or error)"
        fi
    done
    
    print_success "VS Code extensions installation completed"
}

show_vscode_info() {
    if is_dry_run; then
        print_would_configure "VS Code" "post-installation setup information"
        return 0
    fi
    
    print_status "VS Code Installation Complete!"
    echo ""
    echo "Next steps:"
    echo "1. Launch VS Code from applications menu or run: code"
    echo "2. Configure your preferences in Settings (Ctrl+,)"
    echo "3. Install additional extensions as needed"
    echo "4. Set up Settings Sync to sync across devices (optional)"
    echo "5. Configure integrated terminal and Git integration"
    echo ""
    echo "Installed extensions:"
    echo "- C# Dev Kit (ms-dotnettools.csharp)"
    echo "- Prettier (esbenp.prettier-vscode)"
    echo "- ESLint (ms-vscode.eslint)"
    echo "- GitLens (eamodio.gitlens)"
    echo "- Remote - SSH (ms-vscode-remote.remote-ssh)"
    echo "- Docker (ms-azuretools.vscode-docker)"
    echo ""
    echo "Useful resources:"
    echo "- Documentation: https://code.visualstudio.com/docs"
    echo "- Extensions: https://marketplace.visualstudio.com/"
    echo "- Keyboard shortcuts: https://code.visualstudio.com/shortcuts/keyboard-shortcuts-linux.pdf"
    echo ""
}

# Main execution
install_vscode_module