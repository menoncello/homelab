#!/bin/bash
# Discovery Stack Deployment Script
# Deploys media discovery services for homelab

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Stack name
STACK_NAME="discovery"
STACK_DIR="$(dirname "$0")"

echo -e "${GREEN}=== Discovery Stack Deployment ===${NC}"
echo ""

# Check if .env exists
if [ ! -f "$STACK_DIR/.env" ]; then
    echo -e "${YELLOW}Creating .env from .env.example...${NC}"
    cp "$STACK_DIR/.env.example" "$STACK_DIR/.env"
    echo -e "${RED}ERROR: .env file created but not configured!${NC}"
    echo "Please edit $STACK_DIR/.env with your API keys and credentials:"
    echo "  - Spotify Client ID/Secret"
    echo "  - LastFM API Key"
    echo "  - Lidarr API Key"
    echo "  - Jellyseerr API Key"
    echo "  - Trakt credentials"
    echo "  - PodcastIndex credentials"
    echo ""
    echo "After configuring, run this script again."
    exit 1
fi

# Check Docker context
echo -e "${YELLOW}Checking Docker context...${NC}"
CURRENT_CONTEXT=$(docker context ls -q '{{ .Name }}' | head -1)
if [ "$CURRENT_CONTEXT" != "homelab" ]; then
    echo -e "${YELLOW}Switching to homelab context...${NC}"
    docker context use homelab
fi

# Check if Swarm is initialized
echo -e "${YELLOW}Checking Swarm status...${NC}"
if ! docker info | grep -q "Swarm: active"; then
    echo -e "${RED}ERROR: Docker Swarm is not initialized!${NC}"
    echo "Run: docker swarm init"
    exit 1
fi

# Check if homelab-net exists
echo -e "${YELLOW}Checking overlay network...${NC}"
if ! docker network ls | grep -q "homelab-net"; then
    echo -e "${YELLOW}Creating homelab-net overlay network...${NC}"
    docker network create --driver overlay --attachable homelab-net
fi

# Check if music directory exists
echo -e "${YELLOW}Checking music directory...${NC}"
if [ ! -d "/media/music" ]; then
    echo -e "${YELLOW}Creating /media/music directory...${NC}"
    sudo mkdir -p /media/music
    sudo chown -R 1000:1000 /media/music
    echo -e "${GREEN}Music directory created. Place your music files in /media/music${NC}"
fi

# Check if PostgreSQL is running (for PinePods)
echo -e "${YELLOW}Checking PostgreSQL service...${NC}"
if ! docker service ls | grep -q "content_postgresql"; then
    echo -e "${RED}WARNING: PostgreSQL not found! PinePods requires a database.${NC}"
    echo "Deploy content stack first: docker stack deploy -c stacks/content/docker-compose.yml content"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Deploy stack
echo ""
echo -e "${GREEN}Deploying Discovery Stack...${NC}"
docker stack deploy -c "$STACK_DIR/docker-compose.yml" "$STACK_NAME"

# Wait for services to start
echo ""
echo -e "${YELLOW}Waiting for services to start...${NC}"
sleep 5

# Check service status
echo ""
echo -e "${GREEN}Service Status:${NC}"
docker stack services "$STACK_NAME" --format "table {{.Name}}\t{{.Replicas}}\t{{.Ports}}"

echo ""
echo -e "${GREEN}=== Discovery Stack Deployed Successfully ===${NC}"
echo ""
echo -e "Access URLs:"
echo -e "  - Lidify:       http://192.168.31.5:3333"
echo -e "  - Navidrome:    http://192.168.31.5:4533"
echo -e "  - Movary:       http://192.168.31.5:5056"
echo -e "  - ListSync:     http://192.168.31.5:8082"
echo -e "  - PinePods:     http://192.168.31.5:8083"
echo ""
echo -e "Check logs with: docker service logs -f ${STACK_NAME}_<service>"
echo -e "Remove stack with: docker stack rm ${STACK_NAME}"
