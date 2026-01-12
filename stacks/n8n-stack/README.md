# n8n Stack

n8n is a workflow automation tool that helps you connect different apps and services.

## Access

- **URL:** http://192.168.31.6:5678
- **Default:** Create admin account on first launch

## First Time Setup

### 1. Create n8n database in PostgreSQL

```bash
# After database-stack is deployed, create n8n database
docker exec -it $(docker ps -q -f name=database_postgresql) psql -U postgres -c "
CREATE DATABASE n8n;
CREATE USER n8n WITH ENCRYPTED PASSWORD 'your_secure_password';
GRANT ALL PRIVILEGES ON DATABASE n8n TO n8n;
"

# Verify
docker exec -it $(docker ps -q -f name=database_postgresql) psql -U postgres -c "\l"
```

### 2. Create secrets

```bash
# 1. Create secrets from examples
cd stacks/n8n-stack/secrets
cp n8n_db_password.txt.example n8n_db_password.txt
cp n8n_encryption_key.txt.example n8n_encryption_key.txt

# 2. Set database password (must match what you set in PostgreSQL)
nano n8n_db_password.txt

# 3. Generate encryption key (32 random characters)
openssl rand -hex 32 > n8n_encryption_key.txt
```

### 3. Create volume directories (on Xeon01)

```bash
ssh eduardo@192.168.31.6
sudo mkdir -p /srv/docker/n8n
sudo chown -R 1000:1000 /srv/docker/n8n
```

### 4. Deploy stack (from manager)

```bash
cd ~/homelab/stacks/n8n-stack
docker stack deploy -c media.docker-compose.yml n8n

# Verify
docker service ls | grep n8n
docker service logs -f n8n_n8n
```

## Configuration

After first launch:

1. **Create admin account**
2. **Settings → Credentials** - Add API keys for services you want to automate
3. **Settings → Workflow** - Configure execution settings

## Example Workflows

### Sync Sonarr → Jellyfin
1. Webhook trigger from Sonarr
2. Call Jellyfin API to refresh library

### Backup Automation
1. Schedule trigger (daily)
2. PostgreSQL backup
3. Upload to backup location

### Notifications
1. Webhook trigger
2. Send notification via Discord/Telegram/Email

## Tips

- Use credentials store for sensitive data
- Enable webhook mode for external triggers
- Configure SMTP for email notifications
- Set up execution history for debugging
