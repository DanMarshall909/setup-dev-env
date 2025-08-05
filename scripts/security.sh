#!/bin/bash

# Security layer for password manager integration

# Get basic functions without circular dependency
get_root_dir() {
    echo "$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." &> /dev/null && pwd )"
}

get_setting() {
    local key=$1
    local settings_file="$(get_root_dir)/configs/settings.json"
    if [ -f "$settings_file" ] && command -v jq &> /dev/null; then
        jq -r "$key" "$settings_file" 2>/dev/null || echo ""
    else
        echo ""
    fi
}

# Get security settings
get_security_setting() {
    local key=$1
    get_setting ".security.$key"
}

# Check which password manager is configured
get_password_manager() {
    local manager=$(get_security_setting "password_manager.provider")
    if [ -z "$manager" ]; then
        echo "none"
    else
        echo "$manager"
    fi
}

# Check if password manager is available
is_password_manager_available() {
    local manager=$(get_password_manager)
    
    case $manager in
        "1password")
            command_exists "op"
            ;;
        "bitwarden")
            command_exists "bw"
            ;;
        "lastpass")
            command_exists "lpass"
            ;;
        "keepass")
            command_exists "keepassxc-cli"
            ;;
        "pass")
            command_exists "pass"
            ;;
        "none"|"")
            return 1
            ;;
        *)
            return 1
            ;;
    esac
}

# Get secret from password manager
get_secret() {
    local secret_path=$1
    local field=${2:-"password"}
    local manager=$(get_password_manager)
    
    if ! is_password_manager_available; then
        print_warning "Password manager '$manager' is not available or not configured"
        return 1
    fi
    
    case $manager in
        "1password")
            get_secret_1password "$secret_path" "$field"
            ;;
        "bitwarden")
            get_secret_bitwarden "$secret_path" "$field"
            ;;
        "lastpass")
            get_secret_lastpass "$secret_path" "$field"
            ;;
        "keepass")
            get_secret_keepass "$secret_path" "$field"
            ;;
        "pass")
            get_secret_pass "$secret_path" "$field"
            ;;
        *)
            print_error "Unknown password manager: $manager"
            return 1
            ;;
    esac
}

# 1Password CLI integration
get_secret_1password() {
    local item_path=$1
    local field=$2
    
    # Check if signed in
    if ! op account list &>/dev/null; then
        print_status "Please sign in to 1Password CLI"
        eval $(op signin)
    fi
    
    # Get the secret
    if [ "$field" = "password" ]; then
        op item get "$item_path" --fields password 2>/dev/null
    else
        op item get "$item_path" --fields "$field" 2>/dev/null
    fi
}

# Bitwarden CLI integration
get_secret_bitwarden() {
    local item_name=$1
    local field=$2
    
    # Check if unlocked
    if ! bw status | grep -q "unlocked"; then
        print_status "Please unlock Bitwarden"
        export BW_SESSION=$(bw unlock --raw)
    fi
    
    # Get item and extract field
    local item_json=$(bw get item "$item_name" 2>/dev/null)
    if [ "$field" = "password" ]; then
        echo "$item_json" | jq -r '.login.password'
    else
        echo "$item_json" | jq -r ".fields[] | select(.name==\"$field\") | .value"
    fi
}

# LastPass CLI integration
get_secret_lastpass() {
    local item_name=$1
    local field=$2
    
    # Check if logged in
    if ! lpass status -q; then
        print_status "Please log in to LastPass"
        lpass login
    fi
    
    # Get the secret
    if [ "$field" = "password" ]; then
        lpass show "$item_name" --password
    else
        lpass show "$item_name" --field="$field"
    fi
}

# KeePass CLI integration
get_secret_keepass() {
    local entry_path=$1
    local field=$2
    local db_path=$(get_security_setting "password_manager.keepass.database_path")
    
    if [ -z "$db_path" ] || [ ! -f "$db_path" ]; then
        print_error "KeePass database not found. Please configure database_path in settings.json"
        return 1
    fi
    
    # Get the secret (will prompt for master password)
    if [ "$field" = "password" ]; then
        keepassxc-cli show -s "$db_path" "$entry_path" -a password
    else
        keepassxc-cli show -s "$db_path" "$entry_path" -a "$field"
    fi
}

