#!/bin/bash

# Quick VM Test Script - Simple version for testing installations

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration - adjust these for your VM
VM_NAME="${1:-pop-os}"              # VirtualBox VM name
SNAPSHOT="${2:-clean}"              # Snapshot name
VM_IP="${3:-192.168.1.100}"        # VM IP address (or use localhost with port forwarding)
VM_USER="${4:-dan}"                # VM username

echo -e "${BLUE}=== VM Installation Test Script ===${NC}"
echo "VM: $VM_NAME"
echo "Snapshot: $SNAPSHOT"
echo "Target: $VM_USER@$VM_IP"
echo ""

# Step 1: Rollback VM
echo -e "${YELLOW}Step 1: Rolling back VM to snapshot...${NC}"
VBoxManage controlvm "$VM_NAME" poweroff 2>/dev/null || true
sleep 2
VBoxManage snapshot "$VM_NAME" restore "$SNAPSHOT"
echo "✓ Snapshot restored"

# Step 2: Start VM
echo -e "${YELLOW}Step 2: Starting VM...${NC}"
VBoxManage startvm "$VM_NAME" --type headless
echo "✓ VM started"

# Step 3: Wait for VM to be ready
echo -e "${YELLOW}Step 3: Waiting for VM to boot (30 seconds)...${NC}"
sleep 30

# Optional: Wait for SSH
echo -n "Waiting for SSH..."
while ! ssh -q -o ConnectTimeout=2 -o StrictHostKeyChecking=no "$VM_USER@$VM_IP" exit 2>/dev/null; do
    echo -n "."
    sleep 5
done
echo " Ready!"

# Step 4: Run installation
echo -e "${YELLOW}Step 4: Running installation...${NC}"
ssh "$VM_USER@$VM_IP" 'curl -sSL https://raw.githubusercontent.com/danmarshall909/setup-dev-env/master/install.sh | bash'

# Step 5: Collect logs
echo -e "${YELLOW}Step 5: Collecting logs...${NC}"
mkdir -p vm-logs
scp -r "$VM_USER@$VM_IP:~/.local/share/setup-dev-env/logs/*" vm-logs/ 2>/dev/null || echo "No logs found"

echo -e "${GREEN}✅ Test completed!${NC}"
echo "Logs saved in: vm-logs/"

# Show summary if available
if [ -f vm-logs/latest-summary.log ]; then
    echo ""
    echo -e "${BLUE}=== Installation Summary ===${NC}"
    cat vm-logs/latest-summary.log
fi