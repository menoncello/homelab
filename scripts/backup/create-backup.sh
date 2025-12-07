#!/bin/bash
# Homelab Backup Script
# =====================
# Creates comprehensive backup of all homelab services

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
BACKUP_DIR="/opt/homelab-backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="homelab_backup_${TIMESTAMP}"

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

# Create backup directory
create_backup_dir() {
    log "Creating backup directory: $BACKUP_DIR"
    sudo mkdir -p "$BACKUP_DIR/$BACKUP_NAME"
    sudo chmod 755 "$BACKUP_DIR"
    success "Backup directory created"
}

# Backup Terraform state
backup_terraform() {
    log "Backing up Terraform state..."

    cd "$(dirname "$0")/../terraform"

    # Backup Terraform state
    sudo cp terraform.tfstate "$BACKUP_DIR/$BACKUP_NAME/terraform.tfstate"

    # Backup Terraform outputs
    if [[ -f ../config/terraform-outputs.json ]]; then
        sudo cp ../config/terraform-outputs.json "$BACKUP_DIR/$BACKUP_NAME/"
    fi

    # Backup Terraform configurations
    sudo tar -czf "$BACKUP_DIR/$BACKUP_NAME/terraform-config.tar.gz" \
        *.tf *.tfvars* modules/ 2>/dev/null || true

    success "Terraform backup completed"
}

# Backup Docker volumes
backup_docker_volumes() {
    log "Backing up Docker volumes..."

    # List important volumes to backup
    volumes=(
        "grafana_data"
        "prometheus_data"
        "alertmanager_data"
        "nextcloud_data"
        "gitea_data"
        "immich_upload"
        "vaultwarden_data"
        "mysql_data"
        "postgresql_data"
        "redis_data"
        "jellyfin_config"
        "sonarr_config"
        "radarr_config"
        "bookstack_config"
        "audiobookshelf_config"
        "kavita_config"
    )

    cd "$BACKUP_DIR/$BACKUP_NAME"

    for volume in "${volumes[@]}"; do
        if docker volume ls --format "{{.Name}}" | grep -q "^${volume}$"; then
            log "Backing up volume: $volume"
            sudo docker run --rm \
                -v "$volume":/volume:ro \
                -v "$BACKUP_DIR/$BACKUP_NAME":/backup \
                alpine sh -c "
                    cd /volume &&
                    tar -czf /backup/${volume}.tar.gz .
                " || warning "Failed to backup $volume"

            if [[ $? -eq 0 ]]; then
                success "$volume backed up"
            fi
        fi
    done
}

# Backup application configurations
backup_configs() {
    log "Backing up application configurations..."

    cd "$(dirname "$0")/.."

    # Backup config directory
    sudo tar -czf "$BACKUP_DIR/$BACKUP_NAME/config.tar.gz" config/ 2>/dev/null || true

    # Backup Docker compose files
    sudo tar -czf "$BACKUP_DIR/$BACKUP_NAME/docker-compose.tar.gz" \
        docker-compose/ 2>/dev/null || true

    # Backup Cloudflare tunnel config
    sudo tar -czf "$BACKUP_DIR/$BACKUP_NAME/cloudflare-tunnel.tar.gz" \
        cloudflare-tunnel/ 2>/dev/null || true

    # Backup scripts
    sudo tar -czf "$BACKUP_DIR/$BACKUP_NAME/scripts.tar.gz" scripts/ 2>/dev/null || true

    success "Configuration backup completed"
}

# Backup databases
backup_databases() {
    log "Backing up databases..."

    cd "$BACKUP_DIR/$BACKUP_NAME"

    # MySQL backups
    mysql_containers=$(docker ps --format "{{.Names}}" | grep mysql || true)
    for container in $mysql_containers; do
        log "Backing up MySQL from $container"
        sudo docker exec "$container" mysqldump --single-transaction -u root --all-databases \
            > "mysql_${container}_backup.sql" 2>/dev/null || warning "MySQL backup failed for $container"
    done

    # PostgreSQL backups
    postgres_containers=$(docker ps --format "{{.Names}}" | grep postgres || true)
    for container in $postgres_containers; do
        log "Backing up PostgreSQL from $container"
        sudo docker exec "$container" pg_dumpall -U postgres \
            > "postgresql_${container}_backup.sql" 2>/dev/null || warning "PostgreSQL backup failed for $container"
    done

    success "Database backup completed"
}

