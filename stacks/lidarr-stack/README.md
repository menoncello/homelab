# Lidarr Stack

Lidarr is a music collection manager for Usenet and BitTorrent users.

## Access

- **URL:** http://192.168.31.75:8686
- **Default credentials:**
  - Username: admin
  - Password: (set on first launch)

## First Time Setup

```bash
# 1. Create volume directories (on Helios)
ssh eduardo@192.168.31.75
sudo mkdir -p /data/docker/lidarr
sudo chown -R 1000:1000 /data/docker/lidarr

# 2. Create music library (on Xeon01)
ssh eduardo@192.168.31.208
sudo mkdir -p /home/docker-data/music
sudo chown -R 1000:1000 /home/docker-data/music

# 3. Ensure downloads directory exists (on Helios)
ssh eduardo@192.168.31.75
sudo mkdir -p /media/downloads
sudo chown -R 1000:1000 /media/downloads

# 4. Deploy stack (from manager)
cd ~/homelab/stacks/lidarr-stack
docker stack deploy -c docker-compose.yml lidarr

# 5. Verify deployment
docker service ls | grep lidarr
docker service logs -f lidarr_lidarr
```

## Configuration

After first launch:

1. **Settings → Media Management**
   - Root Folders: `/music` (for your music library)
   - Delete: Enable if you want Lidarr to manage deletions

2. **Settings → Download Clients**
   - Add Transmission (should already be configured from Sonarr/Radarr)
   - Host: `transmission`
   - Port: 9091

3. **Settings → Indexers**
   - Add Jackett (already running in arr-stack)
   - URL: `http://jackett:9117`
   - Add your music indexers

4. **Settings → Connect**
   - Connect to Jellyfin for notifications
   - Connect to Homarr for dashboard integration

## Tips

- Lidarr works best with quality profiles set up (FLAC, MP3 320, etc.)
- Enable metadata tagging for automatic organization
- Set up notification for download completion
