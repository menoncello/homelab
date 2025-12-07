#!/bin/bash
# Homelab System Maintenance Script
# ==================================
# Performs routine maintenance tasks

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "This script requires root privileges. Using sudo..."
        exec sudo "$0" "$@"
    fi
}

# System updates
system_updates() {
    log "Performing system updates..."

    # Update package lists
    apt-get update

    # Upgrade packages
    apt-get upgrade -y

    # Install security updates
    apt-get dist-upgrade -y

    # Remove unused packages
    apt-get autoremove -y
    apt-get autoclean

    success "System updates completed"
}

# Docker maintenance
docker_maintenance() {
    log "Performing Docker maintenance..."

    # Prune unused Docker resources
    docker system prune -af --volumes

    # Clean build cache
    docker builder prune -af

    success "Docker maintenance completed"
}

# Check disk space
check_disk_space() {
    log "Checking disk space..."

    local usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')

    if [[ $usage -gt 85 ]]; then
        error "Disk usage is critically high: ${usage}%"
        log "Running disk cleanup..."

        # Clean Docker
        docker system prune -af

        # Clean package cache
        apt-get clean

        # Clean logs
        find /var/log -type f -name "*.log.*" -mtime +30 -delete 2>/dev/null || true

        # Check space again
        usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
        if [[ $usage -gt 85 ]]; then
            error "Disk usage still high after cleanup: ${usage}%"
        else
            success "Disk usage reduced to: ${usage}%"
        fi
    else
        success "Disk usage is acceptable: ${usage}%"
    fi
}

# Check system resources
check_system_resources() {
    log "Checking system resources..."

    # Memory usage
    local mem_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    if [[ $mem_usage -gt 90 ]]; then
        warning "High memory usage: ${mem_usage}%"
    else
        success "Memory usage: ${mem_usage}%"
    fi

    # Load average
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}')
    local cpu_cores=$(nproc)
    local load_threshold=$((cpu_cores * 2))

    if (( $(echo "$load_avg > $load_threshold" | bc -l) )); then
        warning "High load average: $load_avg (cores: $cpu_cores)"
    else
        success "Load average: $load_avg (cores: $cpu_cores)"
    fi
}

