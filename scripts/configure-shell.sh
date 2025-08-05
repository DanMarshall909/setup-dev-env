#!/bin/bash

# Shell configuration script (Zsh + Oh My Zsh)

# Source common functions
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/common.sh"

configure_shell() {
    print_status "Configuring shell environment..."
    log_script_start "configure-shell.sh"
    
    # Install Zsh
    install_package "zsh" "Zsh"
    
    # Install Oh My Zsh
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        print_status "Installing Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    else
        print_warning "Oh My Zsh already installed"
    fi
    
    # Install popular plugins
    install_zsh_plugins
    
    # Set Zsh as default shell
    if [ "$SHELL" != "/usr/bin/zsh" ] && [ "$SHELL" != "/bin/zsh" ]; then
        print_status "Setting Zsh as default shell..."
        sudo chsh -s $(which zsh) $USER
        print_warning "You'll need to log out and back in for the shell change to take effect"
    fi
    
    print_success "Shell configuration complete"
    
    log_script_end "configure-shell.sh" 0
}

install_zsh_plugins() {
    local ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
    
    # zsh-autosuggestions
    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
        print_status "Installing zsh-autosuggestions..."
        git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
    fi
    
    # zsh-syntax-highlighting
    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
        print_status "Installing zsh-syntax-highlighting..."
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
    fi
    
    # powerlevel10k theme
    if [ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]; then
        print_status "Installing Powerlevel10k theme..."
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"
    fi
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    configure_shell
fi