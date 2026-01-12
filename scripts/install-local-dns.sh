#!/bin/bash
# Instalar DNS local no Pi-hole
# Execute no Helios (192.168.31.5) como eduardo

set -e

VOLUME_PATH="/var/lib/docker/volumes/pihole-config/_data"
CUSTOM_LIST="$VOLUME_PATH/custom.list"

echo "=== Instalando DNS local no Pi-hole ==="

# Criar arquivo custom.list
sudo tee "$CUSTOM_LIST" > /dev/null <<EOF
192.168.31.5 jellyfin.homelab
192.168.31.5 sonarr.homelab
192.168.31.5 radarr.homelab
192.168.31.5 lidarr.homelab
192.168.31.5 transmission.homelab
192.168.31.5 home.homelab
192.168.31.5 pihole.homelab
192.168.31.5 proxy.homelab
192.168.31.6 nextcloud.homelab
192.168.31.6 audiobookshelf.homelab
192.168.31.6 n8n.homelab
192.168.31.6 kavita.homelab
192.168.31.6 stacks.homelab
192.168.31.5 helios.homelab
192.168.31.6 xeon01.homelab
EOF

# Ajustar permissões
sudo chown 1000:1000 "$CUSTOM_LIST"

echo "✓ DNS local instalado"
echo ""
echo "Reiniciando Pi-hole..."
docker service update --force pihole_pihole 2>&1 | grep -E "(overall progress|converged)" | tail -2

echo ""
echo "=== Pronto! ==="
echo "Aguarde 10 segundos e teste:"
echo "  dig @192.168.31.5 jellyfin.homelab"
