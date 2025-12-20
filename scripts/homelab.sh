#!/bin/bash
# Homelab Management Script
# ===========================
# Main entry point for all homelab operations

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Help function
show_help() {
    echo -e "${BOLD}🏠 Homelab Management Console${NC}"
    echo -e "${BOLD}============================${NC}"
    echo
    echo "This is the main entry point for managing your Homelab infrastructure."
    echo "Use one of the following commands:"
    echo
    echo -e "${CYAN}Deployment Commands:${NC}"
    echo "  deploy                 Deploy full homelab infrastructure"
    echo "    deploy infra         Deploy infrastructure only"
    echo "    deploy services      Deploy Docker services only"
    echo "    deploy check          Run post-deployment checks"
    echo
    echo -e "${CYAN}Backup Commands:${NC}"
    echo "  backup                 Create full backup"
    echo "    backup volumes       Backup Docker volumes only"
    echo "    backup configs       Backup configurations only"
    echo "    backup databases    Backup databases only"
    echo "  restore <name>         Restore from backup"
    echo "    restore <name> --volumes    Restore volumes only"
    echo "    restore <name> --configs     Restore configs only"
    echo "    restore <name> --databases  Restore databases only"
    echo "    restore <name> --dry-run     Preview restore"
    echo
    echo -e "${CYAN}Update Commands:${NC}"
    echo "  update                 Update all services"
    echo "    update <stack>         Update specific stack"
    echo "    update databases      Update database services"
    echo "    update nginx-proxy    Update reverse proxy"
    echo "    update monitoring    Update monitoring stack"
    echo "    update media          Update media services"
    echo "    update books          Update books services"
    echo "    update prod-services  Update productivity services"
    echo "    update clean          Clean unused Docker resources"
    echo "    update health         Run health checks"
    echo "    update rollback <stack> Rollback specific stack"
    echo
    echo -e "${CYAN}Maintenance Commands:${NC}"
    echo "  maintenance            Run full system maintenance"
    echo "    maintenance updates    System package updates"
    echo "    maintenance docker     Docker maintenance"
    echo "    maintenance disk       Disk space cleanup"
    echo "    maintenance health     System health checks"
    echo "    maintenance logs       Log rotation"
    echo "    maintenance security   Security checks"
    echo "    maintenance backup     Database backups"
    echo "    maintenance performance- Performance optimization"
    echo "    maintenance report     Generate maintenance report"
    echo
    echo -e "${CYAN}Monitoring Commands:${NC}"
    echo "  monitor                Show real-time dashboard"
    echo "    monitor system        System metrics"
    echo "    monitor docker       Docker container metrics"
    echo "    monitor health       Health check status"
    echo "    monitor performance  Performance metrics"
    echo "    monitor network       Network information"
    echo "    monitor report       Generate monitoring report"
    echo "    monitor alert \"msg\"   Send alert message"
    echo "    monitor log          Show alert log"
    echo
    echo -e "${CYAN}Quick Actions:${NC}"
    echo "  status                 Show current status"
    echo "  logs [service]        Show service logs"
    echo "  restart <service>     Restart specific service"
    echo "  stop <service>        Stop specific service"
    echo "  start <service>       Start specific service"
    echo "  ps                    Show running processes"
    echo "  top                   Show system top"
    echo
    echo -e "${CYAN}Configuration:${NC}"
    echo "  config                 Show configuration status"
    echo "  config check          Validate all configurations"
    echo "  config doctor          Run diagnostics"
    echo "  config lid-cover       Configure Helios to ignore lid cover"
    echo
    echo -e "${CYAN}Info:${NC}"
    echo "  info                  Show system information"
    echo "  version               Show script versions"
    echo "  help                  Show this help"
    echo
    echo -e "${YELLOW}Examples:${NC}"
    echo "  ./homelab.sh deploy      # Deploy everything"
    echo "  ./homelab.sh backup      # Create backup"
    echo "  ./homelab.sh update      # Update services"
    echo "  ./homelab.sh monitor     # Show dashboard"
    echo "  ./homelab.sh status      # Show status"
    echo "  ./homelab.sh logs jellyfin  # Show Jellyfin logs"
    echo
}

