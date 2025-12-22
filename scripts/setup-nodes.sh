#!/bin/bash
# scripts/setup-nodes.sh

echo "Setting up Docker Swarm node labels..."

# Check if Docker Swarm is initialized
if ! docker info | grep -q "Swarm: active"; then
    echo "Error: Docker Swarm is not active"
    echo "Please initialize Swarm first with: docker swarm init"
    exit 1
fi

# Get list of nodes
NODES=$(docker node ls --format "{{.Hostname}}")

if [ -z "$NODES" ]; then
    echo "Error: No nodes found in Swarm"
    exit 1
fi

echo "Found nodes:"
echo "$NODES"
echo ""

# Label Helios (manager)
if echo "$NODES" | grep -q "^helios$"; then
    echo "Labeling Helios..."
    docker node update --label-add gpu=true helios 2>/dev/null || echo "  - gpu label already exists or failed"
    docker node update --label-add arr=true helios 2>/dev/null || echo "  - arr label already exists or failed"
    docker node update --label-add proxy=true helios 2>/dev/null || echo "  - proxy label already exists or failed"
    echo "✓ Helios labeled: gpu, arr, proxy"
else
    echo "Warning: Helios node not found"
fi

# Label Xeon01 (worker)
if echo "$NODES" | grep -q "^xeon01$"; then
    echo "Labeling Xeon01..."
    docker node update --label-add storage=true xeon01 2>/dev/null || echo "  - storage label already exists or failed"
    docker node update --label-add database=true xeon01 2>/dev/null || echo "  - database label already exists or failed"
    echo "✓ Xeon01 labeled: storage, database"
else
    echo "Warning: Xeon01 node not found"
fi

echo ""
echo "Node labels:"
docker node ls --format "table {{.Hostname}}\t{{.Availability}}\t{{.Status}}\t{{.Spec.Labels}}" | column -t

echo ""
echo "Node labeling complete!"
echo ""
echo "Label placement:"
echo "  Helios (gpu=true):   Jellyfin, GPU services"
echo "  Helios (arr=true):   Sonarr, Radarr, Transmission"
echo "  Helios (proxy=true): Nginx Proxy Manager"
echo "  Xeon01 (storage=true): Nextcloud, Audiobookshelf"
echo "  Xeon01 (database=true): PostgreSQL, Redis"
