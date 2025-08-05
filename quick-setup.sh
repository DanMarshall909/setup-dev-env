#!/bin/bash

# Quick setup script - can be run with:
# curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/setup-dev-env/main/quick-setup.sh | bash

set -e

echo "Linux Development Environment - Quick Setup"
echo "=========================================="

# Clone the repository
SETUP_DIR="$HOME/setup-dev-env"

if [ -d "$SETUP_DIR" ]; then
    echo "Setup directory already exists at $SETUP_DIR"
    read -p "Do you want to remove it and start fresh? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$SETUP_DIR"
    else
        echo "Please remove or rename $SETUP_DIR and try again."
        exit 1
    fi
fi

# Install git if not present
if ! command -v git &> /dev/null; then
    echo "Installing Git..."
    sudo apt-get update
    sudo apt-get install -y git
fi

# Clone repository
echo "Cloning setup repository..."
git clone https://github.com/YOUR_USERNAME/setup-dev-env.git "$SETUP_DIR"
cd "$SETUP_DIR"

# Make scripts executable
chmod +x setup.sh scripts/*.sh

# Check for 1Password CLI
if ! command -v op &> /dev/null; then
    echo ""
    echo "1Password CLI not detected."
    echo "Would you like to install it now? (recommended for automatic setup)"
    read -p "Install 1Password CLI? (Y/n) " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        ./scripts/security.sh install_password_manager 1password
        echo ""
        echo "Please sign in to 1Password CLI:"
        eval $(op signin)
    fi
fi

# Run the automated setup
echo ""
echo "Ready to run automated setup!"
echo "This will install and configure:"
echo "  - Git and GitHub CLI"
echo "  - Node.js and TypeScript tools"
echo "  - .NET SDK and C# tools"
echo "  - JetBrains Rider"
echo "  - Docker"
echo "  - Zsh with Oh My Zsh"
echo "  - Common development tools"
echo ""

# Run with appropriate flags
if [ -n "$SETUP_FORCE_YES" ]; then
    ./scripts/run-all.sh --force
else
    ./scripts/run-all.sh
fi

# Show completion message
if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Setup completed successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Restart your terminal or run: source ~/.$(basename $SHELL)rc"
    echo "2. Check the setup summary in: ~/.local/share/setup-dev-env/logs/"
    echo "3. Start coding! 🚀"
else
    echo ""
    echo "❌ Setup encountered errors. Check the logs for details:"
    echo "   ~/.local/share/setup-dev-env/logs/latest.log"
fi