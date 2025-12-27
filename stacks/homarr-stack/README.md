# Homarr Stack

A sleek, modern dashboard that puts all of your homelab services in one place.

## Access

- **URL:** http://192.168.31.75:7575
- **Default credentials:** Set on first launch

## First Time Setup

```bash
# 1. Create volume directories (on Helios)
ssh eduardo@192.168.31.75
sudo mkdir -p /data/docker/homarr/data
sudo chown -R 1000:1000 /data/docker/homarr

# 2. Deploy stack (from manager)
cd ~/homelab/stacks/homarr-stack
docker stack deploy -c docker-compose.yml homarr

# 3. Verify deployment
docker service ls | grep homarr
docker service logs -f homarr_homarr
```

## Configuration

Homarr stores configuration in `/data/docker/homarr` on Helios:
- `configs/` - Board configurations
- `data/` - User data and icons

### Environment Variables

Copy `.env.example` to `.env` and configure your settings:

```bash
cd ~/homelab/stacks/homarr-stack
cp .env.example .env

# Edit .env and add your Homarr API key
nano .env
```

**Required variables:**
- `HOMARR_URL` - Your Homarr instance URL (default: http://192.168.31.75:7575)
- `HOMARR_API_KEY` - API key for automated setup (get from Profile → Settings → API Keys)

**Security Note:** The `.env` file is excluded from git via `.gitignore` to protect your secrets.

## Adding Services

1. Open Homarr in browser
2. Click "Add element" → "Service"
3. Configure:
   - Name: Service name
   - URL: Service URL (e.g., http://192.168.31.237:8989 for Sonarr)
   - Icon: Search or use Materia icon
   - Category: Group (Media, Automation, etc.)

## Dashboard Configuration

A pre-configured dashboard is available in `configs/default-dashboard.json` with all homelab services organized by category.

### Services Configured

**Media:**
- Jellyfin (port 8096)
- Audiobookshelf (port 8080)
- Kavita (port 5000)

**Automation (ARR Suite):**
- Sonarr (port 8989) - TV Shows
- Radarr (port 7878) - Movies
- Lidarr (port 8686) - Music
- Bazarr (port 6767) - Subtitles
- Prowlarr (port 9696) - Indexer manager
- Jackett (port 9117) - Torrent indexer

**Books:**
- Listenarr (port 8988) - Audiobooks
- LazyLibrarian (port 5299) - Author tracking

**Requests:**
- Jellyseerr (port 5055) - Media requests
- AudioBookRequest (port 8000) - Audiobook requests

**Downloads:**
- qBittorrent (port 9091)

**Infrastructure:**
- Nginx Proxy Manager (port 81)
- Pi-hole (port 8053)

**Tools:**
- n8n (port 5678) - Workflow automation
- ebook2audiobook (port 7860) - eBook to audiobook conversion

### Importing Dashboard

**Option 1: Automated Setup via API (Recommended - Fastest)**

This option automatically creates all apps, categories, and widgets using the Homarr API.

```bash
cd ~/homelab/stacks/homarr-stack

# 1. Copy and configure .env file
cp .env.example .env
nano .env  # Add your HOMARR_API_KEY

# 2. Make scripts executable and run
chmod +x setup-dashboard.sh
./setup-dashboard.sh
```

The script will automatically create:
- 7 categories (Media, Automation, Requests, Infrastructure, Downloads, Books, Tools)
- 18 apps with all your services pre-configured

**Getting your API Key:**
1. Open http://192.168.31.75:7575 in browser
2. Click on your profile (top right)
3. Go to Settings → API Keys
4. Create a new API key
5. Copy and paste into `.env` file

**Option 2: Web UI Import**
1. Access Homarr at http://192.168.31.75:7575
2. Go to Management → Boards
3. Create a new board or edit existing
4. Use the reference table below to add services manually

**Option 3: Manual Configuration via Web UI**
1. Access Homarr at http://192.168.31.75:7575
2. Click "Add element" → "App"
3. Configure each service from the table below

| Service | URL | Category | Integration |
|---------|-----|----------|-------------|
| Jellyfin | http://192.168.31.75:8096 | Media | - |
| Sonarr | http://192.168.31.75:8989 | Automation | Sonarr |
| Radarr | http://192.168.31.75:7878 | Automation | Radarr |
| Lidarr | http://192.168.31.75:8686 | Automation | Lidarr |
| Bazarr | http://192.168.31.75:6767 | Automation | - |
| Prowlarr | http://192.168.31.75:9696 | Automation | - |
| Jackett | http://192.168.31.75:9117 | Automation | - |
| Jellyseerr | http://192.168.31.75:5055 | Requests | Overseerr |
| Audiobookshelf | http://192.168.31.75:8080 | Media | - |
| Kavita | http://192.168.31.75:5000 | Books | - |
| Listenarr | http://192.168.31.75:8988 | Books | - |
| LazyLibrarian | http://192.168.31.75:5299 | Books | - |
| AudioBookRequest | http://192.168.31.75:8000 | Requests | - |
| qBittorrent | http://192.168.31.75:9091 | Downloads | qBittorrent |
| Nginx Proxy Manager | http://192.168.31.75:81 | Infrastructure | - |
| Pi-hole | http://192.168.31.75:8053 | Infrastructure | Pi-hole |
| n8n | http://192.168.31.75:5678 | Tools | - |
| ebook2audiobook | http://192.168.31.75:7860 | Tools | - |

### Setting Up Integrations

For services with integrations (Sonarr, Radarr, Lidarr, Jellyseerr, qBittorrent, Pi-hole):

1. Go to the service settings
2. Click "Integration"
3. Configure:
   - **API Key**: Get from Settings → API Key in the respective service
   - **URL**: Use internal Docker network name (e.g., `http://sonarr:8989`)

### Backup and Restore

```bash
# Backup dashboard configuration
ssh eduardo@192.168.31.75
cp -r /data/docker/homarr/data/configs ~/homarr-backup-$(date +%Y%m%d)

# Restore dashboard configuration
cp ~/homarr-backup-YYYYMMDD/* /data/docker/homarr/data/configs/
docker service update --force homarr_homarr
```
