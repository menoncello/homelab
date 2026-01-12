#!/bin/bash
# Script para corrigir permissões dos diretórios de mídia
# Uso: ./scripts/fix-media-permissions.sh

set -e

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Corrigindo permissões dos diretórios de mídia ===${NC}"
echo ""

# Lista de diretórios
MEDIA_DIRS=(
    "/media/series"
    "/media/movies"
    "/media/music"
    "/media/audiobooks"
    "/media/incomplete"
)

# Corrigir permissões dos diretórios
for dir in "${MEDIA_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo -e "${GREEN}✓ Corrigindo: $dir${NC}"
        find "$dir" -type d -exec chmod 775 {} \; 2>/dev/null || true
        find "$dir" -type f -exec chmod 664 {} \; 2>/dev/null || true
    else
        echo -e "${YELLOW}⚠ Diretório não existe: $dir${NC}"
    fi
done

echo ""
echo -e "${GREEN}=== Permissões corrigidas! ===${NC}"
echo ""
echo "Permissões atuais:"
ls -la /media/ | grep -E "series|movies|music|audiobooks|incomplete"