# Create backup manifest
create_manifest() {
    log "Creating backup manifest..."

    cat > "$BACKUP_DIR/$BACKUP_NAME/manifest.json" << EOF
{
  "backup_name": "$BACKUP_NAME",
  "timestamp": "$(date -Iseconds)",
  "hostname": "$(hostname)",
  "os_version": "$(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"')",
  "docker_version": "$(docker --version)",
  "terraform_version": "$(terraform --version | cut -d' ' -f2 | head -n1)",
  "backup_type": "full",
  "components": {
    "terraform": true,
    "docker_volumes": true,
    "configurations": true,
    "databases": true
  },
  "backup_files": [
    $(ls -1 "$BACKUP_DIR/$BACKUP_NAME" | sed 's/^/"/g' | sed 's/$/"/g' | sed '$!s/$/,/g')
  ]
}
EOF

    success "Backup manifest created"
}

# Compress backup
compress_backup() {
    log "Compressing backup..."

    cd "$BACKUP_DIR"
    sudo tar -czf "${BACKUP_NAME}.tar.gz" "$BACKUP_NAME/"
    sudo rm -rf "$BACKUP_NAME/"

    local backup_size=$(du -h "${BACKUP_NAME}.tar.gz" | cut -f1)
    success "Backup compressed: ${BACKUP_NAME}.tar.gz ($backup_size)"
}

# Cleanup old backups
cleanup_old_backups() {
    log "Cleaning up old backups (keeping last 7 days)..."

    cd "$BACKUP_DIR"

    # Remove backups older than 7 days
    sudo find . -name "homelab_backup_*.tar.gz" -mtime +7 -delete

    # Keep only the 10 most recent backups
    local backup_count=$(ls -1 homelab_backup_*.tar.gz 2>/dev/null | wc -l)
    if [[ $backup_count -gt 10 ]]; then
        ls -1t homelab_backup_*.tar.gz | tail -n +$((backup_count - 9)) | xargs -r sudo rm
    fi

    success "Old backups cleaned up"
}

# Verify backup
verify_backup() {
    log "Verifying backup integrity..."

    local backup_file="$BACKUP_DIR/${BACKUP_NAME}.tar.gz"

    # Check if file exists
    if [[ ! -f "$backup_file" ]]; then
        error "Backup file not found: $backup_file"
        return 1
    fi

    # Test archive integrity
    if sudo tar -tzf "$backup_file" | head -10 > /dev/null; then
        success "Backup integrity verified"
    else
        error "Backup integrity check failed"
        return 1
    fi

    # Check backup size
    local backup_size=$(du -m "$backup_file" | cut -f1)
    if [[ $backup_size -lt 10 ]]; then
        warning "Backup seems too small (${backup_size}MB)"
    else
        success "Backup size is reasonable (${backup_size}MB)"
    fi
}

# Show backup summary
show_summary() {
    local backup_file="$BACKUP_DIR/${BACKUP_NAME}.tar.gz"
    local backup_size=$(du -h "$backup_file" | cut -f1)

    echo
    echo "📋 Backup Summary"
    echo "=================="
    echo "Backup file: $backup_file"
    echo "Size: $backup_size"
    echo "Created: $(date)"
    echo
    echo "To restore:"
    echo "  sudo tar -xzf $backup_file -C /opt/homelab-backups/"
    echo "  sudo ./restore.sh $BACKUP_NAME"
    echo
    echo "Backup location: $BACKUP_DIR"
    echo
}

# Main function
main() {
    echo "🔄 Homelab Backup Script"
    echo "======================="
    echo

    # Check if running as root (required for some operations)
    if [[ $EUID -ne 0 ]]; then
        echo "This script requires root privileges. Using sudo..."
        exec sudo "$0" "$@"
    fi

    # Parse arguments
    case "${1:-full}" in
        "full")
            create_backup_dir
            backup_terraform
            backup_configs
            backup_docker_volumes
            backup_databases
            ;;
        "volumes")
            create_backup_dir
            backup_docker_volumes
            ;;
        "configs")
            create_backup_dir
            backup_terraform
            backup_configs
            ;;
        "databases")
            create_backup_dir
            backup_databases
            ;;
        *)
            echo "Usage: $0 [full|volumes|configs|databases]"
            echo "  full     - Complete backup (default)"
            echo "  volumes  - Docker volumes only"
            echo "  configs  - Terraform and configuration files only"
            echo "  databases- Database dumps only"
            exit 1
            ;;
    esac

    create_manifest
    compress_backup
    cleanup_old_backups
    verify_backup
    show_summary

    success "Backup completed successfully! 🎉"
}

# Error handling
trap 'error "Backup failed at line $LINENO"' ERR

# Run main function
main "$@"