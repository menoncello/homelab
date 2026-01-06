#!/bin/bash
# Deployment script for new homelab services
# Run from the Swarm manager (Helios)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "==> Deploying new homelab services..."
echo "==> Project root: $PROJECT_ROOT"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running on Swarm manager
if ! docker info | grep -q "Swarm: active"; then
    echo "ERROR: Not running on a Swarm manager node"
    exit 1
fi

# Step 1: Deploy database-stack
echo -e "${YELLOW}[1/5] Deploying database-stack...${NC}"
cd "$PROJECT_ROOT/stacks/database-stack"

# Check if secrets exist
if [ ! -f "./secrets/postgres_password.txt" ] || [ ! -f "./secrets/redis_password.txt" ]; then
    echo "ERROR: Database secrets not found!"
    echo "Please run:"
    echo "  cd stacks/database-stack/secrets"
    echo "  cp postgres_password.txt.example postgres_password.txt"
    echo "  cp redis_password.txt.example redis_password.txt"
    echo "  # Edit the files with secure passwords"
    exit 1
fi

docker stack deploy -c docker-compose.yml database
echo -e "${GREEN}✓ database-stack deployed${NC}"
echo ""

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to start..."
sleep 10

# Step 2: Create n8n database
echo -e "${YELLOW}[2/5] Creating n8n database...${NC}"

# Check if n8n password file exists, if not create a random one
N8N_PASSWORD_FILE="$PROJECT_ROOT/stacks/n8n-stack/secrets/n8n_db_password.txt"
if [ ! -f "$N8N_PASSWORD_FILE" ]; then
    echo "Creating n8n database password..."
    openssl rand -hex 16 > "$N8N_PASSWORD_FILE"
fi
N8N_PASSWORD=$(cat "$N8N_PASSWORD_FILE")

echo ""
echo "=========================================="
echo "  Run these commands on XEON01:"
echo "=========================================="
echo ""
echo "# Wait for PostgreSQL to be ready, then:"
echo 'docker exec -it $(docker ps -q -f name=database_postgresql) psql -U postgres'
echo ""
echo "Then run this SQL:"
echo "CREATE DATABASE n8n;"
echo "CREATE USER n8n WITH ENCRYPTED PASSWORD '$N8N_PASSWORD';"
echo "GRANT ALL PRIVILEGES ON DATABASE n8n TO n8n;"
echo '\\c n8n'
echo "GRANT ALL ON SCHEMA public TO n8n;"
echo '\\q'
echo ""
echo "=========================================="
echo ""

# Wait for user to create the database
read -p "Press ENTER after creating the n8n database on Xeon01..."
echo -e "${GREEN}✓ n8n database created${NC}"
echo ""

# Step 3: Deploy n8n-stack
echo -e "${YELLOW}[3/5] Deploying n8n-stack...${NC}"
cd "$PROJECT_ROOT/stacks/n8n-stack"

# Create encryption key if not exists
if [ ! -f "./secrets/n8n_encryption_key.txt" ]; then
    echo "Creating n8n encryption key..."
    openssl rand -hex 32 > ./secrets/n8n_encryption_key.txt
fi

docker stack deploy -c docker-compose.yml n8n
echo -e "${GREEN}✓ n8n-stack deployed${NC}"
echo ""

# Step 4: Deploy lidarr-stack
echo -e "${YELLOW}[4/5] Deploying lidarr-stack...${NC}"
cd "$PROJECT_ROOT/stacks/lidarr-stack"
docker stack deploy -c docker-compose.yml lidarr
echo -e "${GREEN}✓ lidarr-stack deployed${NC}"
echo ""

# Step 5: Deploy homarr-stack
echo -e "${YELLOW}[5/5] Deploying homarr-stack...${NC}"
cd "$PROJECT_ROOT/stacks/homarr-stack"
docker stack deploy -c docker-compose.yml homarr
echo -e "${GREEN}✓ homarr-stack deployed${NC}"
echo ""

# Summary
echo "========================================="
echo -e "${GREEN}==> All services deployed!${NC}"
echo "========================================="
echo ""
echo "Services:"
echo "  Database:   PostgreSQL (5432), Redis (6379)"
echo "  n8n:        http://192.168.31.6:5678"
echo "  Lidarr:     http://192.168.31.5:8686"
echo "  Homarr:     http://192.168.31.5:7575"
echo ""
echo "Check status:"
echo "  docker stack ls"
echo "  docker service ls"
echo ""
echo "View logs:"
echo "  docker service logs -f database_postgresql"
echo "  docker service logs -f n8n_n8n"
echo "  docker service logs -f lidarr_lidarr"
echo "  docker service logs -f homarr_homarr"
