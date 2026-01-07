#!/bin/bash
# Fix permissions for Nginx Proxy Manager
# Execute no Helios (192.168.31.5)

echo "=== Corrigindo permissões do Nginx Proxy Manager ==="

# Parar serviço para corrigir permissões
echo "[1/3] Parando serviço..."
docker service scale proxy_nginx-proxy=0

# Aguardar parada
echo "[2/3] Aguardando container parar..."
sleep 5

# Criar diretório de logs e corrigir permissões
echo "[3/3] Corrigindo permissões..."
VOLUME_PATH="/var/lib/docker/volumes/nginx-proxy-data/_data"

# Criar diretórios necessários com permissões corretas
sudo mkdir -p "$VOLUME_PATH/logs"
sudo mkdir -p "$VOLUME_PATH/data"
sudo mkdir -p "$VOLUME_PATH/nginx"

# Ajustar permissões (o container roda como UID 1000)
sudo chown -R 1000:1000 "$VOLUME_PATH"
sudo chmod -R 755 "$VOLUME_PATH"

echo ""
echo "=== Permissões corrigidas! ==="
echo ""
echo "Reiniciando serviço..."

# Reiniciar serviço
docker service scale proxy_nginx-proxy=1

echo ""
echo "Aguarde 30 segundos e acesse: http://192.168.31.5:81"
echo ""
