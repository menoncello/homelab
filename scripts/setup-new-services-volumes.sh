#!/bin/bash
# Setup script for new homelab services volumes
# Run on BOTH Helios (192.168.31.75) and Xeon01 (192.168.31.208)

set -e

echo "==> Setting up volumes for new homelab services..."
echo "==> Node: $(hostname)"
echo "==> IP: $(hostname -I | awk '{print $1}')"
echo ""

# Detect which server we're on
HOSTNAME=$(hostname)
IP=$(hostname -I | awk '{print $1}')

# Functions for each server
setup_helios() {
    echo "==> Setting up Helios volumes (192.168.31.75)..."

    # Homarr
    echo "  -> Creating Homarr volumes..."
    sudo mkdir -p /data/docker/homarr/data
    sudo chown -R 1000:1000 /data/docker/homarr

    # Lidarr
    echo "  -> Creating Lidarr volumes..."
    sudo mkdir -p /data/docker/lidarr
    sudo chown -R 1000:1000 /data/docker/lidarr

    # Music library for Lidarr
    echo "  -> Creating music library..."
    sudo mkdir -p /media/music
    sudo chown -R 1000:1000 /media/music

    # Downloads (shared)
    echo "  -> Ensuring downloads directory exists..."
    sudo mkdir -p /media/downloads
    sudo chown -R 1000:1000 /media/downloads

    echo "✓ Helios volumes created!"
}

setup_xeon01() {
    echo "==> Setting up Xeon01 volumes (192.168.31.208)..."

    # PostgreSQL
    echo "  -> Creating PostgreSQL volumes..."
    sudo mkdir -p /srv/docker/postgresql
    sudo chown -R 999:999 /srv/docker/postgresql

    # Redis
    echo "  -> Creating Redis volumes..."
    sudo mkdir -p /srv/docker/redis
    sudo chown -R 999:999 /srv/docker/redis

    # n8n
    echo "  -> Creating n8n volumes..."
    sudo mkdir -p /srv/docker/n8n
    sudo chown -R 1000:1000 /srv/docker/n8n

    # Music library for Lidarr
    echo "  -> Creating music library..."
    sudo mkdir -p /home/docker-data/music
    sudo chown -R 1000:1000 /home/docker-data/music

    # Kavita
    echo "  -> Creating Kavita volumes..."
    sudo mkdir -p /srv/docker/kavita/config
    sudo mkdir -p /srv/docker/books
    sudo chown -R 1000:1000 /srv/docker/kavita
    sudo chown -R 1000:1000 /srv/docker/books

    # Stacks
    echo "  -> Creating Stacks volumes..."
    sudo mkdir -p /srv/docker/stacks/{config,logs}
    sudo chown -R 1000:1000 /srv/docker/stacks

    echo "✓ Xeon01 volumes created!"
}

# Main logic
if [[ "$IP" == "192.168.31.75" ]] || [[ "$IP" == "192.168.31.237" ]] || [[ "$HOSTNAME" == "helios" ]] || [[ "$HOSTNAME" == "pop-os" ]]; then
    setup_helios
elif [[ "$IP" == "192.168.31.208" ]] || [[ "$HOSTNAME" == "xeon01" ]]; then
    setup_xeon01
else
    echo "ERROR: Unknown server. Please run on Helios (192.168.31.75) or Xeon01 (192.168.31.208)"
    exit 1
fi

echo ""
echo "==> Verifying volumes..."
echo "Helios volumes:"
echo "  /data/docker/homarr"
echo "  /data/docker/lidarr"
echo "  /media/music"
echo "  /media/downloads"
echo ""
echo "Xeon01 volumes:"
echo "  /srv/docker/postgresql"
echo "  /srv/docker/redis"
echo "  /srv/docker/n8n"
echo "  /srv/docker/kavita/config"
echo "  /srv/docker/books (shared with Stacks)"
echo "  /srv/docker/stacks/{config,logs}"
echo ""
echo "==> Done! Ready to deploy new services."
