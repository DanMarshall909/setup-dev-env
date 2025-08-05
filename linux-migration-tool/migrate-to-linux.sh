#!/bin/bash

# Linux Development Environment Migration Tool
# Automates the setup of a Linux dev environment based on Windows export

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
EXPORT_DIR="${1:-}"
LOG_FILE="$HOME/migration-$(date +%Y%m%d-%H%M%S).log"

# Categories of tools to install
declare -A INSTALL_CATEGORIES=(
    ["essential"]=true
    ["languages"]=true
    ["databases"]=true
    ["containers"]=true
    ["cloud"]=true
    ["ide"]=true
    ["git"]=true
    ["utilities"]=true
)

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

log_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}" | tee -a "$LOG_FILE"
}

# Check if running on supported system
check_system() {
    log_section "System Check"
    
    if [[ ! -f /etc/os-release ]]; then
        log_error "Cannot detect OS. This script requires Ubuntu/Pop!_OS/Debian."
        exit 1
    fi
    
    . /etc/os-release
    log "Detected OS: $NAME $VERSION"
    
    if [[ ! "$ID" =~ ^(ubuntu|pop|debian)$ ]]; then
        log_error "This script is designed for Ubuntu/Pop!_OS/Debian systems."
        exit 1
    fi
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root"
        exit 1
    fi
}

# Update system packages
update_system() {
    log_section "System Update"
    log "Updating package lists..."
    sudo apt update
    
    log "Upgrading existing packages..."
    sudo apt upgrade -y
}

# Install essential build tools
install_essentials() {
    log_section "Essential Build Tools"
    
    local essentials=(
        build-essential
        curl
        wget
        software-properties-common
        apt-transport-https
        ca-certificates
        gnupg
        lsb-release
        git
        vim
        nano
        htop
        jq
        tree
        unzip
        zip
        p7zip-full
        p7zip-rar
    )
    
    log "Installing essential packages..."
    sudo apt install -y "${essentials[@]}"
}

# Install programming languages
install_languages() {
    log_section "Programming Languages"
    
    # Python
    log "Installing Python and pip..."
    sudo apt install -y python3 python3-pip python3-venv python3-dev
    pip3 install --user --upgrade pip
    
    # Go
    log "Installing Go..."
    local go_version="1.24.4"
    if ! command -v go &> /dev/null || [[ $(go version | awk '{print $3}' | sed 's/go//') != "$go_version" ]]; then
        wget -q "https://go.dev/dl/go${go_version}.linux-amd64.tar.gz"
        sudo rm -rf /usr/local/go
        sudo tar -C /usr/local -xzf "go${go_version}.linux-amd64.tar.gz"
        rm "go${go_version}.linux-amd64.tar.gz"
        
        # Add to PATH if not already there
        if ! grep -q "/usr/local/go/bin" ~/.bashrc; then
            echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
        fi
    fi
    
    # Node.js via NodeSource
    log "Installing Node.js LTS..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt install -y nodejs
    
    # .NET SDK
    log "Installing .NET SDK..."
    # Add Microsoft package repository
    wget https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
    sudo dpkg -i packages-microsoft-prod.deb
    rm packages-microsoft-prod.deb
    
    # Install .NET SDKs
    sudo apt update
    sudo apt install -y dotnet-sdk-6.0 dotnet-sdk-7.0 dotnet-sdk-8.0 dotnet-sdk-9.0
    
    # Java
    log "Installing Java (OpenJDK)..."
    sudo apt install -y openjdk-17-jdk openjdk-21-jdk
    
    # Set Java 21 as default
    sudo update-alternatives --set java /usr/lib/jvm/java-21-openjdk-amd64/bin/java
    sudo update-alternatives --set javac /usr/lib/jvm/java-21-openjdk-amd64/bin/javac
    
    # Gradle
    log "Installing Gradle..."
    local gradle_version="8.13"
    wget -q "https://services.gradle.org/distributions/gradle-${gradle_version}-bin.zip"
    sudo unzip -q -d /opt/gradle "gradle-${gradle_version}-bin.zip"
    sudo ln -sfn "/opt/gradle/gradle-${gradle_version}" /opt/gradle/latest
    rm "gradle-${gradle_version}-bin.zip"
    
    # Add to PATH if not already there
    if ! grep -q "/opt/gradle/latest/bin" ~/.bashrc; then
        echo 'export PATH=$PATH:/opt/gradle/latest/bin' >> ~/.bashrc
    fi
    
    # PowerShell Core
    log "Installing PowerShell Core..."
    sudo apt-get install -y powershell
}

