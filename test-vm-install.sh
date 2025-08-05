#!/bin/bash

# VM Testing Script - Automates VM rollback and installation testing
# Supports multiple VM platforms (VirtualBox, VMware, QEMU/KVM)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
VM_NAME="${VM_NAME:-pop-os-test}"
VM_TYPE="${VM_TYPE:-virtualbox}"  # virtualbox, vmware, qemu
SNAPSHOT_NAME="${SNAPSHOT_NAME:-clean-install}"
VM_USER="${VM_USER:-dan}"
VM_HOST="${VM_HOST:-pop-os}"
VM_SSH_PORT="${VM_SSH_PORT:-2222}"
INSTALL_METHOD="${INSTALL_METHOD:-oneliner}"  # oneliner, clone, local
LOCAL_PATH="${LOCAL_PATH:-$(pwd)}"
LOG_FILE="vm-test-$(date +%Y%m%d-%H%M%S).log"

# Usage function
show_usage() {
    cat << EOF
VM Installation Test Script

Usage: $0 [options]

Options:
    -n, --name NAME         VM name (default: $VM_NAME)
    -t, --type TYPE         VM type: virtualbox, vmware, qemu (default: $VM_TYPE)
    -s, --snapshot NAME     Snapshot name (default: $SNAPSHOT_NAME)
    -u, --user USER         VM username (default: $VM_USER)
    -h, --host HOST         VM hostname (default: $VM_HOST)
    -p, --port PORT         SSH port (default: $VM_SSH_PORT)
    -m, --method METHOD     Install method: oneliner, clone, local (default: $INSTALL_METHOD)
    -l, --local PATH        Local path for sync (default: $LOCAL_PATH)
    --dry-run               Show what would be done without executing
    --help                  Show this help message

Examples:
    # Test with VirtualBox VM
    $0 --name ubuntu-test --snapshot fresh-install

    # Test with local code sync
    $0 --method local --local /home/dan/code/setup-dev-env

    # Test with VMware
    $0 --type vmware --name pop-os-vm

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--name) VM_NAME="$2"; shift 2 ;;
        -t|--type) VM_TYPE="$2"; shift 2 ;;
        -s|--snapshot) SNAPSHOT_NAME="$2"; shift 2 ;;
        -u|--user) VM_USER="$2"; shift 2 ;;
        -h|--host) VM_HOST="$2"; shift 2 ;;
        -p|--port) VM_SSH_PORT="$2"; shift 2 ;;
        -m|--method) INSTALL_METHOD="$2"; shift 2 ;;
        -l|--local) LOCAL_PATH="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        --help) show_usage; exit 0 ;;
        *) echo "Unknown option: $1"; show_usage; exit 1 ;;
    esac
done

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# VM control functions
rollback_virtualbox() {
    log "Rolling back VirtualBox VM '$VM_NAME' to snapshot '$SNAPSHOT_NAME'..."
    VBoxManage snapshot "$VM_NAME" restore "$SNAPSHOT_NAME"
    log "Starting VM..."
    VBoxManage startvm "$VM_NAME" --type headless
    log "Waiting for VM to boot..."
    sleep 30
}

rollback_vmware() {
    log "Rolling back VMware VM '$VM_NAME' to snapshot '$SNAPSHOT_NAME'..."
    vmrun -T ws revertToSnapshot "$VM_NAME" "$SNAPSHOT_NAME"
    log "Starting VM..."
    vmrun -T ws start "$VM_NAME" nogui
    log "Waiting for VM to boot..."
    sleep 30
}

rollback_qemu() {
    log "Rolling back QEMU/KVM VM '$VM_NAME' to snapshot '$SNAPSHOT_NAME'..."
    virsh snapshot-revert "$VM_NAME" "$SNAPSHOT_NAME"
    log "Starting VM..."
    virsh start "$VM_NAME"
    log "Waiting for VM to boot..."
    sleep 30
}

