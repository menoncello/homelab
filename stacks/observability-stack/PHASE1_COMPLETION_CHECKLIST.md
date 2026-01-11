# Phase 1 Completion Checklist - When Xeon01 Comes Online

**Purpose:** Quick reference for completing Phase 1 of the observability implementation once Xeon01 (192.168.31.6) is back online.

---

## Pre-Flight Checks (Before Bringing Services Online)

### 1. Verify Node Status
```bash
# Expected: Xeon01 status = Ready, Availability = Active
```

### 2. Verify Node Labels
```bash
docker node inspect xeon01 --format '{{.Spec.Labels}}'
# Expected: map[database:true storage:true]
```

If labels missing:
```bash
docker node update --label-add database=true xeon01
docker node update --label-add storage=true xeon01
```

### 3. Verify Volume Directories
```bash
# On Xeon01 (via SSH)
ssh eduardo@192.168.31.6
ls -la /srv/docker/observability/
# Expected: victoria/ directory exists

# If missing, create it:
sudo mkdir -p /srv/docker/observability/victoria
sudo chown -R 1000:1000 /srv/docker/observability/victoria
```

### 4. Verify Disk Space
```bash
# On Xeon01
df -h /srv/docker/
# Expected: >100GB available
```

### 5. Verify Network Connectivity
```bash
# From pop-os manager
ping -c 3 192.168.31.6
# Expected: Responsive

# Test Docker Swarm communication
docker node inspect xeon01
# Expected: Node details returned
```

---

## Step 1: Monitor VictoriaMetrics Startup

VictoriaMetrics should start automatically once Xeon01 is online. Watch it come up:

```bash
# Watch service status
docker service ps observability_victoria-metrics --no-trunc
# Status should transition from: Pending → Starting → Running

# Watch logs
docker service logs -f observability_victoria-metrics
# Look for: "started VictoriaMetrics"
# Look for: "loaded Prometheus config"
# Look for: "started scraping targets"
```

**Expected timeline:**
- 0-30s: Task scheduling
- 30-60s: Container pulling (if first time)
- 60-90s: Service startup
- 90-120s: Targets discovered and scraping begins

---

## Step 2: Verify VictoriaMetrics Health

Once the service shows "Running", run these checks:

```bash
# Get container ID
VM_TASK=$(docker ps -q -f name=observability_victoria-metrics | head -1)

# 1. Health check
docker exec $VM_TASK wget -qO- http://localhost:8428/health
# Expected: OK

# 2. Check targets discovery
docker exec $VM_TASK wget -qO- http://localhost:8428/api/v1/targets | jq .
# Expected: JSON with activeTargets array

# 3. Verify targets are healthy
docker exec $VM_TASK wget -qO- http://localhost:8428/api/v1/targets | \
  jq '.data.activeTargets[] | {job: .labels.job, instance: .labels.instance, health: .health}'
# Expected: All targets show health="up"

# 4. Query metrics
docker exec $VM_TASK wget -qO- "http://localhost:8428/api/v1/query?query=up" | jq .
# Expected: Metrics returned

# 5. Check specific metric
docker exec $VM_TASK wget -qO- "http://localhost:8428/api/v1/query?query=node_cpu_seconds_total" | jq .
# Expected: CPU metrics from node-exporter
```

**Expected targets:**
- `node-exporter` on `pop-os`
- `cadvisor` on `pop-os`
- `victoriametrics` (self-monitoring)
- `node-exporter` on `xeon01` (when agent starts)
- `cadvisor` on `xeon01` (when agent starts)

---

## Step 3: Deploy Grafana

After VictoriaMetrics is verified working:

```bash
cd ~/homelab/stacks/observability-stack

# Run deployment script
./deploy-grafana.sh
```

**What the script does:**
1. Checks if grafana_admin_password secret exists
2. Creates secret from secrets/secrets.yml if needed
3. Creates volume directory on manager node
4. Deploys the stack with Grafana service
5. Shows service status and logs

**Manual deployment** (if script fails):
```bash
# 1. Create secret
GRAFANA_PASSWORD=$(grep grafana_admin_password secrets/secrets.yml | awk '{print $2}')
echo "$GRAFANA_PASSWORD" | docker secret create grafana_admin_password -

# 2. Create volume (on manager/pop-os)
ssh eduardo@192.168.31.5 "mkdir -p /data/docker/observability/grafana && sudo chown -R 1000:1000 /data/docker/observability/grafana"

# 3. Deploy stack
docker stack deploy -c monitoring.yml observability
```

---

## Step 4: Verify Grafana Health

After Grafana deploys:

