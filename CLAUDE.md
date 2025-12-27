# Homelab Infrastructure - Project Conventions

## Project Overview

Docker Swarm-based homelab running on 2 servers (pop-os + Xeon01) with 2.5Gbps networking and GPU acceleration. Focused on media streaming, content automation, and self-hosted services.

**Architecture:**
- **pop-os (Manager):** i7/64GB/RTX 3070ti - GPU services + media transcoding
- **Xeon01 (Worker):** Xeon/96GB - Databases + storage-intensive services

**Key Technologies:**
- Docker Swarm with overlay networks
- NVIDIA Container Runtime for GPU acceleration
- Modular stack architecture (infrastructure, gpu-services, arr-stack, content, proxy)
- Nginx Proxy Manager for HTTPS termination

---

## Repository Structure

```
homelab/
├── stacks/                    # Docker compose files per service category
│   ├── infrastructure/        # Base networks, volumes
│   ├── gpu-services/          # Jellyfin with GPU support
│   ├── arr-stack/             # Sonarr, Radarr, Transmission
│   ├── content/               # Nextcloud, Audiobookshelf, PostgreSQL
│   └── proxy/                 # Nginx Proxy Manager
├── scripts/                   # Automation scripts
│   ├── setup-gpu.sh          # NVIDIA container runtime setup
│   ├── create-volumes.sh     # Persistent volume creation
│   ├── setup-nodes.sh        # Docker Swarm node labeling
│   └── deploy.sh             # Full deployment automation
├── volumes/                   # Volume definitions (managed by Docker)
├── docs/                      # Design docs and plans
│   ├── servers.md            # Server specifications
│   └── plans/                # Implementation plans
└── CLAUDE.md                  # This file
```

---

## Docker Swarm Conventions

### Stack Management

**Always use Docker contexts:**
```bash
# Switch to homelab context
docker context use homelab

# Verify context
docker context ls
docker info | grep "Swarm"
```

**Deploy individual stacks:**
```bash
# From stack directory
cd stacks/infrastructure
docker stack deploy -c docker-compose.yml infrastructure

# Remove stack
docker stack rm infrastructure
```

**Check stack status:**
```bash
# List all stacks
docker stack ls

# Services in a stack
docker stack services infrastructure

# Detailed service info
docker service inspect infrastructure_network-setup
```

### Service Placement Constraints

**Node labels (applied via setup-nodes.sh):**
```yaml
# pop-os labels
- node.labels.gpu == true      # GPU-accelerated services
- node.labels.arr == true      # Media download automation
- node.labels.proxy == true    # Reverse proxy

# Xeon01 labels
- node.labels.storage == true  # Storage-intensive services
- node.labels.database == true # Database services
```

**Example in compose:**
```yaml
deploy:
  placement:
    constraints:
      - node.labels.gpu == true
```

### Service Management

**Scaling:**
```bash
# Scale service (though most are replicas: 1)
docker service scale infrastructure_jellyfin=2
```

**Updating services:**
```bash
# Force update/restart
docker service update --force infrastructure_jellyfin

# Rolling update with image
docker service update --image jellyfin:latest infrastructure_jellyfin
```

**Logs:**
```bash
# Follow service logs
docker service logs -f infrastructure_jellyfin

# Logs for specific replica
docker service logs --since 1h infrastructure_jellyfin
```

---

## GPU Configuration

### NVIDIA Container Runtime

**Installed via scripts/setup-gpu.sh:**
- NVIDIA Container Toolkit
- Custom Docker daemon configuration
- GPU detection in containers

**Verifying GPU access:**
```bash
# On host
nvidia-smi

# In container
docker exec jellyfin nvidia-smi

# Check GPU passthrough
docker inspect jellyfin | grep -A 10 "DeviceRequest"
```

**Docker Compose GPU configuration:**
```yaml
deploy:
  resources:
    reservations:
      devices:
        - driver: nvidia
          count: 1
          capabilities: [gpu]
```

