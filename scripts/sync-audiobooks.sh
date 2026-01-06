#!/bin/bash

# Script para mover audiobooks do Mac para o servidor
# Uso: ./scripts/sync-audiobooks.sh

SOURCE_DIR="/Users/menoncello/Music/Libation/Books"
REMOTE_USER="eduardo"
REMOTE_HOST="192.168.31.5"
REMOTE_DIR="/media/audiobooks"

echo "📚 Sincronizando audiobooks..."
echo "Origem: $SOURCE_DIR"
echo "Destino: $REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR"
echo ""

# Copiar arquivos e apagar origem
rsync -avz --remove-source-files --progress "$SOURCE_DIR" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR"

# Verificar se rsync foi bem-sucedido
if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Arquivos copiados com sucesso!"
    echo "🧹 Limpando pastas vazias..."
    /usr/bin/find "$SOURCE_DIR" -type d -empty -delete
    echo "✅ Concluído!"
else
    echo ""
    echo "❌ Erro no rsync. Pastas vazias não foram apagadas."
    exit 1
fi
