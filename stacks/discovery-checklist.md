# Checklist - Configuração Discovery Stack

Use este checklist para acompanhar o progresso da configuração.

## Ordem de Configuração

**IMPORTANTE:** Siga esta ordem para evitar problemas de dependência.

```
1. Nginx Proxy Manager
2. qBittorrent
3. Prowlarr
4. Sonarr, Radarr, Lidarr, Listenarr (em paralelo)
5. Bazarr
6. Jellyseerr
7. Lidify
8. ListSync
9. Movary
```

---

## Checklist de Progresso

### FASE 1: Infraestrutura

- [ ] **1.1** Configurar Nginx Proxy Manager - 11 Proxy Hosts
  - [ ] sonarr.menoncello.com → 192.168.31.5:8989
  - [ ] radarr.menoncello.com → 192.168.31.5:7878
  - [ ] lidarr.menoncello.com → 192.168.31.5:8686
  - [ ] listenarr.menoncello.com → 192.168.31.5:8988
  - [ ] prowlarr.menoncello.com → 192.168.31.5:9696
  - [ ] bazarr.menoncello.com → 192.168.31.5:6767
  - [ ] qbittorrent.menoncello.com → 192.168.31.5:9091
  - [ ] jellyseerr.menoncello.com → 192.168.31.5:5055
  - [ ] lidify.menoncello.com → 192.168.31.5:3333
  - [ ] listsync.menoncello.com → 192.168.31.6:8082
  - [ ] movary.menoncello.com → 192.168.31.5:5056
