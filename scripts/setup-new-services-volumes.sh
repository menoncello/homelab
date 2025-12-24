#!/bin/bash
# Setup script for new homelab services volumes
# Run on BOTH Helios (192.168.31.237) and Xeon01 (192.168.31.208)

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
    echo "==> Setting up Helios volumes (192.168.31.237)..."

    # Homarr
    echo "  -> Creating Homarr volumes..."
    sudo mkdir -p /data/docker/homarr/data
    sudo chown -R 1000:1000 /data/docker/homarr

    # Lidarr
    echo "  -> Creating Lidarr volumes..."
    sudo mkdir -p /data/docker/lidarr
    sudo chown -R 1000:1000 /data/docker/lidarr

    # Downloads (shared)
    echo "  -> Ensuring downloads directory exists..."
    sudo mkdir -p /media/downloads
    sudo chown -R 1000:1000 /media/downloads

    echo "✓ Helios volumes created!"
}

setup_xeon01() {
    echo "==> Setting up Xeon01 volumes (192.168.31.208)..."

    # n8n
    echo "  -> Creating n8n volumes..."
    sudo mkdir -p /srv/docker/n8n
    sudo chown -R 1000:1000 /srv/docker/n8n

    # Music library for Lidarr
    echo "  -> Creating music library..."
    sudo mkdir -p /home/docker-data/music
    sudo chown -R 1000:1000 /home/docker-data/music

    echo "✓ Xeon01 volumes created!"
}

# Main logic
if [[ "$IP" == "192.168.31.237" ]] || [[ "$HOSTNAME" == "helios" ]]; then
    setup_helios
elif [[ "$IP" == "192.168.31.208" ]] || [[ "$HOSTNAME" == "xeon01" ]]; then
    setup_xeon01
else
    echo "ERROR: Unknown server. Please run on Helios (192.168.31.237) or Xeon01 (192.168.31.208)"
    exit 1
fi

echo ""
echo "==> Verifying volumes..."
echo "Helios volumes:"
echo "  /data/docker/homarr"
echo "  /data/docker/lidarr"
echo "  /media/downloads"
echo ""
echo "Xeon01 volumes:"
echo "  /srv/docker/n8n"
echo "  /home/docker-data/music"
echo ""
echo "==> Done! Ready to deploy new services."
