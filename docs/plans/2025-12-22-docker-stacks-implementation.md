# Docker Stacks Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implementar homelab com stacks Docker separadas, configuração GPU e volumes específicos

**Architecture:** Docker Swarm com stacks modulares (infrastructure, media, content-management), GPU passthrough para Jellyfin, volumes persistentes distribuídos

**Tech Stack:** Docker Swarm, NVIDIA Container Runtime, Docker Compose, Nginx Proxy Manager

---

## Estrutura do Repositório

```
homelab/
├── stacks/
│   ├── infrastructure/
│   │   ├── docker-compose.yml      # Rede overlay, volumes base
│   │   └── .env.example
│   ├── gpu-services/
│   │   ├── docker-compose.yml      # Jellyfin com GPU
│   │   ├── jellyfin/
│   │   │   └── Dockerfile.custom
│   │   └── .env
│   ├── arr-stack/
│   │   ├── docker-compose.yml      # Sonarr, Radarr, Transmission
│   │   └── .env
│   ├── content/
│   │   ├── docker-compose.yml      # Nextcloud, Audiobookshelf
│   │   └── .env
│   └── proxy/
│       ├── docker-compose.yml      # Nginx Proxy Manager
│       └── ssl/
├── volumes/
│   ├── helios/
│   │   ├── ssd/
│   │   └── hdd/
│   └── xeon01/
│       └── ssd/
└── scripts/
    ├── setup-gpu.sh
    ├── create-volumes.sh
    └── deploy.sh
```

---

### Task 1: Configurar GPU Runtime

**Files:**
- Create: `scripts/setup-gpu.sh`
- Create: `stacks/gpu-services/jellyfin/Dockerfile.custom`

**Step 1: Create GPU setup script**

```bash
#!/bin/bash
# scripts/setup-gpu.sh

echo "Setting up NVIDIA Container Runtime..."

# Install NVIDIA Container Runtime
curl -s -L https://nvidia.github.io/nvidia-container-runtime/gpgkey | sudo apt-key add -
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-container-runtime/$distribution/nvidia-container-runtime.list | sudo tee /etc/apt/sources.list.d/nvidia-container-runtime.list

sudo apt-get update
sudo apt-get install -y nvidia-container-runtime

# Configure Docker daemon
sudo mkdir -p /etc/docker
cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "default-runtime": "nvidia",
  "runtimes": {
    "nvidia": {
      "path": "nvidia-container-runtime",
      "runtimeArgs": []
    }
  }
}
EOF

# Restart Docker
sudo systemctl restart docker
sudo systemctl status docker

echo "GPU Runtime setup complete!"
```

**Step 2: Run GPU setup script**

```bash
chmod +x scripts/setup-gpu.sh
./scripts/setup-gpu.sh
```

**Step 3: Create custom Jellyfin Dockerfile with GPU**

```dockerfile
# stacks/gpu-services/jellyfin/Dockerfile.custom
FROM jellyfin/jellyfin:latest

# Install NVIDIA GPU drivers support
RUN apt-get update && apt-get install -y \
    nvidia-driver-470 \
    nvidia-cuda-toolkit \
    && rm -rf /var/lib/apt/lists/*

# Add GPU detection script
COPY jellyfin/gpu-setup.sh /usr/local/bin/gpu-setup.sh
RUN chmod +x /usr/local/bin/gpu-setup.sh

ENTRYPOINT ["/usr/local/bin/gpu-setup.sh", "/jellyfin/jellyfin"]
```

**Step 4: Create GPU setup script for Jellyfin**

```bash
#!/bin/bash
# stacks/gpu-services/jellyfin/gpu-setup.sh

# Check for NVIDIA GPU
if command -v nvidia-smi &> /dev/null; then
    echo "NVIDIA GPU detected, configuring hardware acceleration..."
    export JELLYFIN_GID=$(getent group video | cut -d: -f3)
    export NVIDIA_VISIBLE_DEVICES=all
    export NVIDIA_DRIVER_CAPABILITIES=compute,video,utility,graphics
else
    echo "No NVIDIA GPU detected, using software rendering..."
fi

exec "$@"
```

**Step 5: Commit**

```bash
git add scripts/setup-gpu.sh stacks/gpu-services/
git commit -m "feat: add GPU runtime setup and Jellyfin GPU support"
```

---

### Task 2: Criar Estrutura de Volumes

**Files:**
- Create: `scripts/create-volumes.sh`
- Create: `stacks/infrastructure/docker-compose.yml`

**Step 1: Create volume creation script**

