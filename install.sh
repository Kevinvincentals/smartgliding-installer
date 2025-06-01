#!/bin/bash

# MIT License
#
# Copyright (c) 2025 Kevin Vincent Als <kevin@connect365.dk>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# SmartGliding Platform Installer
# Automated installation script for SmartGliding digital flight logging platform

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="smartgliding"
COMPOSE_VERSION="v2.21.0"

# Print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║              SmartGliding Platform Installer                ║"
    echo "║          Digital Flight Logging for Gliding Clubs           ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Detect operating system
detect_os() {
    print_status "Detecting operating system and architecture..."
    
    # Check if running on Linux
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        print_error "This installer only supports Linux. Detected: $OSTYPE"
        exit 1
    fi
    
    # Get architecture
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            ARCH="AMD64"
            ;;
        aarch64|arm64)
            ARCH="ARM64"
            ;;
        *)
            print_error "Unsupported architecture: $ARCH"
            print_error "This installer only supports AMD64 (x86_64) and ARM64 (aarch64) architectures"
            exit 1
            ;;
    esac
    
    # Detect distribution
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
        DISTRO=$ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si)
        VER=$(lsb_release -sr)
        DISTRO=$(echo $OS | tr '[:upper:]' '[:lower:]')
    else
        print_error "Cannot detect Linux distribution"
        exit 1
    fi
    
    # Only support Debian/Ubuntu based systems
    case $DISTRO in
        ubuntu|debian)
            print_success "Detected: $OS $VER ($ARCH)"
            print_success "Supported platform confirmed"
            ;;
        *)
            print_error "Unsupported Linux distribution: $OS"
            print_error "This installer only supports Ubuntu and Debian based systems"
            print_error "Detected distribution: $DISTRO"
            exit 1
            ;;
    esac
}

# Check if running as root
check_root() {
    if [ "$EUID" -eq 0 ]; then
        print_warning "Running as root detected!"
        print_warning "For security reasons, it's recommended to run this script as a regular user with sudo privileges."
        print_warning "Running as root will skip Docker group configuration."
        echo
        read -p "Do you want to continue as root? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_error "Installation cancelled. Please run as a regular user with sudo privileges."
            exit 1
        fi
        RUNNING_AS_ROOT=true
        USE_SUDO=""
        print_warning "Continuing as root..."
    else
        RUNNING_AS_ROOT=false
        USE_SUDO=""  # Will be set to "sudo" if needed in verify_docker
    fi
}

# Install Docker
install_docker() {
    print_status "Checking Docker installation..."
    
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
        print_success "Docker is already installed (version $DOCKER_VERSION)"
        return
    fi
    
    print_status "Installing Docker for $OS ($ARCH)..."
    
    # Set sudo prefix based on whether we're root or not
    local SUDO_PREFIX=""
    if [ "$RUNNING_AS_ROOT" = false ]; then
        SUDO_PREFIX="sudo"
    fi
    
    # Update package index
    $SUDO_PREFIX apt-get update
    
    # Install required packages
    $SUDO_PREFIX apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Add Docker's official GPG key
    $SUDO_PREFIX mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/$DISTRO/gpg | $SUDO_PREFIX gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Set up the repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$DISTRO \
        $(lsb_release -cs) stable" | $SUDO_PREFIX tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker Engine
    $SUDO_PREFIX apt-get update
    $SUDO_PREFIX apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Start and enable Docker
    $SUDO_PREFIX systemctl start docker
    $SUDO_PREFIX systemctl enable docker
    
    # Add user to docker group (only if not running as root)
    if [ "$RUNNING_AS_ROOT" = false ]; then
        $SUDO_PREFIX usermod -aG docker $USER
        print_success "Docker installed successfully"
        print_warning "You may need to log out and back in for Docker group permissions to take effect"
    else
        print_success "Docker installed successfully (running as root)"
    fi
}

# Verify Docker installation
verify_docker() {
    print_status "Verifying Docker installation..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker installation failed"
        exit 1
    fi
    
    # If running as root, Docker should work directly
    if [ "$RUNNING_AS_ROOT" = true ]; then
        if docker ps &> /dev/null; then
            print_success "Docker is working correctly as root"
            USE_SUDO=""
        else
            print_error "Docker is not working properly"
            exit 1
        fi
    else
        # Test Docker without sudo (may fail if user needs to re-login)
        if docker ps &> /dev/null; then
            print_success "Docker is working correctly"
            USE_SUDO=""
        else
            print_warning "Docker is installed but may require logout/login for group permissions"
            print_status "Attempting to use sudo for Docker commands..."
            if sudo docker ps &> /dev/null; then
                USE_SUDO="sudo"
                print_success "Docker is working with sudo"
            else
                print_error "Docker is not working properly"
                exit 1
            fi
        fi
    fi
}

