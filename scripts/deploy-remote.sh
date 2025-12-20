#!/bin/bash
# Remote Deployment Script for Proxmox Server
# ===========================================

set -e

# Configuration
PROXMOX_SERVER="192.168.31.237"
PROXMOX_USER="root"
HOMELAB_DIR="/opt/homelab"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }

# Connect to remote server and deploy
deploy_to_server() {
    log "🚀 Starting deployment to Proxmox server: $PROXMOX_SERVER"

    # Create homelab directory
    ssh $PROXMOX_USER@$PROXMOX_SERVER "mkdir -p $HOMELAB_DIR 2>/dev/null || true"

    # Copy all files to remote server
    log "📁 Copying project files to server..."
    rsync -av --progress \
        --exclude='.git' \
        --exclude='terraform' \
        --exclude='.*' \
        . $PROXMOX_USER@$PROXMOX_SERVER:$HOMELAB_DIR/

    # Set up environment files with proper permissions
    log "⚙️ Setting up environment files..."
    ssh $PROXMOX_USER@$PROXMOX_SERVER "cd $HOMELAB_DIR && \
        cp docker-compose/.env.example docker-compose/.env && \
        cp docker-compose/security/.env.example docker-compose/security/.env && \
        cp cloudflare-tunnel/.env.example cloudflare-tunnel/.env 2>/dev/null || true && \
        chmod 600 */.env 2>/dev/null || true"

    # Update domain in all environment files
    ssh $PROXMOX_USER@$PROXMOX_SERVER "cd $HOMELAB_DIR && \
        sed -i 's/your-homelab-domain.com/menoncello.com/g' cloudflare-tunnel/.env && \
        sed -i 's/your-homelab-domain.com/menoncello.com/g' docker-compose/.env && \
        sed -i 's/your-homelab-domain.com/menoncello.com/g' docker-compose/security/.env"

    success "Files copied and configured successfully!"

    # Deploy Docker services in dependency order
    deploy_services
}

deploy_services() {
    log "🐳 Deploying Docker services to remote server..."

    ssh $PROXMOX_USER@$PROXMOX_SERVER << 'EOF'
cd /opt/homelab

# Deploy in dependency order
echo "🗄️ Deploying databases..."
docker-compose -f docker-compose/databases/docker-compose.yml up -d

echo "⏳ Waiting for databases to initialize (60 seconds)..."
sleep 60

echo "📊 Deploying monitoring..."
docker-compose -f docker-compose/monitoring/docker-compose.yml up -d

echo "⏳ Waiting for monitoring (30 seconds)..."
sleep 30

echo "🔐 Deploying security services..."
docker-compose -f docker-compose/security/docker-compose.yml up -d

echo "⏳ Waiting for security (30 seconds)..."
sleep 30

echo "🌐 Deploying reverse proxy..."
docker-compose -f docker-compose/nginx-proxy/docker-compose.yml up -d

echo "⏳ Waiting for proxy (15 seconds)..."
sleep 15

echo "🎯 Deploying application services..."
docker-compose -f docker-compose/prod-services/docker-compose.yml up -d &
docker-compose -f docker-compose/media/docker-compose.yml up -d &
docker-compose -f docker-compose/books/docker-compose.yml up -d &

echo "⏳ Waiting for applications..."
wait

echo "📋 Deployment completed!"
echo ""
echo "🔍 Checking deployment status..."
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
EOF
}

# Main execution
main() {
    echo "🏠 Homelab Remote Deployment Script"
    echo "==================================="
    echo ""
    echo "Target Server: $PROXMOX_SERVER"
    echo "Destination: $HOMELAB_DIR"
    echo ""

    # Test connection first
    log "🔌 Testing connection to server..."
    if ssh -o ConnectTimeout=10 $PROXMOX_USER@$PROXMOX_SERVER "echo 'Connection successful'"; then
        success "Server connection verified!"
        echo ""
        deploy_to_server
    else
        error "Failed to connect to server: $PROXMOX_SERVER"
        echo ""
        echo "Please ensure:"
        echo "1. Server is accessible at $PROXMOX_SERVER"
        echo "2. SSH key authentication is configured"
        echo "3. Docker is installed on the server"
        exit 1
    fi

    echo ""
    success "🎉 Deployment completed!"
    echo ""
    echo "📋 Next Steps:"
    echo "1. SSH into server: ssh $PROXMOX_USER@$PROXMOX_SERVER"
    echo "2. Check status: cd $HOMELAB_DIR && docker ps"
    echo "3. Access services locally:"
    echo "   - Grafana: http://localhost:3000"
    echo "   - Nginx Proxy: http://localhost:81"
    echo "   - Monitoring: Check docker-compose logs"
    echo ""
}

# Run main function
main "$@"