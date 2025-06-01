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
INSTALL_DIR="/opt/smartgliding"
SMARTGLIDING_USER="smartgliding"
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
        print_success "Running as root - perfect for system installation!"
        print_status "Root privileges are required to:"
        print_status "  • Create the smartgliding system user"
        print_status "  • Set up /opt/smartgliding directory"
        print_status "  • Install Docker (if needed)"
        print_status "  • Configure proper permissions"
        echo
        print_status "The SmartGliding services will run as the dedicated 'smartgliding' user for security."
        RUNNING_AS_ROOT=true
        USE_SUDO=""
    else
        print_status "Running as regular user: $USER"
        print_status "This script requires root privileges to create system users and install software."
        print_warning "You will be prompted for sudo access when needed."
        echo
        RUNNING_AS_ROOT=false
        USE_SUDO=""  # Will be set to "sudo" if needed in verify_docker
        
        # Check if user has sudo privileges
        if ! sudo -n true 2>/dev/null; then
            print_error "This script requires sudo privileges to:"
            print_error "  • Create the smartgliding system user"
            print_error "  • Install Docker (if needed)"
            print_error "  • Set up system directories and permissions"
            echo
            print_error "Please run with sudo or as root: sudo $0"
            exit 1
        fi
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

# Create smartgliding system user
create_smartgliding_user() {
    print_status "Setting up smartgliding system user..."
    
    # Set sudo prefix based on whether we're root or not
    local SUDO_PREFIX=""
    if [ "$RUNNING_AS_ROOT" = false ]; then
        SUDO_PREFIX="sudo"
    fi
    
    # Check if user already exists
    if id "$SMARTGLIDING_USER" &>/dev/null; then
        print_success "User '$SMARTGLIDING_USER' already exists"
    else
        print_status "Creating system user '$SMARTGLIDING_USER'..."
        
        # Create system user with home directory
        $SUDO_PREFIX useradd --system \
            --home-dir "$INSTALL_DIR" \
            --create-home \
            --shell /usr/sbin/nologin \
            --comment "SmartGliding Platform Service User" \
            "$SMARTGLIDING_USER"
        
        print_success "Created system user '$SMARTGLIDING_USER'"
    fi
    
    # Add smartgliding user to docker group
    print_status "Adding '$SMARTGLIDING_USER' to docker group..."
    $SUDO_PREFIX usermod -aG docker "$SMARTGLIDING_USER"
    print_success "User '$SMARTGLIDING_USER' added to docker group"
    
    # Ensure the installation directory exists and has correct ownership
    $SUDO_PREFIX mkdir -p "$INSTALL_DIR"
    $SUDO_PREFIX chown "$SMARTGLIDING_USER:$SMARTGLIDING_USER" "$INSTALL_DIR"
    print_success "Installation directory prepared: $INSTALL_DIR"
}

# Generate secure random string
generate_random_string() {
    local length=${1:-32}
    openssl rand -base64 $length | tr -d "=+/" | cut -c1-$length
}

