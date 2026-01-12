# Guia de Configuração - Discovery Stack

Guia completo passo a passo para configurar todos os 11 serviços da Discovery Stack.

## Índice

1. [Pré-requisitos](#1-pré-requisitos)
2. [Configuração do Proxy](#2-configuração-do-nginx-proxy-manager)
3. [Configuração Básica](#3-configuração-básica)
4. [Configuração do Download Client](#4-configuração-do-qbittorrent)
5. [Configuração do Prowlarr](#5-configuração-do-prowlarr)
6. [Configuração dos ARR Services](#6-configuração-dos-arr-services)
7. [Configuração do Bazarr](#7-configuração-do-bazarr)
8. [Configuração do Jellyseerr](#8-configuração-do-jellyseerr)
9. [Configuração do Lidify](#9-configuração-do-lidify)
10. [Configuração do ListSync](#10-configuração-do-listsync)
11. [Configuração do Movary](#11-configuração-do-movary)
12. [Teste Final](#12-teste-final)

---

## 1. Pré-requisitos

### 1.1 Verificar que todos os serviços estão rodando

```bash
docker stack services discovery
```

Todos devem mostrar `1/1` em REPLICAS.

### 1.2 Preparar arquivo .env

```bash
cd /Users/menoncello/repos/setup/homelab/stacks/discovery-stack
cp .env.example .env
nano .env
```

**Não preencha ainda!** Vamos obter as chaves API durante a configuração.

---

## 2. Configuração do Nginx Proxy Manager

### 2.1 Acessar o Nginx Proxy Manager

Abra: http://192.168.31.5:81

### 2.2 Criar Proxy Hosts

Para cada serviço abaixo, crie um Proxy Host:

**Clique em:** Proxy Hosts > Add Proxy Host

#### Tabela de Configuração

| Domain Names | Forward Host/IP | Forward Port | Scheme | Cache |
|--------------|-----------------|--------------|--------|-------|
| sonarr.menoncello.com | 192.168.31.5 | 8989 | http | ❌ |
| radarr.menoncello.com | 192.168.31.5 | 7878 | http | ❌ |
| lidarr.menoncello.com | 192.168.31.5 | 8686 | http | ❌ |
| listenarr.menoncello.com | 192.168.31.5 | 8988 | http | ❌ |
| prowlarr.menoncello.com | 192.168.31.5 | 9696 | http | ❌ |
| bazarr.menoncello.com | 192.168.31.5 | 6767 | http | ❌ |
| qbittorrent.menoncello.com | 192.168.31.5 | 9091 | http | ❌ |
| jellyseerr.menoncello.com | 192.168.31.5 | 5055 | http | ❌ |
| lidify.menoncello.com | 192.168.31.5 | 3333 | http | ❌ |
| listsync.menoncello.com | 192.168.31.6 | 8082 | http | ❌ |
| movary.menoncello.com | 192.168.31.5 | 5056 | http | ❌ |

### 2.3 Configurar SSL para cada Proxy Host

Para cada serviço:

1. Clique na aba **SSL**
2. Configure:
   - ✅ Enable SSL
   - ✅ Force SSL
   - ✅ HTTP/2 Support
   - ✅ HSTS Enabled
   - SSL Certificate: **Let's Encrypt**
   - Email: seu@email.com
3. Clique em **Save**

### 2.4 DNS

Certifique-se de que seus domínios apontam para 192.168.31.5 via DNS ou configure `/etc/hosts`:

```bash
# No seu computador
sudo nano /etc/hosts
```

Adicione:
```
192.168.31.5 sonarr.menoncello.com
192.168.31.5 radarr.menoncello.com
192.168.31.5 lidarr.menoncello.com
192.168.31.5 listenarr.menoncello.com
192.168.31.5 prowlarr.menoncello.com
192.168.31.5 bazarr.menoncello.com
192.168.31.5 qbittorrent.menoncello.com
192.168.31.5 jellyseerr.menoncello.com
192.168.31.5 lidify.menoncello.com
192.168.31.5 movary.menoncello.com
192.168.31.6 listsync.menoncello.com
```

---

## 3. Configuração Básica

### 3.1 Primeiro Acesso

Acesse cada serviço pela primeira vez para criar a conta administrativa:

| Serviço | URL | Ação |
|---------|-----|------|
| Prowlarr | https://prowlarr.menoncello.com | Criar usuário admin |
| Sonarr | https://sonarr.menoncello.com | Alterar password padrão |
| Radarr | https://radarr.menoncello.com | Alterar password padrão |
| Lidarr | https://lidarr.menoncello.com | Alterar password padrão |
| Listenarr | https://listenarr.menoncello.com | Criar conta |
| Bazarr | https://bazarr.menoncello.com | Criar conta |
| qBittorrent | https://qbittorrent.menoncello.com | Login (admin/adminadmin) |
| Jellyseerr | https://jellyseerr.menoncello.com | Criar usuário admin |
| Movary | https://movary.menoncello.com | Criar conta |

---

## 4. Configuração do qBittorrent

### 4.1 Acessar

https://qbittorrent.menoncello.com

**Login padrão:**
- Username: `admin`
- Password: `adminadmin`

### 4.2 Alterar Password

1. Tools > Options > Web UI
2. Altere o password
3. Clique em **Apply**

### 4.3 Configurar Conexão

1. **Tools > Options > Connection**
2. Configure:
   - Port used for incoming connections: `6881`
   - ✅ Upnp / NAT-PMP (se necessário)
3. Clique em **Apply**

### 4.4 Configurar Categorias

1. **Tools > Options > Downloads**
2. Em "Default Save Path":
   - `/media/incomplete`
3. Em "Keep incomplete torrents in":
   - `/media/incomplete/incomplete`
4. Clique em **Apply**

### 4.5 Criar Categorias

1. **Downloads > Categorias**
2. Adicione as categorias:

| Nome | Save Path |
|------|-----------|
| series | /media/series |
| movies | /media/movies |
| music | /media/music |
| audiobooks | /media/audiobooks |

### 4.6 Configurar Limites de Velocidade (Opcional)

1. Tools > Options > Speed
2. Configure limites globais e alternativos
3. Clique em **Apply**

---

## 5. Configuração do Prowlarr

### 5.1 Acessar

https://prowlarr.menoncello.com

### 5.2 Adicionar Indexers

1. **Settings > Indexers > Add Indexer**
2. Escolha seus indexers de torrent
3. Configure conforme necessário
4. **Teste** antes de salvar
5. Repita para todos os indexers desejados

**Indexers populares:**
- Torznab (varios)
- Jackett (legacy)
- Torrents CSV (vários)

### 5.3 Configurar Aplicativos (ARRs)

1. **Settings > Apps > Add App**
2. Adicione cada ARR service:

#### Sonarr

- **Name:** Sonarr
- **Sync:** ✅ Enable
- **Type:** Sonarr
- **Host:** http://sonarr:8989
- **API Key:** (pegar do Sonarr - veja abaixo)
- **Categories:** TV
- Clique em **Test** e depois **Save**

#### Radarr

- **Name:** Radarr
- **Sync:** ✅ Enable
- **Type:** Radarr
- **Host:** http://radarr:7878
- **API Key:** (pegar do Radarr)
- **Categories:** Movies
- Clique em **Test** e depois **Save**

#### Lidarr

- **Name:** Lidarr
- **Sync:** ✅ Enable
- **Type:** Lidarr
- **Host:** http://lidarr:8686
- **API Key:** (pegar do Lidarr)
- **Categories:** Audio
- Clique em **Test** e depois **Save**

#### Listenarr

- **Name:** Listenarr
- **Sync:** ✅ Enable
- **Type:** Lidarr
- **Host:** http://listenarr:8988
- **API Key:** (pegar do Listenarr)
- **Categories:** Audio
- Clique em **Test** e depois **Save**

### 5.4 Configurar Quality Profiles

1. **Settings > Profiles > Quality > Quality Profiles**
2. Crie profiles personalizados se necessário

---

## 6. Configuração dos ARR Services

**Faça esta configuração para: Sonarr, Radarr, Lidarr, Listenarr**

---

### 6.1 Obter API Key

Para cada serviço:

1. Acesse o serviço (Sonarr/Radarr/Lidarr/Listenarr)
2. **Settings > General**
3. Procure por **API Key**
4. Clique em **Copy** ou copie manualmente
5. **Salve esta chave** - vamos usar no Prowlarr

---

### 6.2 Configurar Download Client

#### Sonarr, Radarr, Lidarr:

1. **Settings > Download Client > +**
2. Selecione **qBittorrent**
3. Configure:
   - **Host:** qbittorrent
   - **Port:** 9091
   - **Username:** admin (ou seu usuário)
   - **Password:** seu password do qBittorrent
   - **Category:** (sonarr/series, radarr/movies, lidarr/music)
4. Clique em **Test** e depois **Save**

#### Listenarr:

1. **Settings > Download Client > +**
2. Selecione **qBittorrent**
3. Configure:
   - **Host:** qbittorrent
   - **Port:** 9091
   - **Username:** admin
   - **Password:** seu password
   - **Category:** audiobooks
4. Clique em **Test** e depois **Save**

---

### 6.3 Configurar Indexers

#### Para todos os ARRs:

1. **Settings > Indexers > Add > Prowlarr**
2. Configure:
   - **Prowlarr Server:** (selecione o Prowlarr)
   - Ou configure manualmente:
     - **Name:** Prowlarr
     - **Sync:** ✅ Enable
     - **Torznab:** (URL do Prowlarr)
     - **API Key:** (API Key do Prowlarr - Settings > General > API Key)
3. Clique em **Test** e depois **Save**

**URL Torznab do Prowlarr:**
```
http://prowlarr:9696/1/api?apikey=SUA_API_KEY_DO_PROWLARR
```

---

### 6.4 Configurar Quality Profiles

#### Sonarr (Séries):

1. **Settings > Profiles > Quality**
2. Configure profiles baseado em suas preferências:
   - **SD:** HDTV-720p, WEBDL-720p
   - **HD-720p:** HDTV-720p, WEBDL-720p, Bluray-720p
   - **HD-1080p:** HDTV-1080p, WEBDL-1080p, Bluray-1080p
   - **Ultra-HD:** HDTV-2160p, WEBDL-2160p, Bluray-2160p

#### Radarr (Filmes):

1. **Settings > Profiles > Quality**
2. Configure profiles:
   - **SD:** DVD, WEBDL-720p
   - **HD-720p:** WEBDL-720p, Bluray-720p
   - **HD-1080p:** WEBDL-1080p, Bluray-1080p, REMUX-1080p
   - **Ultra-HD:** WEBDL-2160p, Bluray-2160p

#### Lidarr (Música):

1. **Settings > Profiles > Quality**
2. Configure:
   - **Lossy:** MP3 256/320kbps
   - **Lossless:** FLAC
   - **Any:** All qualities

#### Listenarr (Audiobooks):

1. **Settings > Quality**
2. Configure preferências de formato:
   - MP3, M4A, M4B, FLAC, AAC, OGG, OPUS

---

### 6.5 Configurar Media Management

#### Sonarr:

1. **Settings > Media Management**
2. Configure:
   - **Series Folder Format:** `{Series TitleYear}`
   - **Season Folder Format:** `Season {season:00}`
   - **Episode Format:** `{Series TitleYear}/Season {season:00}/{Series TitleYear} - S{season:00}E{episode:00} - {Episode Title}{Quality Full}`
   - ✅ Rename Episodes
   - ✅ Use Bulk Sorting

#### Radarr:

1. **Settings > Media Management**
2. Configure:
   - **Movie Folder Format:** `{Movie Title} ({Movie Year})`
   - ✅ Rename Movies
   - ✅ Use Bulk Sorting

#### Lidarr:

1. **Settings > Media Management**
2. Configure:
   - **Artist Folder Format:** `{Artist Name}`
   - **Album Folder Format:** `{Album Title} ({Album Year}) {Album Type}{Media Format}`
   - ✅ Rename Tracks

#### Listenarr:

1. **Settings > Media Management**
2. Configure:
   - **Author Folder Format:** `{Author Name}`
   - **Book Folder Format:** `{Book Title} ({Book Year})`

---

### 6.6 Configurar Root Folders

#### Sonarr:

1. **Settings > Media Management > Root Folders > +**
2. Configure:
   - **Path:** `/media/series`
   - Click em OK

#### Radarr:

1. **Settings > Media Management > Root Folders > +**
2. Configure:
   - **Path:** `/media/movies`
   - Click em OK

#### Lidarr:

1. **Settings > Media Management > Root Folders > +**
2. Configure:
   - **Path:** `/media/music`
   - Click em OK

#### Listenarr:

1. **Settings > Media Management > Root Folders > +**
2. Configure:
   - **Path:** `/media/audiobooks`
   - Click em OK

---

## 7. Configuração do Bazarr

### 7.1 Acessar

https://bazarr.menoncello.com

### 7.2 Configurar Sonarr Connection

1. **Settings > Sonarr**
2. Configure:
   - ✅ Enable
   - **Host:** http://sonarr:8989
   - **API Key:** (API Key do Sonarr)
3. Clique em **Test** e depois **Save**

### 7.3 Configurar Radarr Connection

1. **Settings > Radarr**
2. Configure:
   - ✅ Enable
   - **Host:** http://radarr:7878
   - **API Key:** (API Key do Radarr)
3. Clique em **Test** e depois **Save**

### 7.4 Configurar Legendas

1. **Settings > Subtitles**
2. Configure idiomas preferidos:
   - **Portuguese (Brazil)**
   - **English**
   - **Portuguese**
3. Configure regras de download

### 7.5 Configurar Providers

1. **Settings > Providers > Subtitles**
2. Habilite providers de legendas:
   - OpenSubtitles
   - Podnapisi
   - Subscene (se disponível)

---

## 8. Configuração do Jellyseerr

### 8.1 Acessar

https://jellyseerr.menoncello.com

### 8.2 Obter API Key

1. **Settings > General**
2. Copie a **API Key**
3. **Salve** - vamos usar no ListSync

### 8.3 Configurar Sonarr

1. **Settings > Services > +**
2. Configure:
   - **Type:** Sonarr
   - **Name:** Sonarr
   - **Hostname:** http://sonarr:8989
   - **API Key:** (API Key do Sonarr)
   - ✅ Enable
   - **Quality Profile:** (selecione um profile do Sonarr)
   - **Root Folder:** /media/series
3. Clique em **Test All** e depois **Save**

### 8.4 Configurar Radarr

1. **Settings > Services > +**
2. Configure:
   - **Type:** Radarr
   - **Name:** Radarr
   - **Hostname:** http://radarr:7878
   - **API Key:** (API Key do Radarr)
   - ✅ Enable
   - **Quality Profile:** (selecione um profile do Radarr)
   - **Root Folder:** /media/movies
3. Clique em **Test All** e depois **Save**

### 8.5 Configurar Jellyfin (Opcional)

1. **Settings > General > Jellyfin**
2. Configure:
   - **Hostname:** http://jellyfin:8096
   - **API Key:** (pegar do Jellyfin - Settings > API)
3. Clique em **Test** e depois **Save**

### 8.6 Configurar Usuários e Permissões

1. **Settings > Users**
2. Configure níveis de acesso:
   - **Admin:** Acesso total
   - **User:** Pode fazer requests
   - **Limited:** Requests limitados

### 8.7 Configurar Regras de Aprovação

1. **Settings > Requests**
2. Configure:
   - **Auto Approve:** (para usuários confiáveis)
   - **Require Approval:** (para novos usuários)
   - **Limit requests:** (por dia/semana)

### 8.8 Adicionar JELLYSEERR_API_KEY ao .env

```bash
nano /Users/menoncello/repos/setup/homelab/stacks/discovery-stack/.env
```

Adicione:
```bash
JELLYSEERR_API_KEY=api_key_do_jellyseerr
```

---

## 9. Configuração do Lidify

### 9.1 Obter API Keys Necessárias

#### Lidarr API Key (já temos do passo anterior)

#### Spotify Client ID e Secret

1. Acesse: https://developer.spotify.com/dashboard
2. Clique em **Create App**
3. Preencha:
   - **App name:** Lidify Homelab
   - **App description:** Music discovery
   - **Redirect URI:** `http://localhost:3333/callback`
4. Salve
5. Copie **Client ID** e **Client Secret**

#### LastFM API Key

1. Acesse: https://www.last.fm/api/account/create
2. Preencha o formulário
3. Copie a **API Key**

### 9.2 Adicionar Keys ao .env

```bash
nano /Users/menoncello/repos/setup/homelab/stacks/discovery-stack/.env
```

Adicione:
```bash
# Lidify
LIDARR_API_KEY=api_key_do_lidarr
SPOTIFY_CLIENT_ID=seu_spotify_client_id
SPOTIFY_CLIENT_SECRET=seu_spotify_client_secret
LASTFM_API_KEY=sua_lastfm_api_key
```

### 9.3 Reiniciar Lidify

```bash
docker service update --force discovery_lidify
```

### 9.4 Configurar Lidify

1. Acesse: https://lidify.menoncello.com
2. Siga as instruções na tela:
   - Configure Spotify connection
   - Configure LastFM scrobbling
   - Importe sua coleção do Lidarr

---

## 10. Configuração do ListSync

### 10.1 Obter Trakt Credentials

1. Acesse: https://trakt.tv/oauth/applications
2. Clique em **Create New Application**
3. Preencha:
   - **Name:** ListSync Homelab
   - **Description:** Sync watchlists to Jellyseerr
   - **Redirect URI:** `http://localhost:8082/callback`
4. Clique em **Save App**
5. Copie:
   - **Client ID**
   - **Client Secret**

### 10.2 Obter IMDb Watchlist URL (Opcional)

1. Acesse: https://www.imdb.com/
2. Faça login
3. Crie sua watchlist
4. Vá para: Your Profile > Your Watchlist
5. Copie a URL completa

### 10.3 Obter Letterboxd Username (Opcional)

1. Acesse: https://letterboxd.com/
2. Faça login
3. Vá ao seu perfil
4. Copie o username da URL

### 10.4 Adicionar ao .env

```bash
nano /Users/menoncello/repos/setup/homelab/stacks/discovery-stack/.env
```

Adicione:
```bash
# ListSync
JELLYSEERR_API_KEY=api_key_do_jellyseerr
TRAKT_CLIENT_ID=seu_trakt_client_id
TRAKT_CLIENT_SECRET=seu_trakt_client_secret
TRAKT_ACCESS_TOKEN=
IMDB_USER_LIST_URL=https://www.imdb.com/user/urXXXXXXX/list/watchlist
LETTERBOXD_USERNAME=seu_username
```

### 10.5 Reiniciar ListSync

```bash
docker service update --force discovery_list-sync
```

### 10.6 Configurar ListSync

1. Acesse: https://listsync.menoncello.com
2. Configure as conexões:
   - Trakt: Authenticate via browser
   - IMDb: Adicione sua watchlist URL
   - Letterboxd: Adicione seu username
3. Configure o intervalo de sync:
   - **Sync Interval:** 1h

---

## 11. Configuração do Movary

### 11.1 Acessar

https://movary.menoncello.com

### 11.2 Criar Conta

1. Clique em **Create user**
2. Preencha:
   - **Name:** seu nome
   - **Email:** seu email
   - **Password:** sua senha
3. Clique em **Create**

### 11.3 Importar do Trakt (Opcional)

1. Acesse: https://trakt.tv/oauth/applications
2. Crie um app para Movary:
   - **Name:** Movary
   - **Redirect URI:** `http://localhost:5056/trakt/callback`
3. Copie Client ID e Secret
4. No Movary:
   - **Settings > Import > Trakt**
   - Configure com suas credenciais
   - Importe watch history, watchlist, ratings

### 11.4 Configurar Preferências

1. **Settings > General**
2. Configure:
   - **Theme:** Dark/Light
   - **Language:** Portuguese
3. **Settings > Privacy**
4. Configure quem pode ver sua activity

---

## 12. Teste Final

### 12.1 Teste de Request (Jellyseerr)

1. Acesse: https://jellyseerr.menoncello.com
2. Clique em **+ Request**
3. Pesquise um filme ou série
4. Selecione quality
5. Clique em **Request**
6. Verifique se foi aprovado e enviado para Radarr/Sonarr

### 12.2 Verificar Download (qBittorrent)

1. Acesse: https://qbittorrent.menoncello.com
2. Verifique se o download iniciou
3. Aguarde conclusão

### 12.3 Verificar Import (Sonarr/Radarr)

1. Acesse Sonarr ou Radarr
2. **Activity > Queue**
3. Verifique se está importando
4. **Series/Movies** - verifique se apareceu na biblioteca

### 12.4 Teste de Streaming (Jellyfin)

1. Acesse: https://jellyfin.menoncello.com
2. Verifique se o conteúdo apareceu na biblioteca
3. Teste reprodução

### 12.5 Teste de Legendas (Bazarr)

1. Acesse: https://bazarr.menoncello.com
2. Verifique se as series/filmes aparecem
3. Verifique se legendas foram baixadas automaticamente

---

## Resumo de Conexões

```
Prowlarr (Indexers)
    │
    ├─→ Sonarr ─┬─→ qBittorrent ─→ /media/series
    │           └─→ Bazarr (legendas)
    │
    ├─→ Radarr ─┬─→ qBittorrent ─→ /media/movies
    │           └─→ Bazarr (legendas)
    │
    ├─→ Lidarr ──→ qBittorrent ─→ /media/music
    │           └─→ Lidify (descoberta)
    │
    └─→ Listenarr → qBittorrent ─→ /media/audiobooks

Jellyseerr (Requests)
    │
    ├─→ Sonarr
    └─→ Radarr

ListSync (Watchlists)
    │
    ├─→ Trakt ──┐
    ├─→ IMDb ───┼─→ Jellyseerr
    └─→ Letterboxd

Movary (Tracking)
    │
    └─→ Trakt (import/export)
```

---

## Checklist de Configuração

Use este checklist para garantir que tudo foi configurado:

### Infraestrutura
- [ ] Nginx Proxy Manager configurado (11 hosts)
- [ ] SSL habilitado para todos os serviços
- [ ] DNS configurado

### Download
- [ ] qBittorrent password alterado
- [ ] Port 6881 configurado
- [ ] Categorias criadas (series, movies, music, audiobooks)

### Indexação
- [ ] Prowlarr indexers adicionados
- [ ] Prowlarr apps configurados (Sonarr, Radarr, Lidarr, Listenarr)

### ARR Services
- [ ] Sonarr: Download client + Indexer + Root folder + Quality profile
- [ ] Radarr: Download client + Indexer + Root folder + Quality profile
- [ ] Lidarr: Download client + Indexer + Root folder + Quality profile
- [ ] Listenarr: Download client + Indexer + Root folder + Quality profile

### Legendas
- [ ] Bazarr: Sonarr connection
- [ ] Bazarr: Radarr connection
- [ ] Bazarr: Providers configurados
- [ ] Bazarr: Idiomas configurados

### Requests
- [ ] Jellyseerr: Sonarr connection
- [ ] Jellyseerr: Radarr connection
- [ ] Jellyseerr: Jellyfin connection (opcional)
- [ ] Jellyseerr: Usuários e permissões configurados
- [ ] Jellyseerr API Key salva no .env

### Descoberta de Música
- [ ] Spotify Client ID e Secret obtidos
- [ ] LastFM API Key obtida
- [ ] Lidarr API Key salva no .env
- [ ] Lidify reiniciado
- [ ] Lidify configurado

### Sync de Watchlists
- [ ] Trakt Client ID e Secret obtidos
- [ ] IMDb watchlist URL obtida (opcional)
- [ ] Letterboxd username obtido (opcional)
- [ ] ListSync reiniciado
- [ ] ListSync configurado

### Tracking
- [ ] Movary conta criada
- [ ] Movary import do Trakt (opcional)

---

## Troubleshooting

### Serviço não responde

```bash
# Verificar status
docker stack services discovery

# Ver logs
docker service logs -f discovery_<service>
```

### Erro de conexão entre serviços

1. Verifique se ambos estão na rede `homelab-net`
2. Use nome do serviço (não IP) para conexão interna
3. Verifique API keys

### Downloads não iniciam

1. Verifique qBittorrent está rodando
2. Verifique categoria no qBittorrent
3. Verifique download client settings no ARR
4. Teste indexer no Prowlarr

### .env não funciona

1. Verifique se o arquivo existe
2. Verifique permissões
3. Reinicie o serviço após editar .env:
   ```bash
   docker service update --force discovery_<service>
   ```

---

## URLs Finais

Após configuração completa, acesse todos os serviços via:

- **Sonarr:** https://sonarr.menoncello.com
- **Radarr:** https://radarr.menoncello.com
- **Lidarr:** https://lidarr.menoncello.com
- **Listenarr:** https://listenarr.menoncello.com
- **Prowlarr:** https://prowlarr.menoncello.com
- **Bazarr:** https://bazarr.menoncello.com
- **qBittorrent:** https://qbittorrent.menoncello.com
- **Jellyseerr:** https://jellyseerr.menoncello.com
- **Lidify:** https://lidify.menoncello.com
- **ListSync:** https://listsync.menoncello.com
- **Movary:** https://movary.menoncello.com

---

**Data:** 2026-01-11
**Versão:** 1.0
**Stack:** Discovery Stack - 11 serviços
