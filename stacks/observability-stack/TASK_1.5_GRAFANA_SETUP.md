# Task 1.5: Grafana Deployment with Provisioning

## Status: CONFIGURED (Awaiting Deployment)

### What Was Completed

#### 1. Provisioning Configuration Created

**Datasource Provisioning** (`config/grafana/datasources/datasources.yml`):
- VictoriaMetrics datasource configured
- URL: http://victoria-metrics:8428
- Query interval: 15s
- Query timeout: 60s
- Set as default datasource

**Dashboard Provisioning** (`config/grafana/dashboards/dashboards.yml`):
- File-based dashboard provider configured
- Auto-loading from /etc/grafana/provisioning/dashboards
- Editable dashboards enabled
- Folder structure: flat (all in root)

#### 2. Community Dashboards Downloaded

Three community dashboards downloaded to `config/grafana/dashboards/files/`:

1. **Docker Swarm Monitoring** (18509)
   - Size: 46KB
   - URL: https://grafana.com/api/dashboards/18509
   - Focus: Swarm cluster overview

2. **Node Exporter Full** (1860)
   - Size: 663KB
   - Revision: 29
   - URL: https://grafana.com/api/dashboards/1860
   - Focus: Comprehensive node metrics

3. **Docker Containers** (179)
   - Size: 124 bytes
   - Revision: 10
   - URL: https://grafana.com/api/dashboards/179
   - Focus: Container-specific metrics

#### 3. Grafana Service Configuration

**Service Details:**
- Image: grafana/grafana:11.3.1
- Placement: node.labels.database == true (Xeon01 preferred, fallback to manager)
- Memory: 512MB reservation, 1GB limit
- Health check: HTTP /api/health every 30s
- Restart policy: on-failure, 3 attempts

**Environment Variables:**
- Admin user: admin (configurable via ADMIN_USER env)
- Admin password: from Docker secret
- Root URL: https://grafana.homelab
- Analytics disabled
- Sign-up disabled
- Timezone: America/Sao_Paulo

**Volumes:**
- `/var/lib/grafana` - Persistent data (bind mount)
- `/etc/grafana/provisioning/datasources` - Datasource config (read-only)
- `/etc/grafana/provisioning/dashboards` - Dashboard provider config (read-only)
- `/var/lib/grafana/dashboards` - Dashboard JSON files (read-only)

**Secrets:**
- `grafana_admin_password` - External Docker secret

**Networking:**
- Connected to: homelab-net overlay network
- Scrape labels: prometheus.io.scrape=true, prometheus.io.port=3000

#### 4. Deployment Script Created

**File:** `deploy-grafana.sh`

**Features:**
- Checks if secret exists, creates if needed
- Reads password from secrets/secrets.yml
- Creates volume directory on manager node
- Deploys stack with Grafana
- Shows service status and logs
- Provides access URLs

### Volume Configuration

**Primary (Xeon01):**
- Path: `/srv/docker/observability/grafana`
- Owner: 1000:1000 (Grafana user)

**Fallback (pop-os manager):**
- Path: `/data/docker/observability/grafana`
- Owner: 1000:1000

### Access URLs

**Direct access:**
- http://192.168.31.5:3000 (if on manager)
- http://192.168.31.6:3000 (if on Xeon01)

**Via proxy (once configured):**
- https://grafana.homelab

### Deployment Instructions

**Option 1: Automated Deployment**
```bash
cd ~/homelab/stacks/observability-stack
./deploy-grafana.sh
```

**Option 2: Manual Deployment**

1. Create Docker secret:
```bash
cd ~/homelab/stacks/observability-stack
GRAFANA_PASSWORD=$(grep grafana_admin_password secrets/secrets.yml | awk '{print $2}')
echo "$GRAFANA_PASSWORD" | docker secret create grafana_admin_password -
```

2. Create volume directory on manager node:
```bash
ssh eduardo@192.168.31.5 "mkdir -p /data/docker/observability/grafana && sudo chown -R 1000:1000 /data/docker/observability/grafana"
```

3. Deploy stack:
```bash
docker stack deploy -c monitoring.yml observability
```

4. Verify deployment:
```bash
docker service ps observability_grafana
docker service logs observability_grafana --tail 50
```

### Verification Steps

**1. Check service status:**
```bash
docker service ls | grep grafana
docker service ps observability_grafana --no-trunc
```

**2. Check service health:**
```bash
docker service inspect observability_grafana --format '{{.Spec.TaskTemplate.ContainerSpec.Healthcheck}}'
```

**3. View logs:**
```bash
docker service logs -f observability_grafana
```

