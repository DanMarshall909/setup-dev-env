#!/bin/bash

# Node.js and TypeScript installation script

# Source common functions
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/common.sh"

install_node() {
    print_status "Installing Node.js and npm..."
    log_script_start "install-node.sh"
    
    # For now, just install from apt
    # TODO: Use NodeSource repository for latest version
    install_package "nodejs" "Node.js"
    install_package "npm" "npm"
    
    # Update npm to latest
    print_status "Updating npm to latest version..."
    sudo npm install -g npm@latest
    
    # Install global TypeScript tools
    print_status "Installing TypeScript and global tools..."
    sudo npm install -g typescript ts-node nodemon prettier eslint
    
    # Show versions
    print_success "Node.js installation complete:"
    node --version
    npm --version
    
    log_script_end "install-node.sh" 0
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_node
fi