# Interactive configuration
configure_installation() {
    print_status "Starting configuration..."
    echo
    
    # Check for environment variable overrides
    if [ ! -z "$SMARTGLIDING_MONGODB_URL" ] || [ ! -z "$SMARTGLIDING_JWT_SECRET" ] || [ ! -z "$SMARTGLIDING_WEBHOOK_KEY" ]; then
        print_status "Environment variable configuration detected:"
        [ ! -z "$SMARTGLIDING_MONGODB_URL" ] && print_status "  • Custom MongoDB URL provided"
        [ ! -z "$SMARTGLIDING_JWT_SECRET" ] && print_status "  • Custom JWT secret provided"
        [ ! -z "$SMARTGLIDING_WEBHOOK_KEY" ] && print_status "  • Custom webhook key provided"
        echo
    fi
    
    # Check if we're in interactive mode
    if [ -t 0 ] && [ -t 1 ]; then
        INTERACTIVE_MODE=true
        print_status "Interactive mode detected - you can customize the installation"
    else
        INTERACTIVE_MODE=false
        print_warning "Non-interactive mode detected (running via pipe)"
        print_status "Using secure defaults for installation..."
        print_status "To customize settings, you can either:"
        print_status "  1. Download and run the script directly:"
        print_status "     wget https://raw.githubusercontent.com/Kevinvincentals/smartgliding-installer/main/install.sh"
        print_status "     chmod +x install.sh && ./install.sh"
        print_status "  2. Or use environment variables:"
        print_status "     SMARTGLIDING_MONGODB_URL='your-url' curl ... | bash"
        print_status "     SMARTGLIDING_JWT_SECRET='your-secret' curl ... | bash"
        print_status "     SMARTGLIDING_WEBHOOK_KEY='your-key' curl ... | bash"
        echo
    fi
    
    # Database configuration
    if [ ! -z "$SMARTGLIDING_MONGODB_URL" ]; then
        # Environment variable provided
        MONGODB_URL="$SMARTGLIDING_MONGODB_URL"
        if [[ $MONGODB_URL =~ ^mongodb(\+srv)?:// ]]; then
            USE_EXTERNAL_DB=true
            print_success "Using external MongoDB from environment: ${MONGODB_URL:0:20}..."
        else
            print_error "Invalid SMARTGLIDING_MONGODB_URL format. Please ensure it starts with mongodb:// or mongodb+srv://"
            exit 1
        fi
    elif [ "$INTERACTIVE_MODE" = true ]; then
        print_status "Database Configuration"
        echo "SmartGliding can use either an embedded MongoDB or connect to your existing database."
        echo
        read -p "Do you have your own MongoDB database you want to use? (y/N): " -n 1 -r
        echo
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            USE_EXTERNAL_DB=true
            print_status "Please provide your MongoDB connection string."
            echo "Example: mongodb://username:password@your-server:27017/smartgliding?replicaSet=rs0"
            echo "Or: mongodb+srv://username:password@cluster.mongodb.net/smartgliding"
            echo
            read -p "MongoDB URL: " MONGODB_URL
            
            # Validate URL format
            if [[ ! $MONGODB_URL =~ ^mongodb(\+srv)?:// ]]; then
                print_error "Invalid MongoDB URL format. Please ensure it starts with mongodb:// or mongodb+srv://"
                exit 1
            fi
            
            print_success "External MongoDB configured: $MONGODB_URL"
        else
            USE_EXTERNAL_DB=false
            print_success "Will use embedded MongoDB with automatic setup"
            MONGODB_URL="mongodb://mongodb:27017/smartgliding?replicaSet=rs0"
        fi
    else
        # Non-interactive mode - use embedded database by default
        USE_EXTERNAL_DB=false
        MONGODB_URL="mongodb://mongodb:27017/smartgliding?replicaSet=rs0"
        print_success "Using embedded MongoDB (default for non-interactive mode)"
    fi
    
    echo
    print_status "Security Configuration"
    print_status "Generating secure random values for JWT secret and API keys..."
    
    # Generate random secrets or use environment variables
    if [ ! -z "$SMARTGLIDING_JWT_SECRET" ]; then
        JWT_SECRET="$SMARTGLIDING_JWT_SECRET"
        print_success "Using JWT secret from environment: ${JWT_SECRET:0:8}... (${#JWT_SECRET} characters)"
    else
        JWT_SECRET=$(generate_random_string 64)
        print_success "Generated JWT secret: ${JWT_SECRET:0:8}... (64 characters)"
    fi
    
    if [ ! -z "$SMARTGLIDING_WEBHOOK_KEY" ]; then
        WEBHOOK_API_KEY="$SMARTGLIDING_WEBHOOK_KEY"
        print_success "Using webhook key from environment: ${WEBHOOK_API_KEY:0:8}... (${#WEBHOOK_API_KEY} characters)"
    else
        WEBHOOK_API_KEY=$(generate_random_string 32)
        print_success "Generated webhook API key: ${WEBHOOK_API_KEY:0:8}... (32 characters)"
    fi
    
    if [ "$INTERACTIVE_MODE" = true ] && [ -z "$SMARTGLIDING_JWT_SECRET" ] && [ -z "$SMARTGLIDING_WEBHOOK_KEY" ]; then
        echo
        read -p "Do you want to customize these security settings? (y/N): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo
            print_status "Current JWT Secret: $JWT_SECRET"
            read -p "Enter custom JWT secret (or press Enter to keep current): " CUSTOM_JWT
            if [ ! -z "$CUSTOM_JWT" ]; then
                JWT_SECRET="$CUSTOM_JWT"
                print_success "JWT secret updated"
            fi
            
            echo
            print_status "Current Webhook API Key: $WEBHOOK_API_KEY"
            read -p "Enter custom webhook API key (or press Enter to keep current): " CUSTOM_WEBHOOK
            if [ ! -z "$CUSTOM_WEBHOOK" ]; then
                WEBHOOK_API_KEY="$CUSTOM_WEBHOOK"
                print_success "Webhook API key updated"
            fi
        fi
    elif [ ! -z "$SMARTGLIDING_JWT_SECRET" ] || [ ! -z "$SMARTGLIDING_WEBHOOK_KEY" ]; then
        print_status "Using provided environment variables for security settings"
    else
        print_status "Using generated secure defaults (non-interactive mode)"
    fi
    
    echo
    print_success "Configuration completed!"
    print_status "Database: $([ "$USE_EXTERNAL_DB" = true ] && echo "External MongoDB" || echo "Embedded MongoDB")"
    print_status "JWT Secret: ${JWT_SECRET:0:8}... (${#JWT_SECRET} characters)"
    print_status "Webhook API Key: ${WEBHOOK_API_KEY:0:8}... (${#WEBHOOK_API_KEY} characters)"
    echo
}

# Create installation directory and docker-compose.yml
create_installation() {
    print_status "Creating installation files..."
    
    # Set sudo prefix based on whether we're root or not
    local SUDO_PREFIX=""
    if [ "$RUNNING_AS_ROOT" = false ]; then
        SUDO_PREFIX="sudo"
    fi
    
    # Check if directory already has files
    if [ -f "$INSTALL_DIR/docker-compose.yml" ]; then
        print_warning "SmartGliding installation already exists in $INSTALL_DIR"
        read -p "Do you want to continue and overwrite? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_error "Installation cancelled"
            exit 1
        fi
    fi
    
    print_status "Creating docker-compose.yml with your configuration..."
    
    # Create temporary file with correct permissions
    TEMP_COMPOSE=$(mktemp)
    
    # Generate docker-compose.yml based on database choice
    if [ "$USE_EXTERNAL_DB" = true ]; then
        # External database - no MongoDB services
        cat > "$TEMP_COMPOSE" << EOF
services:
  smartgliding-web:
    image: ghcr.io/kevinvincentals/smartgliding-web:latest
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - DATABASE_URL=$MONGODB_URL
      - JWT_SECRET=$JWT_SECRET
      - PLANE_TRACKER_WS_URL=ws://smartgliding-ogn-backend:8765
      - WEBHOOK_API_KEY=$WEBHOOK_API_KEY
    depends_on:
      smartgliding-ogn-backend:
        condition: service_started
    restart: unless-stopped
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
    user: "\${SMARTGLIDING_UID}:\${SMARTGLIDING_GID}"

  smartgliding-ogn-backend:
    image: ghcr.io/kevinvincentals/smartgliding-ogn-backend:latest
    container_name: smartgliding-ogn-backend
    ports:
      - "8765:8765"
    volumes:
      - ogn_data:/data
    environment:
      - DATABASE_URL=$MONGODB_URL
      - WEBHOOK_URL=http://smartgliding-web:3000/api/webhooks/flights
      - WEBHOOK_API_KEY=$WEBHOOK_API_KEY
      - WEBHOOK_ENABLED=true
    restart: unless-stopped
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
    user: "\${SMARTGLIDING_UID}:\${SMARTGLIDING_GID}"

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
    else
        # Embedded database - include MongoDB services
        cat > "$TEMP_COMPOSE" << EOF
services:
  smartgliding-web:
    image: ghcr.io/kevinvincentals/smartgliding-web:latest
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - DATABASE_URL=$MONGODB_URL
      - JWT_SECRET=$JWT_SECRET
      - PLANE_TRACKER_WS_URL=ws://smartgliding-ogn-backend:8765
      - WEBHOOK_API_KEY=$WEBHOOK_API_KEY
    depends_on:
      mongodb-setup:
        condition: service_completed_successfully
      smartgliding-ogn-backend:
        condition: service_started
    restart: unless-stopped
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
    user: "\${SMARTGLIDING_UID}:\${SMARTGLIDING_GID}"

  smartgliding-ogn-backend:
    image: ghcr.io/kevinvincentals/smartgliding-ogn-backend:latest
    container_name: smartgliding-ogn-backend
    ports:
      - "8765:8765"
    volumes:
      - ogn_data:/data
    environment:
      - DATABASE_URL=$MONGODB_URL
      - WEBHOOK_URL=http://smartgliding-web:3000/api/webhooks/flights
      - WEBHOOK_API_KEY=$WEBHOOK_API_KEY
      - WEBHOOK_ENABLED=true
    depends_on:
      mongodb-setup:
        condition: service_completed_successfully
    restart: unless-stopped
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
    user: "\${SMARTGLIDING_UID}:\${SMARTGLIDING_GID}"

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
    user: "\${SMARTGLIDING_UID}:\${SMARTGLIDING_GID}"

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
    user: "\${SMARTGLIDING_UID}:\${SMARTGLIDING_GID}"

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
    
    # Get smartgliding user UID and GID
    SMARTGLIDING_UID=$(id -u "$SMARTGLIDING_USER")
    SMARTGLIDING_GID=$(id -g "$SMARTGLIDING_USER")
    
    # Move the compose file to the installation directory with proper ownership
    $SUDO_PREFIX mv "$TEMP_COMPOSE" "$INSTALL_DIR/docker-compose.yml"
    $SUDO_PREFIX chown "$SMARTGLIDING_USER:$SMARTGLIDING_USER" "$INSTALL_DIR/docker-compose.yml"
    
    # Create .env file with user mapping and configuration
    $SUDO_PREFIX tee "$INSTALL_DIR/.env" > /dev/null << EOF
SMARTGLIDING_UID=$SMARTGLIDING_UID
SMARTGLIDING_GID=$SMARTGLIDING_GID
USE_EXTERNAL_DB=$USE_EXTERNAL_DB
DATABASE_URL=$MONGODB_URL
JWT_SECRET=$JWT_SECRET
WEBHOOK_API_KEY=$WEBHOOK_API_KEY
EOF
    $SUDO_PREFIX chown "$SMARTGLIDING_USER:$SMARTGLIDING_USER" "$INSTALL_DIR/.env"
    
    # Create database directory with correct ownership (only if using embedded DB)
    if [ "$USE_EXTERNAL_DB" = false ]; then
        $SUDO_PREFIX mkdir -p "$INSTALL_DIR/database"
        $SUDO_PREFIX chown "$SMARTGLIDING_USER:$SMARTGLIDING_USER" "$INSTALL_DIR/database"
        print_success "Database directory created for embedded MongoDB"
    fi
    
    print_success "Installation files created in $INSTALL_DIR"
    print_status "Database type: $([ "$USE_EXTERNAL_DB" = true ] && echo "External MongoDB" || echo "Embedded MongoDB")"
}

# Deploy the stack
deploy_stack() {
    print_status "Deploying SmartGliding platform..."
    
    # Change to installation directory
    cd "$INSTALL_DIR"
    
    # Pull images first
    print_status "Pulling Docker images (this may take a few minutes)..."
    sudo -u "$SMARTGLIDING_USER" docker compose pull
    
    # Start services
    print_status "Starting services..."
    sudo -u "$SMARTGLIDING_USER" docker compose up -d
    
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
    echo -e "${BLUE}Configuration Summary:${NC}"
    echo "• Database: $([ "$USE_EXTERNAL_DB" = true ] && echo "External MongoDB" || echo "Embedded MongoDB")"
    echo "• Database URL: $MONGODB_URL"
    echo "• JWT Secret: ${JWT_SECRET:0:12}... (${#JWT_SECRET} characters)"
    echo "• Webhook API Key: ${WEBHOOK_API_KEY:0:8}... (${#WEBHOOK_API_KEY} characters)"
    echo "• Installation Directory: $INSTALL_DIR"
    echo "• Service User: $SMARTGLIDING_USER"
    echo
    echo -e "${BLUE}Next Steps:${NC}"
    echo "1. Open your web browser"
    echo "2. Navigate to: http://$(hostname -I | awk '{print $1}'):3000/install"
    echo "   (or http://localhost:3000/install if accessing locally)"
    echo "3. Complete the initial setup with your club information"
    echo
    echo -e "${BLUE}Useful Commands:${NC}"
    echo "• View logs:      sudo -u $SMARTGLIDING_USER docker compose -f $INSTALL_DIR/docker-compose.yml logs"
    echo "• Stop services:  sudo -u $SMARTGLIDING_USER docker compose -f $INSTALL_DIR/docker-compose.yml down"
    echo "• Start services: sudo -u $SMARTGLIDING_USER docker compose -f $INSTALL_DIR/docker-compose.yml up -d"
    echo "• Update system:  sudo -u $SMARTGLIDING_USER docker compose -f $INSTALL_DIR/docker-compose.yml pull && sudo -u $SMARTGLIDING_USER docker compose -f $INSTALL_DIR/docker-compose.yml up -d"
    echo
    echo -e "${YELLOW}Configuration stored in: $INSTALL_DIR/.env${NC}"
    if [ "$USE_EXTERNAL_DB" = false ]; then
        echo -e "${YELLOW}Database files stored in: $INSTALL_DIR/database${NC}"
    fi
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
    create_smartgliding_user
    configure_installation
    create_installation
    deploy_stack
    wait_for_services
    show_completion
}

# Run main function
main "$@" 