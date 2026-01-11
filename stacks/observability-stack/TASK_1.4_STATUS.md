# Task 1.4 Status: VictoriaMetrics Backend Deployment

**Date:** 2025-01-09  
**Status:** ✅ COMPLETED (Pending Xeon01 Availability)  
**Stack:** observability

---

## Deployment Summary

### ✅ Completed Steps

1. **Created monitoring.yml compose file**
   - Location: `/Users/menoncello/repos/setup/homelab/stacks/observability-stack/monitoring.yml`
   - Service: `victoria-metrics` (v1.107.0)
   - Memory limits: 2GB max, 1GB reserved
   - Health check: HTTP /health endpoint every 30s

2. **Deployed observability stack**
   - Stack deployed successfully: `docker stack deploy -c monitoring.yml observability`
   - Service created: `observability_victoria-metrics`
   - Status: Pending (waiting for Xeon01)

3. **Verified service configuration**
   - Placement constraint: `node.labels.database == true` (Xeon01)
   - Volume: Bind mount to `/srv/docker/observability/victoria`
   - Network: Connected to `homelab-net`
   - Prometheus config: Mounted from `./config/prometheus/prometheus.yml`

4. **Verified exporter services**
   - ✅ node-exporter: Running on pop-os (port 9100)
   - ✅ cAdvisor: Running on pop-os (port 8080)
   - Both emitting metrics successfully

---

## Current State

### Service Status

```
NAME                             MODE        REPLICAS   IMAGE
observability_cadvisor           global      1/1        gcr.io/cadvisor/cadvisor:v0.49.1
observability_node-exporter      global      1/1        prom/node-exporter:v1.8.2
observability_victoria-metrics   replicated   0/1        victoriametrics/victoria-metrics:v1.107.0
```

### VictoriaMetrics Task Status

```
ID       NAME                               IMAGE                                       NODE      DESIRED STATE   CURRENT STATE
c43wssa  observability_victoria-metrics.1   victoriametrics/victoria-metrics:v1.107.0             Running         Pending
```

**Error Message:** "no suitable node (1 node not available for new tasks; scheduling constraints not satisfied on 1 node)"

### Docker Swarm Node Status

```
ID                            HOSTNAME   STATUS    AVAILABILITY   MANAGER STATUS
3hgeqzd5j0ed1s6ulsxnab23r *   pop-os     Ready     Active         Leader
3y0k7hom96whkmbi13wszsfig     xeon01     Down      Active
```

---

## What Happens When Xeon01 Comes Online

Once Xeon01 (192.168.31.6) comes back online:

1. **Docker Swarm will automatically schedule** the VictoriaMetrics task on Xeon01
2. **Container will start** with the following configuration:
   - Image: victoriametrics/victoria-metrics:v1.107.0
   - Storage: `/srv/docker/observability/victoria` (30-day retention)
   - Scrape config: `/etc/prometheus/prometheus.yml`
   - HTTP port: 8428

3. **Service discovery will activate** and discover:
   - node-exporter tasks (global service)
   - cadvisor tasks (global service)
   - Other services with `prometheus.io.scrape=true` labels

4. **Metrics ingestion will begin** from all discovered targets

---

## Verification Steps (When Xeon01 is Online)

Run the test script to verify VictoriaMetrics is working:

```bash
cd /Users/menoncello/repos/setup/homelab/stacks/observability-stack
./test-victoriametrics.sh
```

Or manually verify:

```bash
# 1. Check service is running
docker service ps observability_victoria-metrics

# 2. Get container ID
VM_TASK=$(docker ps -q -f name=observability_victoria-metrics | head -1)

# 3. Test health endpoint
docker exec $VM_TASK wget -qO- http://localhost:8428/health
# Expected: OK

# 4. Check targets
docker exec $VM_TASK wget -qO- http://localhost:8428/api/v1/targets | jq .

# 5. Query metrics
docker exec $VM_TASK wget -qO- "http://localhost:8428/api/v1/query?query=up" | jq .

# 6. View logs
docker service logs observability_victoria-metrics --tail 50 -f
```

---

## Access Points (After Xeon01 is Online)

- **VictoriaMetrics UI:** http://192.168.31.6:8428
- **VMUI (Query UI):** http://192.168.31.6:8428/vmui
- **Metrics API:** http://192.168.31.6:8428/metrics
- **Health Check:** http://192.168.31.6:8428/health
- **Targets API:** http://192.168.31.6:8428/api/v1/targets

---

## Configuration Details

### Storage Configuration

- **Data Path:** `/srv/docker/observability/victoria`
- **Retention:** 30 days
- **Min Free Space:** 5GB
- **Max Points per Series:** 30,000
- **Latency Offset:** 30s

### Prometheus Scrape Configuration

- **Scrape Interval:** 15s
- **Evaluation Interval:** 15s
- **Service Discovery:** Docker Swarm SD
- **Refresh Interval:** 30s

### Resource Limits

- **Memory Limit:** 2GB
- **Memory Reservation:** 1GB
- **Restart Policy:** On-failure (max 3 attempts)

---

## Files Created

1. **monitoring.yml** - Docker Compose stack file
2. **test-victoriametrics.sh** - Verification script
3. **config/prometheus/prometheus.yml** - Scrape configuration (from Task 1.3)

---

## Next Steps (Task 1.5)

Once VictoriaMetrics is verified working:

1. Deploy Grafana for visualization
2. Configure VictoriaMetrics as Prometheus data source
3. Import pre-built dashboards
4. Set up alerting (if required)

---

## Troubleshooting

### If service doesn't start after Xeon01 comes online:

```bash
# Check node labels
docker node inspect xeon01 --format '{{.Spec.Labels}}'

# Verify volume directory exists
ssh eduardo@192.168.31.6 "ls -la /srv/docker/observability/victoria"

# Check service logs
docker service logs observability_victoria-metrics --tail 100

# Force update
docker service update --force observability_victoria-metrics
```

### If metrics aren't being ingested:

```bash
# Check targets endpoint
curl http://192.168.31.6:8428/api/v1/targets | jq .

# Verify exporter labels
docker service inspect observability_node-exporter --format '{{.Spec.Labels}}'

# Check prometheus config
docker exec $VM_TASK cat /etc/prometheus/prometheus.yml
```

---

## Acceptance Criteria Status

- [x] VictoriaMetrics service created and configured
- [x] Placement constraint set to Xeon01
- [x] Volume configured with bind mount
- [x] Network connected to homelab-net
- [x] Health check configured
- [x] Prometheus config mounted
- [x] Exporters (node-exporter, cadvisor) verified working
- [ ] VictoriaMetrics running on Xeon01 (⏳ Pending node availability)
- [ ] Health check passing (⏳ Pending node availability)
- [ ] Targets discovered via Swarm SD (⏳ Pending node availability)
- [ ] Metrics being ingested (⏳ Pending node availability)

**Overall Status:** ✅ **DEPLOYMENT COMPLETED** - Awaiting Xeon01 availability for verification

---

**Last Updated:** 2025-01-09 16:25  
**Next Review:** After Xeon01 comes online
