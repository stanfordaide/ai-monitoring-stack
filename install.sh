#!/bin/bash

# AI Monitoring Stack Installation Script
# This script installs the monitoring stack to /opt/monitoring

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TARGET_DIR="/opt/monitoring"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/monitoring-install.log"

# Logging function
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if docker is installed
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check if docker-compose is available (either as plugin or standalone)
    if ! docker compose version &> /dev/null && ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    # Check if docker service is running
    if ! systemctl is-active --quiet docker; then
        log_warning "Docker service is not running. Starting Docker..."
        systemctl start docker
        systemctl enable docker
    fi
    
    log_success "Prerequisites check completed"
}

# Create target directory
create_target_directory() {
    log "Creating target directory: $TARGET_DIR"
    
    if [[ -d "$TARGET_DIR" ]]; then
        log_warning "Target directory already exists. Backing up to ${TARGET_DIR}.backup.$(date +%s)"
        mv "$TARGET_DIR" "${TARGET_DIR}.backup.$(date +%s)"
    fi
    
    mkdir -p "$TARGET_DIR"
    log_success "Target directory created"
}

# Copy files to target directory
copy_files() {
    log "Copying files from $SCRIPT_DIR to $TARGET_DIR..."
    
    # Copy all files except the install script itself
    find "$SCRIPT_DIR" -maxdepth 1 -type f -name "*.yml" -o -name "*.yaml" | while read -r file; do
        log "Copying $(basename "$file")..."
        cp "$file" "$TARGET_DIR/"
    done
    
    # Copy monitoring manager script
    if [[ -f "$SCRIPT_DIR/monitoring-manager.sh" ]]; then
        log "Copying monitoring manager script..."
        cp "$SCRIPT_DIR/monitoring-manager.sh" "$TARGET_DIR/"
        chmod +x "$TARGET_DIR/monitoring-manager.sh"
    fi
    
    # Copy README file
    if [[ -f "$SCRIPT_DIR/README.md" ]]; then
        log "Copying README file..."
        cp "$SCRIPT_DIR/README.md" "$TARGET_DIR/"
    fi
    
    # Copy config directory
    if [[ -d "$SCRIPT_DIR/config" ]]; then
        log "Copying config directory..."
        cp -r "$SCRIPT_DIR/config" "$TARGET_DIR/"
    fi
    
    # Copy monitoring-binds directory if it exists
    if [[ -d "$SCRIPT_DIR/monitoring-binds" ]]; then
        log "Copying existing monitoring-binds directory..."
        cp -r "$SCRIPT_DIR/monitoring-binds" "$TARGET_DIR/"
    fi
    
    log_success "Files copied successfully"
}

# Create bind mount directories
create_bind_directories() {
    log "Creating bind mount directories..."
    
    local bind_dirs=(
        "monitoring-binds/grafana/data"
        "monitoring-binds/influxdb/data"
        "monitoring-binds/influxdb/config"
        "monitoring-binds/prometheus/data"
        "monitoring-binds/alertmanager/data"
        "monitoring-binds/pushgateway/data"
        "monitoring-binds/graphite/conf"
        "monitoring-binds/graphite/storage"
        "monitoring-binds/graphite/statsd_config"
    )
    
    for dir in "${bind_dirs[@]}"; do
        local full_path="$TARGET_DIR/$dir"
        if [[ ! -d "$full_path" ]]; then
            log "Creating directory: $full_path"
            mkdir -p "$full_path"
        else
            log "Directory already exists: $full_path"
        fi
    done
    
    log_success "Bind mount directories created"
}

# Set proper permissions
set_permissions() {
    log "Setting proper permissions..."
    
    # Set ownership to the user who will run docker (typically the user who ran sudo)
    local actual_user="${SUDO_USER:-$(whoami)}"
    local actual_group="${SUDO_USER:-$(whoami)}"
    
    # Get the actual user's group
    if [[ -n "$SUDO_USER" ]]; then
        actual_group=$(id -gn "$SUDO_USER")
    fi
    
    log "Setting ownership to $actual_user:$actual_group"
    chown -R "$actual_user:$actual_group" "$TARGET_DIR"
    
    # Set appropriate permissions
    find "$TARGET_DIR" -type d -exec chmod 755 {} \;
    find "$TARGET_DIR" -type f -exec chmod 644 {} \;
    
    # Make sure docker-compose.yml is readable
    chmod 644 "$TARGET_DIR/docker-compose.yml"
    
    # Set specific permissions for Docker containers that run as non-root users
    log "Setting Docker container-specific permissions..."
    
    # Grafana runs as UID 472
    if [[ -d "$TARGET_DIR/monitoring-binds/grafana" ]]; then
        chown -R 472:472 "$TARGET_DIR/monitoring-binds/grafana"
        log "Set Grafana permissions (UID 472)"
    fi
    
    # Prometheus runs as UID 65534 (nobody)
    if [[ -d "$TARGET_DIR/monitoring-binds/prometheus" ]]; then
        chown -R 65534:65534 "$TARGET_DIR/monitoring-binds/prometheus"
        log "Set Prometheus permissions (UID 65534)"
    fi
    
    # AlertManager runs as UID 65534 (nobody)
    if [[ -d "$TARGET_DIR/monitoring-binds/alertmanager" ]]; then
        chown -R 65534:65534 "$TARGET_DIR/monitoring-binds/alertmanager"
        log "Set AlertManager permissions (UID 65534)"
    fi
    
    # Pushgateway runs as UID 65534 (nobody)
    if [[ -d "$TARGET_DIR/monitoring-binds/pushgateway" ]]; then
        chown -R 65534:65534 "$TARGET_DIR/monitoring-binds/pushgateway"
        log "Set Pushgateway permissions (UID 65534)"
    fi
    
    # InfluxDB runs as UID 1000
    if [[ -d "$TARGET_DIR/monitoring-binds/influxdb" ]]; then
        chown -R 1000:1000 "$TARGET_DIR/monitoring-binds/influxdb"
        log "Set InfluxDB permissions (UID 1000)"
    fi
    
    # Graphite runs as root, so keep default ownership but ensure it's writable
    if [[ -d "$TARGET_DIR/monitoring-binds/graphite" ]]; then
        chmod -R 755 "$TARGET_DIR/monitoring-binds/graphite"
        log "Set Graphite permissions"
    fi
    
    log_success "Permissions set successfully"
}

