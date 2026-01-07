#!/bin/bash
# Gerar certificado SSL para homelab
# Execute no Helios (192.168.31.5)

sudo mkdir -p /data/docker/nginx-proxy/ssl
sudo openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
  -keyout /data/docker/nginx-proxy/ssl/homelab.key \
  -out /data/docker/nginx-proxy/ssl/homelab.crt \
  -subj "/C=BR/ST=SP/L=SaoPaulo/O=Homelab/CN=*.homelab" \
  -addext "subjectAltName=DNS:*.homelab,DNS:homelab"
sudo chown -R 1000:1000 /data/docker/nginx-proxy/ssl

echo "✓ Certificado criado!"
echo "Key: /data/docker/nginx-proxy/ssl/homelab.key"
echo "CRT: /data/docker/nginx-proxy/ssl/homelab.crt"
