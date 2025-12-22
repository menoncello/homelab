# Homelab Docker Stacks

Complete Docker Swarm-based homelab infrastructure for media streaming, content automation, and self-hosted services.

## Architecture

**Servers:**
- **Helios** (192.168.31.237) - Manager Node, GPU services
  - i7 11th gen, 64GB RAM, RTX 3070ti Mobile
  - Storage: `/data` (337.8GB), `/media` (955.6GB), `/srv` (444.5GB)

- **Xeon01** (192.168.31.208) - Worker Node, storage-intensive services
  - Xeon E5-2686, 96GB RAM
  - Storage: `/srv` (434.1GB), `/home` (793.8GB)

**Stacks:**
- `infrastructure` - Base volumes and network
- `gpu-services` - Jellyfin with GPU transcoding
- `arr-stack` - Sonarr, Radarr, Transmission
- `content` - Nextcloud, Audiobookshelf, PostgreSQL, Redis
- `proxy` - Nginx Proxy Manager

## Prerequisites

1. **Ubuntu 25.04** installed on both servers
2. **Docker Engine** installed
3. **NVIDIA drivers** installed on Helios (for GPU support)
4. **Docker Swarm** initialized:
   ```bash
   # On Helios (manager)
   docker swarm init

   # On Xeon01 (worker)
   docker swarm join --token [token] 192.168.31.237:2377
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
docker stack deploy -c stacks/infrastructure/docker-compose.yml infrastructure
docker stack deploy -c stacks/proxy/docker-compose.yml proxy
docker stack deploy -c stacks/content/docker-compose.yml content
docker stack deploy -c stacks/gpu-services/docker-compose.yml gpu-services
docker stack deploy -c stacks/arr-stack/docker-compose.yml arr-stack
```

## Access Services

After deployment:

- **Nginx Proxy Manager:** http://192.168.31.237:81
  - Default: admin@example.com / changeme

- **Configure proxy hosts** in Nginx Proxy Manager:
  - jellyfin.homelab.local → jellyfin:8096
  - sonarr.homelab.local → sonarr:8989
  - radarr.homelab.local → radarr:7878
  - transmission.homelab.local → transmission:9091
  - nextcloud.homelab.local → nextcloud:8080
  - audiobooks.homelab.local → audiobookshelf:80

## Stack Details

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
  - Constraints: `node.labels.arr == true`
  - Placement: Helios only

### Content Stack
- **Nextcloud:** File storage and collaboration
- **Audiobookshelf:** Audiobook management
- **PostgreSQL:** Database for services
- **Redis:** Caching for Nextcloud
  - Constraints: `node.labels.storage == true` / `node.labels.database == true`
  - Placement: Xeon01 only

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
docker stack deploy -c stacks/gpu-services/docker-compose.yml gpu-services

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

**Last Updated:** 2025-12-22
**Maintainer:** @eduardo
