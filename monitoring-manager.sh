#!/bin/bash

# AI Monitoring Stack Manager
# Comprehensive management script for the monitoring stack

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
MONITORING_DIR="/opt/monitoring"
COMPOSE_FILE="$MONITORING_DIR/docker-compose.yml"
LOG_FILE="/var/log/monitoring-manager.log"
BACKUP_DIR="/opt/monitoring-backups"

# Determine docker-compose command
if command -v docker &> /dev/null && docker compose version &> /dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
else
    echo -e "${RED}Error: Neither 'docker compose' nor 'docker-compose' found${NC}"
    exit 1
fi

# Logging function
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE" 2>/dev/null || true
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "[ERROR] $1" >> "$LOG_FILE" 2>/dev/null || true
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    echo "[SUCCESS] $1" >> "$LOG_FILE" 2>/dev/null || true
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    echo "[WARNING] $1" >> "$LOG_FILE" 2>/dev/null || true
}

log_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
    echo "[INFO] $1" >> "$LOG_FILE" 2>/dev/null || true
}

# Check if monitoring directory exists
check_installation() {
    if [[ ! -d "$MONITORING_DIR" ]]; then
        log_error "Monitoring directory not found: $MONITORING_DIR"
        log_error "Please run the installation script first"
        exit 1
    fi
    
    if [[ ! -f "$COMPOSE_FILE" ]]; then
        log_error "Docker compose file not found: $COMPOSE_FILE"
        exit 1
    fi
    
    cd "$MONITORING_DIR"
}

# Start the monitoring stack
start_stack() {
    log "Starting monitoring stack..."
    check_installation
    
    $COMPOSE_CMD up -d
    
    log_success "Monitoring stack started"
    sleep 5
    show_status
}

# Stop the monitoring stack
stop_stack() {
    log "Stopping monitoring stack..."
    check_installation
    
    $COMPOSE_CMD down
    
    log_success "Monitoring stack stopped"
}

# Restart the monitoring stack
restart_stack() {
    log "Restarting monitoring stack..."
    check_installation
    
    $COMPOSE_CMD down
    sleep 3
    $COMPOSE_CMD up -d
    
    log_success "Monitoring stack restarted"
    sleep 5
    show_status
}

# Show stack status
show_status() {
    log_info "Checking monitoring stack status..."
    check_installation
    
    echo -e "\n${PURPLE}=== Container Status ===${NC}"
    $COMPOSE_CMD ps
    
    echo -e "\n${PURPLE}=== Service Health ===${NC}"
    check_service_health
}

# Check individual service health
check_service_health() {
    local services=(
        "grafana:3000:/api/health:Grafana"
        "prometheus:9090/-/healthy:Prometheus"
        "influxdb:8086/ping:InfluxDB"
        "alertmanager:9093/-/healthy:AlertManager"
        "prometheus-pushgateway:9091/-/healthy:Pushgateway"
    )
    
    for service in "${services[@]}"; do
        IFS=':' read -r container port endpoint name <<< "$service"
        
        if docker ps --format "table {{.Names}}" | grep -q "^${container}$"; then
            if curl -f -s "http://localhost:${port}${endpoint}" > /dev/null 2>&1; then
                echo -e "${GREEN}✓${NC} $name is healthy"
            else
                echo -e "${RED}✗${NC} $name is unhealthy"
            fi
        else
            echo -e "${RED}✗${NC} $name container is not running"
        fi
    done
    
    # Special check for Graphite (no health endpoint)
    if docker ps --format "table {{.Names}}" | grep -q "^graphite$"; then
        echo -e "${GREEN}✓${NC} Graphite container is running"
    else
        echo -e "${RED}✗${NC} Graphite container is not running"
    fi
}

# Show logs
show_logs() {
    check_installation
    
    local service="$1"
    local follow="$2"
    
    if [[ -n "$service" ]]; then
        log_info "Showing logs for service: $service"
        if [[ "$follow" == "-f" ]]; then
            $COMPOSE_CMD logs -f "$service"
        else
            $COMPOSE_CMD logs --tail=100 "$service"
        fi
    else
        log_info "Showing logs for all services"
        if [[ "$follow" == "-f" ]]; then
            $COMPOSE_CMD logs -f
        else
            $COMPOSE_CMD logs --tail=50
        fi
    fi
}

