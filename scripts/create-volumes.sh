#!/bin/bash
# scripts/create-volumes.sh

echo "Creating persistent volume structure for Homelab..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or with sudo"
    exit 1
fi

# Detect which server we're on
HOSTNAME=$(hostname)
echo "Running on: $HOSTNAME"

if [ "$HOSTNAME" = "helios" ]; then
    echo "Setting up Helios volumes..."

    # Helios: /data/docker for configs
    echo "Creating /data/docker directories..."
    mkdir -p /data/docker/{jellyfin,sonarr,radarr,transmission,nginx-proxy,ebook2audiobook}
    mkdir -p /data/docker/ebook2audiobook/{config,models,output}

    # Helios: /media for media libraries
    echo "Creating /media directories..."
    mkdir -p /media/{movies,series,anime,incomplete,incoming,ebooks}

    echo "Setting permissions..."
    chown -R 1000:1000 /data/docker/
    chown -R 1000:1000 /media/

    echo "✓ Helios volumes created"
    echo "  - /data/docker (configs)"
    echo "  - /media (libraries)"

elif [ "$HOSTNAME" = "xeon01" ]; then
    echo "Setting up Xeon01 volumes..."

    # Xeon01: /srv/docker for configs
    echo "Creating /srv/docker directories..."
    mkdir -p /srv/docker/{nextcloud,audiobookshelf,postgresql}
    mkdir -p /srv/docker/nextcloud/data
    mkdir -p /srv/docker/audiobookshelf/{config,metadata,audiobooks}
    mkdir -p /srv/docker/postgresql/data

    # Xeon01: /home/docker-data for large data
    echo "Creating /home/docker-data directories..."
    mkdir -p /home/docker-data/audiobooks
    mkdir -p /home/docker-data/nextcloud

    echo "Setting permissions..."
    chown -R 1000:1000 /srv/docker/
    chown -R 1000:1000 /home/docker-data/

    echo "✓ Xeon01 volumes created"
    echo "  - /srv/docker (configs)"
    echo "  - /home/docker-data (large data)"

else
    echo "Warning: Unknown hostname '$HOSTNAME'"
    echo "Expected 'helios' or 'xeon01'"
    echo ""
    echo "Creating generic volume structure..."

    # Generic setup
    mkdir -p /data/docker/{jellyfin,sonarr,radarr,transmission,nginx-proxy}
    mkdir -p /media/{movies,series,anime,incomplete}
    mkdir -p /srv/docker/{nextcloud,audiobookshelf,postgresql}
    mkdir -p /home/docker-data/{audiobooks,nextcloud}

    chown -R 1000:1000 /data/docker/ /media/ /srv/docker/ /home/docker-data/

    echo "✓ Generic volumes created"
fi

echo ""
echo "Volume structure created successfully!"
echo ""
echo "Summary:"
df -h | grep -E "(/data|/media|/srv|/home|$)" | awk '{print "  " $NF " - " $3 " available of " $2}'