```bash
# Watch service status
docker service ps observability_grafana --no-trunc
# Status should show: Running

# Get container ID
GRAFANA_TASK=$(docker ps -q -f name=observability_grafana | head -1)

# 1. Health check
docker exec $GRAFANA_TASK wget -qO- http://localhost:3000/api/health
# Expected: {"commit":"...","database":"ok","version":"11.3.1"}

# 2. Verify datasource
docker exec $GRAFANA_TASK wget -qO- http://localhost:3000/api/datasources | jq .
# Expected: VictoriaMetrics datasource with id=1

# 3. Verify dashboards
docker exec $GRAFANA_TASK wget -qO- http://localhost:3000/api/search | jq .
# Expected: 3 dashboards (Docker Swarm Monitoring, Node Exporter Full, Docker Containers)

# 4. Check logs for errors
docker service logs observability_grafana --tail 50
# Look for: "HTTP Server Listen"
# Look for: " provisioning"
# Look for: "Completed loading"
```

---

## Step 5: Access Grafana UI

```bash
# Determine which node is running Grafana
docker service ps observability_grafana --no-trunc | grep Running
# Note the NODE column

# Access URL (use the node IP from above)
# Default: http://192.168.31.5:3000 or http://192.168.31.6:3000

# Login credentials:
# Username: admin
# Password: <from secrets/secrets.yml>
```

**In Grafana UI:**
1. Navigate to: Configuration → Data Sources
2. Verify "VictoriaMetrics" datasource is listed
3. Click "VictoriaMetrics" and verify it shows "OK" status
4. Navigate to: Dashboards → Browse
5. Open each dashboard and verify data is visible:
   - **Node Exporter Full** - Should show CPU, memory, disk, network graphs
   - **Docker Containers** - Should show per-container metrics
   - **Docker Swarm Monitoring** - Should show service health

---

## Step 6: Run Full Verification

```bash
cd ~/homelab/stacks/observability-stack
./verify-metrics-pipeline.sh
```