# Pull latest images
pull_images() {
    log "Pulling latest Docker images..."
    check_installation
    
    $COMPOSE_CMD pull
    log_success "Images updated. Run 'restart' to use new images."
}

# Update stack (pull images and restart)
update_stack() {
    log "Updating monitoring stack..."
    check_installation
    
    $COMPOSE_CMD pull
    $COMPOSE_CMD down
    $COMPOSE_CMD up -d
    
    log_success "Monitoring stack updated and restarted"
    sleep 5
    show_status
}

# Backup data
backup_data() {
    log "Creating backup of monitoring data..."
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="$BACKUP_DIR/backup_$timestamp"
    
    # Create backup directory
    mkdir -p "$backup_path"
    
    # Stop services for consistent backup
    log "Stopping services for backup..."
    stop_stack
    
    # Backup bind mount data
    log "Backing up data directories..."
    if [[ -d "$MONITORING_DIR/monitoring-binds" ]]; then
        cp -r "$MONITORING_DIR/monitoring-binds" "$backup_path/"
        log_success "Data backed up to: $backup_path"
    else
        log_error "No data directory found to backup"
        return 1
    fi
    
    # Backup configuration
    log "Backing up configuration..."
    if [[ -d "$MONITORING_DIR/config" ]]; then
        cp -r "$MONITORING_DIR/config" "$backup_path/"
    fi
    
    # Backup docker-compose file
    cp "$COMPOSE_FILE" "$backup_path/"
    
    # Create backup info file
    cat > "$backup_path/backup_info.txt" << EOF
Backup created: $(date)
Source directory: $MONITORING_DIR
Backup directory: $backup_path
Docker Compose version: $($COMPOSE_CMD version --short 2>/dev/null || echo "Unknown")
EOF
    
    # Restart services
    log "Restarting services..."
    start_stack
    
    log_success "Backup completed: $backup_path"
}

# Restore data from backup
restore_data() {
    local backup_path="$1"
    
    if [[ -z "$backup_path" ]]; then
        log_error "Please specify backup path"
        list_backups
        return 1
    fi
    
    if [[ ! -d "$backup_path" ]]; then
        log_error "Backup directory not found: $backup_path"
        return 1
    fi
    
    log_warning "This will overwrite current data. Are you sure? (y/N)"
    read -r confirmation
    if [[ "$confirmation" != "y" && "$confirmation" != "Y" ]]; then
        log "Restore cancelled"
        return 0
    fi
    
    log "Restoring from backup: $backup_path"
    
    # Stop services
    stop_stack
    
    # Restore data
    if [[ -d "$backup_path/monitoring-binds" ]]; then
        rm -rf "$MONITORING_DIR/monitoring-binds"
        cp -r "$backup_path/monitoring-binds" "$MONITORING_DIR/"
        log_success "Data restored"
    fi
    
    # Restore config if available
    if [[ -d "$backup_path/config" ]]; then
        rm -rf "$MONITORING_DIR/config"
        cp -r "$backup_path/config" "$MONITORING_DIR/"
        log_success "Configuration restored"
    fi
    
    # Start services
    start_stack
    
    log_success "Restore completed"
}

# List available backups
list_backups() {
    log_info "Available backups:"
    
    if [[ ! -d "$BACKUP_DIR" ]]; then
        log_warning "No backup directory found: $BACKUP_DIR"
        return 0
    fi
    
    local count=0
    for backup in "$BACKUP_DIR"/backup_*; do
        if [[ -d "$backup" ]]; then
            local backup_name=$(basename "$backup")
            local backup_date=""
            if [[ -f "$backup/backup_info.txt" ]]; then
                backup_date=$(grep "Backup created:" "$backup/backup_info.txt" | cut -d: -f2- | xargs)
            fi
            echo -e "  ${CYAN}$backup_name${NC} - $backup_date"
            echo -e "    Path: $backup"
            count=$((count + 1))
        fi
    done
    
    if [[ $count -eq 0 ]]; then
        log_info "No backups found"
    fi
}

# Clean old logs
clean_logs() {
    log "Cleaning old logs..."
    check_installation
    
    # Clean docker logs
    docker system prune -f --volumes
    
    # Truncate manager log if it's too large (>100MB)
    if [[ -f "$LOG_FILE" ]] && [[ $(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0) -gt 104857600 ]]; then
        tail -n 1000 "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
        log_success "Manager log file truncated"
    fi
    
    log_success "Logs cleaned"
}

