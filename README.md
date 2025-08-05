# Linux Development Environment Setup

A comprehensive, automated setup script for Linux development environments with TypeScript and C# support.

## 🚀 Quick Start (One-liner)

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/setup-dev-env/main/quick-setup.sh | bash
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

### 1. Fully Automated Setup
```bash
# Clone and run everything automatically
git clone https://github.com/YOUR_USERNAME/setup-dev-env.git
cd setup-dev-env
./scripts/run-all.sh --force
```

### 2. Interactive Setup
```bash
# Run with menu system
./setup.sh
```

### 3. Individual Components
```bash
# Install specific tools
./setup.sh git        # Git and GitHub CLI
./setup.sh node       # Node.js and TypeScript
./setup.sh dotnet     # .NET SDK
./setup.sh rider      # JetBrains Rider
./setup.sh docker     # Docker
./setup.sh shell      # Zsh configuration
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