```bash
#!/bin/bash
# scripts/create-volumes.sh

echo "Creating persistent volume structure..."

# Helios volumes
sudo mkdir -p /mnt/helios-ssd/docker/{jellyfin,sonarr,radarr,transmission,nginx-proxy}
sudo mkdir -p /mnt/helios-hdd/media/{movies,series,anime,incomplete}

# Xeon01 volumes
sudo mkdir -p /mnt/xeon01-ssd/docker/{nextcloud,audiobookshelf,postgresql}
sudo mkdir -p /mnt/xeon01-ssd/docker/nextcloud/data
sudo mkdir -p /mnt/xeon01-ssd/docker/audiobookshelf/{config,metadata,audiobooks}
sudo mkdir -p /mnt/xeon01-ssd/docker/postgresql/data

# Set permissions
sudo chown -R 1000:1000 /mnt/helios-ssd/docker/
sudo chown -R 1000:1000 /mnt/helios-hdd/media/
sudo chown -R 1000:1000 /mnt/xeon01-ssd/docker/

echo "Volume structure created!"
```

**Step 2: Run volume creation script**

```bash
chmod +x scripts/create-volumes.sh
./scripts/create-volumes.sh
```

**Step 3: Create infrastructure stack**

```yaml
# stacks/infrastructure/docker-compose.yml
version: '3.8'

services:
  # Base network and volume setup
  network-setup:
    image: alpine:latest
    deploy:
      mode: global
      restart_policy:
        condition: none
    command: |
      sh -c "
        echo 'Creating overlay network...'
        docker network create --driver overlay --attachable homelab-net 2>/dev/null || echo 'Network exists'
        echo 'Infrastructure setup complete'
      "

networks:
  homelab-net:
    external: true
    driver: overlay
    attachable: true

volumes:
  # Helios volumes (managed by Docker, but bound to host paths)
  jellyfin-config:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /mnt/helios-ssd/docker/jellyfin

  sonarr-config:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /mnt/helios-ssd/docker/sonarr

  radarr-config:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /mnt/helios-ssd/docker/radarr

  transmission-config:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /mnt/helios-ssd/docker/transmission

  # Xeon01 volumes
  nextcloud-data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /mnt/xeon01-ssd/docker/nextcloud

  audiobookshelf-config:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /mnt/xeon01-ssd/docker/audiobookshelf/config

  audiobooks-data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /mnt/xeon01-ssd/docker/audiobookshelf/audiobooks

  postgresql-data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /mnt/xeon01-ssd/docker/postgresql/data

  # Media volumes (shared between stacks)
  movies-data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /mnt/helios-hdd/media/movies

  series-data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /mnt/helios-hdd/media/series

  downloads-data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /mnt/helios-hdd/media/incomplete
```

**Step 4: Create environment template**

```bash
# stacks/infrastructure/.env.example
# Infrastructure stack environment variables
COMPOSE_PROJECT_NAME=infrastructure
NETWORK_NAME=homelab-net

# Volume paths (adjust as needed)
HELIOS_SSD_PATH=/mnt/helios-ssd/docker
HELIOS_HDD_PATH=/mnt/helios-hdd/media
XEON01_SSD_PATH=/mnt/xeon01-ssd/docker
```

**Step 5: Deploy infrastructure stack**

```bash
cd stacks/infrastructure
docker-compose -p infrastructure up -d
```

**Step 6: Commit**

```bash
git add scripts/create-volumes.sh stacks/infrastructure/
git commit -m "feat: create volume structure and infrastructure stack"
```

---

### Task 3: Implementar GPU Services Stack

**Files:**
- Create: `stacks/gpu-services/docker-compose.yml`
- Create: `stacks/gpu-services/.env`

**Step 1: Create GPU services compose file**

```yaml
# stacks/gpu-services/docker-compose.yml
version: '3.8'

services:
  jellyfin:
    build:
      context: ./jellyfin
      dockerfile: Dockerfile.custom
    image: jellyfin-custom:latest
    container_name: jellyfin
    hostname: jellyfin
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.labels.gpu == true
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
    environment:
      - JELLYFIN_PublishedServerUrl=https://jellyfin.homelab.local
      - TZ=America/Sao_Paulo
      - JELLYFIN_GID=44  # video group
    volumes:
      - jellyfin-config:/config
      - jellyfin-cache:/cache
      - movies-data:/media/movies
      - series-data:/media/series
      - downloads-data:/media/downloads
    networks:
      - homelab-net
    ports:
      - "8096:8096"
    restart: unless-stopped

volumes:
  jellyfin-config:
    external: true
  jellyfin-cache:
    driver: local

networks:
  homelab-net:
    external: true
```

