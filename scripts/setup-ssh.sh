#!/bin/bash

# Quick SSH server setup script for VirtualBox VM

# Source common functions
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/common.sh"

echo "Installing and configuring SSH server..."

# Update package list
run_sudo apt update

# Install OpenSSH server
run_sudo apt install -y openssh-server

# Start SSH service
run_sudo systemctl start ssh

# Enable SSH to start on boot
run_sudo systemctl enable ssh

# Check SSH status
echo "SSH service status:"
run_sudo systemctl status ssh --no-pager -l

# Show IP address for SSH connection
echo ""
echo "VM IP addresses:"
hostname -I

echo ""
echo "SSH server setup complete!"
echo "You can now connect from host using:"
echo "ssh $(whoami)@$(hostname -I | awk '{print $1}')"