# Homarr Automated Setup

Configure seu dashboard Homarr automaticamente com todos os serviços, categorias e widgets.

## 🚀 Setup Rápido (2 minutos)

### 1. Obter API Key do Homarr

1. Acesse: http://192.168.31.5:7575
2. Clique no seu perfil (canto superior direito)
3. Vá para **Settings** → **API Keys**
4. Clique em **Create new API key**
5. Dê um nome (ex: "automation")
6. Copie a API key gerada

### 2. Configurar Arquivo .env

```bash
# Copiar o arquivo de exemplo
cp .env.example .env

# Editar e colar sua API key
nano .env
```

Edite o arquivo `.env`:

```bash
HOMARR_URL=http://192.168.31.5:7575
HOMARR_API_KEY=sua_chave_aqui
```

### 3. Executar Script

```bash
chmod +x setup-dashboard.py
./setup-dashboard.py
```

> **Nota:** O script cria automaticamente um ambiente virtual (venv) e instala as dependências.
> Funciona em qualquer sistema, incluindo NixOS!

---

## ✅ O Que Será Configurado

### Categorias (7)
- 🔵 **Media** - Jellyfin, Audiobookshelf
- 🟣 **Automation** - Sonarr, Radarr, Lidarr, Bazarr, Prowlarr, Jackett
- 🩷 **Requests** - Jellyseerr
- 🟢 **Infrastructure** - Nginx Proxy Manager, Pi-hole
- 🟠 **Downloads** - qBittorrent
- 🔷 **Books** - Kavita, Listenarr, Stacks
- 🟣 **Tools** - n8n, eBook2Audiobook, TTS WebUI, Chatterbox

### Apps (19)
Serviços configurados com URLs internas do Docker (service names):

| App | URL Interna | Categoria |
|-----|-------------|-----------|
| Jellyfin | http://jellyfin:8096 | Media |
| Sonarr | http://sonarr:8989 | Automation |
| Radarr | http://radarr:7878 | Automation |
| Lidarr | http://lidarr:8686 | Automation |
| Bazarr | http://bazarr:6767 | Automation |
| Prowlarr | http://prowlarr:9696 | Automation |
| Jackett | http://jackett:9117 | Automation |
| qBittorrent | http://transmission:9091 | Downloads |
| Pi-hole | http://pihole:8053 | Infrastructure |
| Nginx Proxy Manager | http://192.168.31.5:81 | Infrastructure |
| Audiobookshelf | http://audiobookshelf:80 | Media |
| Kavita | http://kavita:5000 | Books |
| Listenarr | http://listenarr:8988 | Books |
| Stacks | http://stacks:7788 | Books |
| Jellyseerr | http://jellyseerr:5055 | Requests |
| n8n | http://n8n:5678 | Tools |
| eBook2Audiobook | http://ebook2audiobook:7860 | Tools |
| TTS WebUI | http://ttswebui:7770 | Tools |
| Chatterbox | http://chatterbox:5123 | Tools |

### Widgets (5)
- **Dash.** - CPU, RAM, Network em tempo real
- **Health Monitoring** - Status do sistema
- **Weather** - Previsão do tempo (São Paulo)
- **RSS Feed** - Notícias do r/homelab
- **Date** - Data e hora atual

### Integrações Configuradas (requer API key)
- Sonarr (API key necessária)
- Radarr (API key necessária)
- Lidarr (API key necessária)
- qBittorrent (usuário/senha necessários)
- Pi-hole (API key necessária)
- Jellyseerr (API key necessária)

---

## 📝 Configurar Integrações Manualmente

Após executar o script, você precisa configurar as API keys das integrações:

### Sonarr / Radarr / Lidarr
1. Abra o serviço (Sonarr/Radarr/Lidarr)
2. **Settings** → **General** → **API Key**
3. Copie a API key
4. No Homarr, edite o app → **Integration**
5. Cole a API key

### qBittorrent
1. qBittorrent → **Tools** → **Options** → **Web UI**
2. Copie usuário e senha
3. No Homarr, edite o qBittorrent → **Integration**

### Pi-hole
1. Pi-hole → **Settings** → **API**
2. Copie a API key
3. No Homarr, edite o Pi-hole → **Integration**

---

## 🔧 Troubleshooting

### Erro: "Cannot connect to Homarr"
```bash
# Verifique se o Homarr está rodando
docker service ls | grep homarr

# Verifique os logs
docker service logs -f homarr_homarr
```

### Erro: "HOMARR_API_KEY not found"
```bash
# Verifique se o arquivo .env existe
cat .env

# Se não existir, copie o exemplo
cp .env.example .env
nano .env
```

### Erro: "401 Unauthorized"
- Verifique se a API key está correta
- Gere uma nova API key no Homarr
- Atualize o arquivo `.env`

### Widgets não aparecem
1. Acesse o Homarr
2. Entre em **Edit Mode**
3. Arraste os widgets para a posição desejada
4. Clique no widget para configurar

---

## 📂 Estrutura de Arquivos

```
stacks/homarr-stack/
├── docker-compose.yml      # Stack Docker
├── setup-dashboard.py      # Script de automação
├── requirements.txt        # Dependências Python
├── .env.example           # Template de configuração
├── .env                   # Suas configurações (não commitar)
├── README.md              # Documentação
├── MANUAL_SETUP.md        # Setup manual
└── AUTOMATED_SETUP.md     # Este arquivo
```

---

## 🎨 Personalização

### Adicionar/Remover Serviços

Edite o arquivo `setup-dashboard.py`:

```python
APPS = [
    # Adicione seus serviços aqui
    {
        "name": "Meu Serviço",
        "url": "http://meu-servico:porta",
        "icon": "mdi:application",
        "category": "Tools",
    },
]
```

### Modificar Widgets

Edite a seção `WIDGETS` no `setup-dashboard.py`:

```python
WIDGETS = [
    {
        "type": "weather",
        "properties": {
            "defaultCity": "Rio de Janeiro",  # Mudar cidade
            "latitude": -22.9068,
            "longitude": -43.1729,
        }
    },
]
```

### Adicionar Categoria

```python
CATEGORIES = [
    {"name": "Minha Categoria", "color": "#ff0000", "icon": "mdi:star"},
]
```

---

## 🔄 Executar Novamente

Para atualizar o dashboard após alterações:

```bash
python3 setup-dashboard.py
```

O script é idempotente - não cria duplicatas.

---

## 📚 Referências

- [Homarr Documentation](https://homarr.dev/docs/)
- [Homarr GitHub](https://github.com/ajnart/homarr)
- [Homarr Widgets](https://homarr.dev/docs/category/widgets/)

---

**Última atualização:** 2026-01-07
