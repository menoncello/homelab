#!/bin/bash
# Script para configurar Pi-hole como DNS principal do homelab
# Execute no Helios (192.168.31.5) como eduardo

set -e

echo "=== Configurando Pi-hole como DNS principal ==="
echo ""

echo "1. Parando e desabilitando systemd-resolved..."
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved

echo "2. Removendo resolv.conf existente (link simbólico)..."
sudo rm -f /etc/resolv.conf

echo "3. Criando novo /etc/resolv.conf com DNS upstream (Cloudflare)..."
sudo tee /etc/resolv.conf > /dev/null <<EOF
nameserver 1.1.1.1
nameserver 1.0.0.1
# O Pi-hole vai assumir a porta 53 e servirá como DNS local
EOF

echo "4. Verificando configuração..."
cat /etc/resolv.conf

echo ""
echo "5. Verificando se porta 53 está livre..."
ss -lntp '( sport = :53 )' || echo "✓ Porta 53 liberada!"

echo ""
echo "=== Pronto! Agora redeploy o Pi-hole ==="
echo "Execute: cd stacks/pihole && docker stack deploy -c docker-compose.yml pihole"
