#!/bin/bash
# Setup Docker on Proxmox Server
# ==============================

set -e

PROXMOX_SERVER="192.168.31.237"
PROXMOX_USER="root"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }

# Connect and setup Docker
setup_docker() {
    log "🐳 Setting up Docker on Proxmox server..."

    ssh $PROXMOX_USER@$PROXMOX_SERVER << 'EOF'
# Update package lists
apt-get update

# Install Docker prerequisites
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

# Add Docker official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Start and enable Docker
systemctl start docker
systemctl enable docker

# Add user to docker group
usermod -aG docker ubuntu

# Test Docker installation
docker --version
docker-compose version

echo "✅ Docker setup completed!"
EOF

    success "Docker installation completed on Proxmox server!"
}

# Run setup
setup_docker
success "🎉 Docker is now ready for homelab deployment!"