# Create installation directory and docker-compose.yml
create_installation() {
    print_status "Creating installation directory..."
    
    if [ -d "$INSTALL_DIR" ]; then
        print_warning "Directory $INSTALL_DIR already exists"
        read -p "Do you want to continue and overwrite? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_error "Installation cancelled"
            exit 1
        fi
    fi
    
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    print_status "Downloading docker-compose.yml from GitHub..."
    
    # Try to download from GitHub first
    if curl -fsSL -o docker-compose.yml \
        "https://raw.githubusercontent.com/Kevinvincentals/smartgliding-web/main/docker-compose.yml" 2>/dev/null; then
        print_success "Downloaded latest docker-compose.yml from GitHub"
    else
        print_warning "Failed to download from GitHub, using embedded fallback version"
        
        cat > docker-compose.yml << 'EOF'
services:
  smartgliding-web:
    image: ghcr.io/kevinvincentals/smartgliding-web:latest
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - DATABASE_URL=mongodb://mongodb:27017/smartgliding?replicaSet=rs0
      - JWT_SECRET=your-super-secret-key-change-this-in-production
      - PLANE_TRACKER_WS_URL=ws://smartgliding-ogn-backend:8765
      - WEBHOOK_API_KEY=secret
    depends_on:
      mongodb-setup:
        condition: service_completed_successfully
      smartgliding-ogn-backend:
        condition: service_started
    restart: unless-stopped
    labels:
      - "com.centurylinklabs.watchtower.enable=true"

  smartgliding-ogn-backend:
    image: ghcr.io/kevinvincentals/smartgliding-ogn-backend:latest
    container_name: smartgliding-ogn-backend
    ports:
      - "8765:8765"
    volumes:
      - ogn_data:/data
    environment:
      - DATABASE_URL=mongodb://mongodb:27017/smartgliding?replicaSet=rs0
      - WEBHOOK_URL=http://smartgliding-web:3000/api/webhooks/flights
      - WEBHOOK_API_KEY=secret
      - WEBHOOK_ENABLED=true
    depends_on:
      mongodb-setup:
        condition: service_completed_successfully
    restart: unless-stopped
    labels:
      - "com.centurylinklabs.watchtower.enable=true"

  mongodb:
    image: mongo:7
    command: ["--replSet", "rs0", "--bind_ip_all", "--noauth"]
    volumes:
      - ./database:/data/db
    restart: unless-stopped
    healthcheck:
      test: ["CMD","mongosh", "--eval", "db.adminCommand('hello')"]
      interval: 5s
      timeout: 2s
      retries: 10

  mongodb-setup:
    image: mongo:7
    depends_on:
      mongodb:
        condition: service_healthy
    command: >
      mongosh --host mongodb:27017 --eval "
      try {
        rs.status();
        print('Replica set already initialized');
      } catch (err) {
        print('Initializing replica set...');
        rs.initiate({
          _id: 'rs0',
          members: [{ _id: 0, host: 'mongodb:27017' }]
        });
        print('Replica set initialized');
      }
      "
    restart: "no"

  watchtower:
    image: containrrr/watchtower:latest
    container_name: watchtower
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - WATCHTOWER_POLL_INTERVAL=3600  # Check every hour (3600 seconds)
      - WATCHTOWER_CLEANUP=true        # Remove old images after updating
      - WATCHTOWER_INCLUDE_RESTARTING=true
      - WATCHTOWER_LABEL_ENABLE=true   # Only monitor containers with watchtower labels
    command: --interval 3600 --cleanup
    depends_on:
      smartgliding-web:
        condition: service_started
      smartgliding-ogn-backend:
        condition: service_started

volumes:
  ogn_data:
EOF
    fi
    
    print_success "Installation files created in $(pwd)"
}

# Deploy the stack
deploy_stack() {
    print_status "Deploying SmartGliding platform..."
    
    # Pull images first
    print_status "Pulling Docker images (this may take a few minutes)..."
    ${USE_SUDO} docker compose pull
    
    # Start services
    print_status "Starting services..."
    ${USE_SUDO} docker compose up -d
    
    print_success "Services started successfully"
}

# Wait for services to be ready
wait_for_services() {
    print_status "Waiting for services to be ready..."
    
    # Wait for web app to be ready (max 5 minutes)
    local max_attempts=60
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s http://localhost:3000/api/install > /dev/null 2>&1; then
            print_success "SmartGliding web application is ready!"
            break
        fi
        
        printf "\rWaiting for services... (%d/%d)" $attempt $max_attempts
        sleep 5
        ((attempt++))
    done
    
    echo  # New line after progress
    
    if [ $attempt -gt $max_attempts ]; then
        print_error "Services did not start within expected time. Please check logs:"
        print_status "Run: ${USE_SUDO} docker compose logs"
        exit 1
    fi
}

# Show completion message
show_completion() {
    print_success "Installation completed successfully!"
    echo
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗"
    echo -e "║                    INSTALLATION COMPLETE                    ║"
    echo -e "╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${BLUE}Next Steps:${NC}"
    echo "1. Open your web browser"
    echo "2. Navigate to: http://$(hostname -I | awk '{print $1}'):3000/install"
    echo "   (or http://localhost:3000/install if accessing locally)"
    echo "3. Complete the initial setup with your club information"
    echo
    echo -e "${BLUE}Useful Commands:${NC}"
    echo "• View logs:      ${USE_SUDO} docker compose logs"
    echo "• Stop services:  ${USE_SUDO} docker compose down"
    echo "• Start services: ${USE_SUDO} docker compose up -d"
    echo "• Update system:  ${USE_SUDO} docker compose pull && ${USE_SUDO} docker compose up -d"
    echo
    echo -e "${YELLOW}Installation directory: $(pwd)${NC}"
    echo
    print_success "Welcome to SmartGliding! 🛩️"
}

# Main installation function
main() {
    print_header
    
    check_root
    detect_os
    install_docker
    verify_docker
    create_installation
    deploy_stack
    wait_for_services
    show_completion
}

# Run main function
main "$@" 