**Environment variables for GPU:**
```bash
NVIDIA_VISIBLE_DEVICES=all
NVIDIA_DRIVER_CAPABILITIES=compute,video,utility,graphics
```

---

## Volume Management

### Persistent Volume Strategy

**Bind mounts (recommended for performance):**
```yaml
volumes:
  jellyfin-config:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /data/docker/jellyfin
```

**Host paths:**
- **pop-os /data:** `/data/docker/` - Container configs
- **pop-os /media:** `/media/` - Media libraries
- **Xeon01 /srv:** `/srv/docker/` - Container configs
- **Xeon01 /home:** `/home/docker-data/` - Database and user data

### Volume Creation

**Run setup script before first deploy:**
```bash
./scripts/create-volumes.sh
```

**Permissions:**
```bash
# All volumes owned by UID 1000
sudo chown -R 1000:1000 /data/docker/
sudo chown -R 1000:1000 /media/
sudo chown -R 1000:1000 /srv/docker/
sudo chown -R 1000:1000 /home/docker-data/
```

**Never use:** Named volumes without bind mounts (performance issues in Swarm)

---

## Networking

### Overlay Networks

**Main network: `homelab-net`**
```yaml
networks:
  homelab-net:
    external: true
    driver: overlay
    attachable: true
```

**Create network:**
```bash
docker network create --driver overlay --attachable homelab-net
```

**Network rules:**
- All services MUST connect to `homelab-net`
- Services communicate using service names (DNS)
- No port conflicts between stacks
- Internal ports only (no need to expose every port)

### Service Discovery

**Internal communication:**
```yaml
# Nextcloud connects to PostgreSQL
environment:
  - POSTGRES_HOST=postgresql  # Service name, not IP
```

**Access services from host:**
```bash
# Use published port
curl http://localhost:8096

# Or via service name on overlay network
docker exec jellyfin wget -qO- http://sonarr:8989
```

---

## Environment Variables

### Pattern

**Per-stack `.env` files:**
```bash
# stacks/gpu-services/.env
COMPOSE_PROJECT_NAME=gpu-services
JELLYFIN_VERSION=latest
TZ=America/Sao_Paulo
```

**Common variables across all stacks:**
- `TZ` - Timezone (America/Sao_Paulo)
- `PUID` / `PGID` - User ID for permissions (1000:1000)

**Secrets management:**
- Use Docker secrets for sensitive data
- Never commit `.env` files with real values
- Use `.env.example` templates

---

## Deployment Workflow

### Initial Setup

```bash
# 1. Setup GPU runtime (pop-os only)
ssh eduardo@192.168.31.75
./scripts/setup-gpu.sh

# 2. Create volume structure (both servers)
./scripts/create-volumes.sh

# 3. Label nodes (from manager)
docker swarm init  # if not initialized
docker swarm join --token ...  # on Xeon01
./scripts/setup-nodes.sh

# 4. Deploy stacks in order
./scripts/deploy.sh
```

### Updating Services

```bash
# 1. Pull latest changes
git pull

# 2. Update specific stack
cd stacks/gpu-services
docker stack deploy -c docker-compose.yml gpu-services

# 3. Monitor deployment
docker service ps gpu-services_jellyfin
```

### Rolling Updates

```bash
# Update image with rolling restart
docker service update \
  --image jellyfin:newversion \
  --update-delay 10s \
  --update-parallelism 1 \
  gpu-services_jellyfin
```

---

## Security Best Practices

### Network Security

**Docker API:**
- Exposed only on internal network (pop-os:2375)
- Never expose Docker API to internet
- Consider TLS for production

**Firewall rules:**
```bash
# Allow only necessary ports
- 22 (SSH)
- 80/443 (HTTP/HTTPS via proxy)
- 2375 (Docker API, internal only)
- 2377 (Swarm management, internal only)
```

