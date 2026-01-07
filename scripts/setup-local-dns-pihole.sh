#!/bin/bash
# Configurar DNS local no Pi-hole (via custom.list)
# Execute no Helios como eduardo

set -e

VOLUME_PATH="/var/lib/docker/volumes/pihole-config/_data"

echo "=== Criando custom.list no volume do Pi-hole ==="

sudo tee "$VOLUME_PATH/custom.list" > /dev/null <<EOF
192.168.31.5 jellyfin.homelab.local
192.168.31.5 sonarr.homelab.local
192.168.31.5 radarr.homelab.local
192.168.31.5 lidarr.homelab.local
192.168.31.5 transmission.homelab.local
192.168.31.5 homarr.homelab.local
192.168.31.5 pihole.homelab.local
192.168.31.5 proxy.homelab.local
192.168.31.6 nextcloud.homelab.local
192.168.31.6 audiobookshelf.homelab.local
192.168.31.6 n8n.homelab.local
192.168.31.6 kavita.homelab.local
192.168.31.6 stacks.homelab.local
192.168.31.5 helios.homelab.local
192.168.31.6 xeon01.homelab.local
EOF

sudo chown 1000:1000 "$VOLUME_PATH/custom.list"

echo "✓ Arquivo criado"
echo ""
echo "Reiniciando Pi-hole..."
docker service update --force pihole_pihole 2>&1 | tail -3

echo ""
echo "=== Aguarde 10 segundos e teste ==="
echo "dig @192.168.31.5 jellyfin.homelab.local"