# Update docker-compose paths
update_compose_paths() {
    log "Updating docker-compose.yml paths..."
    
    local compose_file="$TARGET_DIR/docker-compose.yml"
    
    if [[ ! -f "$compose_file" ]]; then
        log_error "docker-compose.yml not found in target directory"
        exit 1
    fi
    
    # Update relative paths to absolute paths
    sed -i "s|device: \./monitoring-binds/|device: $TARGET_DIR/monitoring-binds/|g" "$compose_file"
    sed -i "s|device: \./config/|device: $TARGET_DIR/config/|g" "$compose_file"
    
    log_success "Docker-compose paths updated"
}

# Start the monitoring stack
start_monitoring_stack() {
    log "Starting monitoring stack..."
    
    cd "$TARGET_DIR"
    
    # Determine which docker-compose command to use
    if docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
    else
        COMPOSE_CMD="docker-compose"
    fi
    
    # Pull images first
    log "Pulling Docker images..."
    $COMPOSE_CMD pull
    
    # Start the stack
    log "Starting containers..."
    $COMPOSE_CMD up -d
    
    # Wait a moment for containers to start
    sleep 10
    
    # Check container status
    log "Checking container status..."
    $COMPOSE_CMD ps
    
    log_success "Monitoring stack started successfully"
}

# Display access information
display_access_info() {
    log_success "Installation completed successfully!"
    echo ""
    echo "=========================================="
    echo "  AI Monitoring Stack Access Information"
    echo "=========================================="
    echo ""
    echo "📊 Grafana Dashboard:"
    echo "   URL: http://localhost:3000"
    echo "   Username: admin"
    echo "   Password: helloaide123"
    echo ""
    echo "📈 Prometheus:"
    echo "   URL: http://localhost:9092"
    echo ""
    echo "📊 InfluxDB:"
    echo "   URL: http://localhost:8086"
    echo "   Username: admin"
    echo "   Password: helloaide123"
    echo "   Organization: mercure-ai"
    echo "   Bucket: ai-inference-spc"
    echo ""
    echo "📊 Graphite:"
    echo "   Metrics endpoint: localhost:2003-2004"
    echo "   StatsD endpoint: localhost:8125 (UDP)"
    echo ""
    echo "🚨 AlertManager:"
    echo "   URL: http://localhost:9093"
    echo ""
    echo "📤 Pushgateway:"
    echo "   URL: http://localhost:9091"
    echo ""
    echo "📁 Installation Directory: $TARGET_DIR"
    echo "📝 Log File: $LOG_FILE"
    echo ""
    echo "To manage the stack:"
    echo "  cd $TARGET_DIR"
    echo "  ./monitoring-manager.sh start     # Start stack"
    echo "  ./monitoring-manager.sh stop      # Stop stack"
    echo "  ./monitoring-manager.sh restart   # Restart stack"
    echo "  ./monitoring-manager.sh status    # Check status"
    echo "  ./monitoring-manager.sh logs      # View logs"
    echo "  ./monitoring-manager.sh help      # See all commands"
    echo ""
    echo "Or use docker compose directly:"
    echo "  docker compose up -d    # Start"
    echo "  docker compose down     # Stop"
    echo "  docker compose logs -f  # View logs"
    echo ""
}

# Cleanup function
cleanup() {
    if [[ $? -ne 0 ]]; then
        log_error "Installation failed. Check the log file: $LOG_FILE"
        exit 1
    fi
}

# Main installation function
main() {
    log "Starting AI Monitoring Stack installation..."
    log "Source directory: $SCRIPT_DIR"
    log "Target directory: $TARGET_DIR"
    
    # Set trap for cleanup
    trap cleanup EXIT
    
    # Run installation steps
    check_root
    check_prerequisites
    create_target_directory
    copy_files
    create_bind_directories
    update_compose_paths
    set_permissions
    start_monitoring_stack
    display_access_info
    
    log_success "Installation completed successfully!"
}

# Show usage if help is requested
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    echo "AI Monitoring Stack Installation Script"
    echo ""
    echo "Usage: sudo $0"
    echo ""
    echo "This script will:"
    echo "  1. Copy all monitoring stack files to /opt/monitoring"
    echo "  2. Create necessary bind mount directories"
    echo "  3. Update docker-compose.yml paths"
    echo "  4. Set proper permissions"
    echo "  5. Start the monitoring stack with docker-compose"
    echo ""
    echo "Prerequisites:"
    echo "  - Docker must be installed and running"
    echo "  - Docker Compose must be installed"
    echo "  - Script must be run as root (with sudo)"
    echo ""
    exit 0
fi

# Run main function
main "$@"
