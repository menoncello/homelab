#!/bin/bash
# scripts/deploy.sh

set -e

echo "=========================================="
echo "  Homelab Docker Stack Deployment"
echo "=========================================="
echo ""

# Check if Docker Swarm is initialized
if ! docker info | grep -q "Swarm: active"; then
    echo "❌ Error: Docker Swarm is not active"
    echo "Please initialize Swarm first:"
    echo "  On Helios: docker swarm init"
    echo "  On Xeon01: docker swarm join --token [token] [manager-ip]:2377"
    exit 1
fi

echo "✓ Docker Swarm is active"
echo ""

# Step 1: Create overlay network (if not exists)
echo "Step 1: Creating overlay network..."
if docker network ls | grep -q "homelab-net"; then
    echo "✓ Network 'homelab-net' already exists"
else
    docker network create --driver overlay --attachable homelab-net
    echo "✓ Network 'homelab-net' created"
fi
echo ""

# Step 2: Setup GPU (Helios only)
HOSTNAME=$(hostname)
if [ "$HOSTNAME" = "helios" ]; then
    echo "Step 2: Setting up GPU runtime..."
    if [ -f "./scripts/setup-gpu.sh" ]; then
        chmod +x ./scripts/setup-gpu.sh
        sudo ./scripts/setup-gpu.sh
        echo "✓ GPU runtime configured"
    else
        echo "⚠ Warning: setup-gpu.sh not found, skipping GPU setup"
    fi
else
    echo "Step 2: Skipping GPU setup (not on Helios)"
fi
echo ""

# Step 3: Create volumes
echo "Step 3: Creating volume structure..."
if [ -f "./scripts/create-volumes.sh" ]; then
    chmod +x ./scripts/create-volumes.sh
    sudo ./scripts/create-volumes.sh
    echo "✓ Volumes created"
else
    echo "❌ Error: create-volumes.sh not found"
    exit 1
fi
echo ""

# Step 4: Label nodes
echo "Step 4: Labeling nodes..."
if [ -f "./scripts/setup-nodes.sh" ]; then
    chmod +x ./scripts/setup-nodes.sh
    ./scripts/setup-nodes.sh
    echo "✓ Nodes labeled"
else
    echo "⚠ Warning: setup-nodes.sh not found, skipping node labeling"
fi
echo ""

# Step 5: Deploy stacks
echo "Step 5: Deploying stacks..."
echo ""

# Deploy order matters for dependencies
STACKS=(
    "infrastructure"
    "proxy"
    "content"
    "database-stack"
    "gpu-services"
    "media-stack"
    "discovery-stack"
)

for stack in "${STACKS[@]}"; do
    echo "Deploying $stack..."
    if [ -f "./stacks/$stack/docker-compose.yml" ]; then
        docker stack deploy -c stacks/$stack/docker-compose.yml $stack
        echo "✓ $stack deployed"
    else
        echo "⚠ Warning: stacks/$stack/docker-compose.yml not found, skipping"
    fi
    echo ""
done

echo "=========================================="
echo "  Deployment Complete!"
echo "=========================================="
echo ""
echo "Waiting for services to start..."
sleep 10

echo ""
echo "Service Status:"
docker stack ls
echo ""

echo "Services:"
docker service ls --format "table {{.Name}}\t{{.Replicas}}\t{{.Ports}}" | head -10
echo ""

echo "Access URLs:"
echo "  Nginx Proxy Manager:  http://$(hostname -I | awk '{print $1}'):81"
echo "  Configure proxy hosts for each service"
echo ""
echo "Discovery Stack (Automation):"
echo "  - Sonarr:       http://$(hostname -I | awk '{print $1}'):8989"
echo "  - Radarr:       http://$(hostname -I | awk '{print $1}'):7878"
echo "  - Lidarr:       http://$(hostname -I | awk '{print $1}'):8686"
echo "  - Listenarr:    http://$(hostname -I | awk '{print $1}'):8988"
echo "  - Prowlarr:     http://$(hostname -I | awk '{print $1}'):9696"
echo "  - Bazarr:       http://$(hostname -I | awk '{print $1}'):6767"
echo "  - qBittorrent:  http://$(hostname -I | awk '{print $1}'):9091"
echo "  - Jellyseerr:   http://$(hostname -I | awk '{print $1}'):5055"
echo "  - Lidify:       http://$(hostname -I | awk '{print $1}'):3333"
echo "  - Movary:       http://$(hostname -I | awk '{print $1}'):5056"
echo "  - ListSync:     http://$(hostname -I | awk '{print $1}'):8082"
echo ""
echo "Media Stack (Streaming):"
echo "  - Jellyfin:     http://$(hostname -I | awk '{print $1}'):8096"
echo "  - Audiobookshelf: http://$(hostname -I | awk '{print $1}'):13378"
echo "  - Calibre:      http://$(hostname -I | awk '{print $1}'):8083"
echo "  - Navidrome:    http://$(hostname -I | awk '{print $1}'):4533"
echo ""
echo "Next Steps:"
echo "  1. Access Nginx Proxy Manager (default: admin@example.com / changeme)"
echo "  2. Configure SSL certificates"
echo "  3. Set up proxy hosts for services"
echo "  4. Configure Jellyfin for GPU transcoding"
echo "  5. Set up Sonarr/Radarr/Transmission integration"
echo "  6. Configure Discovery Stack (see stacks/discovery-stack/README.md)"
echo ""
echo "Monitor logs:"
echo "  docker service logs -f [service-name]"
echo ""