# Service health checks
service_health_checks() {
    log "Checking service health..."

    # Docker services
    local running_containers=$(docker ps --format "{{.Names}}" | wc -l)
    local total_containers=$(docker ps -a --format "{{.Names}}" | wc -l)

    success "Docker containers: $running_containers running, $total_containers total"

    # Check critical services
    local critical_services=("grafana" "prometheus" "jellyfin" "nextcloud" "mysql" "postgresql")
    local failed_services=()

    for service in "${critical_services[@]}"; do
        if docker ps --format "{{.Names}}" | grep -q "$service"; then
            success "$service is running"
        else
            failed_services+=("$service")
        fi
    done

    if [[ ${#failed_services[@]} -gt 0 ]]; then
        warning "Critical services not running:"
        for service in "${failed_services[@]}"; do
            echo "  - $service"
        done
    fi
}

# Log rotation
log_rotation() {
    log "Performing log rotation..."

    # Docker logs
    local containers=$(docker ps --format "{{.Names}}")
    for container in $containers; do
        # Configure log rotation (max 100MB, 5 files)
        docker inspect "$container" | jq -r '.[0].HostConfig.LogConfig["max-size"]' | grep -q "100m" || {
            warning "$container doesn't have log rotation configured"
        }
    done

    # System logs
    logrotate -f /etc/logrotate.conf 2>/dev/null || warning "logrotate not available"

    success "Log rotation completed"
}

# Security checks
security_checks() {
    log "Performing security checks..."

    # Check for failed login attempts
    if [[ -f /var/log/auth.log ]]; then
        local failed_logins=$(grep "Failed password" /var/log/auth.log | wc -l)
        if [[ $failed_logins -gt 100 ]]; then
            warning "High number of failed login attempts: $failed_logins"
        fi
    fi

    # Check for open ports
    local open_ports=$(netstat -tuln | grep LISTEN | wc -l)
    success "Open ports: $open_ports"

    # Check file permissions
    find /etc -type f -perm /o+w -exec ls -la {} \; 2>/dev/null | head -5 || success "No world-writable files in /etc"
}

# Backup database backups
backup_databases() {
    log "Creating database backups..."

    local backup_dir="/opt/homelab-backups/databases"
    mkdir -p "$backup_dir"

    # MySQL backup
    local mysql_containers=$(docker ps --format "{{.Names}}" | grep mysql)
    for container in $mysql_containers; do
        log "Creating MySQL backup for $container"
        docker exec "$container" mysqldump --single-transaction -u root --all-databases \
            > "$backup_dir/mysql_${container}_$(date +%Y%m%d).sql" 2>/dev/null || warning "MySQL backup failed for $container"
    done

    # PostgreSQL backup
    local postgres_containers=$(docker ps --format "{{.Names}}" | grep postgres)
    for container in $postgres_containers; do
        log "Creating PostgreSQL backup for $container"
        docker exec "$container" pg_dumpall -U postgres \
            > "$backup_dir/postgresql_${container}_$(date +%Y%m%d).sql" 2>/dev/null || warning "PostgreSQL backup failed for $container"
    done

    # Cleanup old database backups (keep last 7 days)
    find "$backup_dir" -name "*.sql" -mtime +7 -delete 2>/dev/null || true

    success "Database backups completed"
}

# Performance optimization
performance_optimization() {
    log "Performing performance optimization..."

    # Clear system caches
    sync
    echo 3 > /proc/sys/vm/drop_caches
    success "System caches cleared"

    # Optimize Docker
    # Prune unused images and containers
    docker system prune -f --volumes > /dev/null

    # Update Docker daemon config for better performance
    if ! grep -q "default-ulimits" /etc/docker/daemon.json 2>/dev/null; then
        log "Optimizing Docker configuration..."
        # This would require manual editing or proper JSON handling
        warning "Manual Docker optimization may be needed"
    fi

    success "Performance optimization completed"
}

# Generate maintenance report
generate_report() {
    log "Generating maintenance report..."

    local report_file="/var/log/homelab-maintenance-$(date +%Y%m%d).log"

    cat > "$report_file" << EOF
Homelab Maintenance Report
=========================
Date: $(date)
Hostname: $(hostname)
Uptime: $(uptime -p)

System Information:
- OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')
- Kernel: $(uname -r)
- CPU Cores: $(nproc)
- Memory: $(free -h | awk 'NR==1{print $2}')

Resource Usage:
- Disk Usage: $(df -h / | awk 'NR==2 {print $5}')
- Memory Usage: $(free | awk 'NR==2{printf "%.1f%%", $3*100/$2}')
- Load Average: $(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}')

Docker Status:
- Running Containers: $(docker ps --format "{{.Names}}" | wc -l)
- Total Containers: $(docker ps -a --format "{{.Names}}" | wc -l)
- Images: $(docker images --format "{{.Repository}}" | grep -v "<none>" | wc -l)

Services Status:
$(docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | head -10)

Maintenance Actions Performed:
- System updates
- Docker maintenance
- Disk space cleanup
- Service health checks
- Log rotation
- Security checks
- Database backups
- Performance optimization

EOF

    success "Maintenance report generated: $report_file"
}

# Main function
main() {
    echo "🔧 Homelab System Maintenance Script"
    echo "======================================"
    echo

    check_root

    # Parse arguments
    case "${1:-full}" in
        "full")
            system_updates
            docker_maintenance
            check_disk_space
            check_system_resources
            service_health_checks
            log_rotation
            security_checks
            backup_databases
            performance_optimization
            generate_report
            ;;
        "updates")
            system_updates
            ;;
        "docker")
            docker_maintenance
            ;;
        "disk")
            check_disk_space
            ;;
        "health")
            check_system_resources
            service_health_checks
            ;;
        "logs")
            log_rotation
            ;;
        "security")
            security_checks
            ;;
        "backup")
            backup_databases
            ;;
        "performance")
            performance_optimization
            ;;
        "report")
            generate_report
            ;;
        "help"|"-h"|"--help")
            echo "Homelab System Maintenance Script"
            echo
            echo "Usage: $0 [command]"
            echo
            echo "Commands:"
            echo "  full       - Complete maintenance (default)"
            echo "  updates    - System package updates only"
            echo "  docker     - Docker maintenance only"
            echo "  disk       - Disk space checks and cleanup"
            echo "  health     - System resource and health checks"
            echo "  logs       - Log rotation only"
            echo "  security   - Security checks only"
            echo "  backup     - Database backups only"
            echo "  performance- Performance optimization only"
            echo "  report     - Generate maintenance report only"
            echo "  help       - Show this help"
            echo
            exit 0
            ;;
        *)
            error "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac

    success "System maintenance completed successfully! 🎉"
}

# Error handling
trap 'error "Maintenance failed at line $LINENO"' ERR

# Run main function with all arguments
main "$@"