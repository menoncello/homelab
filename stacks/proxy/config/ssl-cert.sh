#!/bin/bash
# Gerar certificado SSL auto-assinado para homelab
# Execute no servidor Helios

set -e

CERT_DIR="/data/docker/nginx-proxy/ssl"
CERT_NAME="homelab-local"
DOMAIN="*.homelab"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     Gerando Certificado SSL Auto-assinado                  ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Criar diretório
echo "[1/4] Criando diretório de certificados..."
sudo mkdir -p "$CERT_DIR"
echo "  ✓ $CERT_DIR"

# Gerar certificado
echo "[2/4] Gerando certificado SSL wildcard..."
sudo openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
  -keyout "$CERT_DIR/$CERT_NAME.key" \
  -out "$CERT_DIR/$CERT_NAME.crt" \
  -subj "/C=BR/ST=SP/L=SaoPaulo/O=Homelab/CN=homelab" \
  -addext "subjectAltName=DNS:$DOMAIN,DNS:homelab"

echo "  ✓ Certificado gerado"

# Ajustar permissões
echo "[3/4] Ajustando permissões..."
sudo chown -R 1000:1000 "$CERT_DIR"
chmod 600 "$CERT_DIR/$CERT_NAME.key"
chmod 644 "$CERT_DIR/$CERT_NAME.crt"
echo "  ✓ Permissões ajustadas"

# Mostrar informações
echo "[4/4] Informações do certificado:"
echo ""
sudo openssl x509 -in "$CERT_DIR/$CERT_NAME.crt" -noout -subject -dates
echo ""

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Certificado gerado com sucesso!                           ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Arquivos criados:"
echo "  - $CERT_DIR/$CERT_NAME.crt"
echo "  - $CERT_DIR/$CERT_NAME.key"
echo ""
echo "Válido para: *.homelab"
echo "Validade: 10 anos"
echo ""
