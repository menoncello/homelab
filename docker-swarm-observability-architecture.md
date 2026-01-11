# Docker Swarm Observability Architecture for Homelabs
**Comprehensive Monitoring, Logging, and Tracing Strategy (2025-2026)**

---

## Executive Summary

### The Problem
Docker Swarm homelabs face unique observability challenges: limited resources, mixed workloads (media streaming, databases, ARR automation), and the need to detect performance bottlenecks, capacity constraints, and infrastructure failures before they cause downtime.

### The Solution
A **modular, scalable observability stack** built on open-source components that provides:
- **Metrics**: Prometheus or VictoriaMetrics for time-series data with <100GB storage footprint
- **Logs**: Loki for centralized log aggregation with Promtail agents
- **Tracing**: Tempo for distributed tracing with OpenTelemetry collectors
- **Visualization**: Grafana unified dashboards
- **Alerting**: Alertmanager with Telegram/Email notifications

### Recommended Stack: LGT (Loki, Grafana, Tempo) + Prometheus/VictoriaMetrics
For your **moderate resources (4-8GB RAM, 2-4 cores)** and **limited storage (<100GB)**, I recommend:

| Component | Primary Recommendation | Alternative |
|-----------|----------------------|-------------|
| **Metrics** | VictoriaMetrics (10-20x less storage) | Prometheus (standard) |
| **Logs** | Loki with Promtail | Loki with Docker driver |
| **Tracing** | Tempo with OpenTelemetry Collector | Otel Collector + Jaeger |
| **Visualization** | Grafana | Grafana |
| **Alerting** | Alertmanager (Telegram/Email) | Alertmanager |

### Why VictoriaMetrics over Prometheus?
- **Storage efficiency**: 10-20x less space than Prometheus
- **Better performance**: Multi-threaded, higher throughput
- **Native Docker Swarm SD**: Built-in Swarm service discovery
- **Drop-in replacement**: Prometheus-compatible APIs
- **Active development**: Regular updates through 2025

### Implementation Timeline
- **Option A (Fast)**: 1-2 days for baseline metrics + critical alerts
- **Option B (Robust)**: 3-5 days for full LGT stack with tracing
- **Migration**: Clear upgrade path from A → B

### Key Benefits
✅ **Resource-efficient**: Runs within your 4-8GB RAM constraint
✅ **Storage-optimized**: Aggressive retention policies for <100GB footprint
✅ **Swarm-native**: Uses Docker Swarm service discovery and placement
✅ **Future-proof**: OpenTelemetry compatible, supports modern tracing
✅ **Production-ready**: Battle-tested stacks used in enterprise environments

---

## Recommended Architecture

### Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        DOCKER SWARM CLUSTER                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │  pop-os      │  │   Xeon01     │  │   Node N     │          │
│  │  (Manager)   │  │  (Worker)    │  │  (Worker)    │          │
│  │              │  │              │  │              │          │
│  │ ┌──────────┐ │  │ ┌──────────┐ │  │ ┌──────────┐ │          │
│  │ │Node      │ │  │ │Node      │ │  │ │Node      │ │          │
│  │ │Exporter  │ │  │ │Exporter  │ │  │ │Exporter  │ │          │
│  │ └──────────┘ │  │ └──────────┘ │  │ └──────────┘ │          │
│  │ ┌──────────┐ │  │ ┌──────────┐ │  │ ┌──────────┐ │          │
│  │ │cAdvisor  │ │  │ │cAdvisor  │ │  │ │cAdvisor  │ │          │
│  │ └──────────┘ │  │ └──────────┘ │  │ └──────────┘ │          │
│  │ ┌──────────┐ │  │ ┌──────────┐ │  │ ┌──────────┐ │          │
│  │ │Promtail  │ │  │ │Promtail  │ │  │ │Promtail  │ │          │
│  │ └──────────┘ │  │ └──────────┘ │  │ └──────────┘ │          │
│  │ ┌──────────┐ │  │ ┌──────────┐ │  │ ┌──────────┐ │          │
│  │ │Otel      │ │  │ │Otel      │ │  │ │Otel      │ │          │
│  │ │Collector │ │  │ │Collector │ │  │ │Collector │ │          │
│  │ └──────────┘ │  │ └──────────┘ │  │ └──────────┘ │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
│         │                 │                 │                    │
│         └─────────────────┼─────────────────┘                    │
│                           │                                      │
│                  ┌────────┴────────┐                            │
│                  │ Overlay Network │                            │
│                  │  homelab-net    │                            │
│                  └────────┬────────┘                            │
└───────────────────────────┼─────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
        ▼                   ▼                   ▼
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│VictoriaMetrics│   │     Loki     │   │     Tempo     │
│  (Metrics)    │   │   (Logs)     │   │  (Traces)     │
│  /data: 30GB  │   │  /data: 40GB │   │  /data: 20GB  │
└──────┬────────┘   └──────┬────────┘   └──────┬────────┘
       │                   │                   │
       └───────────────────┼───────────────────┘
                           │
                  ┌────────┴────────┐
                  │     Grafana     │
                  │  /data: 5GB     │
                  └────────┬────────┘
                           │
                  ┌────────┴────────┐
                  │  Alertmanager   │
                  │  (Telegram/     │
                  │   Email alerts) │
                  └─────────────────┘
```

### Component Placement Strategy

#### Global Services (run on ALL nodes)
- **node-exporter**: Host metrics (CPU, RAM, disk, network, temps)
- **cadvisor**: Container metrics (per-container CPU, RAM, network, I/O)
- **promtail**: Log collection from Docker daemon
- **otel-collector**: Trace collection (optional, for tracing)

#### Replicated Services (specific placement)
- **VictoriaMetrics/Prometheus**: 1 replica, constraint: `node.labels.database == true`
- **Loki**: 1 replica, constraint: `node.labels.storage == true`
- **Tempo**: 1 replica, constraint: `node.labels.storage == true`
- **Grafana**: 1 replica, constraint: `node.labels.database == true`
- **Alertmanager**: 3 replicas (HA), constraint: `node.role == manager`

### Storage Allocation (Total: <100GB)

| Component | Storage | Retention | Purpose |
|-----------|---------|-----------|---------|
| **VictoriaMetrics** | 30GB | 30 days | Time-series metrics with 10x compression |
| **Loki** | 40GB | 7 days | Compressed logs with aggressive sampling |
| **Tempo** | 20GB | 7 days | Distributed traces |
| **Grafana** | 5GB | Persistent | Dashboards, users, settings |
| **Buffer/Overhead** | 5GB | - | WAL, compaction, headroom |
| **Total** | **100GB** | | |

### Network Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Reverse Proxy (Nginx PM)                  │
│  grafana.homelab → Grafana                                  │
│  alerts.homelab → Alertmanager (if needed)                  │
└─────────────────────────────────────────────────────────────┘
                            │
                    ┌───────┴────────┐
                    │  homelab-net   │ (overlay network)
                    │  10.0.0.0/24   │
                    └───────┬────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
  ┌─────┴─────┐     ┌──────┴──────┐     ┌──────┴──────┐
  │ Victoria  │     │    Loki     │     │    Tempo     │
  │  Metrics   │     │             │     │             │
  │ :8428      │     │ :3100       │     │ :4318       │
  └───────────┘     └─────────────┘     └─────────────┘
```

---

## Stack Comparison Table

| Stack | Complexity | Resource Use | Cost | Maturity | Homelab Fit | Notes |
|-------|-----------|--------------|------|----------|-------------|-------|
| **LGT + VictoriaMetrics** | Medium | **Low-Med** (4-6GB RAM) | Free | Mature | ⭐⭐⭐⭐⭐ **RECOMMENDED** | Best storage efficiency, Swarm-native SD |
| **LGT + Prometheus** | Medium | Medium (6-8GB RAM) | Free | Very Mature | ⭐⭐⭐⭐ | Standard, proven, but higher storage |
| **Grafana LGTM** | High | High (8-12GB RAM) | Free | Mature | ⭐⭐⭐ | Mimir adds complexity, overkill for homelab |
| **Swarmprom** | Low | Low (2-4GB RAM) | Free | Aging | ⭐⭐ | No tracing, outdated dashboards |
| **Netdata** | Very Low | Low (1-2GB RAM per node) | Free | Mature | ⭐⭐⭐⭐ | Great for quick setup, but decentralized |
| **SigNoz** | Medium-High | Medium (4-6GB RAM) | Free tier | Newer | ⭐⭐⭐ | All-in-one, but less Swarm-specific docs |

