# Linux Development Environment Setup

A comprehensive, automated setup script for Linux development environments with TypeScript and C# support.

## 🚀 Quick Start (One-liner)

```bash
curl -fsSL https://raw.githubusercontent.com/danmarshall909/setup-dev-env/main/setup.sh | bash
```

**Preview what would be installed (dry-run):**
```bash
curl -fsSL https://raw.githubusercontent.com/danmarshall909/setup-dev-env/main/setup.sh | bash -s -- --dry-run
```

## 📋 What Gets Installed

- **Git & GitHub CLI** - Version control and GitHub integration
- **Node.js & TypeScript** - JavaScript/TypeScript development
- **.NET SDK** - C# development
- **JetBrains Rider** - IDE for C# and web development
- **Docker** - Containerization
- **Zsh + Oh My Zsh** - Enhanced shell experience
- **VS Code** - Lightweight code editor with extensions
- **Development Tools** - curl, wget, htop, ripgrep, bat, jq, and more

## 🔍 Dry-Run Mode

Preview what would be installed without making any changes to your system:

```bash
# Preview before installation
./setup.sh node --dry-run            # Show what Node.js installation would do
./setup.sh all --dry-run             # Preview complete setup
./setup.sh --dry-run                 # Interactive mode with dry-run

# Combines with other flags
./setup.sh node --force --dry-run    # Show forced reinstall plan
```

**Dry-run shows:**
- Installation order and dependencies
- Commands that would be executed
- Packages that would be installed
- Configuration changes that would be made
- Network calls that would be performed

## 🔐 Security Features

- **Password Manager Integration** - Supports 1Password, Bitwarden, LastPass, KeePass, and pass
- **Secure Secret Management** - No hardcoded credentials
- **Automated Authentication** - GitHub, npm, Docker Hub tokens from password manager

## 📊 Logging & Monitoring

- **Comprehensive Logging** - All operations logged with timestamps
- **Log Rotation** - Automatic cleanup of old logs
- **Setup Summary** - Detailed report of what was installed
- **Error Tracking** - Detailed error reporting and recovery

## 🛠️ Prerequisites

1. **Ubuntu** (20.04 or newer recommended)
2. **1Password CLI** (optional but recommended) - Install with:
   ```bash
   ./scripts/security.sh install_password_manager 1password
   op signin
   ```
3. **Internet connection**

## 📁 Configuration

All settings are stored in JSON files under `configs/`:

### `configs/settings.json`
Main configuration file containing:
- Package names and repositories
- Menu options and CLI arguments  
- Logging configuration
- Security settings

### `configs/git-config.json`
Git user configuration:
```json
{
  "user": {
    "name": "Your Name",
    "email": "your.email@example.com"
  }
}
```

## 🎯 Usage Options

### 1. Interactive Setup (Recommended)
```bash
# Clone and run interactively
git clone https://github.com/danmarshall909/setup-dev-env.git
cd setup-dev-env
./setup.sh
```

### 2. Dry-Run Mode (Preview Changes)
```bash
# See what would be installed without making changes
./setup.sh --dry-run                 # Interactive dry-run
./setup.sh all --dry-run             # Preview full installation
./setup.sh node --dry-run            # Preview specific module
```

### 3. Individual Modules
```bash
# Install specific modules
./setup.sh git        # Git and GitHub CLI
./setup.sh node       # Node.js and TypeScript
./setup.sh claude     # Claude CLI (requires node)
```

### 4. Module Management
```bash
# List available modules
./setup.sh list

# Show module information
./setup.sh info node

# Show dependency tree
./setup.sh tree claude
```

### 5. Fully Automated Setup
```bash
# Install everything automatically
./setup.sh all --force
```

### 4. With Environment Variables
```bash
# Skip confirmations and continue on errors
SETUP_FORCE_YES=1 SETUP_CONTINUE_ON_ERROR=1 ./scripts/run-all.sh
```

## 🔑 Password Manager Setup

### 1Password
```bash
# Store secrets in 1Password with these paths:
# GitHub/Personal Access Token
# npm/Access Token  
# NuGet/API Key
# Docker Hub/Access Token
```

### Environment Variables (Fallback)
```bash
export GITHUB_TOKEN="ghp_xxxxxxxxxxxx"
export NPM_TOKEN="npm_xxxxxxxxxxxx"
export NUGET_API_KEY="oy2xxxxxxxxxxxx"
export DOCKER_HUB_TOKEN="dckr_pat_xxxxxxxxxxxx"
```

## 📝 Logs and Debugging

### View Logs
```bash
# Latest log
cat ~/.local/share/setup-dev-env/logs/latest.log

# All logs
ls ~/.local/share/setup-dev-env/logs/
```

### Generate Summary
```bash
./scripts/logging.sh create_log_summary
```

### Debug Mode
```bash
# Set debug logging
export SETUP_LOG_LEVEL=DEBUG
./scripts/run-all.sh
```

## 🏗️ Project Structure

```
setup-dev-env/
├── setup.sh                    # Main interactive setup
├── quick-setup.sh              # One-liner installer
├── configs/
│   ├── settings.json           # Main configuration
│   └── git-config.json         # Git user settings
└── scripts/
    ├── common.sh               # Shared functions
    ├── logging.sh              # Logging layer
    ├── security.sh             # Password manager integration
    ├── run-all.sh              # Automated setup
    ├── install-git.sh          # Git and GitHub CLI
    ├── install-node.sh         # Node.js and TypeScript
    ├── install-dotnet.sh       # .NET SDK
    ├── install-rider.sh        # JetBrains Rider
    ├── install-docker.sh       # Docker
    ├── configure-shell.sh      # Zsh configuration
    ├── install-dev-tools.sh    # Common tools
    └── configure-git-advanced.sh # Advanced Git setup
```

## 🎛️ Customization

### Adding New Tools
1. Edit `configs/settings.json` to add menu options
2. Create a new script in `scripts/`
3. Follow the existing pattern using `common.sh` functions

### Changing Settings
All settings are in JSON files - no need to edit shell scripts:
- Package names: `configs/settings.json`
- Messages and prompts: `configs/settings.json`
- Git configuration: `configs/git-config.json`
- Logging levels: `configs/settings.json`

## 🐛 Troubleshooting

### Common Issues

**Permission denied errors:**
```bash
chmod +x scripts/*.sh
```

**Package installation fails:**
```bash
sudo apt update
sudo apt upgrade
```

**Docker permission denied:**
```bash
sudo usermod -aG docker $USER
# Log out and back in
```

**1Password CLI not found:**
```bash
./scripts/security.sh install_password_manager 1password
eval $(op signin)
```

### Getting Help
- Check logs: `~/.local/share/setup-dev-env/logs/latest.log`
- Run with debug: `SETUP_LOG_LEVEL=DEBUG ./scripts/run-all.sh`
- Use continue-on-error: `./scripts/run-all.sh --continue-on-error`

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Add your changes following the existing patterns
4. Update `configs/settings.json` for any new configurations
5. Test the automated setup
6. Submit a pull request

## 📄 License

MIT License - feel free to use and modify for your own setup needs.