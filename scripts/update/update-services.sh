#!/bin/bash
# Homelab Services Update Script
# ===============================
# Updates Docker services and containers

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

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_DIR="$(dirname "$SCRIPT_DIR")/../docker-compose"

# Update specific service stack
update_stack() {
    local stack="$1"
    local stack_dir="$COMPOSE_DIR/$stack"

    if [[ ! -d "$stack_dir" ]]; then
        error "Stack directory not found: $stack_dir"
        return 1
    fi

    log "Updating $stack stack..."

    cd "$stack_dir"

    # Pull latest images
    log "Pulling latest images for $stack..."
    docker-compose pull

    # Update services with zero downtime (if possible)
    log "Updating $stack services..."
    docker-compose up -d --force-recreate --remove-orphans

    # Check service health
    sleep 10
    if docker-compose ps | grep -q "Up"; then
        success "$stack stack updated successfully"
    else
        error "$stack stack update failed"
        docker-compose logs
        return 1
    fi

    cd - > /dev/null
}

# Update all services
update_all() {
    log "Updating all Homelab services..."

    # Array of stacks in dependency order
    local stacks=(
        "databases"
        "nginx-proxy"
        "monitoring"
        "media"
        "books"
        "prod-services"
    )

    for stack in "${stacks[@]}"; do
        update_stack "$stack"
    done

    # Update Cloudflare tunnel
    log "Updating Cloudflare tunnel..."
    cd "$COMPOSE_DIR/../cloudflare-tunnel"
    docker-compose pull
    docker-compose up -d
    success "Cloudflare tunnel updated"
    cd - > /dev/null
}

# Health check after updates
health_check() {
    log "Performing health checks..."

    # Check critical services
    local critical_services=(
        "Grafana:192.168.31.201:3000"
        "Prometheus:192.168.31.201:9090"
        "Jellyfin:192.168.31.151:8096"
        "Nextcloud:192.168.31.202:8081"
    )

    local failed_services=()

    for service in "${critical_services[@]}"; do
        local name=$(echo $service | cut -d: -f1)
        local endpoint=$(echo $service | cut -d: -f2)
        local port=$(echo $service | cut -d: -f3)

        log "Checking $name..."
        if timeout 10 bash -c "</dev/tcp/${endpoint}/${port}" 2>/dev/null; then
            success "$name is healthy"
        else
            warning "$name is not responding yet"
            failed_services+=("$name")
        fi
    done

    # Report failed services
    if [[ ${#failed_services[@]} -gt 0 ]]; then
        warning "The following services are not responding:"
        for service in "${failed_services[@]}"; do
            echo "  - $service"
        done
        log "These services may need more time to start up"
    fi
}

# Cleanup unused Docker resources
cleanup() {
    log "Cleaning up unused Docker resources..."

    # Remove unused images
    log "Removing unused Docker images..."
    docker image prune -f > /dev/null

    # Remove unused volumes (be careful)
    log "Removing unused Docker volumes..."
    docker volume prune -f > /dev/null

    # Remove unused networks
    log "Removing unused Docker networks..."
    docker network prune -f > /dev/null

    success "Cleanup completed"
}

# Show update summary
show_summary() {
    local updated_count=$(docker ps --format "{{.Names}}" | wc -l)
    local image_count=$(docker images --format "{{.Repository}}" | grep -v "<none>" | wc -l)

    echo
    echo "📋 Update Summary"
    echo "=================="
    echo "Running containers: $updated_count"
    echo "Unique images: $image_count"
    echo "Update completed: $(date)"
    echo
    echo "Service URLs:"
    echo "  • Grafana: http://192.168.31.201:3000"
    echo "  • Jellyfin: http://192.168.31.151:8096"
    echo "  • Nextcloud: http://192.168.31.202:8081"
    echo "  • Nginx Proxy Manager: http://192.168.31.200:81"
    echo
}

# Rollback function
rollback() {
    local stack="$1"
    log "Rolling back $stack stack..."

    cd "$COMPOSE_DIR/$stack"

    # Reset to previous images
    log "Rolling back $stack..."
    docker-compose down
    docker-compose up -d

    success "$stack rollback completed"
    cd - > /dev/null
}

# Main function
main() {
    echo "🔄 Homelab Services Update Script"
    echo "================================="
    echo

    # Parse arguments
    case "${1:-all}" in
        "all")
            update_all
            ;;
        "databases"|"nginx-proxy"|"monitoring"|"media"|"books"|"prod-services")
            update_stack "$1"
            ;;
        "clean")
            cleanup
            ;;
        "health")
            health_check
            ;;
        "rollback")
            if [[ -z "$2" ]]; then
                error "Stack name required for rollback"
                echo "Usage: $0 rollback <stack_name>"
                echo "Available stacks: databases nginx-proxy monitoring media books prod-services"
                exit 1
            fi
            rollback "$2"
            ;;
        "help"|"-h"|"--help")
            echo "Homelab Services Update Script"
            echo
            echo "Usage: $0 [command] [options]"
            echo
            echo "Commands:"
            echo "  all         - Update all services (default)"
            echo "  databases   - Update database services only"
            echo "  nginx-proxy - Update reverse proxy only"
            echo "  monitoring  - Update monitoring stack only"
            echo "  media       - Update media services only"
            echo "  books       - Update books services only"
            echo "  prod-services- Update productivity services only"
            echo "  clean       - Clean up unused Docker resources"
            echo "  health      - Run health checks on services"
            echo "  rollback    - Rollback a specific stack"
            echo "  help        - Show this help"
            echo
            exit 0
            ;;
        *)
            error "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac

    # Perform health check after update
    if [[ "${1:-all}" != "clean" ]] && [[ "${1:-all}" != "help" ]]; then
        health_check
    fi

    show_summary
    success "Update completed successfully! 🎉"
}

# Error handling
trap 'error "Update failed at line $LINENO"' ERR

# Run main function with all arguments
main "$@"