**Step 2: Create GPU services environment**

```bash
# stacks/gpu-services/.env
COMPOSE_PROJECT_NAME=gpu-services

# Jellyfin settings
JELLYFIN_VERSION=latest
JELLYFIN_PORT=8096
JELLYFIN_GPU_ENABLED=true

# GPU settings
NVIDIA_VISIBLE_DEVICES=all
NVIDIA_DRIVER_CAPABILITIES=compute,video,utility,graphics
```

**Step 3: Deploy GPU services**

```bash
cd stacks/gpu-services
docker-compose -p gpu-services up -d
```

**Step 4: Verify GPU access in Jellyfin**

```bash
docker exec jellyfin nvidia-smi
# Or check Jellyfin dashboard for hardware acceleration
```

**Step 5: Commit**

```bash
git add stacks/gpu-services/
git commit -m "feat: implement Jellyfin with GPU acceleration"
```

---

### Task 4: Implementar ARR Stack

**Files:**
- Create: `stacks/arr-stack/docker-compose.yml`
- Create: `stacks/arr-stack/.env`

**Step 1: Create ARR stack compose file**

```yaml
# stacks/arr-stack/docker-compose.yml
version: '3.8'

services:
  sonarr:
    image: lscr.io/linuxserver/sonarr:latest
    container_name: sonarr
    hostname: sonarr
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.labels.arr == true
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Sao_Paulo
    volumes:
      - sonarr-config:/config
      - series-data:/media/series
      - downloads-data:/downloads
    networks:
      - homelab-net
    ports:
      - "8989:8989"
    restart: unless-stopped

  radarr:
    image: lscr.io/linuxserver/radarr:latest
    container_name: radarr
    hostname: radarr
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.labels.arr == true
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Sao_Paulo
    volumes:
      - radarr-config:/config
      - movies-data:/media/movies
      - downloads-data:/downloads
    networks:
      - homelab-net
    ports:
      - "7878:7878"
    restart: unless-stopped

  transmission:
    image: lscr.io/linuxserver/transmission:latest
    container_name: transmission
    hostname: transmission
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.labels.arr == true
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Sao_Paulo
      - WEBUI_PORT=9091
    volumes:
      - transmission-config:/config
      - downloads-data:/downloads
      - transmission-watch:/watch
    networks:
      - homelab-net
    ports:
      - "9091:9091"
      - "51413:51413"
      - "51413:51413/udp"
    restart: unless-stopped

volumes:
  sonarr-config:
    external: true
  radarr-config:
    external: true
  transmission-config:
    external: true
  transmission-watch:
    driver: local

networks:
  homelab-net:
    external: true
```

**Step 2: Create ARR stack environment**

```bash
# stacks/arr-stack/.env
COMPOSE_PROJECT_NAME=arr-stack

# Sonarr settings
SONARR_PORT=8989
SONARR_VERSION=latest

# Radarr settings
RADARR_PORT=7878
RADARR_VERSION=latest

# Transmission settings
TRANSMISSION_PORT=9091
TRANSMISSION_PEER_PORT=51413

# User settings
PUID=1000
PGID=1000
TZ=America/Sao_Paulo
```

**Step 3: Deploy ARR stack**

```bash
cd stacks/arr-stack
docker-compose -p arr-stack up -d
```

**Step 4: Commit**

```bash
git add stacks/arr-stack/
git commit -m "feat: implement ARR stack (Sonarr, Radarr, Transmission)"
```

---

### Task 5: Implementar Content Management Stack

**Files:**
- Create: `stacks/content/docker-compose.yml`
- Create: `stacks/content/.env`

**Step 1: Create content stack compose file**