# Status command
show_status() {
    echo -e "${BOLD}📊 Homelab Status${NC}"
    echo -e "${BOLD}================${NC}"
    echo

    # System status
    echo -e "${CYAN}System Information:${NC}"
    echo "Hostname: $(hostname)"
    echo "Uptime: $(uptime -p)"
    echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')"
    echo "Kernel: $(uname -r)"
    echo "CPU Cores: $(nproc)"
    echo "Memory: $(free -h | awk 'NR==2{print $2}')"
    echo "Disk: $(df -h / | awk 'NR==2{print $2}')"
    echo "Load: $(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}')"
    echo

    # Docker status
    echo -e "${CYAN}Docker Status:${NC}"
    if command -v docker &> /dev/null; then
        echo "Docker Version: $(docker --version | cut -d' ' -f3 | cut -d',' -f1)"
        echo "Running Containers: $(docker ps --format "{{.Names}}" | wc -l)"
        echo "Total Containers: $(docker ps -a --format "{{.Names}}" | wc -l)"
        echo "Images: $(docker images --format "{{.Repository}}" | grep -v "<none>" | wc -l)"
    else
        echo "Docker not installed"
    fi
    echo

    # Terraform status
    echo -e "${CYAN}Infrastructure Status:${NC}"
    if command -v terraform &> /dev/null && [[ -f "$SCRIPT_DIR/../terraform/terraform.tfstate" ]]; then
        cd "$SCRIPT_DIR/../terraform"
        if terraform state list | grep -q "data"; then
            echo "Terraform: State file exists ($(terraform state list | wc -l) resources)"
        else
            echo "Terraform: No resources deployed"
        fi
        cd - > /dev/null
    else
        echo "Terraform not configured"
    fi
}

# Logs command
show_logs() {
    local service="$1"

    if [[ -z "$service" ]]; then
        echo -e "${BOLD}📋 Recent Homelab Logs${NC}"
        echo -e "${BOLD}===================${NC}"
        echo

        # Docker logs
        if command -v docker &> /dev/null; then
            echo -e "${CYAN}Docker Logs (last 10 lines per service):${NC}"
            echo
            docker ps --format "{{.Names}}" | head -10 | while read -r container; do
                echo -e "${YELLOW}$container:${NC}"
                docker logs --tail 10 "$container" 2>/dev/null || echo "No logs available"
                echo
            done
        fi
    else
        echo -e "${BOLD}📋 Logs for: $service${NC}"
        echo -e "${BOLD}==================${NC}"

        # Find and show logs for specific service
        local container=$(docker ps --format "{{.Names}}" | grep -i "$service" | head -1)
        if [[ -n "$container" ]]; then
            echo "Showing logs for $container:"
            docker logs -f "$container"
        else
            echo "Service '$service' not found"
            echo "Available services:"
            docker ps --format "{{.Names}}"
        fi
    fi
}

# Service management
manage_service() {
    local action="$1"
    local service="$2"

    if [[ -z "$service" ]]; then
        error "Service name required"
        echo "Usage: $0 $action <service_name>"
        echo "Available services:"
        docker ps --format "{{.Names}}"
        exit 1
    fi

    local container=$(docker ps --format "{{.Names}}" | grep -i "$service" | head -1)
    if [[ -z "$container" ]]; then
        error "Service '$service' not found"
        echo "Available services:"
        docker ps --format "{{.Names}}"
        exit 1
    fi

    case "$action" in
        "restart")
            log "Restarting $container..."
            docker restart "$container"
            success "$container restarted"
            ;;
        "stop")
            log "Stopping $container..."
            docker stop "$container"
            success "$container stopped"
            ;;
        "start")
            log "Starting $container..."
            docker start "$container"
            success "$container started"
            ;;
        *)
            error "Unknown action: $action"
            exit 1
            ;;
    esac
}

