#!/bin/bash

# Git installation and configuration script

# Source common functions
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/common.sh"

install_git() {
    print_status "Setting up Git..."
    
    # Get package info from settings
    local git_package=$(get_package_info 'git' 'package_name')
    local git_display=$(get_package_info 'git' 'display_name')
    
    # Install Git
    if command_exists git; then
        print_warning "$(get_message 'already_installed' "$git_display")"
        git --version
    else
        install_package "$git_package" "$git_display"
        git --version
    fi
    
    # Install jq for JSON parsing if needed
    local jq_package=$(get_package_info 'jq' 'package_name')
    local jq_display=$(get_package_info 'jq' 'display_name')
    
    if ! command_exists jq; then
        install_package "$jq_package" "$jq_display"
    fi
    
    # Configure Git from config file
    configure_git
}

configure_git() {
    local root_dir=$(get_root_dir)
    local config_file="$root_dir/configs/git-config.json"
    
    if [ -f "$config_file" ]; then
        print_status "$(get_message 'configuring_from_file' "$config_file")"
        
        # Read config values
        local git_name=$(jq -r '.user.name' "$config_file")
        local git_email=$(jq -r '.user.email' "$config_file")
        local git_editor=$(jq -r '.core.editor' "$config_file")
        local git_autocrlf=$(jq -r '.core.autocrlf' "$config_file")
        local git_default_branch=$(jq -r '.init.defaultBranch' "$config_file")
        local git_pull_rebase=$(jq -r '.pull.rebase' "$config_file")
        
        # Apply Git configuration
        git config --global user.name "$git_name"
        git config --global user.email "$git_email"
        git config --global core.editor "$git_editor"
        git config --global core.autocrlf "$git_autocrlf"
        git config --global init.defaultBranch "$git_default_branch"
        git config --global pull.rebase "$git_pull_rebase"
        
        print_success "$(get_message 'git_configured')"
        echo "  Name: $git_name"
        echo "  Email: $git_email"
        echo "  Editor: $git_editor"
        echo "  Default branch: $git_default_branch"
    else
        print_warning "$(get_message 'config_not_found' "$config_file")"
        echo ""
        read -p "$(get_prompt 'configure_git_manually')" -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            read -p "$(get_prompt 'git_name')" git_name
            read -p "$(get_prompt 'git_email')" git_email
            
            git config --global user.name "$git_name"
            git config --global user.email "$git_email"
            
            print_success "$(get_message 'git_configured')"
            echo "  Name: $git_name"
            echo "  Email: $git_email"
        fi
    fi
}

install_github_cli() {
    print_status "Installing GitHub CLI..."
    
    # Get package info from settings
    local gh_package=$(get_package_info 'github_cli' 'package_name')
    local gh_display=$(get_package_info 'github_cli' 'display_name')
    
    if command_exists gh; then
        print_warning "$(get_message 'already_installed' "$gh_display")"
        gh --version
    else
        # Get repository settings
        local keyring_url=$(get_setting '.repositories.github_cli.keyring_url')
        local keyring_path=$(get_setting '.repositories.github_cli.keyring_path')
        local apt_source=$(get_setting '.repositories.github_cli.apt_source')
        local apt_list_file=$(get_setting '.repositories.github_cli.apt_list_file')
        
        # Add GitHub CLI repository
        print_status "$(get_message 'adding_repo')"
        curl -fsSL "$keyring_url" | sudo dd of="$keyring_path"
        sudo chmod go+r "$keyring_path"
        echo "$apt_source" | sudo tee "$apt_list_file" > /dev/null
        
        # Update and install
        update_repositories
        install_package "$gh_package" "$gh_display"
        
        print_success "$(get_message 'installed_successfully' "$gh_display")"
        gh --version
        
        echo ""
        print_status "$(get_message 'github_auth_hint')"
    fi
}

# Main function to install all Git-related tools
main() {
    install_git
    install_github_cli
}

# Run installation if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi