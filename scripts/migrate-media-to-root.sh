#!/bin/bash
# Script para migrar /data/media para o disco maior
# Executar no servidor pop-os (eduardo@192.168.31.5)

set -e

echo "=========================================="
echo "Migração de /data/media para disco maior"
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

# Serviços Docker que usam /data/media
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
    docker service scale $service=0 2>/dev/null || echo "    Serviço não encontrado ou já parado"
done
echo "  Aguardando 10 segundos para os containers pararem..."
sleep 10

echo -e "${YELLOW}Passo 2: Criando novo diretório /storage/media...${NC}"
mkdir -p /storage/media
echo "  Diretório criado"

echo -e "${YELLOW}Passo 3: Copiando dados (445GB - isso pode levar um tempo)...${NC}"
echo "  Usando rsync com progresso..."
rsync -aAXHv --info=progress2 --exclude='/media/media' /data/media/ /storage/media/

echo -e "${YELLOW}Passo 4: Verificando cópia...${NC}"
# Usar sudo para conseguir ler todos os diretórios, incluindo /media/media
OLD_SIZE=$(sudo du -s /data/media 2>/dev/null | cut -f1)
NEW_SIZE=$(du -s /storage/media | cut -f1)
echo "  Tamanho original: $OLD_SIZE KB"
echo "  Tamanho copiado: $NEW_SIZE KB"

# Calcular diferença em percentual (permitir até 10% de diferença devido a /media/media excluído)
if [ "$OLD_SIZE" -gt 0 ]; then
    DIFF_PERCENT=$(( ($NEW_SIZE - $OLD_SIZE) * 100 / $OLD_SIZE ))
    echo "  Diferença: $DIFF_PERCENT%"

    if [ "$DIFF_PERCENT" -lt -10 ] || [ "$DIFF_PERCENT" -gt 10 ]; then
        echo -e "${RED}ERRO: Os tamanhos diferem em mais de 10%!${NC}"
        echo "  Isso pode indicar um problema na cópia."
        echo ""
        echo "Investigação:"
        sudo du -sh /data/media/* 2>/dev/null | sort -h | tail -5
        echo "---"
        sudo du -sh /storage/media/* 2>/dev/null | sort -h | tail -5
        exit 1
    fi
fi

echo -e "${GREEN}Cópia verificada com sucesso! (diferença dentro do esperado)${NC}"

echo -e "${YELLOW}Passo 5: Fazendo backup do fstab...${NC}"
cp /etc/fstab /etc/fstab.backup.$(date +%Y%m%d-%H%M%S)
echo "  Backup criado: /etc/fstab.backup.$(date +%Y%m%d-%H%M%S)"

echo -e "${YELLOW}Passo 6: Atualizando fstab...${NC}"
# Remover linhas antigas relacionadas a /data/media e /media
sed -i '/\/data\/media.*\/media.*bind/d' /etc/fstab
sed -i '/^\/dev\/nvme1n1p1.*\/media/d' /etc/fstab

# Adicionar nova entrada para bind mount
echo "# Media library - migrated to root filesystem" >> /etc/fstab
echo "/storage/media    /data/media    none    bind    0    0" >> /etc/fstab

echo "  fstab atualizado:"
cat /etc/fstab | grep -E '(storage|media)'

echo -e "${YELLOW}Passo 7: Desmontando montagem antiga...${NC}"
umount /data/media || echo "  Aviso: Não foi possível desmontar /data/media"

echo -e "${YELLOW}Passo 8: Montando nova configuração...${NC}"
mount /data/media
echo "  Nova montagem:"
df -h /data/media

echo -e "${YELLOW}Passo 9: Reiniciando serviços Docker...${NC}"
for service in "${DOCKER_SERVICES[@]}"; do
    echo "  Iniciando $service..."
    docker service scale $service=1 2>/dev/null || echo "    Serviço não encontrado"
done

echo ""
echo -e "${GREEN}=========================================="
echo "Migração concluída com sucesso!"
echo "==========================================${NC}"
echo ""
echo "Resumo:"
echo "  - Dados copiados de /dev/nvme1n1p1 para / (root filesystem)"
echo "  - Bind mount: /storage/media → /data/media"
echo "  - Serviços reiniciados"
echo ""
echo "Próximos passos:"
echo "  1. Verifique se os serviços estão funcionando"
echo "  2. Se tudo estiver OK, pode formatar o disco antigo (/dev/nvme1n1p1)"
echo ""
echo "Para verificar: docker service ls"
echo "Para reverter se necessário: sudo umount /data/media && sudo mount /dev/nvme1n1p1 /data/media"
