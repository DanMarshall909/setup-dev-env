#!/bin/bash

# Docker installation script

# Source common functions
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/common.sh"

install_docker() {
    print_status "Installing Docker..."
    log_script_start "install-docker.sh"
    
    # Remove old versions
    sudo apt-get remove -y docker docker-engine docker.io containerd runc || true
    
    # Install prerequisites
    install_package "ca-certificates" "CA certificates"
    install_package "curl" "curl"
    install_package "gnupg" "GnuPG"
    install_package "lsb-release" "LSB release"
    
    # Add Docker's official GPG key
    print_status "Adding Docker GPG key..."
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Add repository
    print_status "Adding Docker repository..."
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker Engine
    update_repositories
    install_package "docker-ce" "Docker CE"
    install_package "docker-ce-cli" "Docker CLI"
    install_package "containerd.io" "containerd"
    install_package "docker-compose-plugin" "Docker Compose"
    
    # Add user to docker group
    print_status "Adding user to docker group..."
    sudo usermod -aG docker $USER
    
    # Start and enable Docker
    print_status "Starting Docker service..."
    sudo systemctl start docker
    sudo systemctl enable docker
    
    print_success "Docker installation complete:"
    sudo docker --version
    
    print_warning "You need to log out and back in for group changes to take effect"
    
    log_script_end "install-docker.sh" 0
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_docker
fi