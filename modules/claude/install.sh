#!/bin/bash

# Claude Code module installation script

# Source common functions and module manager
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/../../scripts/common.sh"
source "$SCRIPT_DIR/../../scripts/module-manager.sh"

install_claude_module() {
    print_status "Installing Claude Code module..."
    log_script_start "claude/install.sh"
    
    # Verify Node.js is available (dependency check)
    verify_nodejs_dependency
    
    # Install Claude Code CLI
    install_claude_code_cli
    
    # Configure Claude Code
    configure_claude_code
    
    # Verify installation
    verify_claude_installation
    
    log_script_end "claude/install.sh" 0
}

verify_nodejs_dependency() {
    print_status "Verifying Node.js dependency..."
    
    if ! command_exists node; then
        print_warning "Node.js is required but not installed"
        print_status "Installing Node.js dependency..."
        
        # Try to install node module
        if install_module "node" false false; then
            print_success "Node.js dependency installed"
            # Update PATH for npm-global
            export PATH=~/.npm-global/bin:$PATH
        else
            print_error "Failed to install Node.js dependency"
            print_status "Please install manually: ./setup.sh node"
            return 1
        fi
    fi
    
    local node_version=$(node --version 2>/dev/null | sed 's/v//')
    if [ -z "$node_version" ]; then
        print_error "Node.js verification failed"
        return 1
    fi
    
    local major_version=$(echo "$node_version" | cut -d. -f1)
    
    if [ "$major_version" -lt 18 ]; then
        print_error "Node.js version 18 or higher is required (found: v$node_version)"
        return 1
    fi
    
    print_success "Node.js dependency satisfied: v$node_version"
    return 0
}

install_claude_code_cli() {
    print_status "Installing Claude Code CLI..."
    
    # Check if already installed
    if command_exists claude-code; then
        local current_version=$(claude-code --version 2>/dev/null | head -n1)
        print_warning "Claude Code CLI already installed: $current_version"
        return 0
    fi
    
    # Check if installed via npm
    if npm list -g @anthropic/claude-code >/dev/null 2>&1; then
        print_warning "Claude Code CLI already installed via npm"
        return 0
    fi
    
    # Ensure directories exist and PATH is set
    mkdir -p ~/.local/bin
    export PATH=~/.npm-global/bin:~/.local/bin:$PATH
    
    # Install via npm with proper PATH
    print_status "Installing Claude Code CLI via npm..."
    
    if npm install -g @anthropic/claude-code; then
        print_success "Claude Code CLI installed successfully"
        log_package_operation "install" "@anthropic/claude-code" "global"
        
        # Create symlink if needed
        if [ -f ~/.npm-global/bin/claude-code ] && [ ! -f /usr/local/bin/claude-code ]; then
            sudo ln -sf ~/.npm-global/bin/claude-code /usr/local/bin/claude-code 2>/dev/null || true
        fi
    else
        print_error "Failed to install Claude Code CLI"
        log_package_operation "install" "@anthropic/claude-code" "failed"
        
        # Try alternative installation method
        print_status "Trying alternative installation method..."
        if timeout 30 npx @anthropic/claude-code --version &>/dev/null; then
            print_success "Claude Code available via npx"
            # Create wrapper script
            cat > ~/.local/bin/claude-code << 'EOF'
#!/bin/bash
exec npx @anthropic/claude-code "$@"
EOF
            chmod +x ~/.local/bin/claude-code
            print_success "Created claude-code wrapper script"
        else
            print_warning "npx method also failed - Claude Code CLI not available"
            print_status "You can install manually with: npm install -g @anthropic/claude-code"
            return 1
        fi
    fi
}

configure_claude_code() {
    print_status "Configuring Claude Code..."
    
    # Create config directory
    local config_dir="$HOME/.claude"
    mkdir -p "$config_dir"
    
    # Try to get API key from password manager
    local secret_config=$(get_setting '.security.secrets.anthropic_api_key')
    local secret_path=$(echo "$secret_config" | jq -r '.path')
    local env_var=$(echo "$secret_config" | jq -r '.env_var')
    local field=$(echo "$secret_config" | jq -r '.field')
    
    local api_key=$(get_secret_or_env "$secret_path" "$env_var" "$field")
    
    if [ -n "$api_key" ]; then
        print_status "Configuring API key from password manager..."
        
        # Configure API key
        claude-code auth login --api-key "$api_key" || {
            print_warning "Failed to configure API key automatically"
            print_status "You can configure it manually with: claude-code auth login"
        }
        
        log_config_change "claude" "api_key" "" "<masked>"
        print_success "Claude Code configured with API key"
    else
        print_warning "Anthropic API key not found in password manager"
        print_status "Please configure manually with: claude-code auth login"
        print_status "You can get an API key from: https://console.anthropic.com/"
    fi
    
    # Set up default configuration
    setup_default_config "$config_dir"
}

setup_default_config() {
    local config_dir=$1
    local config_file="$config_dir/config.json"
    
    # Create default configuration if it doesn't exist
    if [ ! -f "$config_file" ]; then
        print_status "Creating default configuration..."
        
        cat > "$config_file" << 'EOF'
{
  "default_model": "claude-3-5-sonnet-20241022",
  "max_tokens": 4096,
  "temperature": 0.7,
  "editor": "code",
  "workspace_settings": {
    "auto_save": true,
    "format_on_save": true,
    "show_line_numbers": true
  },
  "features": {
    "auto_complete": true,
    "code_review": true,
    "documentation_generation": true
  }
}
EOF
        
        log_file_operation "create" "$config_file"
        print_success "Default configuration created"
    else
        print_status "Configuration file already exists"
    fi
}

verify_claude_installation() {
    print_status "Verifying Claude Code installation..."
    
    # Test Claude Code CLI
    if command_exists claude-code; then
        local claude_version=$(claude-code --version 2>/dev/null | head -n1)
        print_success "Claude Code CLI: $claude_version"
    else
        print_error "Claude Code CLI verification failed"
        return 1
    fi
    
    # Test authentication status
    if claude-code auth status &>/dev/null; then
        print_success "Claude Code authentication: OK"
    else
        print_warning "Claude Code authentication: Not configured"
        print_status "Run 'claude-code auth login' to authenticate"
    fi
    
    # Test basic functionality
    if claude-code --help &>/dev/null; then
        print_success "Claude Code functionality: OK"
    else
        print_warning "Claude Code basic functionality check failed"
    fi
}

# Main execution
install_claude_module