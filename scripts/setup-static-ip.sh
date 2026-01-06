#!/bin/bash
# Configurar IP estático para servidor
# Execute com: sudo bash setup-static-ip.sh

set -e

echo "=========================================="
echo "Configuração de IP Estático"
echo "=========================================="
echo ""

if [ "$EUID" -ne 0 ]; then
    echo "Execute como root: sudo bash $0"
    exit 1
fi

# Detectar interfaces
echo "Interfaces de rede detectadas:"
ip -br addr | grep -E "(enp|wlp|enx)"

echo ""
read -p "Qual a interface PRINCIPAL? (ex: enx00e04c680030): " MAIN_IFACE
read -p "Qual IP fixo deseja? (ex: 192.168.31.2): " STATIC_IP
read -p "Qual o gateway? (padrão: 192.168.31.1): " GATEWAY
GATEWAY=${GATEWAY:-192.168.31.1}

# Configurar Netplan
cat > /etc/netplan/01-static-ip.yaml << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $MAIN_IFACE:
      dhcp4: no
      addresses:
        - $STATIC_IP/24
      routes:
        - to: default
          via: $GATEWAY
      nameservers:
        addresses:
          - 192.168.31.1
          - 8.8.8.8
          - 1.1.1.1
EOF

echo ""
echo "Arquivo de configuração criado:"
cat /etc/netplan/01-static-ip.yaml
echo ""

echo "Aplicando configuração..."
netplan apply

echo ""
echo "Aguardando conexão..."
sleep 5

echo ""
echo "Nova configuração:"
ip addr show $MAIN_IFACE | grep "inet "
echo ""
echo "Testando conexão..."
ping -c 3 192.168.31.1 || echo "Aviso: Gateway não responde!"

echo ""
echo "=========================================="
echo "Configuração concluída!"
echo "=========================================="
echo ""
echo "Seu IP fixo é: $STATIC_IP"
echo ""
echo "IMPORTANTE: Atualize seus scripts e configurações!"
echo "  - Docker context"
echo "  - SSH configs"
echo "  - Nginx Proxy Manager"
echo ""
