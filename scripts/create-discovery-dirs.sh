#!/bin/bash
# Script para criar diretórios da Discovery Stack
# Execute este script EM CADA SERVIDOR

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Criando diretórios para Discovery/Media Stacks ===${NC}"
echo ""

# Get hostname
HOSTNAME=$(hostname)

echo -e "${YELLOW}Servidor: $HOSTNAME${NC}"
echo ""

# Common function to create directories
create_dirs() {
    local path=$1
    local owner=$2
    echo "Criando $path..."
    sudo mkdir -p "$path"
    sudo chown -R "$owner:$owner" "$path"
    echo -e "${GREEN}✓ $path criado${NC}"
}

# Helios (Manager) - Mídia e ARR services
if [ "$HOSTNAME" = "helios" ] || [ "$HOSTNAME" = "pop-os" ]; then
    echo -e "${YELLOW}Configurando Helios (Manager)...${NC}"
    echo ""

    # Media directories
    create_dirs "/media/series" "1000"
    create_dirs "/media/movies" "1000"
    create_dirs "/media/incomplete" "1000"
    create_dirs "/media/music" "1000"
    create_dirs "/media/audiobooks" "1000"
    create_dirs "/media/downloads" "1000"

    # Config directories
    create_dirs "/data/docker/lidarr" "1000"
    create_dirs "/data/docker/prowlarr" "1000"
    create_dirs "/data/docker/jellyseerr" "1000"
    create_dirs "/data/docker/listenarr" "1000"
    create_dirs "/data/docker/navidrome" "1000"

    # Audiobookshelf
    create_dirs "/data/docker/audiobookshelf/config" "1000"
    create_dirs "/data/docker/audiobookshelf/metadata" "1000"
    create_dirs "/data/media/audiobooks" "1000"
    create_dirs "/data/media/podcasts" "1000"

# Xeon01 (Worker) - Storage intensive
elif [ "$HOSTNAME" = "xeon01" ] || [ "$HOSTNAME" = "Xeon01" ]; then
    echo -e "${YELLOW}Configurando Xeon01 (Worker)...${NC}"
    echo ""

    # Calibre and books
    create_dirs "/srv/docker/calibre/config" "1000"
    create_dirs "/srv/docker/books" "1000"
    create_dirs "/srv/docker/calibre-ingest" "1000"

else
    echo -e "${YELLOW}Servidor não reconhecido. Criando diretórios básicos...${NC}"
    create_dirs "/media/series" "1000"
    create_dirs "/media/movies" "1000"
    create_dirs "/media/music" "1000"
fi

echo ""
echo -e "${GREEN}=== Diretórios criados com sucesso! ===${NC}"
echo ""
echo "Estrutura criada:"
ls -la /media/ 2>/dev/null || echo "  (/media não existe neste servidor)"
ls -la /data/docker/ 2>/dev/null || echo "  (/data/docker não existe neste servidor)"
ls -la /srv/docker/ 2>/dev/null || echo "  (/srv/docker não existe neste servidor)"
