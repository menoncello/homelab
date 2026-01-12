#!/bin/bash
# Script completo de setup do Pi-hole para Homelab
# Execute no Helios (192.168.31.5) como eduardo

set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     Pi-hole Homelab DNS Setup                              ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# 1. Parar systemd-resolved
echo "[1/5] Parando systemd-resolved..."
sudo systemctl stop systemd-resolved 2>/dev/null || echo "  systemd-resolved já parado"
sudo systemctl disable systemd-resolved 2>/dev/null || echo "  systemd-resolved já desabilitado"

# 2. Remover resolv.conf existente
echo "[2/5] Configurando /etc/resolv.conf..."
sudo rm -f /etc/resolv.conf

# 3. Criar novo resolv.conf com DNS upstream
sudo tee /etc/resolv.conf > /dev/null <<EOF
nameserver 1.1.1.1
nameserver 1.0.0.1
# Pi-hole vai assumir a porta 53 localmente
EOF

echo "  ✓ /etc/resolv.conf configurado"

# 4. Criar diretório e arquivo de DNS local
echo "[3/5] Criando configuração de DNS local..."
sudo mkdir -p /data/docker/pihole

sudo tee /data/docker/pihole/local-dns.conf > /dev/null <<'DNSCONFIG'
# Local DNS Records for Homelab

# Helios (192.168.31.5) Services
address=/jellyfin.homelab/192.168.31.5
address=/sonarr.homelab/192.168.31.5
address=/radarr.homelab/192.168.31.5
address=/lidarr.homelab/192.168.31.5
address=/transmission.homelab/192.168.31.5
address=/home.homelab/192.168.31.5
address=/pihole.homelab/192.168.31.5
address=/proxy.homelab/192.168.31.5

# Xeon01 (192.168.31.6) Services
address=/nextcloud.homelab/192.168.31.6
address=/audiobookshelf.homelab/192.168.31.6
address=/n8n.homelab/192.168.31.6
address=/kavita.homelab/192.168.31.6
address=/stacks.homelab/192.168.31.6

# Server aliases
address=/helios.homelab/192.168.31.5
address=/xeon01.homelab/192.168.31.6
DNSCONFIG

sudo chown 1000:1000 /data/docker/pihole/local-dns.conf
echo "  ✓ DNS local configurado"

# 5. Verificar porta 53
echo "[4/5] Verificando porta 53..."
if ss -lntp '( sport = :53 )' 2>/dev/null | grep -q ":53"; then
    echo "  ⚠ Porta 53 ainda em uso, pode ser o Pi-hole antigo"
else
    echo "  ✓ Porta 53 liberada"
fi

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Setup concluído!                                          ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "[5/5] Próximos passos:"
echo ""
echo "1. No seu computador local, redeploy o Pi-hole:"
echo ""
echo "   cd ~/repos/setup/homelab/stacks/pihole"
echo "   docker -H ssh://eduardo@192.168.31.5 stack deploy -c docker-compose.yml pihole"
echo ""
echo "2. Teste a resolução de DNS:"
echo "   dig @192.168.31.5 jellyfin.homelab"
echo ""
echo "3. Configure seus dispositivos para usar DNS: 192.168.31.5"
echo ""