# Wait for SSH to be available
wait_for_ssh() {
    local max_attempts=30
    local attempt=0
    
    log "Waiting for SSH to be available..."
    while ! ssh -q -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
           -p "$VM_SSH_PORT" "$VM_USER@localhost" exit 2>/dev/null; do
        ((attempt++))
        if [ $attempt -ge $max_attempts ]; then
            log "ERROR: SSH connection timeout after $max_attempts attempts"
            return 1
        fi
        echo -n "."
        sleep 5
    done
    echo ""
    log "SSH connection established"
}

# Run installation based on method
run_oneliner_install() {
    log "Running one-liner installation..."
    ssh -p "$VM_SSH_PORT" "$VM_USER@localhost" << 'EOF'
curl -sSL https://raw.githubusercontent.com/danmarshall909/setup-dev-env/master/install.sh | bash
EOF
}

run_clone_install() {
    log "Running clone-based installation..."
    ssh -p "$VM_SSH_PORT" "$VM_USER@localhost" << 'EOF'
git clone https://github.com/danmarshall909/setup-dev-env.git
cd setup-dev-env
./setup.sh all
EOF
}

run_local_install() {
    log "Syncing local code to VM..."
    # Create directory on VM
    ssh -p "$VM_SSH_PORT" "$VM_USER@localhost" "mkdir -p ~/setup-dev-env"
    
    # Sync files (excluding .git and logs)
    rsync -avz --exclude='.git' --exclude='logs' --exclude='*.log' \
          -e "ssh -p $VM_SSH_PORT" \
          "$LOCAL_PATH/" "$VM_USER@localhost:~/setup-dev-env/"
    
    log "Running local installation..."
    ssh -p "$VM_SSH_PORT" "$VM_USER@localhost" << 'EOF'
cd ~/setup-dev-env
./setup.sh all
EOF
}

# Collect logs from VM
collect_logs() {
    log "Collecting installation logs from VM..."
    local log_dir="vm-logs-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$log_dir"
    
    # Copy setup logs
    scp -P "$VM_SSH_PORT" -r \
        "$VM_USER@localhost:~/.local/share/setup-dev-env/logs/*" \
        "$log_dir/" 2>/dev/null || true
    
    # Copy install log if using one-liner
    scp -P "$VM_SSH_PORT" \
        "$VM_USER@localhost:~/.local/share/setup-dev-env/logs/latest-install.log" \
        "$log_dir/" 2>/dev/null || true
    
    log "Logs collected in: $log_dir"
    
    # Show summary
    if [ -f "$log_dir/latest-summary.log" ]; then
        echo ""
        echo -e "${BLUE}=== Installation Summary ===${NC}"
        cat "$log_dir/latest-summary.log"
    fi
}

# Main execution
main() {
    log "Starting VM installation test"
    log "VM: $VM_NAME ($VM_TYPE)"
    log "Snapshot: $SNAPSHOT_NAME"
    log "Method: $INSTALL_METHOD"
    
    if [ "$DRY_RUN" = "true" ]; then
        log "DRY RUN MODE - showing what would be done:"
        log "1. Rollback $VM_TYPE VM '$VM_NAME' to snapshot '$SNAPSHOT_NAME'"
        log "2. Start VM and wait for SSH"
        log "3. Run $INSTALL_METHOD installation"
        log "4. Collect logs"
        exit 0
    fi
    
    # Rollback VM
    case "$VM_TYPE" in
        virtualbox) rollback_virtualbox ;;
        vmware) rollback_vmware ;;
        qemu) rollback_qemu ;;
        *) log "ERROR: Unknown VM type: $VM_TYPE"; exit 1 ;;
    esac
    
    # Wait for SSH
    if ! wait_for_ssh; then
        log "ERROR: Failed to establish SSH connection"
        exit 1
    fi
    
    # Run installation
    case "$INSTALL_METHOD" in
        oneliner) run_oneliner_install ;;
        clone) run_clone_install ;;
        local) run_local_install ;;
        *) log "ERROR: Unknown install method: $INSTALL_METHOD"; exit 1 ;;
    esac
    
    # Wait for installation to complete
    log "Waiting for installation to complete..."
    sleep 10
    
    # Collect logs
    collect_logs
    
    log "Test completed successfully!"
    echo -e "${GREEN}✅ VM test completed. Check logs in: $LOG_FILE${NC}"
}

# Run main function
main