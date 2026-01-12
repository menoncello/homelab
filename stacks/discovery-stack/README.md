# Discovery Stack

Media discovery and automation services for your homelab. This stack consolidates ALL ARR services, request management, and media tracking tools.

## Overview

The **Discovery Stack** handles media automation, discovery, and requests, while the **Media Stack** handles streaming and consumption.

**Discovery Stack (this stack):**
- **ARR Automation**: Sonarr, Radarr, Lidarr, Listenarr
- **Indexers**: Prowlarr, Jackett
- **Downloads**: qBittorrent
- **Subtitles**: Bazarr
- **Requests**: Jellyseerr
- **Discovery Tools**: Lidify, Movary, ListSync

**Media Stack (separate):**
- **Streaming**: Jellyfin, Audiobookshelf, Navidrome, Calibre-Web

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    HOMARR DASHBOARD                          │
│                 (entrada unificada)                          │
└─────────────────────────────────────────────────────────────┘
                              │
          ┌───────────────────┴───────────────────┐
          │                                       │
          ▼                                       ▼
    ┌─────────────┐                      ┌─────────────┐
    │ DISCOVERY   │                      │   MEDIA     │
    │   STACK     │                      │   STACK     │
    │ (Automation)│                      │ (Streaming) │
    └─────────────┘                      └─────────────┘
          │                                       │
    ┌─────┴─────┐                           ┌────┴────┐
    │           │                           │         │
    ▼           ▼                           ▼         ▼
┌─────────┐ ┌─────────┐              ┌─────────┐ ┌─────────┐
│Sonarr   │ │Radarr   │              │Jellyfin │ │Navidrome│
│(séries) │ │(filmes) │              │(vídeo)  │ │(música) │
└────┬────┘ └────┬────┘              └─────────┘ └─────────┘
     │            │
     └──────┬─────┘
            ▼
     ┌────────────┐
     │  Prowlarr  │
     │ (indexers) │
     └──────┬─────┘
            ▼
     ┌────────────┐
     │qBittorrent │
     │ (downloads)│
     └────────────┘