```yaml
# stacks/content/docker-compose.yml
version: '3.8'

services:
  nextcloud:
    image: nextcloud:latest
    container_name: nextcloud
    hostname: nextcloud
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.labels.storage == true
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Sao_Paulo
      - POSTGRES_HOST=postgresql
      - POSTGRES_DB=nextcloud
      - POSTGRES_USER=nextcloud
      - POSTGRES_PASSWORD_FILE=/run/secrets/postgres_password
      - REDIS_HOST=redis
    volumes:
      - nextcloud-data:/var/www/html
    networks:
      - homelab-net
    ports:
      - "8080:80"
    secrets:
      - postgres_password
    depends_on:
      - postgresql
      - redis
    restart: unless-stopped

  audiobookshelf:
    image: ghcr.io/advplyr/audiobookshelf:latest
    container_name: audiobookshelf
    hostname: audiobookshelf
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.labels.storage == true
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Sao_Paulo
    volumes:
      - audiobookshelf-config:/config
      - audiobookshelf-metadata:/metadata
      - audiobooks-data:/audiobooks
    networks:
      - homelab-net
    ports:
      - "13378:80"
    restart: unless-stopped

  postgresql:
    image: postgres:15-alpine
    container_name: postgresql
    hostname: postgresql
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.labels.storage == true
    environment:
      - POSTGRES_USER_FILE=/run/secrets/postgres_user
      - POSTGRES_PASSWORD_FILE=/run/secrets/postgres_password
      - POSTGRES_DB_FILE=/run/secrets/postgres_db
    volumes:
      - postgresql-data:/var/lib/postgresql/data
    networks:
      - homelab-net
    secrets:
      - postgres_user
      - postgres_password
      - postgres_db
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    container_name: redis
    hostname: redis
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.labels.storage == true
    volumes:
      - redis-data:/data
    networks:
      - homelab-net
    restart: unless-stopped

secrets:
  postgres_user:
    file: ./secrets/postgres_user.txt
  postgres_password:
    file: ./secrets/postgres_password.txt
  postgres_db:
    file: ./secrets/postgres_db.txt

volumes:
  nextcloud-data:
    external: true
  audiobookshelf-config:
    external: true
  audiobookshelf-metadata:
    driver: local
  audiobooks-data:
    external: true
  postgresql-data:
    external: true
  redis-data:
    driver: local

networks:
  homelab-net:
    external: true
```

**Step 2: Create content stack environment**

```bash
# stacks/content/.env
COMPOSE_PROJECT_NAME=content

# Nextcloud settings
NEXTcloud_PORT=8080
NEXTcloud_VERSION=latest

# Audiobookshelf settings
AUDIOBOOKSHELF_PORT=13378
AUDIOBOOKSHELF_VERSION=latest

# PostgreSQL settings
POSTGRES_VERSION=15-alpine
POSTGRES_PORT=5432

# Redis settings
REDIS_VERSION=7-alpine
REDIS_PORT=6379

# User settings
PUID=1000
PGID=1000
TZ=America/Sao_Paulo
```

**Step 3: Create secrets directory and files**

```bash
mkdir -p stacks/content/secrets
echo "nextcloud" > stacks/content/secrets/postgres_user.txt
echo "your_secure_password_here" > stacks/content/secrets/postgres_password.txt
echo "nextcloud" > stacks/content/secrets/postgres_db.txt
chmod 600 stacks/content/secrets/*
```

**Step 4: Deploy content stack**

```bash
cd stacks/content
docker-compose -p content up -d
```

**Step 5: Commit**

```bash
git add stacks/content/
git commit -m "feat: implement content management stack (Nextcloud, Audiobookshelf, PostgreSQL, Redis)"
```

---

### Task 6: Implementar Proxy Stack

**Files:**
- Create: `stacks/proxy/docker-compose.yml`
- Create: `stacks/proxy/.env`
- Create: `scripts/deploy.sh`

**Step 1: Create proxy stack compose file**

```yaml
# stacks/proxy/docker-compose.yml
version: '3.8'

services:
  nginx-proxy:
    image: 'jc21/nginx-proxy-manager:latest'
    container_name: nginx-proxy
    hostname: nginx-proxy
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.labels.proxy == true
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Sao_Paulo
    volumes:
      - nginx-proxy-data:/data
      - nginx-proxy-letsencrypt:/etc/letsencrypt
    networks:
      - homelab-net
    ports:
      - '80:80'
      - '443:443'
      - '81:81'  # Admin interface
    restart: unless-stopped

volumes:
  nginx-proxy-data:
    external: true
  nginx-proxy-letsencrypt:
    driver: local

networks:
  homelab-net:
    external: true
```

**Step 2: Create proxy environment**

```bash
# stacks/proxy/.env
COMPOSE_PROJECT_NAME=proxy

# Nginx Proxy Manager settings
NGINX_PROXY_PORT=80
NGINX_PROXY_SSL_PORT=443
NGINX_PROXY_ADMIN_PORT=81

# User settings
PUID=1000
PGID=1000
TZ=America/Sao_Paulo
```

**Step 3: Create deployment script**

