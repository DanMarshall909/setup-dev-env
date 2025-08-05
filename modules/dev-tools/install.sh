#!/bin/bash

# Development Tools Module - Essential developer tools and utilities

# Source module framework
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/../../scripts/module-framework.sh"

# Module-specific configuration
MODULE_NAME="dev-tools"
MODULE_DISPLAY_NAME="Development Tools"

# List of development tools to install
declare -A DEV_TOOLS=(
    ["ripgrep"]="rg - Fast recursive grep"
    ["fd-find"]="fd - Fast find alternative"
    ["bat"]="bat - Cat with syntax highlighting"
    ["fzf"]="fzf - Fuzzy finder"
    ["tldr"]="tldr - Simplified man pages"
    ["ncdu"]="ncdu - NCurses disk usage"
    ["duf"]="duf - Better df alternative"
    ["httpie"]="httpie - Modern HTTP client"
    ["jless"]="jless - JSON viewer"
    ["yq"]="yq - YAML processor"
)

# Check if module is already installed
check_dev_tools_installed() {
    local installed_count=0
    local total_count=${#DEV_TOOLS[@]}
    
    for tool in "${!DEV_TOOLS[@]}"; do
        case "$tool" in
            "ripgrep") command -v rg &>/dev/null && ((installed_count++)) ;;
            "fd-find") command -v fd &>/dev/null && ((installed_count++)) ;;
            "bat") command -v bat &>/dev/null && ((installed_count++)) ;;
            "fzf") command -v fzf &>/dev/null && ((installed_count++)) ;;
            "tldr") command -v tldr &>/dev/null && ((installed_count++)) ;;
            "ncdu") command -v ncdu &>/dev/null && ((installed_count++)) ;;
            "duf") command -v duf &>/dev/null && ((installed_count++)) ;;
            "httpie") command -v http &>/dev/null && ((installed_count++)) ;;
            "jless") command -v jless &>/dev/null && ((installed_count++)) ;;
            "yq") command -v yq &>/dev/null && ((installed_count++)) ;;
        esac
    done
    
    # Consider installed if more than half are present
    [ $installed_count -gt $((total_count / 2)) ]
}

# Install the module
install_dev_tools() {
    print_status "Installing development tools..."
    
    # Update package lists
    if ! is_dry_run; then
        update_repositories
    fi
    
    # Install ripgrep
    if ! command -v rg &>/dev/null; then
        install_package_with_dry_run "ripgrep" "ripgrep (rg)"
    else
        print_success "✓ ripgrep"
    fi
    
    # Install fd-find
    if ! command -v fd &>/dev/null; then
        install_package_with_dry_run "fd-find" "fd-find"
        # Create symlink for fd command
        if ! is_dry_run && [ -f /usr/bin/fdfind ]; then
            sudo ln -sf /usr/bin/fdfind /usr/local/bin/fd
        fi
    else
        print_success "✓ fd-find"
    fi
    
    # Install bat
    if ! command -v bat &>/dev/null; then
        install_package_with_dry_run "bat" "bat"
        # Create symlink for bat command if needed
        if ! is_dry_run && [ -f /usr/bin/batcat ]; then
            sudo ln -sf /usr/bin/batcat /usr/local/bin/bat
        fi
    else
        print_success "✓ bat"
    fi
    
    # Install fzf
    if ! command -v fzf &>/dev/null; then
        install_package_with_dry_run "fzf" "fzf"
    else
        print_success "✓ fzf"
    fi
    
    # Install tldr
    if ! command -v tldr &>/dev/null; then
        install_package_with_dry_run "tldr" "tldr"
    else
        print_success "✓ tldr"
    fi
    
    # Install ncdu
    if ! command -v ncdu &>/dev/null; then
        install_package_with_dry_run "ncdu" "ncdu"
    else
        print_success "✓ ncdu"
    fi
    
    # Install httpie
    if ! command -v http &>/dev/null; then
        install_package_with_dry_run "httpie" "httpie"
    else
        print_success "✓ httpie"
    fi
    
    # Install modern tools that might need alternative installation
    
    # Install duf (disk usage)
    if ! command -v duf &>/dev/null; then
        if is_dry_run; then
            print_would_install "duf" "duf (modern df)"
        else
            # Try apt first
            if ! install_package "duf" "duf" 2>/dev/null; then
                # Fallback to downloading release
                print_status "Installing duf from GitHub release..."
                local duf_version="0.8.1"
                local duf_url="https://github.com/muesli/duf/releases/download/v${duf_version}/duf_${duf_version}_linux_amd64.deb"
                download_and_install "$duf_url" "duf.deb" "sudo dpkg -i" "duf"
            fi
        fi
    else
        print_success "✓ duf"
    fi
    
    # Install jless (JSON viewer)
    if ! command -v jless &>/dev/null; then
        if is_dry_run; then
            print_would_install "jless" "jless (JSON viewer)"
        else
            print_status "Installing jless..."
            local jless_url="https://github.com/PaulJuliusMartinez/jless/releases/latest/download/jless-x86_64-unknown-linux-gnu.zip"
            local temp_dir="/tmp/jless-install"
            mkdir -p "$temp_dir"
            
            # Try multiple download methods
            local download_success=false
            if curl -fsSL "$jless_url" -o "$temp_dir/jless.zip" 2>/dev/null; then
                download_success=true
            elif wget -q "$jless_url" -O "$temp_dir/jless.zip" 2>/dev/null; then
                download_success=true
            fi
            
            if [ "$download_success" = "true" ] && unzip -q "$temp_dir/jless.zip" -d "$temp_dir" 2>/dev/null; then
                if [ -f "$temp_dir/jless" ]; then
                    sudo mv "$temp_dir/jless" /usr/local/bin/
                    sudo chmod +x /usr/local/bin/jless
                    rm -rf "$temp_dir"
                    print_success "jless installed"
                else
                    print_warning "Failed to install jless - binary not found in archive"
                    rm -rf "$temp_dir"
                fi
            else
                # Fallback: Try installing via cargo if available  
                if command -v cargo &>/dev/null; then
                    print_status "Trying jless installation via cargo..."
                    if timeout 120 cargo install jless &>/dev/null; then
                        print_success "jless installed via cargo"
                    else
                        print_warning "Failed to install jless via cargo - skipping"
                    fi
                else
                    print_warning "Failed to install jless - network or extraction error"
                fi
                rm -rf "$temp_dir"
            fi
        fi
    else
        print_success "✓ jless"
    fi
    
    # Install yq (YAML processor)
    if ! command -v yq &>/dev/null; then
        if is_dry_run; then
            print_would_install "yq" "yq (YAML processor)"
        else
            # Try snap first
            if command -v snap &>/dev/null; then
                install_snap_package "yq" "" "yq"
            else
                # Fallback to direct download
                print_status "Installing yq from GitHub release..."
                local yq_url="https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64"
                if wget -q "$yq_url" -O /tmp/yq; then
                    sudo mv /tmp/yq /usr/local/bin/yq
                    sudo chmod +x /usr/local/bin/yq
                    print_success "yq installed"
                else
                    print_warning "Failed to install yq"
                fi
            fi
        fi
    else
        print_success "✓ yq"
    fi
    
    print_success "$MODULE_DISPLAY_NAME installation completed"
    return 0
}

