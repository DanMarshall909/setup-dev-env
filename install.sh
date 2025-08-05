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
    else
        echo -e "${YELLOW}[WARNING]${NC} Git not found. Installing git..."
        sudo apt update
        sudo apt install -y git
    fi
fi

if ! command -v curl &> /dev/null; then
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${BLUE}[DRY RUN]${NC} Would install: curl"
    else
        echo -e "${YELLOW}[WARNING]${NC} curl not found. Installing curl..."
        sudo apt install -y curl
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
fi