```bash
#!/bin/bash
# scripts/deploy.sh

set -e

echo "Deploying Homelab Stacks..."

# Setup GPU
echo "Setting up GPU runtime..."
./scripts/setup-gpu.sh

# Create volumes
echo "Creating volume structure..."
./scripts/create-volumes.sh

# Deploy stacks in order
echo "Deploying infrastructure stack..."
cd stacks/infrastructure
docker-compose -p infrastructure up -d
cd ../..

echo "Deploying proxy stack..."
cd stacks/proxy
docker-compose -p proxy up -d
cd ../..

echo "Deploying content stack..."
cd stacks/content
docker-compose -p content up -d
cd ../..

echo "Deploying GPU services stack..."
cd stacks/gpu-services
docker-compose -p gpu-services up -d
cd ../..

echo "Deploying ARR stack..."
cd stacks/arr-stack
docker-compose -p arr-stack up -d
cd ../..

echo "Deployment complete!"
echo "Access services via: http://<server-ip>:81 (Nginx Proxy Manager)"
echo "Configure SSL certificates and proxy hosts in Nginx Proxy Manager"
```

**Step 4: Make deployment script executable**

```bash
chmod +x scripts/deploy.sh
```

**Step 5: Deploy proxy stack**

```bash
cd stacks/proxy
docker-compose -p proxy up -d
```

**Step 6: Commit**

```bash
git add stacks/proxy/ scripts/deploy.sh
git commit -m "feat: implement Nginx Proxy Manager stack and deployment script"
```

---

### Task 7: Configure Node Labels and Final Setup

**Files:**
- Create: `scripts/setup-nodes.sh`
- Modify: `README.md`

**Step 1: Create node labeling script**

```bash
#!/bin/bash
# scripts/setup-nodes.sh

echo "Setting up Docker Swarm node labels..."

# On Helios (manager)
docker node update --label-add gpu=true helios
docker node update --label-add arr=true helios
docker node update --label-add proxy=true helios

# On Xeon01 (worker)
docker node update --label-add storage=true xeon01
docker node update --label-add database=true xeon01

# Verify labels
echo "Node labels:"
docker node ls --format "{{.Hostname}}: {{.Spec.Labels}}"

echo "Node labeling complete!"
```

**Step 2: Run node labeling**

```bash
chmod +x scripts/setup-nodes.sh
./scripts/setup-nodes.sh
```

**Step 3: Update README with deployment instructions**

```markdown
# Homelab Docker Stacks

Deploy complete homelab infrastructure with separated Docker stacks.

## Quick Start

```bash
# Clone repository
git clone <repo-url>
cd homelab

# Run full deployment
./scripts/deploy.sh

# Or deploy individual stacks
cd stacks/infrastructure && docker-compose up -d
```

## Stack Structure

- `infrastructure/` - Base networks and volumes
- `gpu-services/` - Jellyfin with GPU acceleration
- `arr-stack/` - Sonarr, Radarr, Transmission
- `content/` - Nextcloud, Audiobookshelf, PostgreSQL
- `proxy/` - Nginx Proxy Manager for HTTPS

## Access Services

- Nginx Proxy Manager: http://<server-ip>:81
- Configure proxy hosts for each service
- Services will be available via HTTPS with certificates

## GPU Acceleration

Jellyfin automatically uses NVIDIA GPU for transcoding when available.
```

**Step 4: Commit**

```bash
git add scripts/setup-nodes.sh README.md
git commit -m "feat: add node labeling and deployment documentation"
```

---

## Final Deployment

**Step 1: Run complete deployment**

```bash
./scripts/deploy.sh
```

**Step 2: Verify all services running**

```bash
docker service ls
docker node ps
```

**Step 3: Configure Nginx Proxy Manager**

1. Access http://<helios-ip>:81
2. Login with default credentials
3. Configure SSL certificates
4. Set up proxy hosts for each service:
   - jellyfin.homelab.local → jellyfin:8096
   - sonarr.homelab.local → sonarr:8989
   - radarr.homelab.local → radarr:7878
   - transmission.homelab.local → transmission:9091
   - nextcloud.homelab.local → nextcloud:8080
   - audiobooks.homelab.local → audiobookshelf:80

**Step 4: Final verification**

```bash
# Test GPU access in Jellyfin
docker exec jellyfin nvidia-smi

# Check service health
curl -f http://localhost:8096/health || echo "Jellyfin not ready"
curl -f http://localhost:8989 || echo "Sonarr not ready"
```

---

## Expected Outcome

Complete homelab setup with:
- ✅ GPU-accelerated Jellyfin transcoding
- ✅ Separated Docker stacks for easy management
- ✅ Persistent volumes distributed across servers
- ✅ Automated media management with ARR stack
- ✅ Secure HTTPS access via Nginx Proxy Manager
- ✅ Content management with Nextcloud and Audiobookshelf