```

## Services

### Video Automation

#### Sonarr (Port 8989)
**Purpose:** TV series automation

**Features:**
- Automatically downloads TV series
- Scene/exception handling
- Quality profiles
- Automatic upgrades

**Configuration:**
- Connects to Prowlarr for indexers
- Connects to qBittorrent for downloads
- Media: `/media/series`

#### Radarr (Port 7878)
**Purpose:** Movie automation

**Features:**
- Automatically downloads movies
- Quality profiles (4K, 1080p, etc.)
- Automatic upgrades
- List management (IMDb, Trakt, etc.)

**Configuration:**
- Connects to Prowlarr for indexers
- Connects to qBittorrent for downloads
- Media: `/media/movies`

#### Bazarr (Port 6767)
**Purpose:** Subtitle automation

**Features:**
- Automatic subtitle downloads
- Multi-language support
- Integration with Sonarr/Radarr
- Profile-based customization

**Configuration:**
- Auto-syncs with Sonarr/Radarr
- Media: `/media/series`, `/media/movies`

### Music Automation

#### Lidarr (Port 8686)
**Purpose:** Music collection automation

**Features:**
- Automatically downloads music
- Artist/album tracking
- Quality profiles
- Automatic organization

**Configuration:**
- Connects to Prowlarr for indexers
- Connects to qBittorrent for downloads
- Media: `/media/music`

#### Lidify (Port 3333)
**Purpose:** Music discovery via Spotify/LastFM

**Features:**
- Recommendations based on Lidarr collection
- Spotify integration
- LastFM scrobbling
- Direct add to Lidarr

**Configuration:**
Requires in `.env`:
- `LIDARR_API_KEY` - from Lidarr Settings
- `SPOTIFY_CLIENT_ID/SECRET` - from Spotify Developer
- `LASTFM_API_KEY` - from LastFM API

### Audiobook Automation

#### Listenarr (Port 8988)
**Purpose:** Audiobook collection automation

**Features:**
- Automatically downloads audiobooks
- Metadata from Audible/Amazon
- Supports: MP3, M4A, M4B, FLAC, AAC, OGG, OPUS
- Author/series tracking

**Configuration:**
- Connects to Prowlarr/Jackett for indexers
- Connects to qBittorrent for downloads
- Media: `/media/audiobooks`

### Indexers

#### Prowlarr (Port 9696)
**Purpose:** Centralized indexer manager

**Features:**
- Single manager for all ARR apps
- Torznab/Newznab support
- Automatic testing
- Filter/tag management
- Torrent + Usenet support

**Configuration:**
1. Add indexers (Torrent sites, Usenet)
2. Create apps for each ARR service
3. Generate API keys for each app

#### Jackett (Port 9117)
**Purpose:** Legacy torrent indexer

**Features:**
- Torrent indexer as a proxy
- Torznab API
- Multiple tracker support

**Note:** Use Prowlarr for new setups

### Download Client

#### qBittorrent (Port 9091)
**Purpose:** Torrent download client

**Features:**
- Web UI
- Category management
- Speed limits
- RSS support
- Auto-import from watch folder

**Configuration:**
- Port 6881 for incoming connections
- Downloads to `/media/incomplete`
- Categories: series, movies, music, audiobooks

### Request Management

#### Jellyseerr (Port 5055)
**Purpose:** Media request management

**Features:**
- User requests for movies/TV
- Auto-approval based on user level
- Integration with Sonarr/Radarr
- Notifications (Discord, Email, etc.)
- Request limits

**Configuration:**
- Connect to Sonarr/Radarr with API keys
- Configure Jellyfin for user sync
- Set up approval rules

### Watchlist Sync

#### ListSync (Port 8082)
**Purpose:** Sync watchlists from external services

**Features:**
- Syncs Trakt watchlists
- Syncs IMDb lists
- Syncs Letterboxd
- Auto-adds to Jellyseerr

**Configuration:**
Requires in `.env`:
- `JELLYSEERR_API_KEY` - from Jellyseerr Settings
- `TRAKT_CLIENT_ID/SECRET/TOKEN` - from Trakt API
- `IMDB_USER_LIST_URL` - your IMDb watchlist URL
- `LETTERBOXD_USERNAME` - your Letterboxd username

### Media Tracking

#### Movary (Port 5056)
**Purpose:** Self-hosted media tracker

**Features:**
- Track watched movies/shows
- Rate and review
- Statistics
- Import/export from Trakt
- Watch list management

**Configuration:**
- No external API required
- Import from Trakt on first setup
- Local database

## Integration with Other Stacks

### Media Stack
Discovery stack **automates** what Media stack **streams**:

| Discovery (Automation) | Media (Streaming) |
|------------------------|-------------------|
| Sonarr → Downloads → | Jellyfin (watch TV) |
| Radarr → Downloads → | Jellyfin (watch movies) |
| Lidarr → Downloads → | Navidrome (listen music) |
| Listenarr → Downloads → | Audiobookshelf (listen audiobooks) |

### Database Stack
- All ARR services use SQLite by default
- Optional: PostgreSQL for better performance

### Infrastructure Stack
- Uses `homelab-net` overlay network
- Services communicate via DNS names

## Environment Variables

Create `.env` file from `.env.example`:

```bash
# Spotify (for Lidify)
SPOTIFY_CLIENT_ID=your_client_id
SPOTIFY_CLIENT_SECRET=your_client_secret

# LastFM (for Lidify)
LASTFM_API_KEY=your_api_key

# Lidarr (for Lidify)
LIDARR_API_KEY=your_lidarr_api_key

# Jellyseerr (for ListSync)
JELLYSEERR_API_KEY=your_jellyseerr_api_key

# Trakt (for ListSync)
TRAKT_CLIENT_ID=your_trakt_client_id
TRAKT_CLIENT_SECRET=your_trakt_client_secret
TRAKT_ACCESS_TOKEN=your_trakt_access_token

# IMDb (for ListSync)
IMDB_USER_LIST_URL=https://www.imdb.com/user/urXXXXXXX/list/watchlist

# Letterboxd (for ListSync)
LETTERBOXD_USERNAME=your_username
```

## API Keys Setup

### Lidarr API Key
1. Access Lidarr: http://192.168.31.5:8686
2. Settings > General > API Key
3. Copy and add to `.env`

### Jellyseerr API Key
1. Access Jellyseerr: http://192.168.31.5:5055
2. Settings > General > API Key
3. Copy and add to `.env`

### Spotify Credentials
1. Go to [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)
2. Create new app
3. Redirect URI: `http://localhost:3333/callback`
4. Copy Client ID and Secret

