#!/bin/bash
# Script para criar toda a estrutura de diretórios de media
# Executar no servidor pop-os (eduardo@192.168.31.5)

set -e

echo "=========================================="
echo "Criando estrutura de diretórios Media"
echo "=========================================="
echo ""

if [ "$EUID" -ne 0 ]; then
    echo "Execute como root: sudo bash $0"
    exit 1
fi

echo "Criando diretórios em /data/media..."
mkdir -p /data/media/audiobooks
mkdir -p /data/media/podcasts
mkdir -p /data/media/music
mkdir -p /data/media/books
mkdir -p /data/media/downloads
mkdir -p /data/media/incomplete
mkdir -p /data/media/downloads/books
mkdir -p /data/media/downloads/movies
mkdir -p /data/media/downloads/series
mkdir -p /data/media/downloads/music
mkdir -p /data/media/downloads/audiobooks
mkdir -p /data/media/downloads/podcasts
mkdir -p /data/media/movies
mkdir -p /data/media/series

echo "✓ Diretórios criados em /data/media"
echo ""

echo "Criando diretórios em /media (via bind mount)..."
# /media é um bind mount de /data/media, então os diretórios já aparecem lá
# Mas vamos garantir permissões corretas

echo "✓ Estrutura sincronizada via bind mount"
echo ""

echo "Ajustando permissões (UID 1000:GID 1000)..."
chown -R 1000:1000 /data/media/audiobooks
chown -R 1000:1000 /data/media/podcasts
chown -R 1000:1000 /data/media/music
chown -R 1000:1000 /data/media/books
chown -R 1000:1000 /data/media/downloads
chown -R 1000:1000 /data/media/movies
chown -R 1000:1000 /data/media/series
chown -R 1000:1000 /data/media/incomplete

echo "✓ Permissões ajustadas"
echo ""

echo "Estrutura final:"
echo ""
tree /data/media 2>/dev/null || ls -la /data/media/
echo ""
echo "=========================================="
echo "Diretórios criados com sucesso!"
echo "=========================================="
echo ""
echo "Mapeamentos dos serviços:"
echo "  Audiobookshelf:"
echo "    /media/audiobooks  → /audiobooks"
echo "    /media/podcasts   → /podcasts"
echo ""
echo "  Calibre:"
echo "    /media/books              → /books"
echo "    /media/downloads/books    → /cwa-book-ingest"
echo ""
echo "  Jellyfin:"
echo "    /media/movies    → /movies"
echo "    /media/series    → /series"
echo "    /media/music     → /music"
echo ""
echo "  Arr services:"
echo "    /media/downloads/movies    → torrents/movies"
echo "    /media/downloads/series    → torrents/series"
echo ""
