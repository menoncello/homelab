# Homarr Stack

A sleek, modern dashboard that puts all of your homelab services in one place.

## Access

- **URL:** http://192.168.31.237:7575
- **Default credentials:** Set on first launch

## First Time Setup

```bash
# 1. Create volume directories (on Helios)
ssh eduardo@192.168.31.237
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

## Adding Services

1. Open Homarr in browser
2. Click "Add element" → "Service"
3. Configure:
   - Name: Service name
   - URL: Service URL (e.g., http://192.168.31.237:8989 for Sonarr)
   - Icon: Search or use Materia icon
   - Category: Group (Media, Automation, etc.)

## Recommended Services to Add

| Service | URL | Category |
|---------|-----|----------|
| Jellyfin | http://192.168.31.237:8096 | Media |
| Sonarr | http://192.168.31.237:8989 | Automation |
| Radarr | http://192.168.31.237:7878 | Automation |
| Lidarr | http://192.168.31.237:8686 | Automation |
| n8n | http://192.168.31.208:5678 | Automation |
| Nextcloud | http://192.168.31.208:8080 | Cloud |
| Audiobookshelf | http://192.168.31.208:13378 | Media |
| Nginx Proxy Manager | http://192.168.31.237:81 | Infrastructure |
| Pi-hole | http://192.168.31.237:8053 | Infrastructure |
