#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Grafana Deployment Script ===${NC}"

# Check if secret exists
if docker secret ls | grep -q "grafana_admin_password"; then
    echo -e "${YELLOW}Secret grafana_admin_password already exists. Skipping creation.${NC}"
else
    echo -e "${GREEN}Creating Docker secret: grafana_admin_password${NC}"
    
    # Check if secrets.yml exists
    if [ ! -f "secrets/secrets.yml" ]; then
        echo -e "${RED}Error: secrets/secrets.yml not found!${NC}"
        echo "Please create secrets/secrets.yml from secrets/secrets.yml.example"
        exit 1
    fi
    
    # Extract password and create secret
    GRAFANA_PASSWORD=$(grep "grafana_admin_password:" secrets/secrets.yml | awk '{print $2}')
    
    if [ -z "$GRAFANA_PASSWORD" ]; then
        echo -e "${RED}Error: grafana_admin_password not found in secrets/secrets.yml${NC}"
        exit 1
    fi
    
    echo "$GRAFANA_PASSWORD" | docker secret create grafana_admin_password -
    echo -e "${GREEN}✓ Secret created successfully${NC}"
fi

# Create volume directory on manager node (pop-os)
echo -e "${GREEN}Creating Grafana volume directory...${NC}"
ssh eduardo@192.168.31.5 "mkdir -p /data/docker/observability/grafana && sudo chown -R 1000:1000 /data/docker/observability/grafana"
echo -e "${GREEN}✓ Volume directory created${NC}"

# Deploy stack
echo -e "${GREEN}Deploying observability stack with Grafana...${NC}"
docker stack deploy -c monitoring.yml observability
echo -e "${GREEN}✓ Stack deployed${NC}"

# Wait for service to start
echo -e "${YELLOW}Waiting for Grafana service to start...${NC}"
sleep 10

# Check service status
echo -e "${GREEN}Checking Grafana service status:${NC}"
docker service ps observability_grafana --no-trunc

# Show logs
echo -e "${GREEN}Grafana service logs (last 20 lines):${NC}"
docker service logs observability_grafana --tail 20

echo -e "${GREEN}=== Deployment Complete ===${NC}"
echo -e "Grafana will be available at: http://192.168.31.5:3000"
echo -e "Or via proxy: https://grafana.homelab (once configured)"