### Container Security

**Run as non-root:**
```yaml
# Most images support PUID/PGID
environment:
  - PUID=1000
  - PGID=1000
```

**Read-only filesystems where possible:**
```yaml
deploy:
  replicas: 1
  read_only: true
```

**Resource limits:**
```yaml
deploy:
  resources:
    limits:
      memory: 4G
    reservations:
      memory: 2G
```

### Secrets Management

**Use Docker secrets for passwords:**
```yaml
secrets:
  postgres_password:
    file: ./secrets/postgres_password.txt

services:
  postgres:
    secrets:
      - postgres_password
    environment:
      - POSTGRES_PASSWORD_FILE=/run/secrets/postgres_password
```

**Never commit:**
- `.env` files with real values
- `secrets/` directory with actual passwords
- SSL private keys

---

## Backup Strategy

### What to Backup

**Critical data:**
- PostgreSQL databases (daily)
- Nextcloud data (weekly)
- Jellyfin library metadata (weekly)
- Configuration files (on change)

**Not critical:**
- Media files (can be re-downloaded)
- Docker images (reproducible)

### Backup Commands

**PostgreSQL:**
```bash
docker exec postgresql pg_dump -U nextcloud nextcloud > backup.sql
```

**Nextcloud:**
```bash
# Data directory
rsync -av /srv/docker/nextcloud/ /backup/nextcloud/

# Database
docker exec nextcloud php occ db:add-maintenance-activation
```

**Volumes:**
```bash
# Snapshot entire volume
docker run --rm -v jellyfin-config:/data -v /backup:/backup alpine \
  tar czf /backup/jellyfin-$(date +%Y%m%d).tar.gz /data
```

---

## Monitoring and Maintenance

### Health Checks

**Check service status:**
```bash
# All services
docker service ls

# Service health
docker service ps gpu-services_jellyfin --no-trunc

# Node status
docker node ls
```

**Resource usage:**
```bash
# Container stats
docker stats

# Node resources
docker node inspect helios --format '{{.Description.Resources}}'
```

### Log Management

**Centralized logging (future):**
- Loki + Promtail for log aggregation
- Grafana for visualization

**Current approach:**
```bash
# Rotate logs
docker service update --log-opt max-size=10m --log-opt max-file=3 infrastructure_jellyfin

# View logs
docker service logs --tail 100 -f infrastructure_jellyfin
```

### Updates

**OS updates:**
```bash
# On both servers
sudo apt update && sudo apt upgrade -y

# Reboot if needed (services auto-start)
sudo reboot
```

**Docker updates:**
```bash
# Update Docker Engine
sudo apt update
sudo apt install --only-upgrade docker-ce docker-ce-cli containerd.io
```

---

## Troubleshooting

### Common Issues

**Service not starting:**
```bash
# Check service status
docker service ps <stack>_<service> --no-trunc

# View logs
docker service logs <stack>_<service>

# Check for resource constraints
docker service inspect <stack>_<service> | grep -A 10 "Resources"
```

**GPU not accessible:**
```bash
# Verify GPU on host
nvidia-smi

# Check container runtime
docker info | grep runtime

# Verify GPU passthrough
docker inspect jellyfin | grep -i nvidia
```

**Volume permission errors:**
```bash
# Check volume ownership
ls -la /data/docker/

# Fix permissions
sudo chown -R 1000:1000 /data/docker/
```

**Network connectivity:**
```bash
# Test overlay network
docker run --rm --network homelab-net alpine ping sonarr

# Check DNS resolution
docker exec jellyfin nslookup sonarr
```

### Debug Mode

**Enable debug logging:**
```yaml
services:
  jellyfin:
    environment:
      - JELLYFIN_LOG_LEVEL=debug
```

**Run container in foreground (testing):**
```bash
docker run --rm -it \
  --network homelab-net \
  -v jellyfin-config:/config \
  jellyfin:latest
```

