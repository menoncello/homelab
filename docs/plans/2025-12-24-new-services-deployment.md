# New Services Deployment Guide

**Date:** 2025-12-24
**Services:** Homarr, n8n, Lidarr, PostgreSQL, Redis

## Overview

Adding 5 new services to the homelab:
- **Homarr** - Dashboard for all services (Helios)
- **Lidarr** - Music manager (Helios)
- **n8n** - Workflow automation (Xeon01)
- **PostgreSQL** - Database server (Xeon01)
- **Redis** - Cache/queue (Xeon01)

## Prerequisites

- Docker Swarm initialized
- Node labels configured (`arr`, `storage`, `database`)
- SSH access to both servers

## Deployment Steps

### Step 1: Create Volumes (Both Servers)

```bash
# On Helios (192.168.31.5)
ssh eduardo@192.168.31.5
cd ~/homelab
./scripts/setup-new-services-volumes.sh

# On Xeon01 (192.168.31.6)
ssh eduardo@192.168.31.6
cd ~/homelab
./scripts/setup-new-services-volumes.sh
```

### Step 2: Configure Database Secrets

```bash
# On manager (Helios)
cd ~/homelab/stacks/database-stack/secrets

# Create secrets from examples
cp postgres_password.txt.example postgres_password.txt
cp redis_password.txt.example redis_password.txt

# Edit with secure passwords
nano postgres_password.txt
nano redis_password.txt
```

### Step 3: Configure n8n Secrets

```bash
# On manager (Helios)
cd ~/homelab/stacks/n8n-stack/secrets

# Create secrets from examples
cp n8n_db_password.txt.example n8n_db_password.txt
cp n8n_encryption_key.txt.example n8n_encryption_key.txt

# Set database password (use a secure password)
echo "your_secure_n8n_password" > n8n_db_password.txt

# Generate encryption key
openssl rand -hex 32 > n8n_encryption_key.txt
```

### Step 4: Deploy All Services

```bash
# On manager (Helios)
cd ~/homelab
./scripts/deploy-new-services.sh
```

The script will:
1. Deploy database-stack (PostgreSQL + Redis)
2. Create n8n database
3. Deploy n8n-stack
4. Deploy lidarr-stack
5. Deploy homarr-stack

### Step 5: Verify Deployment

```bash
# Check all stacks
docker stack ls

# Check services
docker service ls

# Check individual service health
docker service ps database_postgresql
docker service ps n8n_n8n
docker service ps lidarr_lidarr
docker service ps homarr_homarr
```

## Access URLs

| Service | URL | Location |
|---------|-----|----------|
| Homarr | http://192.168.31.5:7575 | Dashboard |
| n8n | http://192.168.31.6:5678 | Workflow automation |
| Lidarr | http://192.168.31.5:8686 | Music manager |
| PostgreSQL | 192.168.31.6:5432 | Database |
| Redis | 192.168.31.6:6379 | Cache |

## Post-Deployment Configuration

### Homarr

1. Open http://192.168.31.5:7575
2. Create admin account
3. Add services to dashboard:
   - Jellyfin: http://192.168.31.5:8096
   - Sonarr: http://192.168.31.5:8989
   - Radarr: http://192.168.31.5:7878
   - Lidarr: http://192.168.31.5:8686
   - n8n: http://192.168.31.6:5678
   - Nextcloud: http://192.168.31.6:8080
   - Audiobookshelf: http://192.168.31.6:13378

### Lidarr

1. Open http://192.168.31.5:8686
2. Set up download client (Transmission)
3. Set up indexer (Jackett)
4. Configure music quality profiles
5. Add root folder: `/music`

### n8n

1. Open http://192.168.31.6:5678
2. Create admin account
3. Configure credentials for services
4. Create example workflows

## Troubleshooting

### Services not starting

```bash
# Check service logs
docker service logs -f <stack>_<service>

# Check service status with details
docker service ps <stack>_<service> --no-trunc
```

### Database connection issues

```bash
# Check PostgreSQL is running
docker service ps database_postgresql

# Test connection
docker exec -it $(docker ps -q -f name=database_postgresql) psql -U postgres
```

### Volume permission issues

```bash
# On Helios
sudo chown -R 1000:1000 /data/docker/

# On Xeon01
sudo chown -R 1000:1000 /srv/docker/
sudo chown -R 1000:1000 /home/docker-data/
```

## Stack Architecture

```
stacks/
├── database-stack/      # NEW
│   ├── docker-compose.yml
│   └── secrets/
├── n8n-stack/           # NEW
│   ├── docker-compose.yml
│   └── secrets/
├── lidarr-stack/        # NEW
│   └── docker-compose.yml
├── homarr-stack/        # NEW
│   └── docker-compose.yml
├── infrastructure/      # Existing
├── gpu-services/        # Existing
├── arr-stack/           # Existing
├── content/             # Existing
├── proxy/               # Existing
└── pihole/              # Existing
```

## Resource Allocation

| Service | Node | Memory |
|---------|------|--------|
| PostgreSQL | Xeon01 | 4GB |
| Redis | Xeon01 | 1GB |
| n8n | Xeon01 | 8GB |
| Lidarr | Helios | 4GB |
| Homarr | Helios | 2GB |