### Detailed Comparison

#### 1. LGT + VictoriaMetrics (RECOMMENDED)
**Pros:**
- 10-20x less storage than Prometheus
- Native Docker Swarm service discovery
- Drop-in Prometheus replacement
- Multi-threaded, better performance
- Active development (2025)
- Unified Grafana UI for all telemetry

**Cons:**
- Less community content than Prometheus
- Some advanced Prometheus features not 1:1 compatible

**Resource Profile:**
- RAM: 4-6GB total (VM: 2GB, Loki: 2GB, Tempo: 1GB, Grafana: 1GB)
- Storage: ~90GB with recommended retention
- CPU: 2-4 cores sufficient

**Best For:** Homelabs with storage constraints wanting full observability stack.

---

#### 2. LGT + Prometheus (Standard)
**Pros:**
- Industry standard, massive community
- Extensive documentation and examples
- Native Docker Swarm SD since v2.20.0
- All Grafana dashboards compatible
- Proven at scale

**Cons:**
- Higher storage requirements (5-10x more than VM)
- Single-threaded scraping
- Longer compaction times
- Less efficient compression

**Resource Profile:**
- RAM: 6-8GB total
- Storage: ~150GB for same retention (may exceed your limit)
- CPU: 2-4 cores

**Best For:** Homelabs with ample storage wanting the "standard" stack.

---

#### 3. Grafana LGTM (Mimir + Loki + Tempo + Grafana)
**Pros:**
- Full Grafana Labs stack
- Horizontal scalability
- Enterprise-grade features
- Unified support from Grafana

**Cons:**
- Mimir is overkill for homelab (single-node)
- Higher resource usage
- More complex deployment
- Mimir designed for multi-tenant, HA scenarios

**Resource Profile:**
- RAM: 8-12GB total
- Storage: ~120GB
- CPU: 4-6 cores

**Best For:** Learning enterprise tools or planning HA architecture.

---

#### 4. Swarmprom (Legacy)
**Pros:**
- Battle-tested Swarm setup
- Low resource usage
- Quick deployment

**Cons:**
- No tracing support
- Outdated dashboards (last update 2020)
- No Loki (uses Prometheus logs, which is deprecated)
- Limited modern features

**Resource Profile:**
- RAM: 2-4GB
- Storage: ~50GB
- CPU: 1-2 cores

**Best For:** Quick, basic monitoring without logs or tracing needs.

---

#### 5. Netdata (Decentralized)
**Pros:**
- Zero configuration, auto-discovers everything
- Beautiful real-time dashboards
- Excellent hardware monitoring (IPMI, SMART, temps)
- Per-node deployment, no SPOF
- Very low latency metrics

**Cons:**
- No centralized query interface
- No long-term storage by default
- No distributed tracing
- Decentralized (harder to see cluster-wide view)
- RAM usage scales with node count

**Resource Profile:**
- RAM: 1-2GB PER NODE
- Storage: Minimal (in-memory by default)
- CPU: 0.5-1 core per node

**Best For:** Quick deployment, small clusters (<3 nodes), hardware monitoring focus.

---

## Docker Swarm Monitoring Checklist

### Host-Level Metrics (via node-exporter)

#### CPU
- [ ] **CPU saturation** (`100% - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)`)
  - Alert if > 90% for 5m
  - **Why**: Detects sustained CPU pressure causing throttling
- [ ] **Per-core CPU usage** (`rate(node_cpu_seconds_total[5m])`)
  - Alert if any core > 95% for 10m
  - **Why**: Identifies single-threaded bottlenecks
- [ ] **Load average** vs CPU cores (`node_load1 / node_cpu_count`)
  - Alert if > CPU count for 10m
  - **Why**: Unix load metric indicates run queue depth
- [ ] **iowait** (`rate(node_cpu_seconds_total{mode="iowait"}[5m])`)
  - Alert if > 20% for 10m
  - **Why**: CPU wasted waiting for I/O indicates slow disks

#### Memory
- [ ] **Memory usage %** (`(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100`)
  - Warning at 80%, Critical at 90%
  - **Why**: Linux performs poorly with <10% free RAM
- [ ] **Swap usage** (`node_memory_SwapTotal_bytes - node_memory_SwapFree_bytes`)
  - Alert if > 1GB for 5m
  - **Why**: Swap usage causes severe performance degradation
- [ ] **Page faults** (`rate(node_vmstat_pgfault[5m])`)
  - Alert if > 1000/sec
  - **Why**: High page faults indicate memory pressure
- [ ] **OOM kills** (`rate(node_vmstat_oom_kill[5m])`)
  - Alert if > 0
  - **Why**: OOM kills indicate severe memory exhaustion

#### Disk
- [ ] **Disk usage %** (`(1 - (node_filesystem_avail_bytes / node_filesystem_size_bytes)) * 100`)
  - Warning at 80%, Critical at 90%
  - **Why**: Filling disks causes crashes, data corruption
- [ ] **Disk I/O wait** (`rate(node_cpu_seconds_total{mode="iowait"}[5m])`)
  - Alert if > 20% for 10m
  - **Why**: High iowait = slow storage bottleneck
- [ ] **Disk latency** (`rate(node_disk_io_time_seconds_total[5m])`)
  - Alert if > 100ms (SSD) or > 200ms (HDD)
  - **Why**: Slow disk I/O affects all services
- [ ] **Disk IOPS** (`rate(node_disk_reads_completed_total[5m]) + rate(node_disk_writes_completed_total[5m])`)
  - Monitor trends, alert if > 80% of max
  - **Why**: Approaching IOPS limits causes queueing
- [ ] **Inode usage** (`node_filesystem_files_free / node_filesystem_files`)
  - Alert if < 10% free
  - **Why**: Running out of inodes prevents file creation even with disk space
- [ ] **SMART health** (`smart_device_healthy`)
  - Alert if any device reports != 1
  - **Why**: Predicts disk failure before data loss

#### Network
- [ ] **Network errors** (`rate(node_network_receive_errs_total[5m]) + rate(node_network_transmit_errs_total[5m])`)
  - Alert if > 1/sec
  - **Why**: Network errors cause retries, performance issues
- [ ] **Network drops** (`rate(node_network_receive_drop_total[5m]) + rate(node_network_transmit_drop_total[5m])`)
  - Alert if > 10/sec
  - **Why**: Packet drops indicate buffer overflow or network congestion
- [ ] **TCP connections** (`node_netstat_Tcp_CurrEstab`)
  - Alert if > 10,000
  - **Why**: Connection limits cause new connection failures
- [ ] **TCP retransmissions** (`rate(node_netstat_Tcp_RetransSegs[5m])`)
  - Alert if > 1% of total segments
  - **Why**: High retransmits indicate network instability

#### Hardware
- [ ] **CPU temperature** (`node_hwmon_temp_celsius`)
  - Alert if > 85°C for 5m (critical: 95°C)
  - **Why**: Thermal throttling reduces performance
- [ ] **Disk temperature** (`smart_device_temperature_celsius`)
  - Alert if > 50°C for HDD, > 70°C for SSD
  - **Why**: Heat reduces disk lifespan
- [ ] **Power supply status** (`ipmi_sensor_status{type="Power Supply"}`)
  - Alert if any PSU reports failure
  - **Why**: PSU redundancy is critical for uptime
- [ ] **Fan speed** (`ipmi_sensor_status{type="Fan"}`)
  - Alert if any fan = 0 RPM
  - **Why**: Failed fans cause overheating

---

### Docker Swarm Metrics

#### Cluster Health
- [ ] **Manager quorum** (`swarm_node_manager_leader{swarm_manager_is_leader="true"}`)
  - Alert if count = 0 (lost quorum)
  - **Why**: Without quorum, Swarm cannot make decisions
