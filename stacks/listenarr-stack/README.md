# Listenarr Stack

Audiobook collection manager - similar to Sonarr/Radarr but for audiobooks.

## Features

- ✅ Search, download, and organize audiobooks automatically
- ✅ Rich metadata from Audible and Amazon
- ✅ Supports multiple formats: MP3, M4A, M4B, FLAC, AAC, OGG, OPUS
- ✅ Integrates with Jackett for torrent indexers
- ✅ Supports qBittorrent, Transmission, SABnzbd, NZBGet
- ✅ Real-time download monitoring
- ✅ Customizable naming patterns
- ✅ Beautiful responsive web interface

## Quick Start

```bash
cd stacks/listenarr-stack
docker stack deploy -c docker-compose.yml listenarr
```

## Access

- **Web UI:** http://192.168.31.75:8988
- **Port:** 8988 (internal: 5000)

## Configuration

### First Time Setup

1. Open the web UI at http://listenarr.homelab.local:5000
2. Create your admin account
3. Configure your download client (qBittorrent, Transmission, etc.)
4. Add Jackett or other indexers for audiobook search
5. Set up your audiobook library path

### Download Client

Go to **Settings → Download Clients** and add:
- qBittorrent (recommended)
- Transmission
- SABnzbd
- NZBGet

### Indexers

Go to **Settings → Indexers** and add:
- Jackett (Torznab)
- Other NZB/Torrent indexers

Use the `jackett-to-arrs` script to automatically add Jackett indexers:
```bash
cd inner-projects/jackett-to-arrs
bun run add-indexers
```

### Library

Add authors or audiobooks you want to track, and Listenarr will automatically:
- Search for new releases
- Download when available
- Organize and rename files

## Volumes

| Volume | Path | Purpose |
|--------|------|---------|
| `listenarr-config` | /data/docker/listenarr | Configuration and database |
| `listenarr-downloads` | /media/downloads | Download location |
| `listenarr-audiobooks` | /media/audiobooks | Audiobook library |

## Resources

- [Listenarr GitHub](https://github.com/therobbiedavis/Listenarr)
- [Discord](https://discord.gg/CwZ2Sqp9NF)

## Notes

- Listenarr is still in beta - expect some rough edges
- For more stable audiobook management, consider [Readarr](https://github.com/Readarr/Readarr)
- Integration with Audiobookshelf coming soon