**Expected result:** All checks should pass (except possibly Xeon01 agents if they haven't started yet)

---

## Step 7: Verify End-to-End Metrics Flow

### 7.1 Test Metrics Collection

```bash
# From VictoriaMetrics
curl -s "http://192.168.31.6:8428/api/v1/query?query=up" | jq '.data.result[] | {metric: .metric, value: .value[1]}'
# Expected: up=1 for all targets
```

### 7.2 Test Grafana Query

```bash
# Query VictoriaMetrics through Grafana
GRAFANA_NODE=$(docker service ps observability_grafana --no-trunc | grep Running | awk '{print $4}')
curl -s "http://$GRAFANA_NODE:3000/api/datasources/proxy/1/api/v1/query?query=up" \
  -u admin:<password> | jq .
# Expected: Metrics returned
```

### 7.3 Test Dashboard Data

In Grafana UI:
1. Open "Node Exporter Full" dashboard
2. Set time range to "Last 5 minutes"
3. Verify graphs are updating
4. Check for data points (not blank graphs)

---

## Step 8: Configure Nginx Proxy Manager (Optional)

For external access via https://grafana.homelab:

1. **Access Nginx Proxy Manager:**
   ```
   URL: http://192.168.31.5:81
   Login: admin@example.com / <initial password>
   ```

2. **Add Proxy Host:**
   - Domain Names: `grafana.homelab`
   - Forward Hostname/IP: `192.168.31.6` (or node running Grafana)
   - Forward Port: `3000`
   - Cache Assets: Disable (for Grafana)
   - Block Common Exploits: Enable
   - Websockets Support: Enable

3. **Add SSL Certificate:**
   - Tab: SSL
   - SSL Certificate: Request a new SSL Certificate
   - Domain Names: `grafana.homelab`
   - Email: your-email@example.com
   - I Agree to Terms: Check
   - Save

4. **Test Access:**
   ```
   https://grafana.homelab
   Should show Grafana login page with valid SSL
   ```

---

## Step 9: Verify Xeon01 Agents (When Node is Fully Online)

After Xeon01 is online and stable:

```bash
# Check that agents are running on Xeon01
docker service ps observability_node-exporter
docker service ps observability_cadvisor
# Both should show tasks on Xeon01

# Test endpoints on Xeon01
curl -s http://192.168.31.6:9100/metrics | head -20
curl -s http://192.168.31.6:8080/metrics | head -20

# Verify VictoriaMetrics discovered them
curl -s http://192.168.31.6:8428/api/v1/targets | \
  jq '.data.activeTargets[] | select(.labels.instance == "xeon01") | {job: .labels.job, health: .health}'
# Expected: Both node-exporter and cadvisor show health="up"
```

---

## Troubleshooting

### VictoriaMetrics Won't Start

**Symptom:** Service stays in "Pending" state

**Check:**
```bash
# 1. Verify node is available
docker node ls

# 2. Check node labels
docker node inspect xeon01 --format '{{.Spec.Labels}}'

# 3. Verify volume exists
ssh eduardo@192.168.31.6 "ls -la /srv/docker/observability/victoria"

# 4. Check service logs (even if not running)
docker service logs observability_victoria-metrics --tail 50
```

**Fix:**
```bash
# If volume missing, create it
ssh eduardo@192.168.31.6 "sudo mkdir -p /srv/docker/observability/victoria && sudo chown -R 1000:1000 /srv/docker/observability/victoria"

# If labels missing, add them
docker node update --label-add database=true xeon01

# Force update service
docker service update --force observability_victoria-metrics
```

---

### Grafana Won't Start

**Symptom:** Service fails or restarts repeatedly

**Check:**
```bash
# 1. Check service status
docker service ps observability_grafana --no-trunc

# 2. View logs
docker service logs observability_grafana --tail 100

# 3. Check for common errors:
#    - "permission denied" → volume permissions
#    - "secret not found" → missing secret
#    - "datasource not found" → VM not reachable
```

**Fix:**
```bash
# If permission error
ssh eduardo@192.168.31.5 "sudo chown -R 1000:1000 /data/docker/observability/grafana"
# Or on Xeon01 if running there
ssh eduardo@192.168.31.6 "sudo chown -R 1000:1000 /srv/docker/observability/grafana"

# If secret missing
GRAFANA_PASSWORD=$(grep grafana_admin_password secrets/secrets.yml | awk '{print $2}')
echo "$GRAFANA_PASSWORD" | docker secret create grafana_admin_password -

# Force update
docker service update --force observability_grafana
```

---

### Targets Not Discovered

**Symptom:** VictoriaMetrics shows no targets or targets are "down"

**Check:**
```bash
# 1. Verify agents are running
docker service ls | grep observability

# 2. Check agent endpoints are accessible
curl -s http://192.168.31.5:9100/metrics | head -5
curl -s http://192.168.31.5:8080/metrics | head -5

# 3. Check agent labels
docker service inspect observability_node-exporter --format '{{.Spec.Labels}}'
# Should show: prometheus.io.scrape=true

# 4. Check VM can reach agents
VM_TASK=$(docker ps -q -f name=observability_victoria-metrics | head -1)
docker exec $VM_TASK wget -qO- http://observability_node-exporter:9100/metrics | head -5
```

**Fix:**
```bash
# If labels missing, redeploy agents with correct labels
# Check agents.yml file and redeploy

# If VM can't reach agents, check network
docker network inspect homelab-net

# Verify all services on same network
docker service inspect observability_victoria-metrics --format '{{.Spec.TaskTemplate.Networks}}'
docker service inspect observability_node-exporter --format '{{.Spec.TaskTemplate.Networks}}'
```

---

### Dashboards Not Loading

**Symptom:** Grafana shows no dashboards

**Check:**
```bash
# 1. Verify dashboard files exist
ls -la config/grafana/dashboards/files/

# 2. Verify mount in container
GRAFANA_TASK=$(docker ps -q -f name=observability_grafana | head -1)
docker exec $GRAFANA_TASK ls -la /var/lib/grafana/dashboards/

# 3. Check provisioning logs
docker service logs observability_grafana | grep -i "provision"
```

**Fix:**
```bash
# If dashboards not mounted, check monitoring.yml volume paths
# Should be: ./config/grafana/dashboards/files:/var/lib/grafana/dashboards:ro

# Redeploy Grafana
docker service update --force observability_grafana
```

---

## Phase 1 Acceptance Criteria

Once all steps complete, verify:

- [ ] Xeon01 is online and labeled correctly
- [ ] VictoriaMetrics is running and healthy
- [ ] VictoriaMetrics discovered all agent targets
- [ ] Targets show health="up" in VM API
- [ ] Metrics are being ingested (query returns data)
- [ ] Grafana is running and healthy
- [ ] Grafana datasource is configured and working
- [ ] Grafana dashboards are loaded (3 dashboards)
- [ ] Dashboard graphs show real data
- [ ] Both nodes have agents running and emitting metrics
- [ ] No errors in service logs
- [ ] Verification script passes all checks

---

## Next Steps After Phase 1

Once Phase 1 is complete:

1. **Phase 2:** Deploy Loki + Promtail for log aggregation
2. **Phase 3:** Configure Alertmanager for alerts
3. **Phase 4:** Add custom dashboards for homelab services
4. **Phase 5:** Deploy Tempo for distributed tracing (optional)

---

**Created:** 2025-01-09
**Purpose:** Phase 1 completion guide for when Xeon01 is back online
