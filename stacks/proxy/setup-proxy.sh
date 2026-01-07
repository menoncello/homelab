#!/bin/bash
# Script completo de setup do Nginx Proxy Manager
# Configura proxy hosts + SSL para todos os serviços

set -e

# Configurações
NGINX_PM_URL="http://192.168.31.5:81"
NGINX_PM_USER="admin@example.com"
NGINX_PM_PASS="changeme"  # Usuário deve mudar no primeiro acesso
CERT_DIR="/data/docker/nginx-proxy/ssl"
CERT_NAME="homelab-local"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     Nginx Proxy Manager Setup                              ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Verificar se Nginx PM está acessível
echo "[1/6] Verificando Nginx Proxy Manager..."
if ! curl -s "$NGINX_PM_URL" > /dev/null; then
    echo -e "${RED}✗ Nginx PM não está acessível em $NGINX_PM_URL${NC}"
    echo "  Verifique se o container está rodando:"
    echo "  docker service ls | grep proxy"
    exit 1
fi
echo -e "${GREEN}✓ Nginx PM acessível${NC}"

# Gerar certificado SSL
echo ""
echo "[2/6] Gerando certificado SSL..."
if [ ! -f "$CERT_DIR/$CERT_NAME.crt" ]; then
    sudo mkdir -p "$CERT_DIR"
    sudo openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
      -keyout "$CERT_DIR/$CERT_NAME.key" \
      -out "$CERT_DIR/$CERT_NAME.crt" \
      -subj "/C=BR/ST=SP/L=SaoPaulo/O=Homelab/CN=homelab.local" \
      -addext "subjectAltName=DNS:*.homelab.local,DNS:homelab.local"
    sudo chown -R 1000:1000 "$CERT_DIR"
    echo -e "${GREEN}✓ Certificado gerado${NC}"
else
    echo -e "${YELLOW}⚠ Certificado já existe, pulando...${NC}"
fi

# Fazer login e obter token
echo ""
echo "[3/6] Autenticando na API..."
TOKEN=$(curl -s "$NGINX_PM_URL/api/tokens" \
  -H "Content-Type: application/json" \
  -d "{\"identity\":\"$NGINX_PM_USER\",\"secret\":\"$NGINX_PM_PASS\"}" \
  | jq -r '.token // empty')

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
    echo -e "${RED}✗ Falha na autenticação${NC}"
    echo ""
    echo "Possíveis causas:"
    echo "  1. Credenciais incorretas (verifique NGINX_PM_USER e NGINX_PM_PASS)"
    echo "  2. Primeiro acesso necessário - acesse http://192.168.31.5:81"
    echo "     e faça login inicial para criar o usuário admin"
    echo ""
    echo "Após configurar, atualize as credenciais neste script e execute novamente."
    exit 1
fi
echo -e "${GREEN}✓ Autenticado${NC}"

# Criar certificado customizado no Nginx PM
echo ""
echo "[4/6] Importando certificado para Nginx PM..."

CERT_CONTENT=$(sudo cat "$CERT_DIR/$CERT_NAME.crt" | awk 'NF {sub(/\r/, ""); printf "%s\\n",$0}')
KEY_CONTENT=$(sudo cat "$CERT_DIR/$CERT_NAME.key" | awk 'NF {sub(/\r/, ""); printf "%s\\n",$0}')

CERT_ID=$(curl -s "$NGINX_PM_URL/api/nginx/custom-certificates" \
  -H "Authorization: Bearer $TOKEN" \
  | jq -r ".[] | select(.certificate.nice_name==\"$CERT_NAME\") | .id // empty")

if [ -z "$CERT_ID" ]; then
    # Criar novo certificado
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

        # Deletar host existente para recriar com certificado
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
echo "  Adicione uma exceção de segurança para continuar."
echo ""
