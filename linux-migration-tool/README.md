# Linux Development Environment Migration Tool

Automated migration tool to set up a complete Linux development environment based on your Windows development setup export.

## Overview

This tool analyzes your Windows development environment export and automatically installs and configures equivalent Linux tools, focusing on development productivity and minimizing manual setup.

## Quick Start

1. **Copy your Windows export** to your Linux system
2. **Make scripts executable:**
   ```bash
   chmod +x migrate-to-linux.sh config-migrator.sh
   ```
3. **Run the migration:**
   ```bash
   ./migrate-to-linux.sh /path/to/windows-dev-setup-export
   ./config-migrator.sh /path/to/windows-dev-setup-export
   ```

## What Gets Installed

### Programming Languages & Runtimes
- **Python 3** with pip and venv
- **Go 1.24.4** (latest stable)
- **Node.js LTS** with npm
- **.NET SDK** (versions 6.0, 7.0, 8.0, 9.0)
- **Java** (OpenJDK 17 & 21)
- **PowerShell Core**

### Development Tools
- **Visual Studio Code** with your extensions
- **JetBrains Toolbox** (for Rider/IntelliJ installation)
- **Git** with enhanced configuration
- **Docker** & Docker Compose
- **Gradle**
- **GitHub CLI**

### Cloud & DevOps
- **AWS CLI v2**
- **Azure CLI**
- **Azure Data Studio**

### Database Tools
- **PostgreSQL 16**
- **Azure Data Studio**

### Version Control & Diff Tools
- **GitKraken**
- **Meld**
- **ripgrep**

### Productivity Tools
- **Terminator/Tilix** (terminal emulators)
- **CopyQ** (clipboard manager)
- **Ulauncher** (app launcher - PowerToys alternative)
- **Obsidian** (knowledge management)

## Configuration Migration

The `config-migrator.sh` script handles:

- **Git configuration** with useful aliases and VS Code integration
- **SSH setup** with common development configurations
- **Shell environment** with development-friendly aliases and prompt
- **VS Code settings** optimized for development
- **Development directories** (`~/code`, `~/scripts`)
- **Utility scripts** for project creation and tool updates

## Manual Steps Required

After running the migration tools:

1. **Log out and back in** for Docker group membership
2. **Configure Git identity:**
   ```bash
   git config --global user.name "Your Name"
   git config --global user.email "your.email@example.com"
   ```
3. **Generate SSH keys:**
   ```bash
   ssh-keygen -t ed25519 -C "your.email@example.com"
   ```
4. **Launch JetBrains Toolbox** to install Rider/IntelliJ IDEA
5. **Import your SSH/GPG keys** from your Windows backup

## VS Code Extensions

If your Windows export includes `vscode-extensions.txt`, all extensions will be automatically installed, including:
- Language support extensions
- Git tools (GitLens)
- Docker/Kubernetes tools
- Claude integration extensions
- MCP tools

## Development Workflow Features

### Enhanced Shell
- Git branch in prompt
- Comprehensive aliases for Git, Docker, .NET, Node.js, Python, Go
- Smart history management
- Development shortcuts

### Quick Project Creation
```bash
new-project my-app dotnet    # Creates .NET solution
new-project my-app node      # Creates Node.js project
new-project my-app python    # Creates Python project with venv
new-project my-app go        # Creates Go module
```

### Tool Updates
```bash
update-dev-tools             # Updates all development tools
```

## Directory Structure

```
~/
├── code/
│   ├── personal/           # Personal projects
│   ├── work/              # Work projects
│   └── experiments/       # Experimental code
├── scripts/               # Custom scripts
└── .local/bin/           # User binaries
```

## Supported Linux Distributions

- **Ubuntu 20.04+**
- **Pop!_OS 20.04+**
- **Debian 11+**

## Tool Compatibility

| Windows Tool | Linux Equivalent | Status |
|-------------|------------------|---------|
| Visual Studio 2022 | VS Code + .NET CLI / Rider | ✅ Full |
| Visual Studio Code | Visual Studio Code | ✅ Identical |
| JetBrains Tools | Same tools | ✅ Full |
| Docker Desktop | Docker CE | ✅ Better performance |
| PowerToys | Ulauncher + native tools | ✅ Good alternative |
| Windows Terminal | Terminator/Tilix | ✅ Full features |
| SQL Server Management Studio | Azure Data Studio | ✅ Cross-platform |

## Troubleshooting

### Docker Permission Issues
```bash
sudo usermod -aG docker $USER
# Log out and back in
```

### VS Code Extensions Fail
```bash
# Install manually if automated install fails
code --install-extension ms-dotnettools.csharp
```

### Node.js Permission Issues
```bash
# Already configured to use ~/.npm-global
npm config set prefix '~/.npm-global'
```

### Java Version Management
```bash
# Switch Java versions
sudo update-alternatives --config java
```

## Post-Migration Verification

Run this to verify your installation:
```bash
# Check versions
python3 --version
go version
node --version
dotnet --version
java -version

# Check tools
code --version
git --version
docker --version
```

## Contributing

To add support for additional tools or improve the migration process:

1. Update the tool mappings in `migrate-to-linux.sh`
2. Add configuration steps to `config-migrator.sh`
3. Update this README with the new capabilities

## Support

For issues or questions:
- Check the generated migration report
- Review installation logs in `~/migration-*.log`
- Verify tool compatibility in the HTML migration report