- [ ] **Node availability** (`swarm_node_availablity`)
  - Alert if any node = "unavailable"
  - **Why**: Unavailable nodes indicate hardware/OS issues
- [ ] **Node status** (`swarm_node_status`)
  - Alert if any node = "down"
  - **Why**: Down nodes reduce cluster capacity
- [ ] **Manager count** (`count(swarm_node_manager_is_leader == 1)`)
  - Alert if < 3 (odd number recommended)
  - **Why**: Need 3+ managers for HA

#### Service Health
- [ ] **Service replica count** (`swarm_service_replicas_desired - swarm_service_replicas_running`)
  - Alert if > 0
  - **Why**: Missing replicas indicate scaling or placement failures
- [ ] **Task restart rate** (`rate(swarm_task_restart_total[5m])`)
  - Alert if > 0.1/sec (6/min)
  - **Why**: High restart rates indicate application issues
- [ ] **Task failures** (`increase(swarm_task_failed_total[1h])`)
  - Alert if > 5 in 1h
  - **Why**: Repeated failures indicate resource constraints or bugs
- [ ] **Service state** (`swarm_service_tasks_up{service="..."}`)
  - Alert if = 0
  - **Why**: Service completely down
- [ ] **Rolling update status** (`swarm_service_update_status`)
  - Alert if stuck in "updating"
  - **Why**: Stuck updates prevent deployments

#### Resource Allocation
- [ ] **Service CPU limits** (`container_spec_cpu_quota`)
  - Monitor vs actual usage
  - **Why**: Detect over-provisioning or under-provisioning
- [ ] **Service memory limits** (`container_spec_memory_limit_bytes`)
  - Alert if usage > 90% of limit
  - **Why**: Approaching limits causes OOM kills
- [ ] **Service placement failures** (`swarm_task_placement_error`)
  - Alert if any placement errors
  - **Why**: Placement failures indicate resource exhaustion or constraint conflicts
- [ ] **Reserved vs available resources** (`node_cpu_reserved / node_cpu_total`)
  - Alert if > 90%
  - **Why**: Over-allocation prevents new service deployment

#### Overlay Network
- [ ] **Overlay network errors** (`swarm_network_ingress_errors`)
  - Alert if > 1/sec
  - **Why**: Overlay errors cause inter-service communication failures
- [ ] **Overlay network drops** (`swarm_network_ingress_drops`)
  - Alert if > 10/sec
  - **Why**: Packet drops in overlay indicate MTU or driver issues
- [ ] **DNS resolution latency** (`swarm_dns_resolution_duration_seconds`)
  - Alert if p95 > 100ms
  - **Why**: Slow DNS causes cascading delays
- [ ] **Service discovery failures** (`swarm_service_discovery_errors`)
  - Alert if any failures
  - **Why**: DNS failures break service communication

#### Image & Deployment
- [ ] **Image pull failures** (`swarm_task_image_pull_errors`)
  - Alert if any failures
  - **Why**: Pull failures prevent deployments
- [ ] **Image pull latency** (`swarm_task_image_pull_duration_seconds`)
  - Alert if p95 > 30s
  - **Why**: Slow pulls slow down deployments
- [ ] **Container startup time** (`time() - container_start_time_seconds`)
  - Alert if p95 > 60s
  - **Why**: Slow startups indicate resource starvation or app issues

---

### Service-Level Metrics

#### Web Services (Nginx, Traefik, Apps)
- [ ] **Request rate** (`rate(http_requests_total[5m])`)
  - Monitor trends, alert on >50% drop
  - **Why**: Sudden drops indicate service issues
- [ ] **Error rate** (`rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m])`)
  - Alert if > 1% for 5m
  - **Why**: High error rates indicate application failures
- [ ] **Latency p95** (`histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))`)
  - Alert if > 1s for web apps, > 5s for batch jobs
  - **Why**: Latency SLA violations
- [ ] **Active connections** (`nginx_connections_active`)
  - Alert if > 80% of max
  - **Why**: Approaching connection limits

#### Databases (PostgreSQL, MySQL)
- [ ] **Connection pool usage** (`pg_stat_activity_count / pg_max_connections`)
  - Alert if > 80%
  - **Why**: Connection exhaustion causes rejections
- [ ] **Query latency p95** (`pg_stat_statements_query_duration_p95`)
  - Alert if > 1s
  - **Why**: Slow queries degrade app performance
- [ ] **Lock waits** (`rate(pg_lock_wait_count[5m])`)
  - Alert if > 10/sec
  - **Why**: Lock contention indicates query conflicts
- [ ] **Replication lag** (`pg_replication_lag_seconds`)
  - Alert if > 30s
  - **Why**: Replication lag causes stale reads
- [ ] **Transaction rate** (`rate(pg_stat_xact_commit[5m])`)
  - Monitor trends
  - **Why**: Detect unusual activity patterns

#### ARR Stack (Sonarr, Radarr, Lidarr, etc.)
- [ ] **Download queue depth** (`sonarr_queue_count`)
  - Alert if > 50
  - **Why**: Growing queues indicate download issues
- [ ] **Import failures** (`rate(sonarr_import_failed_total[1h])`)
  - Alert if > 0
  - **Why**: Import failures need manual intervention
- [ ] **Health check status** (`sonarr_health_status`)
  - Alert if any health check fails
  - **Why**: Health checks detect configuration issues

#### Media Streaming (Jellyfin, Plex)
- [ ] **Transcoding sessions** (`jellyfin_transcoding_count`)
  - Alert if > (GPU count * 3)
  - **Why**: Too many transcodes overload GPU/CPU
- [ ] **GPU utilization** (`nvidia_gpu_utilization`)
  - Alert if > 90% for 10m
  - **Why**: GPU saturation causes stuttering
- [ ] **Stream bitrate** (`jellyfin_stream_bitrate`)
  - Monitor for quality issues
  - **Why**: Low bitrates indicate bandwidth or transcoding issues
- [ ] **Active users** (`jellyfin_active_users_count`)
  - Track trends
  - **Why**: Capacity planning for concurrent streams

---

### Network & Connectivity

#### Internal Connectivity
- [ ] **Service-to-service latency** (`probe_duration_seconds{job="blackbox"}`)
  - Alert if p95 > 500ms
  - **Why**: Inter-service delays degrade overall performance
- [ ] **DNS resolution** (`probe_dns_duration_seconds`)
  - Alert if p95 > 100ms
  - **Why**: Slow DNS causes cascading delays
- [ ] **Overlay network MTU issues** (`overlay_mtu_mismatch`)
  - Alert if MTU mismatch detected
  - **Why**: MTU issues cause dropped packets

#### External Connectivity
- [ ] **Gateway reachability** (`probe_success{instance="gateway"}`)
  - Alert if = 0
  - **Why**: Can't reach internet = downloads fail
- [ ] **ISP latency** (`probe_icmp_duration_seconds{instance="8.8.8.8"}`)
  - Alert if p95 > 100ms
  - **Why**: High ISP latency affects streaming
- [ ] **DNS resolution (external)** (`probe_dns_lookup_duration_seconds{instance="8.8.8.8"}`)
  - Alert if p95 > 500ms
  - **Why**: Slow external DNS affects all services

#### Reverse Proxy (Nginx PM)
- [ ] **Proxy errors** (`rate(nginx_proxy_errors_total[5m])`)
  - Alert if > 1/min
  - **Why**: Proxy errors prevent external access
- [ ] **SSL certificate expiry** `(nginx_ssl_cert_not_after - time()) / 86400`)
  - Alert if < 30 days
  - **Why**: Expired certs break all external access
- [ ] **Upstream response time** (`nginx_upstream_response_time_seconds`)
  - Alert if p95 > 5s
  - **Why**: Slow upstreams indicate service issues

---

## Alert Catalogue

### Severity Levels

| Severity | Description | Response Time | Notification |
|----------|-------------|---------------|--------------|
| **P0 - Critical** | Service down, data loss risk, security breach | Immediate | Telegram + Email |
| **P1 - High** | Major functionality degraded, performance severely impacted | < 15 min | Telegram + Email |
| **P2 - Medium** | Minor functionality degraded, performance impacted | < 1 hour | Telegram |
| **P3 - Low** | Informational, capacity planning | Next business day | Email only |

