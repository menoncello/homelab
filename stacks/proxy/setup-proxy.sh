#!/bin/bash
# Script completo de setup do Nginx Proxy Manager
# Configura proxy hosts + SSL para todos os serviços

set -e

# Configurações
NGINX_PM_URL="http://192.168.31.5:81"
NGINX_PM_USER="eduardo.menoncello@gmail.com"
NGINX_PM_PASS="4PFucpC3AdEwWC23E!PuenQuYDJRiCbREQWRN3G!"
CERT_NAME="homelab"
REMOTE_HOST="eduardo@192.168.31.5"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     Nginx Proxy Manager Setup                              ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Verificar se Nginx PM está acessível
echo "[1/6] Verificando Nginx Proxy Manager..."
if ! curl -s "$NGINX_PM_URL" > /dev/null; then
    echo -e "${RED}✗ Nginx PM não está acessível em $NGINX_PM_URL${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Nginx PM acessível${NC}"

# Ler certificado do servidor remoto
echo ""
echo "[2/6] Lendo certificado SSL..."
CERT_CONTENT=$(ssh "$REMOTE_HOST" "cat /data/docker/nginx-proxy/ssl/homelab.crt" | awk 'NF {sub(/\r/, ""); printf "%s\\n",$0}')
KEY_CONTENT=$(ssh "$REMOTE_HOST" "cat /data/docker/nginx-proxy/ssl/homelab.key" | awk 'NF {sub(/\r/, ""); printf "%s\\n",$0}')
echo -e "${GREEN}✓ Certificado lido${NC}"

# Fazer login e obter token
echo ""
echo "[3/6] Autenticando na API..."
TOKEN=$(curl -s "$NGINX_PM_URL/api/tokens" \
  -H "Content-Type: application/json" \
  -d "{\"identity\":\"$NGINX_PM_USER\",\"secret\":\"$NGINX_PM_PASS\"}" \
  | jq -r '.token // empty')

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
    echo -e "${RED}✗ Falha na autenticação${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Autenticado${NC}"

# Criar certificado customizado no Nginx PM
echo ""
echo "[4/6] Importando certificado para Nginx PM..."

CERT_ID=$(curl -s "$NGINX_PM_URL/api/nginx/custom-certificates" \
  -H "Authorization: Bearer $TOKEN" \
  | jq -r ".[] | select(.certificate.nice_name==\"$CERT_NAME\") | .id // empty")

if [ -z "$CERT_ID" ]; then
    CERT_RESPONSE=$(curl -s "$NGINX_PM_URL/api/nginx/custom-certificates" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d "{
        \"nice_name\": \"$CERT_NAME\",
        \"certificate\": \"$CERT_CONTENT\",
        \"key\": \"$KEY_CONTENT\"
      }")
    CERT_ID=$(echo "$CERT_RESPONSE" | jq -r '.id // empty')
    echo -e "${GREEN}✓ Certificado importado (ID: $CERT_ID)${NC}"
else
    echo -e "${YELLOW}⚠ Certificado já existe (ID: $CERT_ID), atualizando...${NC}"
    curl -s "$NGINX_PM_URL/api/nginx/custom-certificates/$CERT_ID" \
      -X PUT \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d "{
        \"nice_name\": \"$CERT_NAME\",
        \"certificate\": \"$CERT_CONTENT\",
        \"key\": \"$KEY_CONTENT\"
      }" > /dev/null
    echo -e "${GREEN}✓ Certificado atualizado${NC}"
fi

# Ler hosts do JSON
echo ""
echo "[5/6] Configurando proxy hosts..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTS_JSON="$SCRIPT_DIR/config/proxy-hosts.json"

if [ ! -f "$HOSTS_JSON" ]; then
    echo -e "${RED}✗ Arquivo $HOSTS_JSON não encontrado${NC}"
    exit 1
fi

HOST_COUNT=$(jq '.hosts | length' "$HOSTS_JSON")
echo "  Configurando $HOST_COUNT serviços..."

# Criar hosts
jq -c '.hosts[]' "$HOSTS_JSON" | while read -r host; do
    DOMAIN=$(echo "$host" | jq -r '.domain')
    TARGET=$(echo "$host" | jq -r '.target')
    PORT=$(echo "$host" | jq -r '.port')
    NAME=$(echo "$host" | jq -r '.name')

    # Verificar se host já existe
    EXISTING=$(curl -s "$NGINX_PM_URL/api/nginx/proxy-hosts" \
      -H "Authorization: Bearer $TOKEN" \
      | jq -r ".[] | select(.domain_names==[\"$DOMAIN\"]) | .id // empty")

    if [ -n "$EXISTING" ]; then
        echo -e "  ${YELLOW}⚠ $NAME ($DOMAIN) já existe, atualizando...${NC}"
        curl -s "$NGINX_PM_URL/api/nginx/proxy-hosts/$EXISTING" \
          -X DELETE \
          -H "Authorization: Bearer $TOKEN" > /dev/null
    fi

    # Criar proxy host
    RESULT=$(curl -s "$NGINX_PM_URL/api/nginx/proxy-hosts" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d "{
        \"domain_names\": [\"$DOMAIN\"],
        \"forward_host\": \"$TARGET\",
        \"forward_port\": $PORT,
        \"access_list_id\": \"0\",
        \"certificate_id\": $CERT_ID,
        \"ssl_forced\": true,
        \"http2_support\": true,
        \"forward_scheme\": \"http\",
        \"enabled\": true,
        \"meta\": {
          \"letsencrypt_agree\": false,
          \"dns_challenge\": false
        }
      }")

    HOST_ID=$(echo "$RESULT" | jq -r '.id // empty')

    if [ -n "$HOST_ID" ] && [ "$HOST_ID" != "null" ]; then
        echo -e "  ${GREEN}✓ $NAME → https://$DOMAIN${NC}"
    else
        echo -e "  ${RED}✗ $NAME falhou: $RESULT${NC}"
    fi
done

# Resumo
echo ""
echo "[6/6] Configuração concluída!"
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Serviços configurados                                      ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Acesse os serviços via:"
jq -r '.hosts[] | "  • https://\(.domain) → \(.name)"' "$HOSTS_JSON"
echo ""
echo -e "${YELLOW}⚠ Nota: O certificado é auto-assinado.${NC}"
echo "  Seu navegador mostrará um aviso de segurança."
echo "  Clique 'Avançado' → 'Aceitar o risco' para continuar."
echo ""
