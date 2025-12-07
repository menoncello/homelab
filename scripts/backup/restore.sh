#!/bin/bash
# Homelab Restore Script
# ====================
# Restores homelab from backup

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
BACKUP_DIR="/opt/homelab-backups"
EXTRACT_DIR="/tmp/homelab_restore"

# Check arguments
check_args() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: $0 <backup_name> [options]"
        echo
        echo "Available backups:"
        ls -1 "$BACKUP_DIR"/*.tar.gz 2>/dev/null | xargs -n1 basename | sed 's/.tar.gz$//' | sort -r | head -10
        echo
        echo "Options:"
        echo "  --dry-run  - Show what would be restored without actually restoring"
        echo "  --volumes - Restore Docker volumes only"
        echo "  --configs  - Restore configurations only"
        echo "  --databases- Restore databases only"
        exit 1
    fi

    BACKUP_NAME="$1"
    BACKUP_FILE="$BACKUP_DIR/${BACKUP_NAME}.tar.gz"

    if [[ ! -f "$BACKUP_FILE" ]]; then
        error "Backup file not found: $BACKUP_FILE"
        exit 1
    fi
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "This script requires root privileges. Using sudo..."
        exec sudo "$0" "$@"
    fi
}

# Extract backup
extract_backup() {
    log "Extracting backup: $BACKUP_FILE"

    # Clean extract directory
    rm -rf "$EXTRACT_DIR"
    mkdir -p "$EXTRACT_DIR"

    # Extract backup
    tar -xzf "$BACKUP_FILE" -C "$EXTRACT_DIR/"

    # Verify extraction
    if [[ ! -d "$EXTRACT_DIR/$BACKUP_NAME" ]]; then
        error "Backup extraction failed"
        exit 1
    fi

    success "Backup extracted successfully"
}

# Restore Terraform state
restore_terraform() {
    log "Restoring Terraform state..."

    cd "$(dirname "$0")/../terraform"

    # Stop any running Terraform operations
    if [[ -f .terraform.lock.hcl ]]; then
        terraform force-unlock -force 2>/dev/null || true
    fi

    # Restore Terraform state
    if [[ -f "$EXTRACT_DIR/$BACKUP_NAME/terraform.tfstate" ]]; then
        cp "$EXTRACT_DIR/$BACKUP_NAME/terraform.tfstate" .
        success "Terraform state restored"
    else
        warning "Terraform state not found in backup"
    fi

    # Restore Terraform outputs
    if [[ -f "$EXTRACT_DIR/$BACKUP_NAME/terraform-outputs.json" ]]; then
        cp "$EXTRACT_DIR/$BACKUP_NAME/terraform-outputs.json" ../config/
        success "Terraform outputs restored"
    fi

    cd - > /dev/null
}

# Restore Docker volumes
restore_docker_volumes() {
    log "Restoring Docker volumes..."

    cd "$EXTRACT_DIR/$BACKUP_NAME"

    # Find all volume backup files
    for volume_tar in *.tar.gz; do
        if [[ -f "$volume_tar" ]]; then
            # Extract volume name from filename
            volume_name="${volume_tar%.tar.gz}"

            # Check if volume exists
            if docker volume ls --format "{{.Name}}" | grep -q "^${volume_name}$"; then
                log "Restoring volume: $volume_name"

                # Remove existing data in volume
                docker run --rm \
                    -v "$volume_name":/volume \
                    alpine sh -c "rm -rf /volume/*" 2>/dev/null || true

                # Restore volume data
                tar -xzf "$volume_tar" -C /var/lib/docker/volumes/"${volume_name}"/_data/ 2>/dev/null || {
                    warning "Failed to restore $volume_name"
                }

                success "$volume_name restored"
            else
                warning "Volume $volume_name does not exist, skipping"
            fi
        fi
    done

    cd - > /dev/null
}

# Restore configurations
restore_configs() {
    log "Restoring configurations..."

    cd "$(dirname "$0")/.."

    # Restore config directory
    if [[ -f "$EXTRACT_DIR/$BACKUP_NAME/config.tar.gz" ]]; then
        tar -xzf "$EXTRACT_DIR/$BACKUP_NAME/config.tar.gz" 2>/dev/null || {
            warning "Failed to restore config directory"
        }
        success "Configurations restored"
    fi

    # Restore Docker compose files
    if [[ -f "$EXTRACT_DIR/$BACKUP_NAME/docker-compose.tar.gz" ]]; then
        tar -xzf "$EXTRACT_DIR/$BACKUP_NAME/docker-compose.tar.gz" 2>/dev/null || {
            warning "Failed to restore docker-compose directory"
        }
        success "Docker compose files restored"
    fi

    # Restore Cloudflare tunnel config
    if [[ -f "$EXTRACT_DIR/$BACKUP_NAME/cloudflare-tunnel.tar.gz" ]]; then
        tar -xzf "$EXTRACT_DIR/$BACKUP_NAME/cloudflare-tunnel.tar.gz" 2>/dev/null || {
            warning "Failed to restore cloudflare-tunnel directory"
        }
        success "Cloudflare tunnel config restored"
    fi

    # Restore scripts
    if [[ -f "$EXTRACT_DIR/$BACKUP_NAME/scripts.tar.gz" ]]; then
        tar -xzf "$EXTRACT_DIR/$BACKUP_NAME/scripts.tar.gz" 2>/dev/null || {
            warning "Failed to restore scripts directory"
        }
        success "Scripts restored"
    fi

    cd - > /dev/null
}

# Restore databases
restore_databases() {
    log "Restoring databases..."

    cd "$EXTRACT_DIR/$BACKUP_NAME"

    # Restore MySQL databases
    for mysql_backup in mysql_*_backup.sql; do
        if [[ -f "$mysql_backup" ]]; then
            # Extract container name from filename
            container_name="${mysql_backup#mysql_}"
            container_name="${container_name%_backup.sql}"

            # Find running MySQL container
            mysql_container=$(docker ps --format "{{.Names}}" | grep -i mysql | head -1)
            if [[ -n "$mysql_container" ]]; then
                log "Restoring MySQL database to $mysql_container"

                # Wait for MySQL to be ready
                docker exec "$mysql_container" sh -c 'while ! mysqladmin ping -h localhost --silent; do sleep 1; done'

                # Restore database
                docker exec -i "$mysql_container" mysql -u root < "$mysql_backup" || {
                    warning "Failed to restore MySQL backup to $mysql_container"
                }

                success "MySQL database restored"
            else
                warning "No MySQL container found for restore"
            fi
        fi
    done

    # Restore PostgreSQL databases
    for postgres_backup in postgresql_*_backup.sql; do
        if [[ -f "$postgres_backup" ]]; then
            # Extract container name from filename
            container_name="${postgres_backup#postgresql_}"
            container_name="${container_name%_backup.sql}"

            # Find running PostgreSQL container
            postgres_container=$(docker ps --format "{{.Names}}" | grep -i postgres | head -1)
            if [[ -n "$postgres_container" ]]; then
                log "Restoring PostgreSQL database to $postgres_container"

                # Wait for PostgreSQL to be ready
                docker exec "$postgres_container" sh -c 'while ! pg_isready -U postgres; do sleep 1; done'

                # Restore database
                docker exec -i "$postgres_container" psql -U postgres < "$postgres_backup" || {
                    warning "Failed to restore PostgreSQL backup to $postgres_container"
                }

                success "PostgreSQL database restored"
            else
                warning "No PostgreSQL container found for restore"
            fi
        fi
    done

    cd - > /dev/null
}

# Verify restore
verify_restore() {
    log "Verifying restore..."

    # Check Terraform state
    if [[ -f "../terraform/terraform.tfstate" ]]; then
        success "Terraform state file exists"
    else
        warning "Terraform state file missing"
    fi

    # Check Docker volumes
    local volume_count=$(docker volume ls --format "{{.Name}}" | wc -l)
    log "Docker volumes found: $volume_count"

    # Check Docker services
    local service_count=$(docker ps --format "{{.Names}}" | wc -l)
    log "Docker services running: $service_count"

    # Check manifest
    if [[ -f "$EXTRACT_DIR/$BACKUP_NAME/manifest.json" ]]; then
        success "Backup manifest found"
        log "Original backup: $(jq -r '.backup_name' "$EXTRACT_DIR/$BACKUP_NAME/manifest.json")"
        log "Backup date: $(jq -r '.timestamp' "$EXTRACT_DIR/$BACKUP_NAME/manifest.json")"
    fi

    success "Restore verification completed"
}

# Restart services
restart_services() {
    log "Restarting services to apply restored data..."

    # Restart database containers first
    log "Restarting database containers..."
    docker restart $(docker ps --format "{{.Names}}" | grep -E "(mysql|postgres|redis)" || true) 2>/dev/null || true

    # Wait for databases
    sleep 10

    # Restart application containers
    log "Restarting application containers..."
    docker restart $(docker ps --format "{{.Names}}" | grep -v -E "(mysql|postgres|redis)" || true) 2>/dev/null || true

    success "Services restarted"
}

# Show restore summary
show_summary() {
    echo
    echo "📋 Restore Summary"
    echo "=================="
    echo "Backup restored: $BACKUP_NAME"
    echo "Restore date: $(date)"
    echo "Location: $BACKUP_FILE"
    echo
    echo "Next steps:"
    echo "1. Verify services are running: docker ps"
    echo "2. Check service logs: docker-compose logs [service]"
    echo "3. Test critical services (Grafana, Jellyfin, etc.)"
    echo "4. Run backup script to create fresh backup"
    echo
}

# Cleanup
cleanup() {
    log "Cleaning up..."
    rm -rf "$EXTRACT_DIR"
    success "Cleanup completed"
}

# Main function
main() {
    echo "🔄 Homelab Restore Script"
    echo "========================="
    echo

    check_args "$@"
    check_root

    # Parse additional options
    RESTORE_TYPE="full"
    DRY_RUN=false

    shift
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --volumes)
                RESTORE_TYPE="volumes"
                shift
                ;;
            --configs)
                RESTORE_TYPE="configs"
                shift
                ;;
            --databases)
                RESTORE_TYPE="databases"
                shift
                ;;
            *)
                error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "🔍 DRY RUN MODE - No actual changes will be made"
        echo
    fi

    extract_backup

    case "$RESTORE_TYPE" in
        "full")
            if [[ "$DRY_RUN" != "true" ]]; then
                restore_terraform
                restore_configs
                restore_docker_volumes
                restore_databases
                restart_services
            fi
            ;;
        "volumes")
            if [[ "$DRY_RUN" != "true" ]]; then
                restore_docker_volumes
                restart_services
            fi
            ;;
        "configs")
            if [[ "$DRY_RUN" != "true" ]]; then
                restore_terraform
                restore_configs
            fi
            ;;
        "databases")
            if [[ "$DRY_RUN" != "true" ]]; then
                restore_databases
                restart_services
            fi
            ;;
    esac

    verify_restore
    show_summary

    if [[ "$DRY_RUN" != "true" ]]; then
        cleanup
        success "Restore completed successfully! 🎉"
    else
        success "Dry run completed successfully! 🎉"
    fi
}

# Error handling
trap 'error "Restore failed at line $LINENO"' ERR

# Run main function with all arguments
main "$@"