#!/bin/bash
# scripts/deploy-ebook2audiobook.sh
# Deploy ebook2audiobook stack to homelab

set -e

echo "==================================="
echo "ebook2audiobook Deployment Script"
echo "==================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or with sudo"
    echo "Example: sudo ./scripts/deploy-ebook2audiobook.sh"
    exit 1
fi

# Detect which server we're on
HOSTNAME=$(hostname)
echo "Running on: $HOSTNAME"

if [ "$HOSTNAME" != "helios" ] && [ "$HOSTNAME" != "pop-os" ]; then
    echo "Warning: This should run on pop-os (helios) for GPU support"
    echo "Current hostname: $HOSTNAME"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check Docker Swarm mode
if ! docker info | grep -q "Swarm: active"; then
    echo "Error: Docker Swarm is not active"
    echo "Initialize with: docker swarm init"
    exit 1
fi

# Check if homelab-net exists
if ! docker network ls | grep -q "homelab-net"; then
    echo "Creating homelab-net overlay network..."
    docker network create --driver overlay --attachable homelab-net
fi

# Create volume directories
echo ""
echo "Creating volume directories..."
mkdir -p /data/docker/ebook2audiobook/{config,models,output}
mkdir -p /media/ebooks

# Set permissions
echo "Setting permissions (UID 1000:1000)..."
chown -R 1000:1000 /data/docker/ebook2audiobook
chown -R 1000:1000 /media/ebooks

echo "✓ Volumes created:"
echo "  - /data/docker/ebook2audiobook/config"
echo "  - /data/docker/ebook2audiobook/models"
echo "  - /data/docker/ebook2audiobook/output"
echo "  - /media/ebooks (input directory)"
echo ""

# Check GPU availability
echo "Checking GPU availability..."
if command -v nvidia-smi &> /dev/null; then
    nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader
    echo "✓ NVIDIA GPU detected"
else
    echo "Warning: nvidia-smi not found. GPU may not be available."
    echo "The service will run on CPU (slower)."
fi

# Get the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
STACK_DIR="$PROJECT_ROOT/stacks/ebook2audiobook-stack"

# Check if stack file exists
if [ ! -f "$STACK_DIR/docker-compose.yml" ]; then
    echo "Error: Stack file not found: $STACK_DIR/docker-compose.yml"
    exit 1
fi

# Deploy stack
echo ""
echo "Deploying ebook2audiobook stack..."
cd "$STACK_DIR"
docker stack deploy -c docker-compose.yml ebook2audiobook

# Wait for service to start
echo ""
echo "Waiting for service to start..."
sleep 10

# Check service status
echo ""
echo "Service status:"
docker stack services ebook2audiobook

echo ""
echo "==================================="
echo "Deployment Complete!"
echo "==================================="
echo ""
echo "Access the web interface at:"
echo "  http://localhost:7860"
echo "  or http://<server-ip>:7860"
echo ""
echo "Place ebooks in: /media/ebooks"
echo "Output will be in: /data/docker/ebook2audiobook/output"
echo ""
echo "To view logs:"
echo "  docker service logs -f ebook2audiobook_ebook2audiobook"
echo ""
echo "To remove stack:"
echo "  docker stack rm ebook2audiobook"
echo ""
