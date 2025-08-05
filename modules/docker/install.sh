#!/bin/bash

# Docker module installation script - reusing code from scripts/install-docker.sh

# Source module framework
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/../../scripts/module-framework.sh"

# Check if Docker is already installed
check_docker_installed() {
    command -v docker &>/dev/null && systemctl is-active --quiet docker
}

# Install Docker - reusing logic from scripts/install-docker.sh
install_docker() {
    if is_dry_run; then
        print_would_execute "apt-get remove docker docker-engine docker.io containerd runc"
        print_would_install "ca-certificates curl gnupg lsb-release" "Docker prerequisites"  
        print_would_execute "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor"
        print_would_execute "add Docker repository to /etc/apt/sources.list.d/docker.list"
        print_would_install "docker-ce docker-ce-cli containerd.io docker-compose-plugin" "Docker Engine"
        print_would_execute "usermod -aG docker $USER"
        print_would_execute "systemctl start docker && systemctl enable docker"
        return 0
    fi
    
    # Remove old versions
    print_status "Removing old Docker versions..."
    sudo apt-get remove -y docker docker-engine docker.io containerd runc || true
    
    # Install prerequisites
    install_package_with_dry_run "ca-certificates" "CA certificates"
    install_package_with_dry_run "curl" "curl"
    install_package_with_dry_run "gnupg" "GnuPG"
    install_package_with_dry_run "lsb-release" "LSB release"
    
    # Try multiple installation methods for better compatibility
    if ! install_docker_with_official_repo; then
        print_warning "Official Docker repository failed, trying alternative methods..."
        if ! install_docker_with_convenience_script; then
            print_warning "Convenience script failed, trying distribution packages..."
            if ! install_docker_with_distro_packages; then
                print_error "All Docker installation methods failed"
                return 1
            fi
        fi
    fi
    
    # Configure and start Docker
    print_status "Configuring Docker service..."
    
    # Enable and start Docker service with error handling
    if ! is_dry_run; then
        # Enable Docker to start on boot
        if sudo systemctl enable docker 2>/dev/null; then
            print_success "Docker enabled to start on boot"
        else
            print_warning "Could not enable Docker service (systemd may not be available)"
        fi
        
        # Try to start Docker
        if sudo systemctl start docker 2>/dev/null; then
            print_success "Docker service started"
        else
            # Fallback for systems without systemd
            if sudo service docker start 2>/dev/null; then
                print_success "Docker service started (via init.d)"
            else
                print_warning "Could not start Docker service - may need manual start"
            fi
        fi
        
        # Create docker group if it doesn't exist
        if ! getent group docker > /dev/null 2>&1; then
            sudo groupadd docker
        fi
        
        # Add user to docker group
        if sudo usermod -aG docker "$USER"; then
            print_success "User added to docker group (logout required for changes)"
        fi
    else
        print_would_execute "sudo systemctl enable docker"
        print_would_execute "sudo systemctl start docker"
        print_would_execute "sudo usermod -aG docker $USER"
    fi
    
    return 0
}

# Method 1: Official Docker repository
install_docker_with_official_repo() {
    print_status "Trying official Docker repository..."
    
    # Detect distribution for Docker repository
    local distro=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
    local codename=$(lsb_release -cs)
    
    # Pop!_OS is based on Ubuntu, use Ubuntu repos
    if [[ "$distro" == "pop" ]]; then
        distro="ubuntu"
        # Map Pop!_OS version to Ubuntu codename
        case "$(lsb_release -rs)" in
            "22.04") codename="jammy" ;;
            "20.04") codename="focal" ;;
            *) codename="jammy" ;; # Default to latest LTS
        esac
    fi
    
    # Add Docker repository
    if ! add_apt_repository \
        "https://download.docker.com/linux/$distro/gpg" \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$distro $codename stable" \
        "/etc/apt/sources.list.d/docker.list" \
        "Docker repository"; then
        return 1
    fi
    
    # Install Docker packages
    local failed=false
    install_package_with_dry_run "docker-ce" "Docker CE" || failed=true
    install_package_with_dry_run "docker-ce-cli" "Docker CLI" || failed=true
    install_package_with_dry_run "containerd.io" "containerd" || failed=true
    install_package_with_dry_run "docker-compose-plugin" "Docker Compose" || failed=true
    
    if [[ "$failed" == "true" ]]; then
        print_warning "Official Docker packages failed to install"
        return 1
    fi
    
    print_success "Docker installed via official repository"
    return 0
}

