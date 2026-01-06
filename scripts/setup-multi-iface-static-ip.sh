#!/bin/bash
# Configurar IP estátivo para MÚLTIPLAS interfaces (Ethernet + WiFi)
# O servidor terá o mesmo IP independente de qual interface está ativa

set -e

echo "=========================================="
echo "Setup IP Fixo Multi-Interface"
echo "=========================================="
echo ""

if [ "$EUID" -ne 0 ]; then
    echo "Execute como root: sudo bash $0"
    exit 1
fi

read -p "IP fixo desejado (ex: 192.168.31.2): " STATIC_IP
read -p "Gateway (padrão: 192.168.31.1): " GATEWAY
GATEWAY=${GATEWAY:-192.168.31.1}

# Backup
cp /etc/netplan/90-NM-*.yaml /etc/netplan/backup-before-static-$(date +%Y%m%d-%H%M%S).yaml 2>/dev/null || true

# Detectar TODAS as interfaces ethernet e wireless
ETHERNET_IFACES=$(ip -br addr | grep -E "^(enp|enx)" | awk '{print $1}')
WIFI_IFACES=$(ip -br addr | grep -E "^wlp" | awk '{print $1}')

echo ""
echo "Interfaces encontradas:"
echo "Ethernet: $ETHERNET_IFACES"
echo "WiFi: $WIFI_IFACES"
echo ""

# Criar configuração com todas as interfaces
cat > /etc/netplan/01-static-ip.yaml << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
EOF

# Adicionar cada interface ethernet
for iface in $ETHERNET_IFACES; do
    cat >> /etc/netplan/01-static-ip.yaml << EOF
    $iface:
      dhcp4: no
      addresses:
        - $STATIC_IP/24
      routes:
        - to: default
          via: $GATEWAY
          on-boot: true
      nameservers:
        addresses:
          - 192.168.31.1
          - 8.8.8.8
          - 1.1.1.1
      optional: true
EOF
done

# Adicionar WiFi se existir
if [ -n "$WIFI_IFACES" ]; then
    for iface in $WIFI_IFACES; do
        cat >> /etc/netplan/01-static-ip.yaml << EOF
    $iface:
      dhcp4: no
      addresses:
        - $STATIC_IP/24
      routes:
        - to: default
          via: $GATEWAY
          on-boot: true
      nameservers:
        addresses:
          - 192.168.31.1
          - 8.8.8.8
          - 1.1.1.1
      optional: true
      access-points:
        "NOME_DO_WIFI":
          password: "SENHA_DO_WIFI"
EOF
    done
fi

echo "Arquivo de configuração criado:"
cat /etc/netplan/01-static-ip.yaml
echo ""

echo "Aplicando configuração..."
netplan apply

echo ""
echo "Aguardando conexão..."
sleep 5

echo ""
echo "Verificando configuração:"
ip -br addr | grep -E "(enp|wlp|enx)"
echo ""

echo "Testando conexão..."
ping -c 2 192.168.31.1 && echo "✓ Gateway OK!" || echo "✗ Gateway sem resposta!"
ping -c 2 8.8.8.8 && echo "✓ Internet OK!" || echo "✗ Sem internet!"

echo ""
echo "=========================================="
echo "Configuração concluída!"
echo "=========================================="
echo ""
echo "Seu novo IP fixo: $STATIC_IP"
echo ""
echo "⚠️  ATUALIZE SUAS CONFIGURAÇÕES:"
echo "   1. SSH: ssh eduardo@$STATIC_IP"
echo "   2. Docker context: docker context create ... --docker-host=tcp://$STATIC_IP:2375"
echo "   3. Nginx Proxy Manager"
echo "   4. Scripts que usam 192.168.31.5"
echo ""
