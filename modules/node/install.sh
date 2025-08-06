#!/bin/bash

# Node.js module installation script

# Source common functions
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/../../scripts/common.sh"

install_node_module() {
    print_status "Installing Node.js module..."
    log_script_start "node/install.sh"
    
    # Install Node.js using NodeSource repository for latest LTS
    install_nodejs
    
    # Configure npm (must be done before installing global packages)
    configure_npm
    
    # Install global TypeScript tools
    install_typescript_tools
    
    # Verify installation
    verify_nodejs_installation
    
    log_script_end "node/install.sh" 0
}

install_nodejs() {
    print_status "Installing Node.js..."
    
    if command_exists node; then
        local current_version=$(node --version)
        print_warning "Node.js already installed: $current_version"
        return 0
    fi
    
    if is_dry_run; then
        print_would_execute "curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -"
        print_would_install "nodejs" "Node.js"
        print_would_execute "node --version && npm --version"
        return 0
    fi
    
    # Install Node.js 18.x LTS from NodeSource
    print_status "Adding NodeSource repository..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    
    # Install Node.js
    install_package "nodejs" "Node.js"
    
    # Verify installation
    print_success "Node.js installed:"
    node --version
    npm --version
}

install_typescript_tools() {
    print_status "Installing TypeScript and global tools..."
    
    # Read global packages from module config
    local module_config="$SCRIPT_DIR/module.json"
    local packages=$(jq -r '.global_packages[]' "$module_config" 2>/dev/null)
    
    if is_dry_run; then
        if [ -n "$packages" ]; then
            while IFS= read -r package; do
                if [ -n "$package" ]; then
                    print_would_execute "npm install -g $package"
                fi
            done <<< "$packages"
        else
            print_would_execute "npm install -g typescript ts-node nodemon prettier eslint @types/node"
        fi
        return 0
    fi
    
    if [ -n "$packages" ]; then
        # Install packages one by one for better error handling
        while IFS= read -r package; do
            if [ -n "$package" ]; then
                print_status "Installing global package: $package"
                if npm install -g "$package"; then
                    print_success "Installed: $package"
                    log_package_operation "install" "$package" "global"
                else
                    print_error "Failed to install: $package"
                    log_package_operation "install" "$package" "failed"
                fi
            fi
        done <<< "$packages"
    else
        # Fallback to default packages
        print_status "Installing default TypeScript tools..."
        if npm install -g typescript ts-node nodemon prettier eslint @types/node; then
            print_success "Default TypeScript tools installed"
        else
            print_warning "Some TypeScript tools may have failed to install"
        fi
    fi
}

configure_npm() {
    print_status "Configuring npm..."
    
    if is_dry_run; then
        local author_name="$(git config --global user.name 2>/dev/null || echo 'Developer')"
        local author_email="$(git config --global user.email 2>/dev/null || echo 'dev@example.com')"
        print_would_configure "npm" "Global packages directory: ~/.npm-global"
        print_would_configure "npm" "init-author-name=$author_name"
        print_would_configure "npm" "init-author-email=$author_email"
        print_would_configure "npm" "init-license=MIT"
        print_would_configure "npm" "save-exact=true"
        print_would_configure "npm" "authentication token (if available)"
        return 0
    fi
    
    # Fix npm permissions by using user directory for global packages
    print_status "Setting up npm global packages directory..."
    mkdir -p ~/.npm-global
    npm config set prefix '~/.npm-global'
    
    # Add to PATH in current session
    export PATH=~/.npm-global/bin:$PATH
    
    # Add to shell configuration files
    local shell_config=""
    if [ -f ~/.bashrc ]; then
        shell_config=~/.bashrc
    elif [ -f ~/.bash_profile ]; then
        shell_config=~/.bash_profile
    fi
    
    if [ -n "$shell_config" ]; then
        # Check if already added
        if ! grep -q "npm-global/bin" "$shell_config"; then
            echo "" >> "$shell_config"
            echo "# npm global packages path" >> "$shell_config"
            echo 'export PATH=~/.npm-global/bin:$PATH' >> "$shell_config"
            print_success "Added npm global path to $shell_config"
        fi
    fi
    
    # Set npm defaults
    npm config set init-author-name "$(git config --global user.name 2>/dev/null || echo 'Developer')"
    npm config set init-author-email "$(git config --global user.email 2>/dev/null || echo 'dev@example.com')"
    npm config set init-license "MIT"
    npm config set save-exact true
    
    # Configure npm token if available
    configure_npm_auth
    
    print_success "npm configured"
}

configure_npm_auth() {
    if is_dry_run; then
        print_would_configure "npm" "authentication token from password manager"
        return 0
    fi
    
    # Try to get npm token from password manager
    local secret_config=$(get_setting '.security.secrets.npm_token')
    local secret_path=$(echo "$secret_config" | jq -r '.path')
    local env_var=$(echo "$secret_config" | jq -r '.env_var')
    local field=$(echo "$secret_config" | jq -r '.field')
    
    local npm_token=$(get_secret_or_env "$secret_path" "$env_var" "$field" 2>/dev/null)
    
    # Validate token - should not contain warning messages or be empty
    if [ -n "$npm_token" ] && [[ ! "$npm_token" == *"WARNING"* ]] && [[ ! "$npm_token" == *"not available"* ]]; then
        print_status "Configuring npm authentication..."
        npm config set //registry.npmjs.org/:_authToken "$npm_token"
        log_config_change "npm" "auth_token" "" "<masked>"
        print_success "npm authentication configured"
    else
        print_status "npm token not configured (will use public packages only)"
        # Clear any invalid token that might be set
        npm config delete //registry.npmjs.org/:_authToken 2>/dev/null || true
    fi
}

verify_nodejs_installation() {
    print_status "Verifying Node.js installation..."
    
    if is_dry_run; then
        print_would_execute "node --version"
        print_would_execute "npm --version"
        print_would_execute "tsc --version"
        print_would_execute "npm ping"
        print_success "DRY RUN: All verification checks would be performed"
        return 0
    fi
    
    # Test Node.js
    if command_exists node; then
        local node_version=$(node --version)
        print_success "Node.js: $node_version"
    else
        print_error "Node.js verification failed"
        return 1
    fi
    
    # Test npm
    if command_exists npm; then
        local npm_version=$(npm --version)
        print_success "npm: $npm_version"
    else
        print_error "npm verification failed"
        return 1
    fi
    
    # Test TypeScript
    if command_exists tsc; then
        local ts_version=$(tsc --version)
        print_success "TypeScript: $ts_version"
    else
        print_warning "TypeScript not available globally"
    fi
    
    # Test npm connectivity
    if npm ping &>/dev/null; then
        print_success "npm registry connectivity: OK"
    else
        print_warning "npm registry connectivity: Failed (check internet connection)"
    fi
}

# Main execution
install_node_module