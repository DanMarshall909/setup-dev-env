#!/bin/bash

# Advanced Git configuration with security integration

# Source common functions
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/common.sh"

configure_git_advanced() {
    print_status "Configuring advanced Git settings..."
    log_script_start "configure-git-advanced"
    
    # Configure Git credentials
    configure_git_credentials
    
    # Configure GitHub CLI authentication
    configure_github_cli_auth
    
    # Configure Git hooks
    configure_git_hooks
    
    log_script_end "configure-git-advanced" 0
}

configure_git_credentials() {
    print_status "Configuring Git credentials..."
    
    # Check if credential helper is already configured
    local current_helper=$(git config --global credential.helper)
    
    if [ -n "$current_helper" ]; then
        print_warning "Git credential helper already configured: $current_helper"
        log_config_change "git" "credential.helper" "$current_helper" "$current_helper"
    else
        # Configure based on password manager
        local pm=$(get_password_manager)
        
        case $pm in
            "1password")
                print_status "Configuring Git to use 1Password..."
                git config --global credential.helper "osxkeychain"  # For macOS
                # For Linux, use libsecret
                if [ -f /usr/share/doc/git/contrib/credential/libsecret/git-credential-libsecret ]; then
                    git config --global credential.helper /usr/share/doc/git/contrib/credential/libsecret/git-credential-libsecret
                else
                    # Install and build libsecret helper
                    install_package "libsecret-1-0" "libsecret"
                    install_package "libsecret-1-dev" "libsecret-dev"
                    install_package "make" "make"
                    
                    cd /usr/share/doc/git/contrib/credential/libsecret
                    sudo make
                    git config --global credential.helper /usr/share/doc/git/contrib/credential/libsecret/git-credential-libsecret
                    cd - > /dev/null
                fi
                log_config_change "git" "credential.helper" "" "libsecret"
                ;;
            *)
                print_status "Using default Git credential storage..."
                git config --global credential.helper "store"
                log_config_change "git" "credential.helper" "" "store"
                ;;
        esac
    fi
}

configure_github_cli_auth() {
    if ! command_exists gh; then
        print_warning "GitHub CLI not installed, skipping authentication"
        return
    fi
    
    # Check if already authenticated
    if gh auth status &>/dev/null; then
        print_success "GitHub CLI already authenticated"
        return
    fi
    
    print_status "Configuring GitHub CLI authentication..."
    
    # Try to get GitHub token from password manager
    local secret_config=$(get_setting '.security.secrets.github_token')
    local secret_path=$(echo "$secret_config" | jq -r '.path')
    local env_var=$(echo "$secret_config" | jq -r '.env_var')
    local field=$(echo "$secret_config" | jq -r '.field')
    
    local github_token=$(get_secret_or_env "$secret_path" "$env_var" "$field")
    
    if [ -n "$github_token" ]; then
        print_status "Using GitHub token from password manager..."
        echo "$github_token" | gh auth login --with-token
        log_info "GitHub CLI authenticated using token from password manager"
    else
        print_status "Please authenticate with GitHub manually..."
        gh auth login
        log_info "GitHub CLI authenticated manually"
    fi
}

configure_git_hooks() {
    print_status "Configuring Git hooks..."
    
    # Global git hooks directory
    local hooks_dir="$HOME/.config/git/hooks"
    mkdir -p "$hooks_dir"
    
    # Configure global hooks path
    git config --global core.hooksPath "$hooks_dir"
    log_config_change "git" "core.hooksPath" "" "$hooks_dir"
    
    # Create commit-msg hook for conventional commits
    cat > "$hooks_dir/commit-msg" << 'EOF'
#!/bin/bash
# Conventional Commits hook

commit_regex='^(feat|fix|docs|style|refactor|test|chore|perf|ci|build|revert)(\(.+\))?: .{1,50}'

if ! grep -qE "$commit_regex" "$1"; then
    echo "Commit message does not follow Conventional Commits format!"
    echo "Format: <type>(<scope>): <subject>"
    echo "Example: feat(auth): add login functionality"
    echo ""
    echo "Types: feat, fix, docs, style, refactor, test, chore, perf, ci, build, revert"
    exit 1
fi
EOF
    
    chmod +x "$hooks_dir/commit-msg"
    log_file_operation "create" "$hooks_dir/commit-msg"
    
    print_success "Git hooks configured"
}

# Main function
main() {
    configure_git_advanced
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi