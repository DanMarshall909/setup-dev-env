# Module Framework Documentation

## Overview

The Module Framework extracts common patterns from module installation scripts, reducing boilerplate and ensuring consistency across all modules.

## Benefits

✅ **Reduced Boilerplate**: Standard patterns extracted into reusable functions  
✅ **Consistent Structure**: All modules follow the same flow and patterns  
✅ **Dry-Run Support**: Built-in dry-run functionality for all operations  
✅ **Error Handling**: Standardized error handling and logging  
✅ **Easy Creation**: Template-based module generation  

## Quick Start

### Create a New Module

```bash
# Generate a new module from template
./scripts/create-module.sh docker "Docker" "Container platform" "containerization"

# Edit the generated files
vim modules/docker/install.sh     # Implement installation logic
vim modules/docker/module.json    # Update metadata

# Test the module
./setup.sh docker --dry-run       # Preview installation
./setup.sh docker                 # Install module
```

## Framework Functions

### Core Module Functions

```bash
# Initialize module with standard setup
init_module "module-name" "Display Name"

# Complete module with cleanup
complete_module [exit_code]

# Standard installation flow
run_standard_install_flow \
    "check_function" \
    "install_function" \
    "verify_function" \
    "info_function"
```

### Installation Helpers

```bash
# Install apt packages with dry-run support
install_package_with_dry_run "package-name" "Display Name"

# Install snap packages
install_snap_package "package" "--classic" "Display Name"

# Install npm global packages
install_npm_global "package-name" "Display Name"

# Download and install files
download_and_install "url" "temp-name" "install-command" "description"

# Add apt repositories
add_apt_repository "key-url" "repo-line" "list-file" "description"
```

### Verification Helpers

```bash
# Verify command is available
verify_command_available "command" "Display Name"

# Check if already installed
handle_already_installed "check_function" "verify_function"
```

### Information Display

```bash
# Show post-installation information
show_post_install_info "Module Name" "next_steps" "docs_url" "config_notes"
```

## Module Structure

Each module has a standardized structure:

```
modules/
├── module-name/
│   ├── module.json     # Metadata and configuration
│   ├── install.sh      # Installation script
│   └── status.sh       # Status checking script
```

### module.json Schema

```json
{
  "name": "module-name",
  "description": "Brief description",
  "version": "1.0.0",
  "category": "tool|ide|language|containerization",
  "tags": ["tag1", "tag2"],
  "dependencies": ["other-module"],
  "conflicts": ["conflicting-module"],
  "provides": ["command1", "command2"],
  "platforms": ["ubuntu", "debian"],
  "min_os_version": "18.04",
  "check_installed": "command to check if installed",
  "get_version": "command to get version",
  "size_estimate": "100MB",
  "install_time_estimate": "2-5 minutes",
  "post_install_actions": [
    "Step 1",
    "Step 2"
  ],
  "documentation": {
    "homepage": "https://example.com",
    "docs": "https://example.com/docs",
    "config_files": ["~/.config/tool/"]
  }
}
```

## Installation Script Template

```bash
#!/bin/bash

# Module installation script using framework

# Source module framework
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/../../scripts/module-framework.sh"

# Check if installed
check_my_module_installed() {
    command -v my_command &>/dev/null
}

# Install the module
install_my_module() {
    # Use framework helpers
    install_package_with_dry_run "my-package" "My Package"
    
    # Or implement custom logic with dry-run support
    if is_dry_run; then
        print_would_execute "custom installation command"
        return 0
    fi
    
    # Actual installation commands
    # ...
}

# Verify installation
verify_my_module_installation() {
    verify_command_available "my_command" "My Command"
}

# Show information
show_my_module_info() {
    local next_steps="1. Configure settings
2. Run initial setup"
    
    show_post_install_info "My Module" "$next_steps" "https://docs.example.com"
}

# Main module execution
install_my_module_module() {
    init_module "my-module" "My Module"
    
    run_standard_install_flow \
        "check_my_module_installed" \
        "install_my_module" \
        "verify_my_module_installation" \
        "show_my_module_info"
}

# Execute
install_my_module_module
```

## Status Script Template

```bash
#!/bin/bash

# Module status script

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/../../scripts/common.sh"

check_my_module_status() {
    local command="$1"
    
    case "$command" in
        "installed")
            command -v my_command &>/dev/null
            ;;
        "summary")
            if command -v my_command &>/dev/null; then
                local version=$(my_command --version | head -n1)
                echo "✅ My Module $version"
            else
                echo "❌ My Module not installed"
            fi
            ;;
        "status")
            cat << EOF
{
  "name": "my-module",
  "installed": $(command -v my_command &>/dev/null && echo true || echo false),
  "version": "$(my_command --version 2>/dev/null | head -n1 || echo 'unknown')",
  "command_available": $(command -v my_command &>/dev/null && echo true || echo false)
}
EOF
            ;;
    esac
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    check_my_module_status "${1:-summary}"
fi
```

## Migration from Legacy Scripts

To convert existing scripts to use the framework:

1. **Identify patterns**: Look for common installation patterns
2. **Extract functions**: Break down into check/install/verify/info functions
3. **Use framework helpers**: Replace manual patterns with framework functions
4. **Add dry-run support**: Use `is_dry_run()` checks and `print_would_*` functions
5. **Test thoroughly**: Verify both dry-run and actual installation work

## Example: Before and After

### Before (Legacy Script)
```bash
#!/bin/bash
# 50+ lines of boilerplate and installation logic mixed together
```

### After (Framework-based)
```bash
#!/bin/bash
# 30 lines focused only on module-specific logic
# Framework handles all the common patterns
```

The framework reduces typical module scripts from 50+ lines to ~30 lines while adding more functionality and consistency.

## Development Workflow

1. **Generate module**: `./scripts/create-module.sh name "Display Name"`
2. **Implement logic**: Edit `install.sh` with module-specific functions
3. **Update metadata**: Edit `module.json` with accurate information
4. **Test dry-run**: `./setup.sh module-name --dry-run`
5. **Test installation**: `./setup.sh module-name`
6. **Verify status**: `./setup.sh info module-name`
7. **Commit changes**: Add to version control

This framework makes module development faster, more consistent, and less error-prone.