### Critical Alerts (P0)

#### Service Down
```yaml
# Prometheus / VictoriaMetrics
groups:
  - name: critical_service_down
    interval: 30s
    rules:
      - alert: ServiceDown
        expr: up{job=~"node-exporter|cadvisor|promtail"} == 0
        for: 2m
        labels:
          severity: critical
          tier: p0
        annotations:
          summary: "Service {{ $labels.job }} on {{ $labels.instance }} is down"
          description: "{{ $labels.job }} has been down for more than 2 minutes"
          runbook: |
            1. Check if container is running: docker ps | grep {{ $labels.job }}
            2. Check service logs: docker service logs --tail 100 {{ $labels.job }}
            3. Check node health: docker node ls
            4. Restart if needed: docker service update --force {{ $labels.job }}
            5. Check resource constraints: docker service inspect {{ $labels.job }}
```

**Response Runbook:**
1. **Verify**: SSH to affected node, check `docker ps -a | grep <service>`
2. **Logs**: `docker service logs --tail 200 --follow <service>`
3. **Restart**: `docker service update --force <service>`
4. **Investigate**: Check for OOM kills, resource limits, disk space
5. **Escalate**: If restart doesn't fix, check node health and logs

---

#### Manager Quorum Lost
```yaml
      - alert: SwarmManagerQuorumLost
        expr: |
          count(swarm_node_manager_is_leader == 1) < bool(count(swarm_node_manager_is_leader == 1) % 2)
        for: 1m
        labels:
          severity: critical
          tier: p0
        annotations:
          summary: "Docker Swarm manager quorum lost"
          description: "Swarm has lost manager quorum. Cluster cannot make decisions."
          runbook: |
            CRITICAL: Swarm is in read-only mode
            1. DO NOT restart any managers
            2. Check manager node status: docker node ls
            3. Identify down managers: docker node inspect <manager>
            4. If manager is down but not failed: attempt to revive
            5. If manager failed: demote it from surviving manager
            6. Force-new-cluster is LAST RESORT (data loss risk)
```

**Response Runbook:**
1. **ASSESS**: Run `docker node ls` from any manager
2. **STOP**: Do NOT restart any managers blindly
3. **RECOVER**:
   - If manager is down but host is up: `systemctl restart docker`
   - If manager host is down: Wait for recovery or demote from another manager
4. **DEMOTE** (if manager unrecoverable): `docker node demote <manager>`
5. **LAST RESORT** (all managers down): `docker swarm init --force-new-cluster`

---

#### Disk Full
```yaml
      - alert: DiskFull
        expr: |
          (1 - (node_filesystem_avail_bytes{fstype!="tmpfs"} / node_filesystem_size_bytes)) * 100 > 90
        for: 5m
        labels:
          severity: critical
          tier: p0
        annotations:
          summary: "Disk {{ $labels.device }} on {{ $labels.instance }} is {{ $value }}% full"
          description: "Disk is critically full. Service disruption imminent."
          runbook: |
            1. Check what's using space: du -sh /* 2>/dev/null | sort -hr | head -20
            2. Check Docker volumes: docker system df
            3. Clean Docker: docker system prune -a --volumes
            4. Check logs: find /var/log -type f -size +100M
            5. Expand disk if needed (LVM or add new disk)
```

**Response Runbook:**
1. **IMMEDIATE**:
   - SSH to affected node
   - Check: `df -h` and `du -sh /* | sort -hr | head -20`
2. **QUICK WINS**:
   - `docker system prune -a --volumes` (Docker cleanup)
   - `journalctl --vacuum-time=7d` (clean logs)
   - `apt clean && apt autoclean` (package cache)
3. **INVESTIGATE**:
   - Find large files: `find / -type f -size +1G 2>/dev/null`
   - Check volume usage: `docker system df -v`
4. **RESOLVE**:
   - Delete old backups / logs
   - Expand disk (if possible)
   - Move data to network storage

---

#### OOM Kill Detected
```yaml
      - alert: OOMKillDetected
        expr: rate(node_vmstat_oom_kill[5m]) > 0
        for: 1m
        labels:
          severity: critical
          tier: p0
        annotations:
          summary: "OOM kill detected on {{ $labels.instance }}"
          description: "System is out of memory and killing processes."
          runbook: |
            1. Check what was killed: dmesg | grep -i "out of memory" | tail -20
            2. Check memory usage: free -h
            3. Find memory hogs: ps aux --sort=-%mem | head -20
            4. Check containers: docker stats --no-stream
            5. Add more RAM or reduce memory limits
```

**Response Runbook:**
1. **IDENTIFY VICTIM**:
   - `dmesg | grep -i "killed process" | tail -20`
   - `journalctl -k | grep -i oom`
2. **CHECK MEMORY**:
   - `free -h` - overall usage
   - `docker stats --no-stream` - container usage
3. **RESOLVE**:
   - Add swap: `fallocate -l 4G /swapfile && mkswap /swapfile && swapon /swapfile`
   - Reduce container memory limits
   - Stop unnecessary services
   - Add physical RAM

---

#### SMART Failure Predicted
```yaml
      - alert: SMARTFailurePredicted
        expr: smart_device_healthy != 1
        for: 1m
        labels:
          severity: critical
          tier: p0
        annotations:
          summary: "SMART predicts disk failure on {{ $labels.device }} at {{ $labels.instance }}"
          description: "Disk is about to fail. Replace immediately."
          runbook: |
            1. Check SMART details: smartctl -a /dev/{{ $labels.device }}
            2. BACKUP DATA IMMEDIATELY if not already backed up
            3. Schedule disk replacement
            4. Migrate services to another node
            5. Replace disk and restore from backup
```

**Response Runbook:**
1. **VERIFY**: `smartctl -a /dev/<device>` - check attributes
2. **BACKUP**: If important data not backed up, backup NOW
3. **MIGRATE**: Move services to another node in Swarm
4. **REPLACE**: Schedule disk replacement (ASAP)
5. **RESTORE**: Restore data from backup to new disk

---

### High Severity Alerts (P1)

#### High CPU Saturation
```yaml
      - alert: HighCPUSaturation
        expr: |
          100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 90
        for: 10m
        labels:
          severity: warning
          tier: p1
        annotations:
          summary: "CPU saturation on {{ $labels.instance }} is {{ $value }}%"
          description: "CPU has been >90% for 10 minutes"
          runbook: |
            1. Find CPU hogs: docker stats --no-stream | sort -k3 -h
            2. Check per-core: top (press 1)
            3. Consider scaling services or moving to other nodes
            4. Check for CPU-intensive processes: ps aux --sort=-%cpu | head -20
```

---

#### High Memory Usage
```yaml
      - alert: HighMemoryUsage
        expr: |
          (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
        for: 10m
        labels:
          severity: warning
          tier: p1
        annotations:
          summary: "Memory usage on {{ $labels.instance }} is {{ $value }}%"
          description: "Memory usage exceeds 85% for 10 minutes"
          runbook: |
            1. Check memory hogs: docker stats --no-stream | sort -k4 -h
            2. Check system memory: ps aux --sort=-%mem | head -20
            3. Check swap usage: free -h
            4. Consider adding memory or reducing container limits
```

---

#### Service Restarts Too Frequently
```yaml
      - alert: ServiceRestartingTooFrequently
        expr: rate(swarm_task_restart_total[10m]) > 0.1
        for: 5m
        labels:
          severity: warning
          tier: p1
        annotations:
          summary: "Service {{ $labels.service_name }} restarting frequently"
          description: "Service restart rate: {{ $value }}/sec"
          runbook: |
            1. Check service logs: docker service logs --tail 200 <service>
            2. Check resource limits: docker service inspect <service>
            3. Look for OOM kills in logs
            4. Check health check configuration
            5. Verify application configuration
```

---

