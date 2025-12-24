# Database Stack

PostgreSQL and Redis for all homelab services.

## Services

| Service | Port | Purpose |
|---------|------|---------|
| PostgreSQL | 5432 | Relational database |
| Redis | 6379 | Cache and queue |

## First Time Setup

```bash
# 1. Create secrets from examples
cd stacks/database-stack/secrets
cp postgres_user.txt.example postgres_user.txt
cp postgres_password.txt.example postgres_password.txt
cp postgres_db.txt.example postgres_db.txt
cp redis_password.txt.example redis_password.txt

# 2. Edit secrets with secure passwords
nano postgres_password.txt
nano redis_password.txt

# 3. Deploy stack
cd ..
docker stack deploy -c docker-compose.yml database
```

## Creating Databases

```bash
# Connect to PostgreSQL
docker exec -it $(docker ps -q -f name=database_postgresql) psql -U postgres

# Create database and user
CREATE DATABASE n8n;
CREATE USER n8n WITH ENCRYPTED PASSWORD 'your_password';
GRANT ALL PRIVILEGES ON DATABASE n8n TO n8n;

# List databases
\l

# Exit
\q
```

## Volumes

- `postgresql-data` - Database data (Xeon01: /srv/docker/postgresql)
- `redis-data` - Redis persistence (Xeon01: /srv/docker/redis)
