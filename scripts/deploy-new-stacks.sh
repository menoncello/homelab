#!/bin/bash
# Deploy all 23 individual stacks

set -e

echo "Deploying 23 new individual stacks..."

# Infrastructure stacks (4)
echo "=== Infrastructure Stacks ==="
docker stack deploy -c stacks/infrastructure/infrastructure/docker-compose.yml infrastructure
docker stack deploy -c stacks/infrastructure/proxy/docker-compose.yml proxy
docker stack deploy -c stacks/infrastructure/pihole/docker-compose.yml pihole
docker stack deploy -c stacks/infrastructure/samba/docker-compose.yml samba

# Media Automation stacks (12)
echo "=== Media Automation Stacks ==="
docker stack deploy -c stacks/media-automation/sonarr/docker-compose.yml sonarr
docker stack deploy -c stacks/media-automation/radarr/docker-compose.yml radarr
docker stack deploy -c stacks/media-automation/qbittorrent/docker-compose.yml qbittorrent
docker stack deploy -c stacks/media-automation/bazarr/docker-compose.yml bazarr
docker stack deploy -c stacks/media-automation/jackett/docker-compose.yml jackett
docker stack deploy -c stacks/media-automation/lidarr/docker-compose.yml lidarr
docker stack deploy -c stacks/media-automation/prowlarr/docker-compose.yml prowlarr
docker stack deploy -c stacks/media-automation/jellyseerr/docker-compose.yml jellyseerr
docker stack deploy -c stacks/media-automation/flaresolverr/docker-compose.yml flaresolverr
docker stack deploy -c stacks/media-automation/stacks/docker-compose.yml stacks
docker stack deploy -c stacks/media-automation/listenarr/docker-compose.yml listenarr
docker stack deploy -c stacks/media-automation/calibre/docker-compose.yml calibre-media

# Content Servers stacks (4)
echo "=== Content Servers Stacks ==="
docker stack deploy -c stacks/content-servers/jellyfin/docker-compose.yml jellyfin
docker stack deploy -c stacks/content-servers/nextcloud/docker-compose.yml nextcloud
docker stack deploy -c stacks/content-servers/audiobookshelf/docker-compose.yml audiobookshelf
docker stack deploy -c stacks/content-servers/calibre/docker-compose.yml calibre

# Productivity stacks (3)
echo "=== Productivity Stacks ==="
docker stack deploy -c stacks/productivity/n8n/docker-compose.yml n8n
docker stack deploy -c stacks/productivity/anynote/docker-compose.yml anynote
docker stack deploy -c stacks/productivity/onlyoffice/docker-compose.yml onlyoffice

# Dashboards stack (1)
echo "=== Dashboards Stack ==="
docker stack deploy -c stacks/dashboards/homarr/docker-compose.yml homarr

echo "=== All 23 stacks deployed! ==="
echo "Check status with: docker stack ls"