# Pass (standard unix password manager) integration
get_secret_pass() {
    local secret_path=$1
    local field=$2
    
    if [ "$field" = "password" ]; then
        pass show "$secret_path" | head -n1
    else
        pass show "$secret_path" | grep "^$field:" | cut -d' ' -f2-
    fi
}

# Get secret with fallback to environment variable
get_secret_or_env() {
    local secret_path=$1
    local env_var=$2
    local field=${3:-"password"}
    
    # First try password manager
    local secret=$(get_secret "$secret_path" "$field" 2>/dev/null)
    
    if [ -n "$secret" ]; then
        echo "$secret"
    elif [ -n "$env_var" ] && [ -n "${!env_var}" ]; then
        # Fallback to environment variable
        echo "${!env_var}"
    else
        return 1
    fi
}

# Get secret with fallback to prompt
get_secret_or_prompt() {
    local secret_path=$1
    local prompt_text=$2
    local field=${3:-"password"}
    local is_password=${4:-false}
    
    # First try password manager
    local secret=$(get_secret "$secret_path" "$field" 2>/dev/null)
    
    if [ -n "$secret" ]; then
        echo "$secret"
    else
        # Fallback to prompt
        if [ "$is_password" = true ]; then
            read -s -p "$prompt_text" secret
            echo >&2  # New line after password
        else
            read -p "$prompt_text" secret
        fi
        echo "$secret"
    fi
}

# Install password manager CLI tools
install_password_manager() {
    local manager=${1:-$(get_password_manager)}
    
    case $manager in
        "1password")
            install_1password_cli
            ;;
        "bitwarden")
            install_bitwarden_cli
            ;;
        "lastpass")
            install_lastpass_cli
            ;;
        "keepass")
            install_package "keepassxc" "KeePassXC"
            ;;
        "pass")
            install_package "pass" "pass"
            ;;
        *)
            print_error "Unknown password manager: $manager"
            return 1
            ;;
    esac
}

# Install 1Password CLI
install_1password_cli() {
    if command_exists "op"; then
        print_warning "1Password CLI is already installed"
        op --version
    else
        print_status "Installing 1Password CLI..."
        
        # Add 1Password repository
        curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
            sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
        
        echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/amd64 stable main' | \
            sudo tee /etc/apt/sources.list.d/1password.list
        
        sudo mkdir -p /etc/debsig/policies/AC2D62742012EA22/
        curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol | \
            sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol
        
        sudo mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22
        curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
            sudo gpg --dearmor --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg
        
        # Update and install
        update_repositories
        install_package "1password-cli" "1Password CLI"
        
        print_success "1Password CLI installed successfully"
        op --version
    fi
}

# Install Bitwarden CLI
install_bitwarden_cli() {
    if command_exists "bw"; then
        print_warning "Bitwarden CLI is already installed"
        bw --version
    else
        print_status "Installing Bitwarden CLI..."
        
        # Download from GitHub releases
        local version=$(curl -s https://api.github.com/repos/bitwarden/clients/releases/latest | jq -r '.tag_name' | sed 's/cli-v//')
        local url="https://github.com/bitwarden/clients/releases/download/cli-v${version}/bw-linux-${version}.zip"
        
        # Download and install
        curl -L "$url" -o /tmp/bw.zip
        sudo unzip -q /tmp/bw.zip -d /usr/local/bin/
        sudo chmod +x /usr/local/bin/bw
        rm /tmp/bw.zip
        
        print_success "Bitwarden CLI installed successfully"
        bw --version
    fi
}

# Install LastPass CLI
install_lastpass_cli() {
    if command_exists "lpass"; then
        print_warning "LastPass CLI is already installed"
        lpass --version
    else
        print_status "Installing LastPass CLI..."
        
        # Install build dependencies
        install_package "build-essential" "Build tools"
        install_package "cmake" "CMake"
        install_package "libcurl4-openssl-dev" "libcurl"
        install_package "libxml2-dev" "libxml2"
        install_package "libssl-dev" "OpenSSL"
        install_package "pkg-config" "pkg-config"
        
        # Clone and build
        local temp_dir=$(mktemp -d)
        git clone https://github.com/lastpass/lastpass-cli.git "$temp_dir"
        cd "$temp_dir"
        make
        sudo make install
        cd - > /dev/null
        rm -rf "$temp_dir"
        
        print_success "LastPass CLI installed successfully"
        lpass --version
    fi
}