# Configuration commands
show_config() {
    echo -e "${BOLD}⚙️ Configuration Status${NC}"
    echo -e "${BOLD}====================${NC}"
    echo

    # Terraform configuration
    echo -e "${CYAN}Terraform Configuration:${NC}"
    if [[ -f "$SCRIPT_DIR/../terraform/terraform.tfvars" ]]; then
        success "Terraform variables file exists"
        echo "Location: $SCRIPT_DIR/../terraform/terraform.tfvars"
    else
        warning "Terraform variables file not found"
        echo "Expected: $SCRIPT_DIR/../terraform/terraform.tfvars"
    fi

    # Docker environment
    echo
    echo -e "${CYAN}Docker Environment:${NC}"
    if [[ -f "$SCRIPT_DIR/../docker-compose/.env" ]]; then
        success "Docker environment file exists"
        echo "Location: $SCRIPT_DIR/../docker-compose/.env"
        # Check if DOMAIN is set
        if grep -q "^DOMAIN=" "$SCRIPT_DIR/../docker-compose/.env"; then
            success "Domain is configured"
        else
            warning "Domain not configured"
        fi
    else
        warning "Docker environment file not found"
        echo "Expected: $SCRIPT_DIR/../docker-compose/.env"
    fi

    # Scripts directory
    echo
    echo -e "${CYAN}Scripts Directory:${NC}"
    echo "Location: $SCRIPT_DIR"
    echo "Available scripts:"
    find "$SCRIPT_DIR" -name "*.sh" -type f | sort | sed 's|.*/|  |g'
}

# Info command
show_info() {
    echo -e "${BOLD}ℹ️  Homelab Information${NC}"
    echo -e "${BOLD}=====================${NC}"
    echo
    echo "Script Version: 1.0.0"
    echo "Script Directory: $SCRIPT_DIR"
    echo "Working Directory: $(pwd)"
    echo
    echo "Available Commands:"
    echo "  - Deployment: deploy, backup, restore, update"
    echo "  - Maintenance: maintenance, monitor, logs"
    echo "  - Management: status, restart, start, stop"
    echo "  - Configuration: config, info, help"
    echo
}

# Version command
show_version() {
    echo "Homelab Management Script v1.0.0"
    echo
    echo "Component Versions:"
    if command -v docker &> /dev/null; then
        echo "Docker: $(docker --version | cut -d' ' -f3 | cut -d',' -f1)"
    fi
    if command -v terraform &> /dev/null; then
        echo "Terraform: $(terraform version | head -n1 | cut -d' ' -f2)"
    fi
    echo "Bash: $(bash --version | head -n1 | cut -d' ' -f4)"
}

# Execute command
execute_command() {
    local cmd="$1"
    shift
    local args=("$@")

    case "$cmd" in
        "deploy")
            "$SCRIPT_DIR/deployment/deploy.sh" "${args[@]}"
            ;;
        "backup")
            "$SCRIPT_DIR/backup/create-backup.sh" "${args[@]}"
            ;;
        "restore")
            "$SCRIPT_DIR/backup/restore.sh" "${args[@]}"
            ;;
        "update")
            "$SCRIPT_DIR/update/update-services.sh" "${args[@]}"
            ;;
        "maintenance")
            "$SCRIPT_DIR/maintenance/system-maintenance.sh" "${args[@]}"
            ;;
        "monitor")
            "$SCRIPT_DIR/monitoring/monitoring.sh" "${args[@]}"
            ;;
        "status")
            show_status
            ;;
        "logs")
            show_logs "${args[@]}"
            ;;
        "restart"|"stop"|"start")
            manage_service "$cmd" "${args[@]}"
            ;;
        "config")
            case "${1:-}" in
                "lid-cover")
                    "$SCRIPT_DIR/configure-lid-cover.sh" "${args[@]}"
                    ;;
                *)
                    show_config "${args[@]}"
                    ;;
            esac
            ;;
        "info")
            show_info
            ;;
        "version")
            show_version
            ;;
        "help"|"-h"|"--help"|"")
            show_help
            ;;
        "")
            show_help
            ;;
        *)
            error "Unknown command: $cmd"
            echo "Use '$0 help' for available commands"
            exit 1
            ;;
    esac
}

# Main function
main() {
    # Check if scripts directory exists
    if [[ ! -d "$SCRIPT_DIR" ]]; then
        error "Scripts directory not found: $SCRIPT_DIR"
        echo "Please run this script from the correct directory"
        exit 1
    fi

    # Check for dependencies
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed or not in PATH"
        exit 1
    fi

    # Execute command
    execute_command "$@"
}

# Run main function with all arguments
main "$@"