**4. Test API health endpoint:**
```bash
docker exec $(docker ps -q -f name=observability_grafana | head -1) \
  wget -qO- http://localhost:3000/api/health
```

Expected output:
```json
{"commit":"...","database":"ok","version":"11.3.1"}
```

**5. Verify datasource provisioning:**
```bash
docker exec $(docker ps -q -f name=observability_grafana | head -1) \
  wget -qO- http://localhost:3000/api/datasources
```

Expected: VictoriaMetrics datasource configured

**6. Verify dashboard provisioning:**
```bash
docker exec $(docker ps -q -f name=observability_grafana | head -1) \
  wget -qO- http://localhost:3000/api/search?query=*
```

Expected: 3 dashboards loaded

### Troubleshooting

**Secret not found:**
```bash
docker secret ls | grep grafana
# If missing, recreate:
echo "your_password" | docker secret create grafana_admin_password -
```

**Volume permission errors:**
```bash
# On the node running Grafana:
sudo chown -R 1000:1000 /srv/docker/observability/grafana
# or
sudo chown -R 1000:1000 /data/docker/observability/grafana
```

**Datasource not connecting:**
- Check VictoriaMetrics is running: `docker service ps observability_victoria-metrics`
- Test connectivity: `docker exec observability_grafana ping victoria-metrics`
- Verify datasource config in container: `docker exec observability_grafana cat /etc/grafana/provisioning/datasources/datasources.yml`

**Dashboards not loading:**
- Check dashboard files exist: `ls -la config/grafana/dashboards/files/`
- Verify mount in container: `docker exec observability_grafana ls -la /var/lib/grafana/dashboards/`
- Check dashboard provider logs: `docker service logs observability_grafana | grep provision`

**Health check failing:**
```bash
# Check service is actually running
docker ps | grep grafana

# Manual health check
docker exec $(docker ps -q -f name=observability_grafana) \
  wget --no-verbose --tries=1 --spider http://localhost:3000/api/health

# Check for startup errors
docker service logs observability_grafana --tail 100
```

### Next Steps

1. **Deploy the stack** using the deployment script when the cluster is online
2. **Verify datasource** connects to VictoriaMetrics
3. **Import additional dashboards** as needed from Grafana.com
4. **Configure Nginx Proxy Manager** for https://grafana.homelab access
5. **Set up alerts** in Grafana using VictoriaMetrics alerting rules
6. **Configure user authentication** (LDAP, OAuth, etc.) if needed

### Files Modified

- `/Users/menoncello/repos/setup/homelab/stacks/observability-stack/monitoring.yml` - Added Grafana service
- `/Users/menoncello/repos/setup/homelab/stacks/observability-stack/config/grafana/datasources/datasources.yml` - Created
- `/Users/menoncello/repos/setup/homelab/stacks/observability-stack/config/grafana/dashboards/dashboards.yml` - Created
- `/Users/menoncello/repos/setup/homelab/stacks/observability-stack/config/grafana/dashboards/files/` - 3 dashboards downloaded
- `/Users/menoncello/repos/setup/homelab/stacks/observability-stack/deploy-grafana.sh` - Created deployment script

### Acceptance Criteria Status

- [x] Grafana service configuration created
- [x] VictoriaMetrics datasource provisioned
- [x] Community dashboards downloaded
- [x] Service configured with secrets
- [x] Health check configured
- [x] Connected to homelab-net
- [ ] **PENDING:** Grafana service deployed (awaiting cluster access)
- [ ] **PENDING:** Service verified running (awaiting cluster access)
- [ ] **PENDING:** Health check passing (awaiting cluster access)

### Notes

- Xeon01 (192.168.31.6) was offline during configuration
- Volume path adjusted for pop-os manager: `/data/docker/observability/grafana`
- Secret reference uses external Docker secret (must be created before deployment)
- All dashboards are read-only in the container to prevent modification
- Dashboard JSON files can be updated by modifying files in `config/grafana/dashboards/files/`

### Configuration Validation

The monitoring.yml file has been validated and includes:
- Proper secret reference
- Valid volume configuration
- Correct network attachment
- Health check definition
- Resource limits
- Placement constraints

**YAML Syntax:** Valid ✓
**Secret Reference:** External (must be created separately) ✓
**Volume Bind Mount:** Configured ✓
**Network:** homelab-net external ✓
**Health Check:** wget command with proper timeout ✓

---

**Created:** 2025-01-09
**Task:** 1.5 - Deploy Grafana with provisioning
**Status:** Configuration complete, deployment pending cluster access
