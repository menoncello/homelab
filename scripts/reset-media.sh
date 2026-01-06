#!/bin/bash
# Script para LIMPAR e recriar a estrutura de media do zero
# Executar no servidor pop-os (eduardo@192.168.31.5)

set -e

echo "=========================================="
echo "RESET COMPLETO - Estrutura de Media"
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

echo -e "${YELLOW}⚠️  AVISO: Isso vai parar todos os serviços e recriar a estrutura de media${NC}"
echo -e "${YELLOW}    O diretório /storage/media será APAGADO!${NC}"
echo ""
read -p "Continuar? (s/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo "Cancelado."
    exit 1
fi

# Serviços Docker
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

echo -e "${YELLOW}Passo 1: Parando todos os serviços Docker...${NC}"
for service in "${DOCKER_SERVICES[@]}"; do
    docker service scale $service=0 2>/dev/null || true
done
echo "  Serviços parados. Aguardando 10 segundos..."
sleep 10

echo -e "${YELLOW}Passo 2: Desmontando todas as montagens de media...${NC}"
umount /media 2>/dev/null && echo "  ✓ /media desmontado" || true
umount /data/media 2>/dev/null && echo "  ✓ /data/media desmontado" || true
umount /storage/media 2>/dev/null && echo "  ✓ /storage/media desmontado" || true
umount /mnt/old-disk 2>/dev/null && echo "  ✓ /mnt/old-disk desmontado" || true

echo -e "${YELLOW}Passo 3: Limpando o fstab...${NC}"
cp /etc/fstab /etc/fstab.backup.reset-$(date +%Y%m%d-%H%M%S)
# Remover todas as linhas com media/bind
sed -i '/storage.*media.*bind/d' /etc/fstab
sed -i '/data.*media.*bind/d' /etc/fstab
sed -i '/^\/dev\/nvme1n1p1.*\/media/d' /etc/fstab
echo "  ✓ fstab limpo"

echo -e "${YELLOW}Passo 4: Removendo /storage/media...${NC}"
if [ -d "/storage/media" ]; then
    rm -rf /storage/media
    echo "  ✓ /storage/media removido"
else
    echo "  (não existia)"
fi

echo -e "${YELLOW}Passo 5: Recriando estrutura de diretórios...${NC}"
mkdir -p /data/media
mkdir -p /media
echo "  ✓ Diretórios criados"

echo -e "${YELLOW}Passo 6: Montando o disco antigo em /data/media...${NC}"
mount /dev/nvme1n1p1 /data/media
echo "  ✓ Disco montado em /data/media"
df -h /data/media

echo -e "${YELLOW}Passo 7: Configurando bind mount /data/media → /media...${NC}"
cat >> /etc/fstab << EOF

# Media library bind mount
/data/media    /media    none    bind    0    0
EOF
mount /media
echo "  ✓ Bind mount criado"
df -h /media

echo -e "${YELLOW}Passo 8: Verificando estrutura final...${NC}"
echo ""
echo "  Conteúdo de /data/media:"
ls -la /data/media/
echo ""
echo "  Conteúdo de /media:"
ls -la /media/
echo ""
echo "  Montagens ativas:"
mount | grep media

echo -e "${YELLOW}Passo 9: Recarregando systemd...${NC}"
systemctl daemon-reload
echo "  ✓ systemd recarregado"

echo -e "${YELLOW}Passo 10: Reiniciando serviços Docker...${NC}"
for service in "${DOCKER_SERVICES[@]}"; do
    docker service scale $service=1 2>/dev/null || true
    echo "  ✓ $service iniciado"
done

echo ""
echo -e "${GREEN}=========================================="
echo "Reset concluído com sucesso!"
echo "==========================================${NC}"
echo ""
echo "Estrutura final:"
echo "  /dev/nvme1n1p1 → /data/media (disco antigo 469GB)"
echo "  /data/media → /media (bind mount)"
echo ""
echo "Para verificar os serviços:"
echo "  docker service ls"
echo "  docker service ps <nome_do_serviço>"
echo ""
