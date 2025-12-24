# Kavita + Stacks Design

**Date:** 2025-12-24
**Services:** Kavita (ebook reader) + Stacks (Anna's Archive download manager)

## Overview

Adding two complementary services for book management:
- **Kavita:** Modern digital library server for EPUB, PDF, comics, and manga
- **Stacks:** Download manager for Anna's Archive with web UI and API

**Integration:** Shared folder approach - Stacks downloads to `/srv/docker/books`, Kavita reads from same location.

## Architecture

### Stack Structure
```
stacks/
├── kavita-stack/
│   ├── docker-compose.yml
│   └── README.md
└── stacks-stack/
    ├── docker-compose.yml
    └── README.md
```

### Node Placement
- **Kavita:** Xeon01 (`node.labels.storage == true`)
- **Stacks:** Xeon01 (`node.labels.storage == true`)
- **FlareSolverr:** Xeon01 (optional, for Cloudflare bypass)

### Network
- All services connect to `homelab-net` (existing overlay network)

## Volumes

### Directory Structure (Xeon01)
```bash
/srv/docker/
├── kavita/
│   └── books/              # Shared library
├── stacks/
│   ├── config/
│   ├── downloads/          # Mapped to kavita/books
│   └── logs/
```

### Kavita Volumes
```yaml
kavita-config:
  driver: local
  driver_opts:
    type: none
    o: bind
    device: /srv/docker/kavita/config

kavita-books:
  driver: local
  driver_opts:
    type: none
    o: bind
    device: /srv/docker/books
```

### Stacks Volumes
```yaml
stacks-config:
  driver: local
  driver_opts:
    type: none
    o: bind
    device: /srv/docker/stacks/config

stacks-downloads:
  driver: local
  driver_opts:
    type: none
    o: bind
    device: /srv/docker/books

stacks-logs:
  driver: local
  driver_opts:
    type: none
    o: bind
    device: /srv/docker/stacks/logs
```

## Service Configuration

### Kavita
```yaml
image: kavitareader/kavita:latest
ports:
  - 5000:5000
environment:
  - TZ=America/Sao_Paulo
memory: 2GB
```

### Stacks
```yaml
image: zelest/stacks:latest
ports:
  - 7788:7788
environment:
  - USERNAME=admin
  - PASSWORD=<secure>
  - SOLVERR_URL=flaresolverr:8191
  - TZ=America/Sao_Paulo
memory: 1GB
```

### FlareSolverr (optional)
```yaml
image: ghcr.io/flaresolverr/flaresolverr:latest
ports:
  - 8191:8191
environment:
  - LOG_LEVEL=info
```

## Access URLs

| Service | URL | Purpose |
|---------|-----|---------|
| Kavita | http://192.168.31.208:5000 | Read ebooks/comics |
| Stacks | http://192.168.31.208:7788 | Download manager UI |
| FlareSolverr | http://192.168.31.208:8191 | Cloudflare bypass |

## Integration Flow

1. User finds book on Anna's Archive
2. Click Tampermonkey button → sends to Stacks
3. Stacks downloads to `/srv/docker/books/`
4. Kavita scans folder → book appears in library

## First Time Setup

1. Create volumes on Xeon01
2. Deploy stacks
3. Configure Stacks API key
4. Install Tampermonkey script
5. Set up Kavita library

## Security Notes

- Change default passwords
- Use VPN/reverse proxy for external access
- Stacks includes rate limiting (5 failed attempts = 10min lockout)