# Method 2: Docker convenience script
install_docker_with_convenience_script() {
    print_status "Trying Docker convenience script..."
    
    if is_dry_run; then
        print_would_execute "curl -fsSL https://get.docker.com | sh"
        return 0
    fi
    
    # Download and run Docker convenience script
    if curl -fsSL https://get.docker.com -o /tmp/get-docker.sh; then
        print_status "Running Docker installation script..."
        if sudo sh /tmp/get-docker.sh; then
            rm -f /tmp/get-docker.sh
            print_success "Docker installed via convenience script"
            return 0
        else
            rm -f /tmp/get-docker.sh
            print_warning "Docker convenience script failed"
            return 1
        fi
    else
        print_warning "Could not download Docker convenience script"
        return 1
    fi
}

# Method 3: Distribution packages
install_docker_with_distro_packages() {
    print_status "Trying distribution Docker packages..."
    
    # Try installing docker.io from Ubuntu/Pop!_OS repos
    local packages=("docker.io" "docker-compose")
    local failed=false
    
    for package in "${packages[@]}"; do
        if ! install_package_with_dry_run "$package" "Docker ($package)"; then
            failed=true
        fi
    done
    
    if [[ "$failed" == "true" ]]; then
        print_warning "Distribution Docker packages failed"
        return 1
    fi
    
    # Create docker command symlink if needed
    if ! is_dry_run && [ -f /usr/bin/docker.io ] && [ ! -f /usr/local/bin/docker ]; then
        sudo ln -sf /usr/bin/docker.io /usr/local/bin/docker
        print_success "Created docker command symlink"
    fi
    
    print_success "Docker installed via distribution packages"
    return 0
}

# Verify Docker installation
verify_docker_installation() {
    if is_dry_run; then
        print_would_execute "docker --version"
        print_would_execute "docker compose version || docker-compose --version"
        print_success "DRY RUN: Docker verification would complete"
        return 0
    fi
    
    # Verify Docker command (could be docker or docker.io)
    local docker_cmd=""
    if command -v docker &>/dev/null; then
        docker_cmd="docker"
    elif command -v docker.io &>/dev/null; then
        docker_cmd="docker.io"
    else
        print_error "Docker command not found"
        return 1
    fi
    
    # Verify Docker version
    local docker_version=$(sudo $docker_cmd --version 2>/dev/null)
    if [ -n "$docker_version" ]; then
        print_success "Docker: $docker_version"
    else
        print_warning "Could not get Docker version"
    fi
    
    # Check Docker service (try multiple service names)
    local service_running=false
    if systemctl is-active --quiet docker 2>/dev/null; then
        print_success "Docker service is running"
        service_running=true
    elif systemctl is-active --quiet docker.service 2>/dev/null; then
        print_success "Docker.service is running"
        service_running=true
    elif service docker status &>/dev/null; then
        print_success "Docker service is running (via init.d)"
        service_running=true
    else
        print_warning "Docker service status unknown - may need manual start"
    fi
    
    # Test Docker functionality (as root since user group change requires logout)
    if [ "$service_running" = "true" ]; then
        print_status "Testing Docker functionality..."
        if timeout 30 sudo $docker_cmd run --rm hello-world &>/dev/null; then
            print_success "Docker is working correctly"
        else
            print_warning "Docker test failed - service may be starting or need restart"
        fi
    fi
    
    # Check for Docker Compose
    if command -v docker &>/dev/null && docker compose version &>/dev/null; then
        local compose_version=$(docker compose version 2>/dev/null | head -n1)
        print_success "Docker Compose: $compose_version"
    elif command -v docker-compose &>/dev/null; then
        local compose_version=$(docker-compose --version 2>/dev/null)
        print_success "Docker Compose: $compose_version"
    else
        print_warning "Docker Compose not available"
    fi
    
    return 0
}

# Show Docker post-installation info
show_docker_info() {
    local next_steps="1. Log out and back in for group changes to take effect
2. Test Docker: docker run hello-world  
3. Start using Docker containers and images
4. Consider installing Docker Desktop for GUI management"
    
    local docs_url="https://docs.docker.com/"
    
    local config_notes="Docker is installed and configured to start on boot.
Your user has been added to the 'docker' group.
Log out and back in to use Docker without sudo."
    
    show_post_install_info "Docker" "$next_steps" "$docs_url" "$config_notes"
}

# Main module execution using framework
install_docker_module() {
    init_module "docker" "Docker"
    
    run_standard_install_flow \
        "check_docker_installed" \
        "install_docker" \
        "verify_docker_installation" \
        "show_docker_info"
}

# Execute if run directly
install_docker_module