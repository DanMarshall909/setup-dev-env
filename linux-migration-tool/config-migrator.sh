#!/bin/bash

# Configuration Migration Tool
# Migrates specific development configurations from Windows export

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

EXPORT_DIR="${1:-}"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

log() {
    echo -e "${GREEN}[CONFIG]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Migrate Git configuration
migrate_git_config() {
    log "Setting up Git configuration..."
    
    # Set recommended Git configurations for development
    git config --global init.defaultBranch main
    git config --global pull.rebase false
    git config --global core.autocrlf input
    git config --global core.editor "code --wait"
    git config --global merge.tool "code"
    git config --global mergetool.code.cmd 'code --wait --merge $REMOTE $LOCAL $BASE $MERGED'
    git config --global diff.tool "code"
    git config --global difftool.code.cmd 'code --wait --diff $LOCAL $REMOTE'
    
    # Useful aliases
    git config --global alias.st status
    git config --global alias.co checkout
    git config --global alias.br branch
    git config --global alias.ci commit
    git config --global alias.lg "log --oneline --graph --decorate"
    git config --global alias.last "log -1 HEAD"
    git config --global alias.unstage "reset HEAD --"
    
    log "Git configuration completed"
}

# Setup development directories and environment
setup_dev_environment() {
    log "Setting up development environment structure..."
    
    # Create development directories
    mkdir -p ~/code/{personal,work,experiments}
    mkdir -p ~/scripts
    mkdir -p ~/.local/bin
    
    # Add ~/.local/bin to PATH if not already there
    if ! grep -q "~/.local/bin" ~/.bashrc; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    fi
    
    log "Development directories created"
}

# Configure SSH for development
setup_ssh_config() {
    log "Setting up SSH configuration..."
    
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    
    # Create SSH config with common settings
    if [[ ! -f ~/.ssh/config ]]; then
        cat > ~/.ssh/config <<EOF
# SSH Configuration for Development

# GitHub
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519

# Default settings
Host *
    AddKeysToAgent yes
    UseKeychain yes
    ServerAliveInterval 60
    ServerAliveCountMax 3
EOF
        chmod 600 ~/.ssh/config
        log "SSH config created at ~/.ssh/config"
    else
        log_warning "SSH config already exists"
    fi
    
    # Check for SSH keys
    if [[ ! -f ~/.ssh/id_ed25519 ]] && [[ ! -f ~/.ssh/id_rsa ]]; then
        log_warning "No SSH keys found. Generate with: ssh-keygen -t ed25519 -C 'your.email@example.com'"
    fi
}

# Configure shell environment
configure_shell() {
    log "Configuring shell environment..."
    
    # Add development-friendly bash configurations
    cat >> ~/.bashrc <<'EOF'

# Development Environment Configurations
# =====================================

# Enhanced command prompt with git branch
parse_git_branch() {
    git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/'
}
export PS1="\u@\h:\[\033[32m\]\w\[\033[33m\]\$(parse_git_branch)\[\033[00m\]$ "

# Development aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gco='git checkout'
alias gbr='git branch'
alias glog='git log --oneline --graph --decorate'

# Development shortcuts
alias ccode='cd ~/code'
alias mkcd='mkdir -p "$1" && cd "$1"'
alias weather='curl wttr.in'
alias ports='netstat -tulanp'

# Docker shortcuts
alias dps='docker ps'
alias dpa='docker ps -a'
alias di='docker images'
alias dex='docker exec -it'

# .NET development
alias dr='dotnet run'
alias dt='dotnet test'
alias db='dotnet build'
alias dc='dotnet clean'

# Node.js development  
alias ni='npm install'
alias ns='npm start'
alias nt='npm test'
alias nrd='npm run dev'

# Python development
alias py='python3'
alias pip='pip3'
alias venv='python3 -m venv'

# Go development
alias gor='go run'
alias gob='go build'
alias got='go test'
alias gom='go mod'

# History settings
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoredups:erasedups
shopt -s histappend

# Make less more friendly for non-text input files
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

EOF

    log "Shell configuration added to ~/.bashrc"
}

# Configure VS Code settings
configure_vscode() {
    log "Configuring VS Code settings..."
    
    local vscode_config_dir="$HOME/.config/Code/User"
    mkdir -p "$vscode_config_dir"
    
    # Create settings.json with development-friendly defaults
    cat > "$vscode_config_dir/settings.json" <<'EOF'
{
    "workbench.startupEditor": "welcomePage",
    "editor.fontSize": 14,
    "editor.fontFamily": "'Fira Code', 'Cascadia Code', 'JetBrains Mono', 'Source Code Pro', monospace",
    "editor.fontLigatures": true,
    "editor.tabSize": 4,
    "editor.insertSpaces": true,
    "editor.detectIndentation": true,
    "editor.trimAutoWhitespace": true,
    "editor.formatOnSave": true,
    "editor.codeActionsOnSave": {
        "source.organizeImports": true
    },
    "editor.rulers": [80, 120],
    "editor.minimap.enabled": true,
    "editor.bracketPairColorization.enabled": true,
    "editor.guides.bracketPairs": "active",
    
    "files.autoSave": "afterDelay",
    "files.autoSaveDelay": 1000,
    "files.trimTrailingWhitespace": true,
    "files.insertFinalNewline": true,
    "files.exclude": {
        "**/node_modules": true,
        "**/bin": true,
        "**/obj": true,
        "**/.git": true,
        "**/.DS_Store": true
    },
    
    "terminal.integrated.defaultProfile.linux": "bash",
    "terminal.integrated.fontSize": 13,
    "terminal.integrated.copyOnSelection": true,
    
    "git.enableSmartCommit": true,
    "git.confirmSync": false,
    "git.autofetch": true,
    
    "explorer.confirmDelete": false,
    "explorer.confirmDragAndDrop": false,
    
    "workbench.colorTheme": "Default Dark+",
    "workbench.iconTheme": "vs-seti",
    
    "extensions.autoUpdate": true,
    "update.mode": "start",
    
    "dotnet.preferOmnisharp": false,
    "omnisharp.enableAsyncCompletion": true,
    
    "python.defaultInterpreterPath": "/usr/bin/python3",
    "python.formatting.provider": "black",
    "python.linting.enabled": true,
    "python.linting.pylintEnabled": true,
    
    "go.toolsManagement.autoUpdate": true,
    "go.useLanguageServer": true,
    
    "typescript.updateImportsOnFileMove.enabled": "always",
    "javascript.updateImportsOnFileMove.enabled": "always"
}
EOF

    log "VS Code settings configured"
}

# Configure development tools
configure_dev_tools() {
    log "Configuring development tools..."
    
    # Configure npm global prefix to avoid permission issues
    mkdir -p ~/.npm-global
    npm config set prefix '~/.npm-global'
    
    # Add npm global bin to PATH
    if ! grep -q "~/.npm-global/bin" ~/.bashrc; then
        echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.bashrc
    fi
    
    # Configure pip to install to user directory by default
    mkdir -p ~/.config/pip
    cat > ~/.config/pip/pip.conf <<EOF
[install]
user = true
EOF
    
    log "Development tools configured"
}

# Create useful development scripts
create_dev_scripts() {
    log "Creating development utility scripts..."
    
    mkdir -p ~/.local/bin
    
    # Script to quickly start a new project
    cat > ~/.local/bin/new-project <<'EOF'
#!/bin/bash
# Quick project setup script

PROJECT_NAME="$1"
PROJECT_TYPE="${2:-generic}"

if [[ -z "$PROJECT_NAME" ]]; then
    echo "Usage: new-project <name> [type]"
    echo "Types: dotnet, node, python, go, generic"
    exit 1
fi

cd ~/code/personal
mkdir -p "$PROJECT_NAME"
cd "$PROJECT_NAME"

case "$PROJECT_TYPE" in
    dotnet)
        dotnet new sln -n "$PROJECT_NAME"
        echo "# $PROJECT_NAME" > README.md
        git init
        curl -s https://raw.githubusercontent.com/github/gitignore/main/VisualStudio.gitignore > .gitignore
        ;;
    node)
        npm init -y
        echo "# $PROJECT_NAME" > README.md
        git init
        curl -s https://raw.githubusercontent.com/github/gitignore/main/Node.gitignore > .gitignore
        ;;
    python)
        python3 -m venv venv
        echo "# $PROJECT_NAME" > README.md
        git init
        curl -s https://raw.githubusercontent.com/github/gitignore/main/Python.gitignore > .gitignore
        ;;
    go)
        go mod init "$PROJECT_NAME"
        echo "# $PROJECT_NAME" > README.md
        git init
        curl -s https://raw.githubusercontent.com/github/gitignore/main/Go.gitignore > .gitignore
        ;;
    *)
        echo "# $PROJECT_NAME" > README.md
        git init
        ;;
