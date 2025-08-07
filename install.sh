#!/bin/bash

# One-liner installer for Linux Development Environment Setup
# Downloads and runs the full setup system

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Initialize logging early
init_early_logging() {
    export SETUP_LOG_DIR="$HOME/.local/share/setup-dev-env/logs"
    mkdir -p "$SETUP_LOG_DIR"
    export SETUP_INSTALL_LOG="$SETUP_LOG_DIR/install-$(date +%Y%m%d-%H%M%S).log"
    ln -sf "$SETUP_INSTALL_LOG" "$SETUP_LOG_DIR/latest-install.log"
    
    echo "================================================================================
Linux Development Environment - One-liner Installation Log
================================================================================
Start Time: $(date)
Host: $(hostname)
User: $(whoami)
Command: $0 $*
================================================================================
" > "$SETUP_INSTALL_LOG"
}

# Enhanced logging function
log_install() {
    local level="$1"
    shift
    local message="$*"
    local timestamp="$(date '+%H:%M:%S')"
    
    echo "[$timestamp] [$level] $message" >> "$SETUP_INSTALL_LOG"
}

# Enhanced error logging for debugging
log_install_error() {
    local context="$1"
    local error_message="$2"
    
    log_install "ERROR" "$context: $error_message"
    echo "" >> "$SETUP_INSTALL_LOG"
    echo "🚨 ERROR in $context:" >> "$SETUP_INSTALL_LOG"
    echo "   $error_message" >> "$SETUP_INSTALL_LOG"
    echo "" >> "$SETUP_INSTALL_LOG"
}

# Initialize early logging
init_early_logging

# Repository settings
REPO_URL="https://github.com/danmarshall909/setup-dev-env.git"
INSTALL_DIR="$HOME/setup-dev-env"

# Check if running in dry-run mode and filter arguments
DRY_RUN=false
FILTERED_ARGS=()

for arg in "$@"; do
    case "$arg" in
        "--dry-run"|"-d") 
            DRY_RUN=true 
            ;;
        *)
            FILTERED_ARGS+=("$arg")
            ;;
    esac
done

echo -e "${BLUE}Linux Development Environment Setup${NC}"
echo -e "${BLUE}====================================${NC}"
echo ""

if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}=== DRY RUN MODE - No changes will be made ===${NC}"
    echo ""
fi

# Check prerequisites
echo -e "${BLUE}[INFO]${NC} Checking prerequisites..."

if ! command -v git &> /dev/null; then
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${BLUE}[DRY RUN]${NC} Would install: git"
        log_install "INFO" "Dry-run: Would install git prerequisite"
    else
        echo -e "${YELLOW}[WARNING]${NC} Git not found. Installing git..."
        log_install "WARN" "Git prerequisite missing, installing..."
        if sudo apt update && sudo apt install -y git; then
            log_install "INFO" "Git prerequisite installed successfully"
        else
            echo -e "${RED}[ERROR]${NC} Failed to install git"
            log_install_error "Prerequisites" "Failed to install git prerequisite"
            exit 1
        fi
    fi
fi

if ! command -v curl &> /dev/null; then
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${BLUE}[DRY RUN]${NC} Would install: curl"
        log_install "INFO" "Dry-run: Would install curl prerequisite"
    else
        echo -e "${YELLOW}[WARNING]${NC} curl not found. Installing curl..."
        log_install "WARN" "Curl prerequisite missing, installing..."
        if sudo apt install -y curl; then
            log_install "INFO" "Curl prerequisite installed successfully"
        else
            echo -e "${RED}[ERROR]${NC} Failed to install curl"
            log_install_error "Prerequisites" "Failed to install curl prerequisite"
            exit 1
        fi
    fi
fi

# Clone or update repository
if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${BLUE}[DRY RUN]${NC} Would clone repository to: $INSTALL_DIR"
    echo -e "${BLUE}[DRY RUN]${NC} Would execute: git clone $REPO_URL $INSTALL_DIR"
    
    if [ ${#FILTERED_ARGS[@]} -eq 0 ]; then
        echo -e "${BLUE}[DRY RUN]${NC} Would run: $INSTALL_DIR/setup.sh all --dry-run (install all modules)"
    else
        echo -e "${BLUE}[DRY RUN]${NC} Would run: $INSTALL_DIR/setup.sh ${FILTERED_ARGS[*]} --dry-run"
    fi
else
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${BLUE}[INFO]${NC} Updating existing installation..."
        cd "$INSTALL_DIR"
        git pull
    else
        echo -e "${BLUE}[INFO]${NC} Cloning repository..."
        git clone "$REPO_URL" "$INSTALL_DIR"
    fi

    # Run the main setup script
    echo -e "${BLUE}[INFO]${NC} Starting setup..."
    cd "$INSTALL_DIR"
    
    # If no filtered arguments provided, run automated setup
    if [ ${#FILTERED_ARGS[@]} -eq 0 ]; then
        echo -e "${BLUE}[INFO]${NC} Running automated setup (install all modules)..."
        if [[ "$DRY_RUN" == "true" ]]; then
            ./setup.sh all --dry-run
        else
            ./setup.sh all
        fi
    else
        if [[ "$DRY_RUN" == "true" ]]; then
            ./setup.sh "${FILTERED_ARGS[@]}" --dry-run
        else
            ./setup.sh "${FILTERED_ARGS[@]}"
        fi
    fi
fi

if [[ "$DRY_RUN" == "true" ]]; then
    echo ""
    echo -e "${GREEN}[SUCCESS]${NC} Dry-run complete. Run without --dry-run to install."
    echo ""
    echo "To install manually:"
    echo "  git clone $REPO_URL"
    echo "  cd setup-dev-env"
    echo "  ./setup.sh"
else
    echo ""
    echo -e "${GREEN}[SUCCESS]${NC} Setup installer completed!"
    echo "Repository installed at: $INSTALL_DIR"
    
    # Clean up sensitive environment variables and history
    if [ -n "$SUDO_PASSWORD" ]; then
        echo -e "${BLUE}[INFO]${NC} Cleaning up sensitive environment variables and history..."
        unset SUDO_PASSWORD
        export SUDO_PASSWORD=""
        
        # Remove from bash history if possible
        if [ -n "$BASH" ] && [ "$BASH" != "/bin/sh" ]; then
            history -d $(history | grep -n "SUDO_PASSWORD" | cut -d: -f1 | tail -1) 2>/dev/null || true
            if [ -f "$HOME/.bash_history" ]; then
                grep -v "SUDO_PASSWORD" "$HOME/.bash_history" > "$HOME/.bash_history.tmp" 2>/dev/null || true
                mv "$HOME/.bash_history.tmp" "$HOME/.bash_history" 2>/dev/null || true
            fi
        fi
    fi
fi