# Verify installation
verify_dev_tools_installation() {
    if is_dry_run; then
        print_would_execute "Verifying development tools installation"
        return 0
    fi
    
    print_status "Verifying development tools..."
    local verified=0
    local total=${#DEV_TOOLS[@]}
    
    # Check each tool
    verify_command_available "rg" "ripgrep" && ((verified++)) || true
    verify_command_available "fd" "fd-find" && ((verified++)) || true
    verify_command_available "bat" "bat" && ((verified++)) || true
    verify_command_available "fzf" "fzf" && ((verified++)) || true
    verify_command_available "tldr" "tldr" && ((verified++)) || true
    verify_command_available "ncdu" "ncdu" && ((verified++)) || true
    verify_command_available "duf" "duf" && ((verified++)) || true
    verify_command_available "http" "httpie" && ((verified++)) || true
    verify_command_available "jless" "jless" && ((verified++)) || true
    verify_command_available "yq" "yq" && ((verified++)) || true
    
    print_success "Development tools verified: $verified/$total installed"
    
    # Update tldr cache if installed
    if command -v tldr &>/dev/null; then
        print_status "Updating tldr cache..."
        tldr --update 2>/dev/null || true
    fi
    
    return 0
}

# Show post-installation information
show_dev_tools_info() {
    local next_steps="• Use 'rg <pattern>' for fast recursive searching
• Use 'fd <name>' for fast file finding
• Use 'bat <file>' for syntax-highlighted file viewing
• Use 'fzf' for fuzzy finding in pipes
• Use 'tldr <command>' for simplified command examples
• Use 'ncdu' for interactive disk usage analysis
• Use 'duf' for a modern df replacement
• Use 'http' for API testing
• Use 'jless' for viewing JSON files
• Use 'yq' for YAML processing"
    
    local docs_url="https://github.com/sharkdp/fd
https://github.com/BurntSushi/ripgrep
https://github.com/sharkdp/bat"
    
    local config_notes="• bat: Create ~/.config/bat/config for custom settings
• fzf: Add to ~/.bashrc: [ -f ~/.fzf.bash ] && source ~/.fzf.bash
• ripgrep: Create ~/.config/ripgrep/config for default options"
    
    show_post_install_info "$MODULE_DISPLAY_NAME" "$next_steps" "$docs_url" "$config_notes"
}

# Main module execution using framework
install_dev_tools_module() {
    init_module "$MODULE_NAME" "$MODULE_DISPLAY_NAME"
    
    run_standard_install_flow \
        "check_dev_tools_installed" \
        "install_dev_tools" \
        "verify_dev_tools_installation" \
        "show_dev_tools_info"
}

# Execute if run directly
install_dev_tools_module