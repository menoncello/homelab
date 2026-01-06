#!/bin/bash
# Script para REVERTER a migração e voltar ao estado original
# Executar no servidor pop-os (eduardo@192.168.31.5)

set -e

echo "=========================================="
echo "ROLLBACK - Revertendo migração"
echo "=========================================="
echo ""

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Verificar se está rodando como root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Este script precisa ser executado como root (sudo)${NC}"
    echo "Use: sudo bash $0"
    exit 1
fi

# Serviços Docker que podem estar usando /data/media
DOCKER_SERVICES=(
    "arr-stack_bazarr"
    "arr-stack_jackett"
    "arr-stack_radarr"
    "arr-stack_sonarr"
    "arr-stack_transmission"
    "audiobookshelf_audiobookshelf"
    "calibre_book-searcher"
    "calibre_calibre"
    "calibre_converter"
    "chatterbox-stack_chatterbox-api"
    "chatterbox-stack_chatterbox-server"
    "ebook2audiobook_ebook2audiobook"
    "gpu-services_jellyfin"
    "lazylibrarian_lazylibrarian"
    "listenarr_listenarr"
    "tts-webui-stack_tts-webui"
)

echo -e "${YELLOW}Passo 1: Parando serviços Docker...${NC}"
for service in "${DOCKER_SERVICES[@]}"; do
    echo "  Parando $service..."
    docker service scale $service=0 2>/dev/null || echo "    Serviço não encontrado"
done
echo "  Aguardando 10 segundos..."
sleep 10

echo -e "${YELLOW}Passo 2: Desmontando todas as montagens de media...${NC}"
# Desmontar tudo relacionado a media
umount /media 2>/dev/null && echo "  /media desmontado" || echo "  /media não estava montado"
umount /data/media 2>/dev/null && echo "  /data/media desmontado" || echo "  /data/media não estava montado"
umount /storage/media 2>/dev/null && echo "  /storage/media desmontado" || echo "  /storage/media não estava montado"

echo -e "${YELLOW}Passo 3: Limpando o fstab...${NC}"
# Backup do fstab atual
cp /etc/fstab /etc/fstab.backup.rollback-$(date +%Y%m%d-%H%M%S)

# Remover todas as linhas relacionadas a media (bind mounts)
sed -i '/storage.*media.*bind/d' /etc/fstab
sed -i '/data.*media.*bind/d' /etc/fstab
sed -i '/^\/dev\/nvme1n1p1.*\/media/d' /etc/fstab

echo "  fstab limpo"
echo ""
echo "Conteúdo atual do fstab (linhas com media):"
cat /etc/fstab | grep -E '(storage|media)' || echo "  (nenhuma linha com media encontrada)"

echo -e "${YELLOW}Passo 4: Remontando o disco antigo em /data/media...${NC}"
# Criar ponto de montagem se não existir
mkdir -p /data/media

# Montar o disco antigo diretamente
mount /dev/nvme1n1p1 /data/media

echo "  Disco montado:"
df -h /data/media

echo -e "${YELLOW}Passo 5: Verificando conteúdo...${NC}"
ls -la /data/media/
du -sh /data/media/* 2>/dev/null

echo -e "${YELLOW}Passo 6: Reiniciando serviços Docker...${NC}"
for service in "${DOCKER_SERVICES[@]}"; do
    echo "  Iniciando $service..."
    docker service scale $service=1 2>/dev/null || echo "    Serviço não encontrado"
done

echo ""
echo -e "${GREEN}=========================================="
echo "Rollback concluído!"
echo "==========================================${NC}"
echo ""
echo "Estado atual:"
echo "  - /dev/nvme1n1p1 montado em /data/media (disco antigo)"
echo "  - Bind mounts removidos do fstab"
echo "  - Serviços reiniciados"
echo ""
echo "O diretório /storage/media ainda existe com os dados copiados."
echo "Você pode removê-lo depois se quiser:"
echo "  sudo rm -rf /storage/media"
echo ""
echo "Para verificar os serviços:"
echo "  docker service ls"
echo ""