# Install databases
install_databases() {
    log_section "Database Tools"
    
    # PostgreSQL
    log "Installing PostgreSQL 16..."
    sudo sh -c 'echo "deb https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
    sudo apt update
    sudo apt install -y postgresql-16 postgresql-client-16
    
    # Azure Data Studio
    log "Installing Azure Data Studio..."
    wget -q https://azuredatastudio-update.azurewebsites.net/latest/linux-x64/stable -O azuredatastudio.deb
    sudo dpkg -i azuredatastudio.deb || sudo apt-get install -f -y
    rm azuredatastudio.deb
}

# Install containerization tools
install_containers() {
    log_section "Containerization Tools"
    
    # Docker
    log "Installing Docker..."
    # Remove old versions
    sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Add Docker's official GPG key
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Set up repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Add user to docker group
    sudo usermod -aG docker $USER
    log_warning "You'll need to log out and back in for docker group membership to take effect"
    
    # VirtualBox
    log "Installing VirtualBox..."
    sudo apt install -y virtualbox virtualbox-ext-pack
}

# Install cloud tools
install_cloud_tools() {
    log_section "Cloud & DevOps Tools"
    
    # AWS CLI
    log "Installing AWS CLI v2..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -q awscliv2.zip
    sudo ./aws/install
    rm -rf awscliv2.zip aws/
    
    # Azure CLI
    log "Installing Azure CLI..."
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
    
    # GitHub CLI
    log "Installing GitHub CLI..."
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt update
    sudo apt install -y gh
}

# Install IDEs and editors
install_ides() {
    log_section "IDEs and Editors"
    
    # VS Code
    log "Installing Visual Studio Code..."
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
    sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
    sudo apt update
    sudo apt install -y code
    
    # JetBrains Toolbox
    log "Downloading JetBrains Toolbox..."
    local toolbox_url=$(curl -s 'https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release' | jq -r '.TBA[0].downloads.linux.link')
    wget -q "$toolbox_url" -O jetbrains-toolbox.tar.gz
    tar -xzf jetbrains-toolbox.tar.gz
    
    # Find the extracted directory and move the binary
    local toolbox_dir=$(find . -maxdepth 1 -type d -name "jetbrains-toolbox-*" | head -n1)
    if [[ -n "$toolbox_dir" ]]; then
        sudo mv "$toolbox_dir/jetbrains-toolbox" /opt/
        rm -rf "$toolbox_dir" jetbrains-toolbox.tar.gz
        
        # Create desktop entry
        cat > ~/.local/share/applications/jetbrains-toolbox.desktop <<EOF
[Desktop Entry]
Type=Application
Name=JetBrains Toolbox
Icon=/opt/jetbrains-toolbox/toolbox.svg
Exec=/opt/jetbrains-toolbox
Categories=Development;IDE;
Terminal=false
StartupWMClass=jetbrains-toolbox
EOF
        log "JetBrains Toolbox installed. Launch it to install Rider and IntelliJ IDEA."
    fi
    
    # Install Cursor if available
    log "Checking for Cursor editor..."
    # Note: Cursor installation method may vary - check their official site
}

# Install Git tools
install_git_tools() {
    log_section "Git and Version Control Tools"
    
    # GitKraken
    log "Installing GitKraken..."
    wget -q https://release.gitkraken.com/linux/gitkraken-amd64.deb
    sudo dpkg -i gitkraken-amd64.deb || sudo apt-get install -f -y
    rm gitkraken-amd64.deb
    
    # Meld
    log "Installing Meld..."
    sudo apt install -y meld
    
    # ripgrep
    log "Installing ripgrep..."
    sudo apt install -y ripgrep
}

# Install development utilities
install_utilities() {
    log_section "Development Utilities"
    
    # Install various utilities
    local utils=(
        terminator      # Terminal emulator
        tilix          # Another terminal option
        copyq          # Clipboard manager
        ulauncher      # Application launcher (PowerToys alternative)
        httpie         # HTTP client
        direnv         # Environment variable management
        tmux           # Terminal multiplexer
        fzf            # Fuzzy finder
    )
    
    log "Installing development utilities..."
    sudo apt install -y "${utils[@]}"
    
    # Install Obsidian
    log "Installing Obsidian..."
    wget -q https://github.com/obsidianmd/obsidian-releases/releases/latest/download/obsidian_1.4.16_amd64.deb -O obsidian.deb
    sudo dpkg -i obsidian.deb || sudo apt-get install -f -y
    rm obsidian.deb
}