#### Database Replication Lag
```yaml
      - alert: DatabaseReplicationLag
        expr: pg_replication_lag_seconds > 30
        for: 5m
        labels:
          severity: warning
          tier: p1
        annotations:
          summary: "PostgreSQL replication lag is {{ $value }} seconds"
          description: "Replica is falling behind primary"
          runbook: |
            1. Check replica status: psql -c "SELECT * FROM pg_stat_replication;"
            2. Check network latency between nodes
            3. Check replica load: top, iotop
            4. Check for long-running queries on primary
```

---

### Medium Severity Alerts (P2)

#### Disk Space Warning
```yaml
      - alert: DiskSpaceWarning
        expr: |
          (1 - (node_filesystem_avail_bytes{fstype!="tmpfs"} / node_filesystem_size_bytes)) * 100 > 80
        for: 15m
        labels:
          severity: info
          tier: p2
        annotations:
          summary: "Disk {{ $labels.device }} on {{ $labels.instance }} is {{ $value }}% full"
          description: "Disk usage exceeds 80%. Plan cleanup or expansion."
```

---

#### High Error Rate
```yaml
      - alert: HighErrorRate
        expr: |
          rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]) > 0.01
        for: 5m
        labels:
          severity: warning
          tier: p2
        annotations:
          summary: "Error rate on {{ $labels.job }} is {{ $value }}%"
          description: "HTTP 5xx errors exceed 1%"
          runbook: |
            1. Check application logs: docker service logs <service>
            2. Check database connectivity
            3. Check recent deployments
            4. Verify external dependencies
```

---

#### SSL Certificate Expiring Soon
```yaml
      - alert: SSLCertificateExpiring
        expr: (nginx_ssl_cert_not_after - time()) / 86400 < 30
        labels:
          severity: warning
          tier: p2
        annotations:
          summary: "SSL certificate for {{ $labels.domain }} expires in {{ $value }} days"
          description: "Renew certificate to avoid service disruption"
          runbook: |
            1. Check cert: openssl s_client -connect {{ $labels.domain }}:443 | grep notAfter
            2. Renew in Nginx Proxy Manager UI
            3. Or use certbot: certbot renew
            4. Reload nginx: nginx -s reload
```

---

### Low Severity Alerts (P3)

#### Capacity Planning - CPU Trend
```yaml
      - alert: CapacityPlanningCPU
        expr: |
          predict_linear(node_cpu_seconds_total{mode="idle"}[1h], 7*24*3600) < 0
        labels:
          severity: info
          tier: p3
        annotations:
          summary: "CPU capacity warning for {{ $labels.instance }}"
          description: "At current rate, CPU will be saturated in 7 days"
```

---

#### Capacity Planning - Disk Trend
```yaml
      - alert: CapacityPlanningDisk
        expr: |
          predict_linear(node_filesystem_avail_bytes[1h], 7*24*3600) < 0
        labels:
          severity: info
          tier: p3
        annotations:
          summary: "Disk {{ $labels.device }} will be full in 7 days"
          description: "Plan disk expansion or cleanup"
```

---

### Inhibition Rules (Noise Reduction)

```yaml
# alertmanager.yml
inhibit_rules:
  # If quorum is lost, don't alert about individual manager issues
  - source_match:
      severity: 'critical'
      alertname: 'SwarmManagerQuorumLost'
    target_match:
      alertname: 'ServiceDown'
    equal: ['instance']

  # If node is down, inhibit all service alerts on that node
  - source_match:
      severity: 'critical'
      alertname: 'NodeDown'
    target_match:
      severity: 'warning'
    equal: ['instance']

  # If OOM is occurring, inhibit high memory usage
  - source_match:
      alertname: 'OOMKillDetected'
    target_match:
      alertname: 'HighMemoryUsage'
    equal: ['instance']

  # If disk is full, inhibit individual service disk space alerts
  - source_match:
      alertname: 'DiskFull'
    target_match:
      alertname: 'DiskSpaceWarning'
    equal: ['instance', 'device']
```

---

## Implementation Steps

### Option A: Fast & Simple (1-2 days)
**Baseline metrics + dashboards + critical alerts**

#### Prerequisites
- Docker Swarm cluster (2+ nodes)
- 100GB storage available
- 4GB RAM available on one node
- Git installed

#### Step 1: Create Monitoring Stack Directory
```bash
mkdir -p ~/homelab/stacks/observability-stack
cd ~/homelab/stacks/observability-stack
```

#### Step 2: Deploy Global Agents (all nodes)
Create `agents.yml`:

```yaml
version: '3.8'

services:
  node-exporter:
    image: prom/node-exporter:latest
    deploy:
      mode: global
      resources:
        limits:
          memory: 128M
        reservations:
          memory: 64M
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    networks:
      - homelab-net
    restart: unless-stopped

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    deploy:
      mode: global
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    privileged: true
    devices:
      - /dev/kmsg
    networks:
      - homelab-net
    restart: unless-stopped

networks:
  homelab-net:
    external: true
```

Deploy agents:
```bash
docker stack deploy -c agents.yml observability
```

Verify:
```bash
docker service ls | grep observability
```

#### Step 3: Deploy Core Monitoring Stack
Create `monitoring.yml`:

```yaml
version: '3.8'

services:
  victoria-metrics:
    image: victoriametrics/victoria-metrics:latest
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.labels.database == true
      resources:
        limits:
          memory: 2048M
        reservations:
          memory: 1024M
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.victoriametrics.rule=Host(`victoriametrics.homelab`)"
        - "traefik.http.routers.victoriametrics.entrypoints=websecure"
    volumes:
      - victoria-data:/victoria
      - ./config/prometheus.yml:/etc/prometheus/prometheus.yml:ro
    command:
      - '--storageDataPath=/victoria'
      - '--promscrape.config=/etc/prometheus/prometheus.yml'
      - '--retentionPeriod=30d'
      - '--storage.minFreeDiskSpaceBytes=5GB'
    networks:
      - homelab-net
    restart: unless-stopped

  alertmanager:
    image: prom/alertmanager:latest
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      resources:
        limits:
          memory: 256M
        reservations:
          memory: 128M
    volumes:
      - ./config/alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro
      - alertmanager-data:/alertmanager
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
    networks:
      - homelab-net
    restart: unless-stopped

  grafana:
    image: grafana/grafana:latest
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.labels.database == true
      resources:
        limits:
          memory: 1024M
        reservations:
          memory: 512M
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.grafana.rule=Host(`grafana.homelab`)"
        - "traefik.http.routers.grafana.entrypoints=websecure"
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=changeme
      - GF_SERVER_ROOT_URL=https://grafana.homelab
      - GF_INSTALL_PLUGINS=grafana-piechart-panel
    volumes:
      - grafana-data:/var/lib/grafana
      - ./config/grafana/dashboards:/etc/grafana/provisioning/dashboards:ro
      - ./config/grafana/datasources:/etc/grafana/provisioning/datasources:ro
    networks:
      - homelab-net
    restart: unless-stopped

volumes:
  victoria-data:
    driver: local
  alertmanager-data:
    driver: local
  grafana-data:
    driver: local

networks:
  homelab-net:
    external: true
```

#### Step 4: Create Prometheus Configuration
Create `config/prometheus.yml`:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'homelab'
    env: 'production'

scrape_configs:
  # Swarm service discovery - auto-discover all services
  - job_name: 'dockerswarm'
    dockerswarm_sd_configs:
      - host: unix:///var/run/docker.sock
        role: tasks
    relabel_configs:
      - source_labels: [__meta_dockerswarm_task_name]
        target_label: job
      - source_labels: [__meta_dockerswarm_node_hostname]
        target_label: instance
      - source_labels: [__meta_dockerswarm_service_name]
        target_label: service
      - regex: __meta_dockerswarm_service_label_prometheus_(.+)
        action: labelmap
        replacement: ${1}

  # Node Exporter
  - job_name: 'node-exporter'
    dockerswarm_sd_configs:
      - host: unix:///var/run/docker.sock
        role: tasks
    relabel_configs:
      - source_labels: [__meta_dockerswarm_task_name]
        regex: 'node-exporter.*'
        action: keep
      - source_labels: [__meta_dockerswarm_node_hostname]
        target_label: instance

  # cAdvisor
  - job_name: 'cadvisor'
    dockerswarm_sd_configs:
      - host: unix:///var/run/docker.sock
        role: tasks
    relabel_configs:
      - source_labels: [__meta_dockerswarm_task_name]
        regex: 'cadvisor.*'
        action: keep
      - source_labels: [__meta_dockerswarm_node_hostname]
        target_label: instance
      - source_labels: [__meta_dockerswarm_container_label_com_docker_compose_service]
        target_label: container

  # VictoriaMetrics self-monitoring
  - job_name: 'victoriametrics'
    static_configs:
      - targets: ['localhost:8428']
