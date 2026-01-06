#!/bin/bash

# Deploy Samba stack for media sharing
# This script deploys a Samba container to share /media over the network

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=== Deploying Samba Stack ==="

# Check if .env exists, if not copy from example
cd "$PROJECT_ROOT/stacks/samba-stack"
if [ ! -f .env ]; then
    echo "Creating .env from .env.example..."
    cp .env.example .env
    echo "ERROR: Please edit .env and set SAMBA_PASSWORD before deploying!"
    echo "Run: nano stacks/samba-stack/.env"
    exit 1
fi

# Deploy stack
echo "Deploying samba-stack..."
docker context use homelab
docker stack deploy -c docker-compose.yml samba-stack

echo "=== Samba Stack Deployed ==="
echo ""
echo "To access from macOS:"
echo "  1. Open Finder"
echo "  2. Press Cmd+K"
echo "  3. Enter: smb://192.168.31.5"
echo "  4. Login with user: eduardo, password: (from .env)"
echo ""
echo "To mount permanently:"
echo "  sudo vifs"
echo "  Add: 192.168.31.5/media /Volumes/media smb auto,url=smb://eduardo:PASSWORD@192.168.31.5/media 0 0"
