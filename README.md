# Homelab Docker Stacks

Complete Docker Swarm-based homelab infrastructure for media streaming, content automation, and self-hosted services.

## Architecture

**Servers:**
- **Helios** (192.168.31.5) - Manager Node, GPU services
  - i7 11th gen, 64GB RAM, RTX 3070ti Mobile
  - Storage: `/data` (337.8GB), `/media` (955.6GB), `/srv` (444.5GB)

- **Xeon01** (192.168.31.6) - Worker Node, storage-intensive services
  - Xeon E5-2686, 96GB RAM
  - Storage: `/srv` (434.1GB), `/home` (793.8GB)

**Stacks:**
- `infrastructure` - Base volumes and network
- `pihole` - DNS server with ad blocking
- `gpu-services` - Jellyfin with GPU transcoding
- `arr-stack` - Sonarr, Radarr, Transmission, Lidarr
- `content` - Nextcloud, Audiobookshelf
- `database-stack` - PostgreSQL, Redis (shared databases)
- `proxy` - Nginx Proxy Manager
- `homarr-stack` - Dashboard for all services
- `n8n-stack` - Workflow automation
- `kavita-stack` - Ebook/comic reading server
- `stacks-stack` - Anna's Archive download manager

## Prerequisites

1. **Ubuntu 25.04** installed on both servers
2. **Docker Engine** installed
3. **NVIDIA drivers** installed on Helios (for GPU support)
4. **Docker Swarm** initialized:
   ```bash
   # On Helios (manager)
   docker swarm init

   # On Xeon01 (worker)
   docker swarm join --token [token] 192.168.31.5:2377
   ```

## Quick Start

### 1. Clone Repository

```bash
git clone https://github.com/menoncello/homelab.git
cd homelab
```

### 2. Configure Secrets

```bash
# Copy and edit secret files
cp stacks/content/secrets/postgres_password.txt.example stacks/content/secrets/postgres_password.txt
nano stacks/content/secrets/postgres_password.txt  # Set secure password
```

### 3. Deploy

```bash
# Run full deployment (Helios only for GPU setup)
./scripts/deploy.sh
```

Or deploy manually:

```bash
# 1. Setup GPU runtime (Helios only)
sudo ./scripts/setup-gpu.sh

# 2. Create volumes
sudo ./scripts/create-volumes.sh

# 3. Create overlay network
docker network create --driver overlay --attachable homelab-net

# 4. Label nodes
./scripts/setup-nodes.sh

# 5. Deploy stacks in order
docker stack deploy -c stacks/infrastructure/media.docker-compose.yml infrastructure
docker stack deploy -c stacks/proxy/media.docker-compose.yml proxy
docker stack deploy -c stacks/database-stack/media.docker-compose.yml database-stack
docker stack deploy -c stacks/content/media.docker-compose.yml content
docker stack deploy -c stacks/gpu-services/media.docker-compose.yml gpu-services
docker stack deploy -c stacks/arr-stack/media.docker-compose.yml arr-stack
docker stack deploy -c stacks/homarr-stack/media.docker-compose.yml homarr-stack
docker stack deploy -c stacks/n8n-stack/media.docker-compose.yml n8n-stack
docker stack deploy -c stacks/lidarr-stack/media.docker-compose.yml lidarr-stack
docker stack deploy -c stacks/kavita-stack/media.docker-compose.yml kavita
docker stack deploy -c stacks/stacks-stack/media.docker-compose.yml stacks
```

## Access Services

After deployment:

**Dashboard & Management:**
- **Homarr:** http://192.168.31.5:7575 - Dashboard for all services
- **Nginx Proxy Manager:** http://192.168.31.5:81 - Reverse proxy (admin@example.com / changeme)
- **Pi-hole:** http://192.168.31.5:8053/admin - DNS with ad blocking (piholeadmin2024)

**Media:**
- **Jellyfin:** http://192.168.31.5:8096 - Media server with GPU transcoding
- **Sonarr:** http://192.168.31.5:8989 - TV series automation
- **Radarr:** http://192.168.31.5:7878 - Movie automation
- **Lidarr:** http://192.168.31.5:8686 - Music automation
- **Transmission:** http://192.168.31.5:9091 - Torrent downloads

**Content & Reading:**
- **Nextcloud:** http://192.168.31.6:8080 - File storage and collaboration
- **Audiobookshelf:** http://192.168.31.6:80 - Audiobook management
- **Kavita:** http://192.168.31.6:5000 - Ebook/comic reading server
- **Stacks:** http://192.168.31.6:7788 - Anna's Archive download manager (admin/admin123)

**Automation:**
- **n8n:** http://192.168.31.6:5678 - Workflow automation

**Configure proxy hosts** in Nginx Proxy Manager:
  - jellyfin.homelab → jellyfin:8096
  - sonarr.homelab → sonarr:8989
  - radarr.homelab → radarr:7878
  - lidarr.homelab → lidarr:8686
  - transmission.homelab → transmission:9091
  - nextcloud.homelab → nextcloud:8080
  - audiobooks.homelab → audiobookshelf:80
  - kavita.homelab → kavita:5000
  - stacks.homelab → stacks:7788
  - n8n.homelab → n8n:5678