```

#### Step 5: Create Alertmanager Configuration
Create `config/alertmanager.yml`:

```yaml
global:
  resolve_timeout: 5m
  telegram_api_url: 'https://api.telegram.org'

route:
  group_by: ['alertname', 'cluster', 'service']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h
  receiver: 'default'
  routes:
    - match:
        tier: p0
      receiver: 'critical'
      continue: false
    - match:
        tier: p1
      receiver: 'high'
      continue: false
    - match:
        tier: p2
      receiver: 'medium'
    - match:
        tier: p3
      receiver: 'low'

receivers:
  - name: 'default'
    telegram_configs:
      - bot_token: 'YOUR_BOT_TOKEN'
        chat_id: 'YOUR_CHAT_ID'
        send_resolved: true

  - name: 'critical'
    telegram_configs:
      - bot_token: 'YOUR_BOT_TOKEN'
        chat_id: 'YOUR_CHAT_ID'
        send_resolved: true
        parse_mode: 'HTML'
    email_configs:
      - to: 'your-email@example.com'
        from: 'alertmanager@homelab'
        smarthost: 'smtp.gmail.com:587'
        auth_username: 'your-email@example.com'
        auth_password: 'your-app-password'
        require_tls: true

  - name: 'high'
    telegram_configs:
      - bot_token: 'YOUR_BOT_TOKEN'
        chat_id: 'YOUR_CHAT_ID'
        send_resolved: true

  - name: 'medium'
    telegram_configs:
      - bot_token: 'YOUR_BOT_TOKEN'
        chat_id: 'YOUR_CHAT_ID'
        send_resolved: true

  - name: 'low'
    email_configs:
      - to: 'your-email@example.com'
        from: 'alertmanager@homelab'
        smarthost: 'smtp.gmail.com:587'

inhibit_rules:
  - source_match:
      severity: 'critical'
      alertname: 'SwarmManagerQuorumLost'
    target_match:
      alertname: 'ServiceDown'
    equal: ['instance']
```

#### Step 6: Setup Grafana Provisioning
Create `config/grafana/datasources/datasources.yml`:

```yaml
apiVersion: 1

datasources:
  - name: VictoriaMetrics
    type: prometheus
    access: proxy
    url: http://victoria-metrics:8428
    isDefault: true
    editable: true

  - name: Alertmanager
    type: alertmanager
    access: proxy
    url: http://alertmanager:9093
    editable: true
```

Create `config/grafana/dashboards/dashboards.yml`:

```yaml
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    editable: true
    options:
      path: /etc/grafana/provisioning/dashboards
```

#### Step 7: Download Community Dashboards
```bash
mkdir -p config/grafana/dashboards

# Docker Swarm monitoring dashboard
wget -O config/grafana/dashboards/swarm-monitoring.json \
  https://grafana.com/api/dashboards/18509/revisions/1/download

# Node exporter full dashboard
wget -O config/grafana/dashboards/node-exporter.json \
  https://grafana.com/api/dashboards/1860/revisions/29/download

# Docker containers dashboard
wget -O config/grafana/dashboards/docker-containers.json \
  https://grafana.com/api/dashboards/179/revisions/10/download
```

#### Step 8: Deploy Monitoring Stack
```bash
# Set environment variables for Telegram
export TELEGRAM_BOT_TOKEN="your-bot-token"
export TELEGRAM_CHAT_ID="your-chat-id"
export EMAIL_TO="your-email@example.com"
export EMAIL_PASSWORD="your-app-password"

# Deploy stack
docker stack deploy -c monitoring.yml observability

# Verify deployment
docker service ls | grep observability
docker service logs -f observability_victoria-metrics
```

#### Step 9: Verify & Test
1. Access Grafana: `https://grafana.homelab` (admin/changeme)
2. Check datasource: Configuration → Data Sources → VictoriaMetrics → Test
3. Import dashboards: Dashboards → Browse
4. Generate test alert:
```bash
# Trigger ServiceDown alert
docker service scale observability_node-exporter=0
# Wait 2 minutes, check Telegram/Email
# Restore service
docker service scale observability_node-exporter=1
```

---

### Option B: Robust & Maintainable (3-5 days)
**Full LGT stack with logs and tracing**

Migration Path: **Option A → Option B** (can upgrade without downtime)

#### Add Logging with Loki

Create `logging.yml`:

```yaml
version: '3.8'

services:
  loki:
    image: grafana/loki:latest
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.labels.storage == true
      resources:
        limits:
          memory: 2048M
        reservations:
          memory: 1024M
    volumes:
      - loki-data:/loki
      - ./config/loki/config.yml:/etc/loki/local-config.yaml:ro
    command:
      - '-config.file=/etc/loki/local-config.yaml'
      - '-store.index-cache-cache.memcached.expiration=24h'
    networks:
      - homelab-net
    restart: unless-stopped

networks:
  homelab-net:
    external: true

volumes:
  loki-data:
    driver: local
```

Create `config/loki/config.yml`:

```yaml
auth_enabled: false

server:
  http_listen_port: 3100

common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory

query_range:
  results_cache:
    cache:
      embedded_cache:
        enabled: true
        max_size_mb: 100

schema_config:
  configs:
    - from: 2024-04-01
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

ruler:
  alertmanager_url: http://alertmanager:9093

limits_config:
  retention_period: 168h  # 7 days
  ingestion_rate_mb: 10
  per_stream_rate_limit: 10MB
  max_entries_limit_per_query: 10000
  max_streams_per_user: 0

chunk_store_config:
  max_look_back_period: 168h

table_manager:
  retention_deletes_enabled: true
  retention_period: 168h
```

Update `agents.yml` to add Promtail:

```yaml
  promtail:
    image: grafana/promtail:latest
    deploy:
      mode: global
      resources:
        limits:
          memory: 256M
        reservations:
          memory: 128M
    volumes:
      - /var/log:/var/log:ro
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
      - ./config/promtail/config.yml:/etc/promtail/config.yml:ro
    command:
      - '-config.file=/etc/promtail/config.yml'
    networks:
      - homelab-net
    restart: unless-stopped
```

Create `config/promtail/config.yml`:

```yaml
server:
  http_listen_port: 9080

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: containers
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
        refresh_interval: 5s
    relabel_configs:
      - source_labels: ['__meta_docker_container_name']
        regex: '/(.*)'
        target_label: container
      - source_labels: ['__meta_docker_container_log_stream']
        target_label: stream
      - source_labels: ['__meta_docker_container_label_com_docker_compose_service']
        target_label: service
      - source_labels: ['__meta_docker_container_label_com_docker_swarm_service_name']
        target_label: swarm_service
    pipeline_stages:
      - json:
          expressions:
            output: log
            stream: stream
            time: time
      - json:
          expressions:
            tag:
          source: output
      - regex:
          expression: '(?P<service_name>[a-z0-9_-]+)'
          source: tag
      - labels:
          service:
```

#### Add Tracing with Tempo

Create `tracing.yml`:

```yaml
version: '3.8'

services:
  tempo:
    image: grafana/tempo:latest
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.labels.storage == true
      resources:
        limits:
          memory: 2048M
        reservations:
          memory: 1024M
    volumes:
      - tempo-data:/tempo
      - ./config/tempo/config.yml:/etc/tempo/config.yml:ro
    command:
      - '-config.file=/etc/tempo/config.yml'
      - '-storage.trace.backend=local'
      - '-storage.trace.local.path=/tempo'
      - '-storage.trace.block=100'
    networks:
      - homelab-net
    restart: unless-stopped

  otel-collector:
    image: otel/opentelemetry-collector:latest
    deploy:
      mode: global
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M
    volumes:
      - ./config/otel-collector/config.yml:/etc/otelcol/config.yml:ro
    command:
      - '--config=/etc/otelcol/config.yml'
    networks:
      - homelab-net
    restart: unless-stopped

networks:
  homelab-net:
    external: true

volumes:
  tempo-data:
    driver: local
```

