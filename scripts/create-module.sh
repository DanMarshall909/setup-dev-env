#!/bin/bash

# Module Generator - Creates new modules from template

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Usage function
show_usage() {
    echo "Module Generator"
    echo "==============="
    echo ""
    echo "Usage: $0 <module-name> <display-name> [description] [category]"
    echo ""
    echo "Arguments:"
    echo "  module-name     Module directory name (lowercase, hyphens allowed)"
    echo "  display-name    Human-readable name for the module"
    echo "  description     Optional: Module description"
    echo "  category        Optional: Module category (default: tool)"
    echo ""
    echo "Examples:"
    echo "  $0 docker 'Docker' 'Container platform' 'containerization'"
    echo "  $0 dotnet '.NET SDK' 'Microsoft .NET development platform' 'language'"
    echo "  $0 vscode 'Visual Studio Code' 'Lightweight code editor' 'ide'"
    echo ""
}

# Validate module name
validate_module_name() {
    local name="$1"
    
    if [[ ! "$name" =~ ^[a-z][a-z0-9-]*$ ]]; then
        echo -e "${RED}Error: Module name must start with lowercase letter and contain only lowercase letters, numbers, and hyphens${NC}"
        return 1
    fi
    
    if [ -d "$ROOT_DIR/modules/$name" ]; then
        echo -e "${RED}Error: Module '$name' already exists${NC}"
        return 1
    fi
    
    return 0
}

# Create module structure
create_module_structure() {
    local module_name="$1"
    local display_name="$2"
    local description="${3:-A development tool}"
    local category="${4:-tool}"
    
    local module_dir="$ROOT_DIR/modules/$module_name"
    
    echo -e "${BLUE}Creating module structure...${NC}"
    mkdir -p "$module_dir"
    
    # Create module.json
    cat > "$module_dir/module.json" << EOF
{
  "name": "$module_name",
  "description": "$description",
  "version": "1.0.0",
  "category": "$category",
  "tags": ["$module_name", "$category"],
  "dependencies": [],
  "conflicts": [],
  "provides": ["$module_name"],
  "platforms": ["ubuntu", "debian"],
  "min_os_version": "18.04",
  "check_installed": "command -v $module_name >/dev/null",
  "get_version": "$module_name --version 2>/dev/null | head -n1 || echo 'unknown'",
  "size_estimate": "Unknown",
  "install_time_estimate": "2-5 minutes",
  "post_install_actions": [
    "Configure $display_name settings",
    "Verify installation"
  ],
  "documentation": {
    "homepage": "https://example.com",
    "docs": "https://example.com/docs",
    "config_files": [
      "~/.config/$module_name/"
    ]
  }
}
EOF
    
    # Create install.sh from template
    cp "$SCRIPT_DIR/module-template.sh" "$module_dir/install.sh"
    chmod +x "$module_dir/install.sh"
    
    # Replace template placeholders
    sed -i "s/MODULE_NAME=\"template\"/MODULE_NAME=\"$module_name\"/g" "$module_dir/install.sh"
    sed -i "s/MODULE_DISPLAY_NAME=\"Template Module\"/MODULE_DISPLAY_NAME=\"$display_name\"/g" "$module_dir/install.sh"
    sed -i "s/MODULE_NAME/$(echo "$module_name" | tr '-' '_')/g" "$module_dir/install.sh"
    
    # Fix the framework path (very important!)
    sed -i 's|../scripts/module-framework.sh|../../scripts/module-framework.sh|g' "$module_dir/install.sh"
    
    # Create status.sh
    cat > "$module_dir/status.sh" << EOF
#!/bin/bash

# $display_name module status script

# Source common functions
SCRIPT_DIR="\$( cd "\$( dirname "\${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "\$SCRIPT_DIR/../../scripts/common.sh"

check_$(echo "$module_name" | tr '-' '_')_status() {
    local command="\$1"
    
    case "\$command" in
        "installed")
            # Return 0 if installed, 1 if not
            command -v $module_name &>/dev/null
            ;;
        "summary")
            # Short status for module listing
            if command -v $module_name &>/dev/null; then
                local version=\$($module_name --version 2>/dev/null | head -n1 || echo "unknown")
                echo "✅ $display_name \$version"
            else
                echo "❌ $display_name not installed"
            fi
            ;;
        "status")
            # Detailed JSON status
            local installed=false
            local version="unknown"
            local command_available=false
            
            if command -v $module_name &>/dev/null; then
                installed=true
                command_available=true
                version=\$($module_name --version 2>/dev/null | head -n1 || echo "unknown")
            fi
            
            cat << EOFSTATUS
{
  "name": "$module_name",
  "installed": \$installed,
  "version": "\$version",
  "command_available": \$command_available
}
EOFSTATUS
            ;;
        *)
            echo "Usage: \$0 {installed|summary|status}"
            exit 1
            ;;
    esac
}

# Main execution
if [[ "\${BASH_SOURCE[0]}" == "\${0}" ]]; then
    check_$(echo "$module_name" | tr '-' '_')_status "\${1:-summary}"
fi
EOF
    
    chmod +x "$module_dir/status.sh"
    
    echo -e "${GREEN}Module '$module_name' created successfully!${NC}"
    echo ""
    echo "Module location: $module_dir"
    echo ""
    echo "Next steps:"
    echo "1. Edit $module_dir/install.sh - implement the installation logic"
    echo "2. Update $module_dir/module.json - add proper metadata"
    echo "3. Test with: ./setup.sh $module_name --dry-run"
    echo "4. Test installation: ./setup.sh $module_name"
    echo ""
}

# Main function
main() {
    if [ $# -lt 2 ]; then
        show_usage
        exit 1
    fi
    
    local module_name="$1"
    local display_name="$2"
    local description="$3"
    local category="$4"
    
    # Validate inputs
    if ! validate_module_name "$module_name"; then
        exit 1
    fi
    
    # Create the module
    create_module_structure "$module_name" "$display_name" "$description" "$category"
}

# Run main function
main "$@"