# Show resource usage
show_resources() {
    log_info "Monitoring stack resource usage:"
    check_installation
    
    echo -e "\n${PURPLE}=== Container Resource Usage ===${NC}"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}" \
        $(docker ps --format "{{.Names}}" | grep -E "(grafana|prometheus|influxdb|alertmanager|pushgateway|graphite)")
    
    echo -e "\n${PURPLE}=== Disk Usage ===${NC}"
    du -sh "$MONITORING_DIR/monitoring-binds"/* 2>/dev/null | sort -hr || log_warning "Could not calculate disk usage"
}

# Show access information
show_access_info() {
    echo -e "\n${PURPLE}=========================================="
    echo -e "  AI Monitoring Stack Access Information"
    echo -e "==========================================${NC}\n"
    
    echo -e "${CYAN}📊 Grafana Dashboard:${NC}"
    echo -e "   URL: http://localhost:3000"
    echo -e "   Username: admin"
    echo -e "   Password: helloaide123\n"
    
    echo -e "${CYAN}📈 Prometheus:${NC}"
    echo -e "   URL: http://localhost:9090\n"
    
    echo -e "${CYAN}📊 InfluxDB:${NC}"
    echo -e "   URL: http://localhost:8086"
    echo -e "   Username: admin"
    echo -e "   Password: helloaide123"
    echo -e "   Organization: mercure-ai"
    echo -e "   Bucket: ai-inference-spc\n"
    
    echo -e "${CYAN}📊 Graphite:${NC}"
    echo -e "   Metrics endpoint: localhost:2003-2004"
    echo -e "   StatsD endpoint: localhost:8125 (UDP)\n"
    
    echo -e "${CYAN}🚨 AlertManager:${NC}"
    echo -e "   URL: http://localhost:9093\n"
    
    echo -e "${CYAN}📤 Pushgateway:${NC}"
    echo -e "   URL: http://localhost:9091\n"
}

# Show help
show_help() {
    echo -e "${PURPLE}AI Monitoring Stack Manager${NC}"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo -e "${CYAN}Commands:${NC}"
    echo "  start                 Start the monitoring stack"
    echo "  stop                  Stop the monitoring stack"
    echo "  restart               Restart the monitoring stack"
    echo "  status                Show stack status and health"
    echo "  logs [service] [-f]   Show logs (optionally follow with -f)"
    echo "  pull                  Pull latest Docker images"
    echo "  update                Pull images and restart stack"
    echo "  backup                Create backup of monitoring data"
    echo "  restore <path>        Restore from backup"
    echo "  list-backups          List available backups"
    echo "  clean                 Clean old logs and unused resources"
    echo "  resources             Show resource usage"
    echo "  info                  Show access information"
    echo "  help                  Show this help message"
    echo ""
    echo -e "${CYAN}Examples:${NC}"
    echo "  $0 start              # Start the monitoring stack"
    echo "  $0 logs grafana       # Show Grafana logs"
    echo "  $0 logs grafana -f    # Follow Grafana logs"
    echo "  $0 backup             # Create a backup"
    echo "  $0 restore /opt/monitoring-backups/backup_20231225_120000"
    echo ""
    echo -e "${CYAN}Files:${NC}"
    echo "  Config: $MONITORING_DIR"
    echo "  Logs: $LOG_FILE"
    echo "  Backups: $BACKUP_DIR"
}

# Main function
main() {
    local command="$1"
    
    case "$command" in
        "start")
            start_stack
            ;;
        "stop")
            stop_stack
            ;;
        "restart")
            restart_stack
            ;;
        "status")
            show_status
            ;;
        "logs")
            show_logs "$2" "$3"
            ;;
        "pull")
            pull_images
            ;;
        "update")
            update_stack
            ;;
        "backup")
            backup_data
            ;;
        "restore")
            restore_data "$2"
            ;;
        "list-backups")
            list_backups
            ;;
        "clean")
            clean_logs
            ;;
        "resources")
            show_resources
            ;;
        "info")
            show_access_info
            ;;
        "help"|"-h"|"--help"|"")
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Create log directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

# Run main function with all arguments
main "$@"
