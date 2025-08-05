#!/bin/bash

# Common development tools installation script

# Source common functions
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/common.sh"

install_dev_tools() {
    print_status "Installing common development tools..."
    log_script_start "install-dev-tools.sh"
    
    # Essential tools
    local essential_tools=(
        "curl:curl"
        "wget:wget"
        "htop:htop"
        "tree:tree"
        "unzip:unzip"
        "zip:zip"
        "vim:Vim"
        "nano:nano"
        "build-essential:Build tools"
        "software-properties-common:Software properties"
        "apt-transport-https:APT HTTPS transport"
        "ca-certificates:CA certificates"
        "gnupg:GnuPG"
        "lsb-release:LSB release"
    )
    
    for tool_info in "${essential_tools[@]}"; do
        local package="${tool_info%%:*}"
        local name="${tool_info#*:}"
        install_package "$package" "$name"
    done
    
    # Install VS Code
    install_vscode
    
    # Install additional development tools
    install_additional_tools
    
    print_success "Development tools installation complete"
    
    log_script_end "install-dev-tools.sh" 0
}

install_vscode() {
    if command_exists code; then
        print_warning "VS Code already installed"
        return
    fi
    
    print_status "Installing Visual Studio Code..."
    
    # Add Microsoft GPG key and repository
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list
    
    update_repositories
    install_package "code" "Visual Studio Code"
    
    # Install useful extensions
    install_vscode_extensions
}

install_vscode_extensions() {
    print_status "Installing VS Code extensions..."
    
    local extensions=(
        "ms-dotnettools.csharp"
        "ms-vscode.vscode-typescript-next"
        "esbenp.prettier-vscode"
        "ms-vscode.vscode-eslint"
        "GitLens.gitlens"
        "ms-vscode-remote.remote-ssh"
        "ms-vscode.remote-explorer"
        "ms-azuretools.vscode-docker"
        "redhat.vscode-yaml"
        "ms-vscode.powershell"
    )
    
    for extension in "${extensions[@]}"; do
        print_status "Installing extension: $extension"
        code --install-extension "$extension" || true
    done
}

install_additional_tools() {
    print_status "Installing additional development tools..."
    
    # ripgrep (better grep)
    install_package "ripgrep" "ripgrep"
    
    # fd (better find)
    install_package "fd-find" "fd"
    
    # bat (better cat)
    install_package "bat" "bat"
    
    # exa (better ls)
    install_package "exa" "exa"
    
    # jq (JSON processor)
    install_package "jq" "jq"
    
    # httpie (HTTP client)
    install_package "httpie" "HTTPie"
    
    # tmux (terminal multiplexer)
    install_package "tmux" "tmux"
    
    # neofetch (system info)
    install_package "neofetch" "neofetch"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_dev_tools
fi