- [ ] **1.2** Habilitar SSL para todos (Let's Encrypt)
- [ ] **1.3** Configurar DNS ou /etc/hosts

### FASE 2: Download Client

- [ ] **2.1** Acessar qBittorrent e alterar password padrão
- [ ] **2.2** Configurar porta 6881
- [ ] **2.3** Criar categorias: series, movies, music, audiobooks
- [ ] **2.4** Configurar save path para cada categoria

### FASE 3: Indexação

- [ ] **3.1** Acessar Prowlarr e criar conta admin
- [ ] **3.2** Adicionar pelo menos 1 indexer (testar antes de salvar)
- [ ] **3.3** Obter API Key do Prowlarr (Settings > General)
- [ ] **3.4** Configurar apps no Prowlarr:
  - [ ] Sonarr (http://sonarr:8989)
  - [ ] Radarr (http://radarr:7878)
  - [ ] Lidarr (http://lidarr:8686)
  - [ ] Listenarr (http://listenarr:8988)

### FASE 4: ARR Services (faça para cada um)

#### Sonarr
- [ ] **4.1** Acessar e criar conta
- [ ] **4.2** Copiar API Key (Settings > General)
- [ ] **4.3** Configurar Download Client (qBittorrent, categoria: series)
- [ ] **4.4** Configurar Indexer (Prowlarr)
- [ ] **4.5** Configurar Quality Profile
- [ ] **4.6** Configurar Root Folder (/media/series)
- [ ] **4.7** Configurar Media Management (rename, format)

#### Radarr
- [ ] **4.8** Acessar e criar conta
- [ ] **4.9** Copiar API Key (Settings > General)
- [ ] **4.10** Configurar Download Client (qBittorrent, categoria: movies)
- [ ] **4.11** Configurar Indexer (Prowlarr)
- [ ] **4.12** Configurar Quality Profile
- [ ] **4.13** Configurar Root Folder (/media/movies)
- [ ] **4.14** Configurar Media Management

#### Lidarr
- [ ] **4.15** Acessar e criar conta
- [ ] **4.16** Copiar API Key (Settings > General)
- [ ] **4.17** Configurar Download Client (qBittorrent, categoria: music)
- [ ] **4.18** Configurar Indexer (Prowlarr)
- [ ] **4.19** Configurar Quality Profile (FLAC, MP3)
- [ ] **4.20** Configurar Root Folder (/media/music)
- [ ] **4.21** Configurar Media Management
- [ ] **4.22** Salvar LIDARR_API_KEY no .env

#### Listenarr
- [ ] **4.23** Acessar e criar conta
- [ ] **4.24** Copiar API Key
- [ ] **4.25** Configurar Download Client (qBittorrent, categoria: audiobooks)
- [ ] **4.26** Configurar Indexer (Prowlarr)
- [ ] **4.27** Configurar Quality Profile
- [ ] **4.28** Configurar Root Folder (/media/audiobooks)
- [ ] **4.29** Configurar Media Management

### FASE 5: Legendas

- [ ] **5.1** Acessar Bazarr e criar conta
- [ ] **5.2** Conectar Sonarr (usar API Key do Sonarr)
- [ ] **5.3** Conectar Radarr (usar API Key do Radarr)
- [ ] **5.4** Configurar idiomas (Portuguese, English)
- [ ] **5.5** Habilitar providers de legendas

### FASE 6: Requests

- [ ] **6.1** Acessar Jellyseerr e criar conta admin
- [ ] **6.2** Copiar JELLYSEERR_API_KEY (Settings > General)
- [ ] **6.3** Conectar Sonarr (API Key)
- [ ] **6.4** Conectar Radarr (API Key)
- [ ] **6.5** Conectar Jellyfin (opcional)
- [ ] **6.6** Configurar usuários e permissões
- [ ] **6.7** Configurar regras de aprovação
- [ ] **6.8** Salvar JELLYSEERR_API_KEY no .env

### FASE 7: Descoberta de Música

- [ ] **7.1** Obter Spotify Client ID e Secret
- [ ] **7.2** Obter LastFM API Key
- [ ] **7.3** Adicionar ao .env:
  ```bash
  SPOTIFY_CLIENT_ID=
  SPOTIFY_CLIENT_SECRET=
  LASTFM_API_KEY=
  LIDARR_API_KEY=
  ```
- [ ] **7.4** Reiniciar Lidify (`docker service update --force discovery_lidify`)
- [ ] **7.5** Acessar Lidify e autenticar Spotify/LastFM

### FASE 8: Sync de Watchlists

- [ ] **8.1** Obter Trakt Client ID e Secret
- [ ] **8.2** Obter IMDb watchlist URL (opcional)
- [ ] **8.3** Obter Letterboxd username (opcional)
- [ ] **8.4** Adicionar ao .env:
  ```bash
  TRAKT_CLIENT_ID=
  TRAKT_CLIENT_SECRET=
  TRAKT_ACCESS_TOKEN=
  IMDB_USER_LIST_URL=
  LETTERBOXD_USERNAME=
  JELLYSEERR_API_KEY=
  ```
- [ ] **8.5** Reiniciar ListSync (`docker service update --force discovery_list-sync`)
- [ ] **8.6** Acessar ListSync e configurar conexões

### FASE 9: Tracking

- [ ] **9.1** Acessar Movary
- [ ] **9.2** Criar conta
- [ ] **9.3** Importar do Trakt (opcional)

### FASE 10: Testes

- [ ] **10.1** Fazer request no Jellyseerr
- [ ] **10.2** Verificar download no qBittorrent
- [ ] **10.3** Verificar import no Sonarr/Radarr
- [ ] **10.4** Verificar legendas no Bazarr
- [ ] **10.5** Verificar streaming no Jellyfin

---

## API Keys Summary

Depois de completar a configuração, seu `.env` deve ter:

```bash
# ============================================================================
# DISCOVERY STACK - ENVIRONMENT VARIABLES
# ============================================================================

# Spotify (para Lidify)
SPOTIFY_CLIENT_ID=seu_client_id_aqui
SPOTIFY_CLIENT_SECRET=seu_client_secret_aqui

# LastFM (para Lidify)
LASTFM_API_KEY=sua_api_key_aqui

# Lidarr (para Lidify)
LIDARR_API_KEY=api_key_do_lidarr_aqui

# Jellyseerr (para ListSync)
JELLYSEERR_API_KEY=api_key_do_jellyseerr_aqui

# Trakt (para ListSync)
TRAKT_CLIENT_ID=seu_trakt_client_id_aqui
TRAKT_CLIENT_SECRET=seu_trakt_client_secret_aqui
TRAKT_ACCESS_TOKEN=  # gerado automaticamente

# IMDb (para ListSync) - Opcional
IMDB_USER_LIST_URL=https://www.imdb.com/user/urXXXXXXX/list/watchlist

# Letterboxd (para ListSync) - Opcional
LETTERBOXD_USERNAME=seu_username_aqui
```

---

## Comandos Úteis

```bash
# Verificar status de todos os serviços
docker stack services discovery

# Ver logs de um serviço
docker service logs -f discovery_<service>

# Reiniciar um serviço após editar .env
docker service update --force discovery_<service>

# Acessar container para troubleshooting
docker exec -it discovery_<service>.1.<id> sh
```

---

## URLs de Referência para API Keys

- **Spotify:** https://developer.spotify.com/dashboard
- **LastFM:** https://www.last.fm/api/account/create
- **Trakt:** https://trakt.tv/oauth/applications
- **IMDb:** https://www.imdb.com/
- **Letterboxd:** https://letterboxd.com/

---

## Tempo Estimado

| Fase | Tempo |
|------|-------|
| Infraestrutura | 20 min |
| Download Client | 5 min |
| Indexação | 15 min |
| ARR Services (x4) | 40 min |
| Legendas | 10 min |
| Requests | 15 min |
| Descoberta de Música | 20 min |
| Sync de Watchlists | 25 min |
| Tracking | 10 min |
| Testes | 15 min |
| **TOTAL** | **~3 horas** |

---

## Dicas

1. **Frequência de saves:** Salve configurações frequentemente
2. **Teste antes de salvar:** Sempre clique em "Test" antes de "Save"
3. **API Keys:** Copie e salve em lugar seguro
4. **Ordem importa:** Siga a ordem do checklist
5. **Documente:** Anote quais quality profiles você criou

---

**Status:** ___/___ completado
**Início:** _____/_____/_____
**Término:** _____/_____/_____