### Trakt Credentials
1. Go to [Trakt API](https://trakt.tv/oauth/applications)
2. Create new app
3. Redirect URI: `http://localhost:8082/callback`
4. Copy Client ID, Secret
5. Generate Access Token

## Deployment

### Prerequisites
```bash
# 1. Create music directory
sudo mkdir -p /media/music
sudo chown -R 1000:1000 /media/music

# 2. Copy .env template
cp stacks/discovery-stack/.env.example stacks/discovery-stack/.env

# 3. Edit .env with your credentials
nano stacks/discovery-stack/.env
```

### Deploy Stack
```bash
# From project root
docker stack deploy -c stacks/discovery-stack/docker-compose.yml discovery
```

### Verify Deployment
```bash
# Check services
docker stack services discovery

# Check logs
docker service logs -f discovery_sonarr
docker service logs -f discovery_radarr
docker service logs -f discovery_lidarr
```

### Remove Stack
```bash
docker stack rm discovery
```

## Access URLs

| Service | URL | Purpose |
|---------|-----|---------|
| **Sonarr** | http://192.168.31.5:8989 | TV series automation |
| **Radarr** | http://192.168.31.5:7878 | Movie automation |
| **Lidarr** | http://192.168.31.5:8686 | Music automation |
| **Listenarr** | http://192.168.31.5:8988 | Audiobook automation |
| **Prowlarr** | http://192.168.31.5:9696 | Indexer manager |
| **Bazarr** | http://192.168.31.5:6767 | Subtitle automation |
| **qBittorrent** | http://192.168.31.5:9091 | Download client |
| **Jellyseerr** | http://192.168.31.5:5055 | Request management |
| **Lidify** | http://192.168.31.5:3333 | Music discovery |
| **Movary** | http://192.168.31.5:5056 | Media tracker |
| **ListSync** | http://192.168.31.5:8082 | Watchlist sync |
| **Jackett** | http://192.168.31.5:9117 | Legacy indexer |

## Setup Guide

### 1. Configure Prowlarr
1. Access http://192.168.31.5:9696
2. Add your torrent indexers
3. Add apps for each ARR service:
   - Sonarr: http://sonarr:8989
   - Radarr: http://radarr:7878
   - Lidarr: http://lidarr:8686
   - Listenarr: http://listenarr:8988

### 2. Configure Download Client
1. Access qBittorrent http://192.168.31.5:9091
2. Tools > Options > Connection
3. Set port: 6881
4. Categories: series, movies, music, audiobooks

### 3. Configure ARR Services
For each ARR (Sonarr, Radarr, Lidarr, Listenarr):
1. Access web UI
2. Settings > Download Client
3. Add qBittorrent
4. Settings > Indexers
5. Add Prowlarr
6. Add your media paths

### 4. Configure Jellyseerr
1. Access http://192.168.31.5:5055
2. Settings > General
3. Add Sonarr/Radarr with API keys
4. Configure Jellyfin for user sync
5. Set up request approval rules

### 5. Configure Discovery Tools
**Lidify:**
1. Access http://192.168.31.5:3333
2. Add Lidarr API key
3. Configure Spotify/LastFM

**ListSync:**
1. Access http://192.168.31.5:8082
2. Configure Trakt/IMDb/Letterboxd
3. Set sync interval

**Movary:**
1. Access http://192.168.31.5:5056
2. Create account
3. Import from Trakt (optional)

## Troubleshooting

### Service not starting
```bash
docker service ps discovery_<service> --no-trunc
docker service logs discovery_<service>
```

### Database errors
Check volume permissions:
```bash
docker volume inspect <volume-name>
ls -la /data/docker/<service>
```

### Indexer not connecting
- Verify Prowlarr is running
- Check API keys in ARR settings
- Test indexer in Prowlarr

### Downloads not starting
- Verify qBittorrent is running
- Check download client settings in ARR
- Verify `/media/incomplete` permissions

## Migration from Old Stacks

If you're migrating from separate stacks:

**Old Stack → New Location:**
- `arr-stack` → `discovery-stack` (Sonarr, Radarr, Bazarr, Jackett, qBittorrent)
- `prowlarr-stack` → `discovery-stack` (Prowlarr)
- `lidarr-stack` → `discovery-stack` (Lidarr)
- `listenarr-stack` → `discovery-stack` (Listenarr)
- `request-stack` → `discovery-stack` (Jellyseerr)

**Migration Steps:**
1. Stop old stacks:
   ```bash
   docker stack rm arr-stack prowlarr-stack lidarr-stack listenarr-stack request-stack
   ```
2. Deploy discovery-stack
3. Volumes are preserved, configs remain intact

## Resources

### Documentation
- [Sonarr Wiki](https://wiki.servarr.com/en/Sonarr)
- [Radarr Wiki](https://wiki.servarr.com/en/Radarr)
- [Lidarr Wiki](https://wiki.servarr.com/en/Lidarr)
- [Prowlarr Wiki](https://wiki.servarr.com/en/Prowlarr)
- [Jellyseerr GitHub](https://github.com/jellyseerr/jellyseerr)

### Community
- [r/selfhosted](https://reddit.com/r/selfhosted)
- [r/UsenetTheInvolved](https://reddit.com/r/UsenetTheInvolved)

---

**Last Updated:** 2025-01-11
**Maintained by:** @eduardo