# Import VS Code extensions
import_vscode_extensions() {
    log_section "VS Code Extensions"
    
    if [[ -f "$EXPORT_DIR/vscode-extensions.txt" ]]; then
        log "Installing VS Code extensions..."
        while IFS= read -r extension; do
            code --install-extension "$extension" || log_warning "Failed to install: $extension"
        done < "$EXPORT_DIR/vscode-extensions.txt"
    else
        log_warning "VS Code extensions list not found in export"
    fi
}

# Setup development directories
setup_directories() {
    log_section "Development Environment Setup"
    
    # Create common development directories
    mkdir -p ~/code
    mkdir -p ~/scripts
    mkdir -p ~/.config
    
    log "Created development directories"
}

# Configure Git
configure_git() {
    log_section "Git Configuration"
    
    # Check if git config exists
    if [[ -z "$(git config --global user.name)" ]]; then
        log_warning "Git user.name not configured. Run: git config --global user.name 'Your Name'"
    fi
    
    if [[ -z "$(git config --global user.email)" ]]; then
        log_warning "Git user.email not configured. Run: git config --global user.email 'your.email@example.com'"
    fi
    
    # Set useful Git aliases
    git config --global alias.co checkout
    git config --global alias.br branch
    git config --global alias.ci commit
    git config --global alias.st status
    git config --global alias.lg "log --oneline --graph --decorate"
    
    log "Git aliases configured"
}

# Generate summary report
generate_report() {
    log_section "Migration Summary"
    
    local report_file="$HOME/migration-report-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "Linux Development Environment Migration Report"
        echo "============================================="
        echo "Generated: $(date)"
        echo ""
        echo "Installed Components:"
        echo ""
        
        # Check installed tools
        echo "Programming Languages:"
        command -v python3 &>/dev/null && echo "  ✓ Python $(python3 --version 2>&1 | awk '{print $2}')"
        command -v go &>/dev/null && echo "  ✓ Go $(go version | awk '{print $3}')"
        command -v node &>/dev/null && echo "  ✓ Node.js $(node --version)"
        command -v dotnet &>/dev/null && echo "  ✓ .NET $(dotnet --version)"
        command -v java &>/dev/null && echo "  ✓ Java $(java -version 2>&1 | head -n1 | awk -F'"' '{print $2}')"
        
        echo ""
        echo "Development Tools:"
        command -v code &>/dev/null && echo "  ✓ Visual Studio Code"
        command -v docker &>/dev/null && echo "  ✓ Docker"
        command -v git &>/dev/null && echo "  ✓ Git $(git --version | awk '{print $3}')"
        command -v gh &>/dev/null && echo "  ✓ GitHub CLI"
        command -v aws &>/dev/null && echo "  ✓ AWS CLI"
        command -v az &>/dev/null && echo "  ✓ Azure CLI"
        
        echo ""
        echo "Next Steps:"
        echo "  1. Log out and back in for Docker group membership"
        echo "  2. Launch JetBrains Toolbox to install Rider/IntelliJ"
        echo "  3. Configure Git with your user details"
        echo "  4. Import your SSH keys and GPG keys"
        echo "  5. Clone your repositories to ~/code"
        
    } | tee "$report_file"
    
    log "\nFull report saved to: $report_file"
    log "Installation log saved to: $LOG_FILE"
}

# Main installation flow
main() {
    log "Starting Linux Development Environment Migration"
    log "==============================================="
    
    # Check for export directory
    if [[ -z "$EXPORT_DIR" ]] || [[ ! -d "$EXPORT_DIR" ]]; then
        log_error "Usage: $0 /path/to/windows-export-directory"
        exit 1
    fi
    
    # Run installation steps
    check_system
    update_system
    install_essentials
    
    # Install categories based on settings
    [[ "${INSTALL_CATEGORIES[languages]}" == true ]] && install_languages
    [[ "${INSTALL_CATEGORIES[databases]}" == true ]] && install_databases
    [[ "${INSTALL_CATEGORIES[containers]}" == true ]] && install_containers
    [[ "${INSTALL_CATEGORIES[cloud]}" == true ]] && install_cloud_tools
    [[ "${INSTALL_CATEGORIES[ide]}" == true ]] && install_ides
    [[ "${INSTALL_CATEGORIES[git]}" == true ]] && install_git_tools
    [[ "${INSTALL_CATEGORIES[utilities]}" == true ]] && install_utilities
    
    # Post-installation tasks
    import_vscode_extensions
    setup_directories
    configure_git
    
    # Generate summary
    generate_report
    
    log "\n${GREEN}Migration completed successfully!${NC}"
    log "Please review the report and complete the manual steps listed."
}

# Run main function
main "$@"