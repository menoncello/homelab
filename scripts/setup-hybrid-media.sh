#!/bin/bash
# Setup HÍBRIDO: Movies + Books no HD 480GB, resto no disco grande
# Executar no servidor pop-os (eduardo@192.168.31.5)

set -e

echo "=========================================="
echo "Setup HÍBRIDO de Media"
echo "=========================================="
echo ""
echo "HD 480GB (/dev/nvme1n1p1):"
echo "  - movies/     (Filmes)"
echo "  - books/      (Ebooks/Calibre)"
echo ""
echo "Disco Grande (root /):"
echo "  - series/"
echo "  - music/"
echo "  - audiobooks/"
echo "  - podcasts/"
echo "  - incomplete/"
echo "  - downloads/"
echo ""
echo "=========================================="
echo ""

if [ "$EUID" -ne 0 ]; then
    echo "Execute como root: sudo bash $0"
    exit 1
fi

# Parar serviços
echo "Parando serviços Docker..."
for svc in audiobookshelf_audiobookshelf calibre_calibre gpu-services_jellyfin arr-stack_radarr arr-stack_sonarr arr-stack_bazarr; do
    docker service scale $svc=0 2>/dev/null || true
done
sleep 5

# Desmontar tudo
echo "Desmontando montagens antigas..."
umount /media 2>/dev/null || true
rm -f /media  # Remover symlink se existir

# Limpar e recriar fstab
cp /etc/fstab /etc/fstab.backup.hybrid-$(date +%Y%m%d-%H%M%S)
sed -i '/storage.*media.*bind/d' /etc/fstab
sed -i '/data.*media.*bind/d' /etc/fstab
sed -i '/^\/dev\/nvme1n1p1.*\/data\/media/d' /etc/fstab

# Criar estrutura no disco grande (root)
echo "Criando estrutura no disco grande..."
mkdir -p /data/media
mkdir -p /data/media/series
mkdir -p /data/media/music
mkdir -p /data/media/audiobooks
mkdir -p /data/media/podcasts
mkdir -p /data/media/incomplete
mkdir -p /data/media/downloads
mkdir -p /data/media/downloads/books
mkdir -p /data/media/downloads/movies
mkdir -p /data/media/downloads/series
mkdir -p /data/media/downloads/music
mkdir -p /data/media/downloads/audiobooks
mkdir -p /data/media/downloads/podcasts

# Montar disco de 480GB
echo "Montando HD 480GB em /storage..."
mkdir -p /storage
mount /dev/nvme1n1p1 /storage 2>/dev/null || umount /storage 2>/dev/null
mount /dev/nvme1n1p1 /storage

# Copiar movies e books do disco grande para o HD 480GB (se existirem)
echo "Copiando dados existentes (pode levar um tempo)..."
if [ "$(ls -A /data/media/movies 2>/dev/null)" ]; then
    echo "  Copiando movies..."
    mkdir -p /storage/movies
    rsync -av --progress /data/media/movies/ /storage/movies/ 2>/dev/null || true
fi

if [ "$(ls -A /data/media/books 2>/dev/null)" ]; then
    echo "  Copiando books..."
    mkdir -p /storage/books
    rsync -av --progress /data/media/books/ /storage/books/ 2>/dev/null || true
fi

# Criar diretórios no HD 480GB
echo "Criando diretórios no HD 480GB..."
mkdir -p /storage/movies
mkdir -p /storage/books

# Remover do disco grande e criar bind mounts
echo "Criando bind mounts..."
rmdir /data/media/movies 2>/dev/null || rm -rf /data/media/movies/* 2>/dev/null || true
rmdir /data/media/books 2>/dev/null || rm -rf /data/media/books/* 2>/dev/null || true

# Criar bind mounts no fstab
cat >> /etc/fstab << 'EOF'

# Hybrid media setup - Movies and Books on 480GB disk
/storage/movies    /data/media/movies    none    bind    0    0
/storage/books     /data/media/books     none    bind    0    0
/data/media        /media                none    bind    0    0
EOF

# Montar bind mounts
mount /data/media/movies
mount /data/media/books
mount /media

# Ajustar permissões
echo "Ajustando permissões..."
chown -R 1000:1000 /data/media/
chown -R 1000:1000 /storage/

# Mostrar estrutura final
echo ""
echo "=========================================="
echo "Estrutura HÍBRIDA criada!"
echo "=========================================="
echo ""
echo "Montagens:"
mount | grep -E "(media|storage)"
echo ""
echo "Estrutura:"
echo "  /data/media/movies  → /storage/movies  (HD 480GB)"
echo "  /data/media/books   → /storage/books   (HD 480GB)"
echo "  /data/media/series  → disco grande"
echo "  /data/media/music   → disco grande"
echo "  /data/media/audiobooks → disco grande"
echo "  /data/media/podcasts  → disco grande"
echo ""
echo "Para serviços Docker (via /media):"
echo "  /media/movies  → HD 480GB"
echo "  /media/books   → HD 480GB"
echo "  /media/series  → Disco grande"
echo "  /media/music   → Disco grande"
echo ""
echo "Reiniciando serviços..."
for svc in audiobookshelf_audiobookshelf calibre_calibre gpu-services_jellyfin arr-stack_radarr arr-stack_sonarr arr-stack_bazarr; do
    docker service scale $svc=1 2>/dev/null || true
    echo "  ✓ $svc"
done

echo ""
echo "Pronto! Verifique com: df -h"