## Stack Details

### Pi-hole Stack
- **Pi-hole:** Network-wide DNS with ad blocking
  - Constraints: `node.labels.proxy == true`
  - Placement: Helios only
  - DNS server on port 53 (TCP/UDP)
  - Web interface on port 8053
  - Default password: piholeadmin2024

**Setup:**
1. Access http://192.168.31.237:8053/admin
2. Login with piholeadmin2024
3. Change password
4. Configure router DHCP to use 192.168.31.237 as DNS server
5. Add local DNS records for *.homelab

### Infrastructure Stack
Creates persistent volumes bound to NVMe mount points.

### GPU Services Stack
- **Jellyfin:** Media server with NVIDIA GPU transcoding
  - Constraints: `node.labels.gpu == true`
  - Placement: Helios only
  - GPU acceleration: Enabled

### ARR Stack
- **Sonarr:** TV series automation
- **Radarr:** Movie automation
- **Transmission:** Torrent downloads
- **Lidarr:** Music automation
  - Constraints: `node.labels.arr == true`
  - Placement: Helios only

### Content Stack
- **Nextcloud:** File storage and collaboration
- **Audiobookshelf:** Audiobook management
  - Constraints: `node.labels.storage == true`
  - Placement: Xeon01 only

### Database Stack
- **PostgreSQL:** Shared database for services
- **Redis:** Caching and job queue
  - Constraints: `node.labels.database == true`
  - Placement: Xeon01 only

### Dashboard Stack
- **Homarr:** Dashboard for all services
  - Constraints: `node.labels.arr == true`
  - Placement: Helios only

### Automation Stack
- **n8n:** Workflow automation
  - Constraints: `node.labels.storage == true`
  - Placement: Xeon01 only

### Reading Stack
- **Kavita:** Ebook/comic reading server
- **Stacks:** Anna's Archive download manager with FlareSolverr
  - Constraints: `node.labels.storage == true`
  - Placement: Xeon01 only
  - Shared folder: `/srv/docker/books`

### Proxy Stack
- **Nginx Proxy Manager:** Reverse proxy with SSL
  - Constraints: `node.labels.proxy == true`
  - Placement: Helios only

## Management

### Check Status

```bash
# List all stacks
docker stack ls

# List services in a stack
docker stack services gpu-services

# Service details
docker service ps gpu-services_jellyfin

# View logs
docker service logs -f gpu-services_jellyfin
```

### Update Stack

```bash
# Redeploy stack
docker stack deploy -c stacks/gpu-services/media.docker-compose.yml gpu-services

# Update service image
docker service update --image jellyfin:newversion gpu-services_jellyfin

# Force restart
docker service update --force gpu-services_jellyfin
```

### Scale Services

```bash
# Scale service (not recommended for stateful services)
docker service scale gpu-services_jellyfin=2
```

## Backup

### Critical Data

1. **PostgreSQL databases** (daily)
   ```bash
   docker exec postgresql pg_dump -U nextcloud nextcloud > backup.sql
   ```

2. **Nextcloud data** (weekly)
   ```bash
   rsync -av /srv/docker/nextcloud/ /backup/nextcloud/
   ```

3. **Configuration files** (on change)
   ```bash
   tar czf configs-$(date +%Y%m%d).tar.gz stacks/*/.env
   ```

## Troubleshooting

### Service Not Starting

```bash
# Check service status
docker service ps <stack>_<service> --no-trunc

# View logs
docker service logs <stack>_<service>

# Check resource constraints
docker service inspect <stack>_<service> | grep -A 10 "Resources"
```

### GPU Not Available

```bash
# Verify GPU on host
nvidia-smi

# Check container runtime
docker info | grep runtime

# Verify GPU passthrough
docker exec jellyfin nvidia-smi
```

### Volume Permission Errors

```bash
# Check ownership
ls -la /data/docker/

# Fix permissions
sudo chown -R 1000:1000 /data/docker/
```

### Network Issues

```bash
# Test overlay network
docker run --rm --network homelab-net alpine ping sonarr

# Check DNS resolution
docker exec jellyfin nslookup sonarr
```

## Security

- **Docker API:** Exposed only on internal network (Helios:2375)
- **Secrets:** Never commit actual passwords (use .example files)
- **SSL:** Configure Let's Encrypt in Nginx Proxy Manager
- **Firewall:** Block external access to management ports

## Roadmap

- [ ] Monitoring with Prometheus + Grafana
- [ ] Log aggregation with Loki + Promtail
- [ ] Automated backups with restic
- [ ] CI/CD pipeline for updates
- [ ] High availability configuration

## Documentation

- `CLAUDE.md` - Project conventions and best practices
- `docs/servers.md` - Server specifications
- `docs/plans/` - Design and implementation docs

## License

MIT

---

**Last Updated:** 2025-12-24
**Maintainer:** @eduardo