---

## Development Workflow

### Making Changes

**1. Plan changes:**
- Read existing design docs in `docs/plans/`
- Check impact on other services
- Test in non-production first

**2. Modify stack files:**
- Edit `docker-compose.yml`
- Update `.env.example` if needed
- Document breaking changes

**3. Deploy changes:**
```bash
cd stacks/<stack-name>
docker stack deploy -c docker-compose.yml <stack-name>
```

**4. Verify:**
```bash
# Check deployment
docker service ps <stack-name>_<service>

# Monitor logs
docker service logs -f <stack-name>_<service>

# Test functionality
curl http://localhost:<port>
```

**5. Commit:**
```bash
git add stacks/ scripts/ docs/
git commit -m "feat: description of changes"
```

### Testing New Services

**Before adding to stack:**
1. Test locally with `docker run`
2. Verify networking compatibility
3. Check resource requirements
4. Document configuration

**Template for new service:**
```yaml
services:
  new-service:
    image: image:tag
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.labels.<label> == true
      resources:
        limits:
          memory: 2G
    environment:
      - TZ=America/Sao_Paulo
    volumes:
      - config:/config
    networks:
      - homelab-net
    restart: unless-stopped
```

---

## Quick Reference

### Essential Commands

```bash
# Context management
docker context use homelab
docker context ls

# Stack operations
docker stack ls
docker stack services <stack>
docker stack deploy -c docker-compose.yml <stack>
docker stack rm <stack>

# Service operations
docker service ls
docker service ps <service>
docker service logs -f <service>
docker service update --force <service>

# Swarm management
docker node ls
docker node inspect <node>

# Network operations
docker network ls
docker network inspect homelab-net

# Volume operations
docker volume ls
docker volume inspect <volume>
```

### Access URLs

After deployment:
- **Nginx Proxy Manager:** http://192.168.31.75:81
- **Audiobookshelf:** http://192.168.31.75:8080
- **Jellyfin:** http://jellyfin.homelab.local (after proxy config)
- **Sonarr:** http://sonarr.homelab.local
- **Radarr:** http://radarr.homelab.local
- **Nextcloud:** http://nextcloud.homelab.local

### Server Access

```bash
# pop-os (Manager)
ssh eduardo@192.168.31.75
docker context use homelab

# Xeon01 (Worker)
ssh eduardo@192.168.31.208
```

---

## Additional Resources

**Design documents:**
- `docs/servers.md` - Server specifications and network config
- `docs/plans/2025-12-22-homelab-hybrid-design.md` - Architecture overview
- `docs/plans/2025-12-22-docker-stacks-implementation.md` - Implementation plan

**External documentation:**
- [Docker Swarm documentation](https://docs.docker.com/engine/swarm/)
- [NVIDIA Container Toolkit](https://github.com/NVIDIA/nvidia-docker)
- [Nginx Proxy Manager](https://nginxproxymanager.com/)
- [Jellyfin with GPU](https://jellyfin.org/docs/general/administration/hardware-acceleration/)

---

## Conventions Summary

**DO:**
- Always use Docker contexts for remote management
- Deploy stacks in dependency order (infrastructure → others)
- Use node labels for service placement
- Bind mount volumes for performance
- Use overlay networks for service communication
- Run containers as non-root (PUID/PGID)
- Document changes in docs/ and commit messages
- Test changes before deploying to production
- Use Docker secrets for sensitive data

**DON'T:**
- Expose Docker API to internet
- Use named volumes without bind mounts in Swarm
- Run services as root
- Hardcode credentials in compose files
- Skip node labeling (leads to random placement)
- Expose every service port (use proxy)
- Commit .env files with real values
- Update all stacks simultaneously (test incrementally)
- Skip backups before major changes

---

**Last Updated:** 2025-12-26
**Maintained by:** @eduardo
**Questions?** Check docs/plans/ or review implementation guide