Create `config/tempo/config.yml`:

```yaml
server:
  http_listen_port: 3200

distributor:
  receivers:
    otlp:
      protocols:
        http:
          endpoint: 0.0.0.0:4318
        grpc:
          endpoint: 0.0.0.0:4317

storage:
  trace:
    backend: local
    local:
      path: /tempo
    block:
      v2:
        encoding: zstd

compactor:
  compaction:
    block_retention: 168h  # 7 days

overrides:
  defaults:
    metrics_filter:
      exclude:
        - '.*'
```

Create `config/otel-collector/config.yml`:

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:
    timeout: 1s
    send_batch_size: 1024

exporters:
  otlp/tempo:
    endpoint: tempo:4317
    tls:
      insecure: true

  logging:
    loglevel: info

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [otlp/tempo, logging]
```

#### Update Grafana for Full Stack

Add to `config/grafana/datasources/datasources.yml`:

```yaml
  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    editable: true

  - name: Tempo
    type: tempo
    access: proxy
    url: http://tempo:3200
    editable: true
```

---

## Risks & Mitigations

### Operational Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| **Monitoring stack becomes SPOF** | High | Medium | Deploy Alertmanager in 3-replica HA mode on managers; use external storage for metrics |
| **Disk space exhaustion** | High | Medium | Set retention size limits; aggressive sampling; automated cleanup alerts; reserve 20% free space |
| **High resource usage affects workloads** | Medium | Low | Set resource limits; use node labels for placement; monitor observability stack metrics |
| **Manager node failure takes down monitoring** | High | Low | Deploy critical components (VictoriaMetrics, Loki) on workers; use proper placement constraints |
| **Security exposure of monitoring UI** | High | Medium | Use reverse proxy with auth; disable public exposure; use read-only users for dashboards |
| **Data loss due to disk failure** | High | Low | Backup critical configs; consider remote storage for metrics; use RAID for data drives |

### Security Hardening

#### Authentication & Authorization

**Grafana:**
```yaml
environment:
  - GF_SERVER_ROOT_URL=https://grafana.homelab
  - GF_AUTH_ANONYMOUS_ENABLED=false
  - GF_AUTH_BASIC_ENABLED=true
  - GF_AUTH_PROXY_ENABLED=true  # Use reverse proxy auth
  - GF_INSTALL_PLUGINS=grafana-sqlite-datasource
```

**Nginx Proxy Manager Configuration:**
- Enable Basic Auth or OAuth2
- Use HTTPS only (TLS 1.3)
- Restrict to VPN/internal network
- Implement IP whitelisting

**Network Segmentation:**
```yaml
# Create dedicated monitoring network
docker network create --driver overlay --opt encrypted monitoring-net

# Only expose necessary ports
# VictoriaMetrics: internal only (no public port)
# Grafana: via proxy only
# Alertmanager: via proxy only
```

#### Secrets Management

**Use Docker Secrets:**
```bash
# Create secrets
echo "your-bot-token" | docker secret create telegram_bot_token -
echo "your-chat-id" | docker secret create telegram_chat_id -

# Update compose to use secrets
services:
  alertmanager:
    secrets:
      - telegram_bot_token
      - telegram_chat_id
    environment:
      - TELEGRAM_BOT_TOKEN_FILE=/run/secrets/telegram_bot_token
      - TELEGRAM_CHAT_ID_FILE=/run/secrets/telegram_chat_id
```

#### TLS Configuration

**Enable TLS for all services:**
```yaml
volumes:
  - ./certs:/certs:ro

environment:
  - GF_SERVER_CERT_FILE=/certs/grafana.crt
  - GF_SERVER_CERT_KEY=/certs/grafana.key
```

#### Backup Strategy

**Daily automated backups:**
```bash
#!/bin/bash
# backup-observability.sh

BACKUP_DIR="/backup/observability"
DATE=$(date +%Y%m%d)

# Backup Grafana dashboards and configs
docker exec grafana grafana-cli admin export-migrate > "$BACKUP_DIR/grafana-$DATE.json"

# Backup VictoriaMetrics snapshot
curl -XPOST http://victoria-metrics:8428/snapshot/create -o "$BACKUP_DIR/snapshot-$DATE.txt"

# Backup configs
tar czf "$BACKUP_DIR/configs-$DATE.tar.gz" config/

# Upload to remote storage
rclone copy "$BACKUP_DIR" remote:homelab-backups/observability/

# Cleanup old backups (>30 days)
find "$BACKUP_DIR" -mtime +30 -delete
```

**Cron job:**
```bash
# Add to crontab
0 2 * * * /scripts/backup-observability.sh
```

---

### Backup & Restore Procedures

#### Backup What?
- **Critical**: Grafana dashboards, alerting rules, datasources config
- **Important**: Prometheus/VictoriaMetrics configuration
- **Optional**: Metrics data (can be regenerated, but useful for trends)
- **Not Critical**: Logs (retained 7 days, acceptable to lose)

#### Automated Backup Script

```bash
#!/bin/bash
# backup-observability.sh - Full backup of observability stack

set -e

BACKUP_ROOT="/backup/observability"
RETENTION_DAYS=30
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$BACKUP_ROOT/$DATE"

mkdir -p "$BACKUP_DIR"

echo "Starting observability backup: $DATE"

# 1. Backup Grafana data
echo "Backing up Grafana..."
docker exec observability_grafana.1.$(docker ps -q -f name=observability_grafana | head -1) \
  grafana-cli admin export-migrate > "$BACKUP_DIR/grafana-export.json"

# 2. Backup Prometheus/Alertmanager configs
echo "Backing up configs..."
cp -r config/ "$BACKUP_DIR/"