esac

code .
echo "Project $PROJECT_NAME created and opened in VS Code"
EOF

    chmod +x ~/.local/bin/new-project
    
    # Script to update all development tools
    cat > ~/.local/bin/update-dev-tools <<'EOF'
#!/bin/bash
# Update all development tools

echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y

echo "Updating Node.js packages..."
npm update -g

echo "Updating Python packages..."
pip3 list --outdated --format=freeze | grep -v '^\-e' | cut -d = -f 1 | xargs -n1 pip3 install -U

echo "Updating Go tools..."
go install -a std

echo "Updating VS Code extensions..."
code --update-extensions

echo "All development tools updated!"
EOF

    chmod +x ~/.local/bin/update-dev-tools
    
    log "Development scripts created in ~/.local/bin"
}

# Import environment variables that matter for development
import_environment() {
    log "Setting up development environment variables..."
    
    if [[ -f "$EXPORT_DIR/environment-variables.csv" ]]; then
        # Only import specific development-related environment variables
        local dev_vars=(
            "JAVA_HOME"
            "GRADLE_HOME"
            "MAVEN_HOME"
            "ANDROID_HOME"
            "FLUTTER_HOME"
            "DOTNET_CLI_TELEMETRY_OPTOUT"
            "NODE_ENV"
        )
        
        for var in "${dev_vars[@]}"; do
            local value=$(grep "^$var," "$EXPORT_DIR/environment-variables.csv" 2>/dev/null | cut -d',' -f2 | tr -d '"')
            if [[ -n "$value" ]] && [[ "$value" != "NOVALUE" ]]; then
                echo "export $var=\"$value\"" >> ~/.bashrc
                log "Imported environment variable: $var"
            fi
        done
    else
        log_warning "Environment variables file not found"
    fi
}

# Main configuration function
main() {
    if [[ -z "$EXPORT_DIR" ]] || [[ ! -d "$EXPORT_DIR" ]]; then
        log_error "Usage: $0 /path/to/windows-export-directory"
        exit 1
    fi
    
    log "Starting configuration migration..."
    
    migrate_git_config
    setup_dev_environment
    setup_ssh_config
    configure_shell
    configure_vscode
    configure_dev_tools
    create_dev_scripts
    import_environment
    
    log "Configuration migration completed!"
    log "Please restart your terminal or run 'source ~/.bashrc' to apply changes"
}

main "$@"