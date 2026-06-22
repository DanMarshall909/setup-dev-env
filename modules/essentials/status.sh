#!/bin/bash

# Essential Tools module status script

# Source common functions
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/../../scripts/common.sh"

ESSENTIAL_PACKAGES=(
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

missing_essential_packages() {
    local package
    for package in "${ESSENTIAL_PACKAGES[@]}"; do
        if ! dpkg -l "$package" 2>/dev/null | awk '$1 == "ii" { found=1 } END { exit !found }'; then
            echo "$package"
        fi
    done
}

check_essentials_status() {
    local command="$1"
    
    case "$command" in
        "installed")
            [ -z "$(missing_essential_packages)" ]
            ;;
        "summary")
            local missing
            missing=$(missing_essential_packages | tr '\n' ' ')
            if [ -z "$missing" ]; then
                echo "✅ Essential Tools (${#ESSENTIAL_PACKAGES[@]}/${#ESSENTIAL_PACKAGES[@]} packages)"
            else
                echo "❌ Essential Tools missing: $missing"
            fi
            ;;
        "status")
            local missing_json="[]"
            local installed=true
            local missing_count=0

            while IFS= read -r package; do
                if [ -n "$package" ]; then
                    installed=false
                    missing_count=$((missing_count + 1))
                    missing_json=$(echo "$missing_json" | jq --arg package "$package" '. + [$package]')
                fi
            done < <(missing_essential_packages)

            local installed_count=$((${#ESSENTIAL_PACKAGES[@]} - missing_count))

            local packages_json="[]"
            local package
            for package in "${ESSENTIAL_PACKAGES[@]}"; do
                packages_json=$(echo "$packages_json" | jq --arg package "$package" '. + [$package]')
            done

            local module_status="installed"
            if [ "$installed" != "true" ]; then
                module_status="partial"
            fi
            
            cat << EOFSTATUS
{
  "name": "essentials",
  "installed": $installed,
  "module_status": "$module_status",
  "installed_count": $installed_count,
  "total_count": ${#ESSENTIAL_PACKAGES[@]},
  "packages": $packages_json,
  "missing_packages": $missing_json
}
EOFSTATUS
            ;;
        *)
            echo "Usage: $0 {installed|summary|status}"
            exit 1
            ;;
    esac
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    check_essentials_status "${1:-summary}"
fi