# 3. Create VictoriaMetrics snapshot
echo "Creating VictoriaMetrics snapshot..."
SNAPSHOT_URL=$(curl -XPOST http://localhost:8428/snapshot/create)
echo "Snapshot created at: $SNAPSHOT_URL"

# 4. Create tarball
echo "Creating archive..."
tar czf "$BACKUP_ROOT/observability-$DATE.tar.gz" -C "$BACKUP_DIR" .

# 5. Upload to remote storage (if configured)
if command -v rclone &> /dev/null; then
  echo "Uploading to remote storage..."
  rclone copy "$BACKUP_ROOT/observability-$DATE.tar.gz" remote:backups/observability/
fi

# 6. Cleanup old backups
echo "Cleaning up old backups..."
find "$BACKUP_ROOT" -name "observability-*.tar.gz" -mtime +$RETENTION_DAYS -delete
find "$BACKUP_ROOT" -type d -mtime +$RETENTION_DAYS -exec rm -rf {} +

echo "Backup completed: $BACKUP_ROOT/observability-$DATE.tar.gz"
```

#### Restore Procedure

```bash
#!/bin/bash
# restore-observability.sh

BACKUP_FILE=$1

if [ -z "$BACKUP_FILE" ]; then
  echo "Usage: $0 <backup-file.tar.gz>"
  exit 1
fi

echo "Restoring from: $BACKUP_FILE"

# 1. Stop observability stack
docker stack rm observability
sleep 30

# 2. Restore configs
tar xzf "$BACKUP_FILE" -C /tmp/

# 3. Restart stack
docker stack deploy -c monitoring.yml observability

# 4. Restore Grafana data
docker cp /tmp/config/grafana-export.json observability_grafana.1:/tmp/
docker exec observability_grafana.1 grafana-cli admin import-migrate /tmp/grafana-export.json

# 5. Verify
docker service ls | grep observability
```

---

## Sources

### Documentation & Official Resources

1. **[Prometheus Docker Swarm Guide](https://prometheus.io/docs/guides/dockerswarm/)** - Official Prometheus documentation for Docker Swarm service discovery (v2.20.0+)

2. **[VictoriaMetrics Documentation](https://docs.victoriametrics.com/)** - Comprehensive docs for VictoriaMetrics, including [Docker Swarm SD configuration](https://docs.victoriametrics.com/victoriametrics/sd_configs/)

3. **[Grafana Loki Documentation](https://grafana.com/docs/loki/latest/)** - Official Loki docs including [Docker driver configuration](https://grafana.com/docs/loki/latest/send-data/docker-driver/configuration/)

4. **[Grafana Tempo Documentation](https://grafana.com/docs/tempo/latest/)** - Official Tempo tracing documentation with [Docker examples](https://grafana.com/docs/tempo/latest/docker-example/)

5. **[OpenTelemetry Docker Deployment](https://opentelemetry.io/docs/demo/docker-deployment/)** - Official OTEL demo with Docker deployment (Updated: Dec 9, 2025)

6. **[Docker Swarm Documentation](https://docs.docker.com/engine/swarm/)** - Official Docker Swarm docs including [Raft consensus](https://docs.docker.com/engine/swarm/raft/)

### Community Guides & Tutorials

7. **[Logging in Docker Swarm](https://last9.io/blog/logging-in-docker-swarm/)** - July 1, 2025 - Covers centralized logging for distributed services

8. **[Grafana LGTM Stack Overview](https://www.infoq.com/news/2025/11/grafana-new-releases/)** - November 2025 - Latest LGTM stack developments

9. **[Grafana Tempo Best Practices](https://last9.io/blog/grafana-tempo-setup-configuration-and-best-practices/)** - November 4, 2025 - Practical Tempo setup guide

10. **[Production-Ready Docker Swarm](https://oneuptime.com/blog/post/2025-11-27-production-docker-swarm/view)** - November 27, 2025 - Production best practices for Swarm

11. **[OpenTelemetry Collector with Docker](https://last9.io/blog/opentelemetry-collector-with-docker/)** - January 24, 2025 - Detailed OTEL Collector guide

### Configuration Examples

12. **[YouMightNotNeedKubernetes Alertmanager](https://github.com/YouMightNotNeedKubernetes/alertmanager)** - HA Alertmanager stack for Docker Swarm

13. **[Docker Swarm Alert Rules Example](https://github.com/ruanbekker/docker-swarm-prometheus-grafana/blob/master/prometheus/rules/alert.rules)** - Production alert rule examples

14. **[Swarm Scheduler Exporter](https://github.com/leinardi/swarm-scheduler-exporter)** - New (Dec 2025) exporter for Swarm scheduler metrics

### Dashboards

15. **[Docker Swarm Monitoring Dashboard](https://grafana.com/grafana/dashboards/18509/)** - Community Swarm monitoring dashboard

16. **[Swarm Stack Monitoring](https://grafana.com/grafana/dashboards/7007/)** - Alternative Swarm dashboard

17. **[SMART Disk Monitoring](https://grafana.com/grafana/dashboards/10530/)** - Disk health monitoring dashboard

### Storage & Performance

18. **[Prometheus Data Retention Guide](https://last9.io/blog/prometheus-data-retention/)** - June 2025 - Storage optimization strategies

19. **[Victoria vs Prometheus Benchmark](https://victoriametrics.com/blog/mimir-benchmark/)** - Performance comparison showing 10-20x efficiency

20. **[Chinese Prometheus Storage Guide](https://blog.csdn.net/gitblog_00103/article/details/152349855)** - November 2025 - Advanced storage optimization

### Security

21. **[Grafana Security Configuration](https://grafana.com/docs/grafana/latest/setup-grafana/configure-security/)** - Official security hardening guide

22. **[CVE-2025-4123: Grafana Ghost](https://docs.indusface.com/en/article/cve-2025-4123)** - 2025 security vulnerability to avoid

23. **[Grafana Auth Proxy](https://grafana.com/docs/grafana/latest/setup-grafana/configure-access/configure-authentication/auth-proxy/)** - Reverse proxy authentication setup

### Hardware Monitoring

24. **[Netdata IPMI Monitoring](https://learn.netdata.cloud/docs/collecting/metrics/hardware-devices-and-sensors/intelligent-platform-management-interface-ipmi)** - IPMI sensor collection

25. **[Netdata SMART Monitoring](https://learn.netdata.cloud/docs/collecting/metrics/hardware-devices-and-sensors/s.m.a.r.t.)** - Disk health monitoring

26. **[Prometheus IPMI Exporter](https://hub.docker.com/r/prometheuscommunity/ipmi-exporter)** - IPMI metrics for Prometheus

### Community & Support

27. **[Docker Forums - Swarm Monitoring](https://forums.docker.com/t/how-to-monitor-docker-swarm-cluster-and-service-replicas-tasks-with-prometheus-and-grafana/150303)** - November 3, 2025 discussion

28. **[Swarmprom Rocktstack](https://dockerswarm.rocks/swarmprom/)** - All-in-one monitoring stack reference

29. **[Awesome Prometheus Alerts](https://samber.github.io/awesome-prometheus-alerts/rules.html)** - Community alert rule collection

---

## Appendices

### Appendix A: Quick Reference Commands

```bash
# Docker Swarm operations
docker node ls                          # List nodes
docker service ls                       # List services
docker stack ps observability           # Stack tasks
docker service logs -f observability_victoria-metrics  # Service logs

# VictoriaMetrics operations
curl http://victoria-metrics:8428/metrics      # All metrics
curl http://victoria-metrics:8428/api/v1/label/__name__/values  # Label values

# Loki queries
curl -G http://loki:3100/loki/api/v1/query \
  --data-urlencode 'query={service="grafana"}'

# Tempo queries
curl http://tempo:3200/api/search?tags=service.name

# Grafana operations
# Restore admin password
docker exec -it observability_grafana.1 grafana-cli admin reset-admin-password admin

# Backup individual components
docker exec observability_grafana.1 grafana-cli admin export-migrate > backup.json
curl -XPOST http://localhost:8428/snapshot/create
```

### Appendix B: Troubleshooting Common Issues

| Issue | Symptoms | Diagnosis | Fix |
|-------|----------|-----------|-----|
| **No metrics appearing** | Empty Grafana dashboards | Check VictoriaMetrics targets: `curl http://vm:8428/api/v1/targets` | Verify agents are running: `docker service ls | grep exporter` |
| **High memory usage** | OOM kills, swap usage | Check: `docker stats` | Reduce retention or add memory limits |
| **Disk filling up** | Alerts for disk space | Check: `docker exec vm du -sh /victoria` | Reduce retention period, enable compaction |
| **Telegram alerts not working** | No alerts received | Check Alertmanager logs: `docker service logs alertmanager` | Verify bot token/chat_id, test via curl |
| **Loki logs missing** | No log data in Grafana | Check Promtail: `docker service logs promtail` | Verify Docker socket mount, check log driver |
| **Tempo no traces** | Empty trace search | Check OTEL collector: `docker service logs otel-collector` | Verify app is sending traces, check endpoint |

### Appendix C: Resource Allocation Calculator

```python
# Calculate resource requirements for your environment

nodes = 2  # Number of nodes
services = 20  # Number of services
retention_days = 30  # Metrics retention
log_retention_days = 7  # Log retention

# Base resource requirements
vm_storage = (nodes * 1GB + services * 500MB) * retention_days * 0.1  # With 10x compression
loki_storage = (nodes * 100MB + services * 50MB) * log_retention_days * 0.5  # With compression
tempo_storage = 20GB  # Fixed for 7 days
grafana_storage = 5GB

total_storage = vm_storage + loki_storage + tempo_storage + grafana_storage
total_ram = 4GB  # VM: 2GB, Loki: 1GB, Tempo: 500MB, Grafana: 512MB

print(f"Total storage: {total_storage}GB")
print(f"Total RAM: {total_ram}GB")
```

---

**Document Version:** 1.0
**Last Updated:** 2025-01-09
**Author:** Observability Architecture Research
**Maintained For:** Docker Swarm Homelab Deployments
