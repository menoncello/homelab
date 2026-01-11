# Docker Swarm Observability Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement a production-ready observability stack (metrics, logs, alerts, dashboards) for a 2-node Docker Swarm homelab with <100GB storage and 4-8GB RAM constraints.

**Architecture:** LGT stack (Loki, Grafana, Tempo) with VictoriaMetrics replacing Prometheus for storage efficiency. Global agents on all nodes (node-exporter, cadvisor, promtail, otel-collector) collecting telemetry into centralized backend services with placement constraints for optimal resource distribution.

**Tech Stack:** VictoriaMetrics (metrics), Loki (logs), Tempo (tracing), Grafana (visualization), Alertmanager (alerting), Promtail (log collection), OpenTelemetry Collector (traces), Docker Swarm service discovery.

---

## Assumptions & Extracted Decisions

### Infrastructure Context

**Current Environment:**
- **pop-os (Manager):** 192.168.31.5, i7/64GB/RTX 3070ti, labels: `gpu=true`, `arr=true`, `proxy=true`
- **Xeon01 (Worker):** 192.168.31.6, Xeon/96GB, labels: `storage=true`, `database=true`
- **Network:** 2.5Gbps, existing overlay network `homelab-net`
- **Existing services:** Media streaming (Jellyfin), ARR stack (Sonarr/Radarr), databases (PostgreSQL), reverse proxy (Nginx PM)

**Resource Constraints:**
- **Observability RAM budget:** 4-8GB total
- **Storage budget:** <100GB total
- **Ops overhead:** Minimal (homelab, not enterprise)

### Extracted Stack Decision

**Primary Choice: LGT + VictoriaMetrics**

**Justification for Homelab:**

| Factor | VictoriaMetrics + LGT | Prometheus + LGT | Decision |
|--------|----------------------|------------------|----------|
| **Storage efficiency** | 10-20x compression | 1x (standard) | **VictoriaMetrics** - Critical for <100GB constraint |
| **RAM usage** | 2-4GB | 3-6GB | **VictoriaMetrics** - Fits 4-8GB budget |
| **Swarm integration** | Native Swarm SD | Native Swarm SD (v2.20+) | **Tie** - Both support |
| **Prometheus compatibility** | Drop-in replacement | Native | **VictoriaMetrics** - All dashboards work |
| **Ops complexity** | Low | Low | **Tie** - Similar deployment |
| **Community content** | Growing | Massive | **Prometheus** - But VM compatible |
| **Active development** | 2025 updates | Stable | **VictoriaMetrics** - Modern features |

**Fallback:** Prometheus + LGT (if VictoriaMetrics shows issues, drop-in replacement path exists)

### Storage Allocation Strategy

| Component | Allocation | Retention | Rationale |
|-----------|------------|-----------|-----------|
| VictoriaMetrics | 30GB | 30 days | 10x compression allows 30d metrics |
| Loki | 40GB | 7 days | Compressed logs, aggressive sampling |
| Tempo | 20GB | 7 days | Distributed traces, optional phase 5 |
| Grafana | 5GB | Persistent | Dashboards, users, settings |
| Buffer/Overhead | 5GB | - | WAL, compaction, safety margin |
| **Total** | **100GB** | | Within constraint |

### Component Placement Strategy

**Global Services (all nodes):**
- `node-exporter` - Host metrics (CPU, RAM, disk, network)
- `cadvisor` - Container metrics (per-container stats)
- `promtail` - Log collection from Docker daemon
- `otel-collector` - Trace collection (phase 5 optional)

**Replicated Services (specific placement):**
- `victoria-metrics` - 1 replica, `node.labels.database == true` (Xeon01: 96GB RAM)
- `loki` - 1 replica, `node.labels.storage == true` (Xeon01: storage-focused)
- `tempo` - 1 replica, `node.labels.storage == true` (Xeon01, phase 5)
- `grafana` - 1 replica, `node.labels.database == true` (Xeon01: centralized access)
- `alertmanager` - 1 replica, `node.role == manager` (pop-os: for quorum awareness)

---

## Architecture Recap

### Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                        DOCKER SWARM CLUSTER                      │
│  ┌──────────────┐  ┌──────────────┐                             │
│  │  pop-os      │  │   Xeon01     │                             │
│  │  (Manager)   │  │  (Worker)    │                             │
│  │              │  │              │                             │
│  │ ┌──────────┐ │  │ ┌──────────┐ │                             │
│  │ │Node      │ │  │ │Node      │ │                             │
│  │ │Exporter  │ │  │ │Exporter  │ │                             │
│  │ └──────────┘ │  │ └──────────┘ │                             │
│  │ ┌──────────┐ │  │ ┌──────────┐ │                             │
│  │ │cAdvisor  │ │  │ │cAdvisor  │ │                             │
│  │ └──────────┘ │  │ └──────────┘ │                             │
│  │ ┌──────────┐ │  │ ┌──────────┐ │                             │
│  │ │Promtail  │ │  │ │Promtail  │ │                             │
│  │ └──────────┘ │  │ └──────────┘ │                             │
│  └──────────────┘  └──────────────┘                             │
│         │                 │                                     │
│         └─────────────────┼─────────────────┐                   │
│                           │                 │                   │
│                  ┌────────┴────────┐       │                   │
│                  │ Overlay Network │       │                   │
│                  │  homelab-net    │       │                   │
│                  └────────┬────────┘       │                   │
└───────────────────────────┼────────────────┼───────────────────┘
                            │                │
                            │                │
        ┌───────────────────┼────────────────┼───────────────────┐
        │                   │                │                   │
        ▼                   ▼                ▼                   ▼
┌──────────────┐   ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│VictoriaMetrics│   │     Loki     │   │     Tempo     │   │   Grafana    │
│  (Metrics)    │   │   (Logs)     │   │  (Traces)     │   │ (Dashboards) │
│  Xeon01       │   │  Xeon01      │   │  Xeon01      │   │  Xeon01      │
│  :8428        │   │  :3100       │   │  :4318       │   │  :3000       │
└──────┬────────┘   └──────┬────────┘   └──────┬────────┘   └──────┬────────┘
       │                   │                   │                   │
       └───────────────────┼───────────────────┘                   │
                           │                                      │
                  ┌────────┴────────┐                            │
                  │  Alertmanager   │                            │
                  │  pop-os (Mgr)   │                            │
                  │  :9093          │                            │
                  └─────────────────┘                            │
                           │                                      │
                           └──────────────────────────────────────┘
                                      │
                                      ▼
                            ┌─────────────────┐
                            │ Nginx Proxy Mgr │
                            │ grafana.homelab │
                            └─────────────────┘
```

### Network Integration

**Internal communication:**
- All services on `homelab-net` overlay network
- Service discovery via Docker Swarm DNS
- Agents → Backends: Service names (e.g., `http://victoria-metrics:8428`)

**External access:**
- Grafana: `https://grafana.homelab` (via Nginx Proxy Manager)
- Alertmanager: `https://alerts.homelab` (optional, for alert status)
- No direct exposure of backends (VictoriaMetrics, Loki, Tempo)

---

## Phased Roadmap

### Phase 0: Prerequisites & Hardening (1 day)

**Goals:**
- Prepare infrastructure for observability stack
- Implement security baseline
- Validate resource availability

**Milestone:** Infrastructure ready for stack deployment

**Tasks:**

#### Task 0.1: Validate Node Labels

**Files:**
- Check: Run docker commands on manager node
- Modify: `scripts/setup-nodes.sh` (if labels missing)

**Step 1: Check existing node labels**
```bash
# From pop-os manager
docker node inspect pop-os --format '{{.Spec.Labels}}'
docker node inspect Xeon01 --format '{{.Spec.Labels}}'
```

Expected output:
```
map[arr:true gpu:true proxy:true]  # pop-os
map[database:true storage:true]     # Xeon01
```

**Step 2: Apply missing labels**
```bash
# If labels missing, add them
docker node update --label-add gpu=true pop-os
docker node update --label-add arr=true pop-os
docker node update --label-add proxy=true pop-os
docker node update --label-add database=true Xeon01
docker node update --label-add storage=true Xeon01
```

**Step 3: Verify labels applied**
```bash
docker node ls --format "table {{.Hostname}}\t{{.Status}}\t{{.Availability}}\t{{.Spec.Labels}}"
```

Expected: Labels show in output

**Acceptance:**
- [ ] pop-os has labels: gpu=true, arr=true, proxy=true
- [ ] Xeon01 has labels: database=true, storage=true

---

#### Task 0.2: Verify Overlay Network

**Files:**
- Check: Network exists and is attachable

**Step 1: Check homelab-net exists**
```bash
docker network ls | grep homelab-net
```

**Step 2: Inspect network configuration**
```bash
docker network inspect homelab-net --format '{{.Attachable}} {{.Driver}}'
```

Expected: `true overlay`

**Step 3: Create network if missing**
```bash
docker network create --driver overlay --attachable homelab-net
```

**Acceptance:**
- [ ] `homelab-net` exists
- [ ] Driver is `overlay`
- [ ] Attachable is `true`

---

#### Task 0.3: Validate Storage Availability

**Files:**
- Check: Available disk space on both nodes

**Step 1: Check Xeon01 storage (primary backend node)**
```bash
ssh eduardo@192.168.31.6 "df -h /srv/docker/ | tail -1"
```

Expected: >100GB available

**Step 2: Check pop-os storage**
```bash
df -h /data/docker/ | tail -1
```

Expected: >20GB available (for local configs)

**Step 3: Create observability directories**
```bash
# On Xeon01
ssh eduardo@192.168.31.6 "sudo mkdir -p /srv/docker/observability/{victoria,loki,tempo,grafana,alertmanager}"
ssh eduardo@192.168.31.6 "sudo chown -R 1000:1000 /srv/docker/observability"

# On pop-os (for backup/configs)
mkdir -p ~/homelab/stacks/observability-stack/{config,secrets,backups}
```

**Acceptance:**
- [ ] Xeon01 has >100GB free
- [ ] pop-os has >20GB free
- [ ] Directories created with correct permissions

---

#### Task 0.4: Configure Secrets Management

**Files:**
- Create: `stacks/observability-stack/secrets/.gitignore`
- Create: `stacks/observability-stack/secrets/secrets.yml.example`

**Step 1: Create secrets directory structure**
```bash
cd ~/homelab/stacks/observability-stack
mkdir -p secrets
```

**Step 2: Create .gitignore for secrets**
```bash
cat > secrets/.gitignore << 'EOF'
# Ignore all secrets except examples
*.pem
*.key
*.txt
*.yml
!.example
EOF
```

**Step 3: Create secrets template**
```bash
cat > secrets/secrets.yml.example << 'EOF'
# Observability Stack Secrets Template
# Copy this file to secrets.yml and fill in real values

# Grafana
grafana_admin_password: changeme123

# Alertmanager - Telegram
telegram_bot_token: "123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11"
telegram_chat_id: "123456789"

# Alertmanager - Email (optional)
email_smtp_host: smtp.gmail.com
email_smtp_port: 587
email_from: alerts@homelab
email_to: your-email@example.com
email_username: your-email@example.com
email_password: your-app-password

# VictoriaMetrics (optional - for remote write)
vm_auth_token: optional_token
EOF
```

**Step 4: Create actual secrets file**
```bash
cp secrets/secrets.yml.example secrets/secrets.yml
# Edit with real values
nano secrets/secrets.yml
```

**Acceptance:**
- [ ] Secrets directory created
- [ ] .gitignore prevents secrets commits
- [ ] secrets.yml created with real values

---

#### Task 0.5: Create Docker Swarm Secrets

**Files:**
- Run: Commands on manager node

**Step 1: Create secrets from values**
```bash
cd ~/homelab/stacks/observability-stack

# Grafana admin
echo "changeme123" | docker secret create grafana_admin_password -

# Telegram
grep telegram_bot_token secrets/secrets.yml | awk '{print $2}' | docker secret create telegram_bot_token -
grep telegram_chat_id secrets/secrets.yml | awk '{print $2}' | docker secret create telegram_chat_id -

# Email (if using)
grep email_password secrets/secrets.yml | awk '{print $2}' | docker secret create email_smtp_password -
```

**Step 2: Verify secrets created**
```bash
docker secret ls
```

Expected: Secrets listed with latest version

**Acceptance:**
- [ ] `grafana_admin_password` secret created
- [ ] `telegram_bot_token` secret created
- [ ] `telegram_chat_id` secret created
- [ ] Secrets not in git (check `git status`)

---

### Phase 1: Baseline Metrics + Dashboards (1-2 days)

**Goals:**
- Deploy metrics collection (node-exporter, cadvisor)
- Deploy VictoriaMetrics backend
- Deploy Grafana with core dashboards
- Validate metrics flow

**Milestone:** Functional metrics pipeline with host and container visibility

**Tasks:**

#### Task 1.1: Create Observability Stack Directory

**Files:**
- Create: `stacks/observability-stack/`
- Create: `stacks/observability-stack/agents.yml`
- Create: `stacks/observability-stack/monitoring.yml`
- Create: `stacks/observability-stack/config/`

**Step 1: Create directory structure**
```bash
cd ~/homelab/stacks
mkdir -p observability-stack/config/{prometheus,alertmanager,grafana/{dashboards,datasources}}
mkdir -p observability-stack/config/promtail
mkdir -p observability-stack/config/loki
mkdir -p observability-stack/config/tempo
mkdir -p observability-stack/config/otel-collector
```

**Step 2: Verify structure**
```bash
tree observability-stack -L 3
```

**Acceptance:**
- [ ] Directory structure created
- [ ] All config subdirectories exist

---

#### Task 1.2: Deploy Global Agents (node-exporter, cadvisor)

**Files:**
- Create: `stacks/observability-stack/agents.yml`

**Step 1: Write agents compose file**
```bash
cat > ~/homelab/stacks/observability-stack/agents.yml << 'EOF'
version: '3.8'

services:
  node-exporter:
    image: prom/node-exporter:v1.8.2
    deploy:
      mode: global
      resources:
        limits:
          memory: 128M
        reservations:
          memory: 64M
      labels:
        - "prometheus.io.scrape=true"
        - "prometheus.io.port=9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc|run)($$|/)'
      - '--collector.filesystem.fs-types-exclude=^(autofs|binfmt_misc|bpf|cgroup2?|configfs|debugfs|devpts|devtmpfs|fusectl|hugetlbfs|iso9660|mqueue|nsfs|overlay|proc|procfs|pstore|rpc_pipefs|securityfs|selinuxfs|squashfs|sysfs|tracefs)$'
    networks:
      - homelab-net
    restart: unless-stopped

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:v0.49.1
    deploy:
      mode: global
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M
      labels:
        - "prometheus.io.scrape=true"
        - "prometheus.io.port=8080"
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
EOF
```

**Step 2: Deploy agents stack**
```bash
cd ~/homelab/stacks/observability-stack
docker stack deploy -c agents.yml observability
```

**Step 3: Verify agents running**
```bash
docker service ls | grep observability
docker service ps observability_node-exporter
docker service ps observability_cadvisor
```

Expected: One task per node (2 tasks each for 2-node cluster)

**Step 4: Test agent endpoints**
```bash
# Test node-exporter
curl http://192.168.31.5:9100/metrics | head -20
curl http://192.168.31.6:9100/metrics | head -20

# Test cadvisor
curl http://192.168.31.5:8080/metrics | head -20
curl http://192.168.31.6:8080/metrics | head -20
```

Expected: Prometheus-formatted metrics output

**Acceptance:**
- [ ] node-exporter running on both nodes
- [ ] cadvisor running on both nodes
- [ ] Metrics accessible via HTTP
- [ ] Services labeled for Prometheus scraping

---

#### Task 1.3: Configure VictoriaMetrics Scrape Config

**Files:**
- Create: `stacks/observability-stack/config/prometheus/prometheus.yml`

**Step 1: Write Prometheus-compatible config for VictoriaMetrics**
```bash
cat > ~/homelab/stacks/observability-stack/config/prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'homelab'
    env: 'production'
    datacenter: 'home'

scrape_configs:
  # Docker Swarm service discovery
  - job_name: 'dockerswarm'
    dockerswarm_sd_configs:
      - host: unix:///var/run/docker.sock
        role: tasks
        refresh_interval: 30s
    relabel_configs:
      # Keep only services with prometheus.io.scrape=true
      - source_labels: [__meta_dockerswarm_service_label_prometheus_io_scrape]
        regex: 'true'
        action: keep
      # Set job from service name
      - source_labels: [__meta_dockerswarm_service_name]
        target_label: job
        regex: 'observability_(.+)'
        replacement: '${1}'
      # Set instance from node hostname
      - source_labels: [__meta_dockerswarm_node_hostname]
        target_label: instance
      # Set service label
      - source_labels: [__meta_dockerswarm_service_name]
        target_label: service
      # Port from label or default
      - source_labels: [__meta_dockerswarm_service_label_prometheus_io_port]
        target_label: __meta_dockerswarm_task_container_port_number
        regex: '(.+)'
      # Add all prometheus.io labels
      - regex: __meta_dockerswarm_service_label_prometheus_io_(.+)
        action: labelmap
        replacement: __meta_${1}

  # Static target for VictoriaMetrics self-monitoring
  - job_name: 'victoriametrics'
    static_configs:
      - targets: ['localhost:8428']
        labels:
          instance: 'xenon01'
```

**Step 2: Validate config syntax**
```bash
# Install promtool if not available
docker run --rm -v $(pwd)/config/prometheus:/workdir prom/prometheus:latest \
  promtool check config /workdir/prometheus.yml
```

Expected: `SUCCESS: 0 rule files found`

**Acceptance:**
- [ ] Config file created
- [ ] Syntax validation passes
- [ ] Docker Swarm SD configured
- [ ] Agent scrapes configured

---

#### Task 1.4: Deploy VictoriaMetrics Backend

**Files:**
- Create: `stacks/observability-stack/monitoring.yml`

**Step 1: Write monitoring stack compose**
```bash
cat > ~/homelab/stacks/observability-stack/monitoring.yml << 'EOF'
version: '3.8'

services:
  victoria-metrics:
    image: victoriametrics/victoria-metrics:v1.107.0
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
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.victoriametrics.rule=Host(`victoriametrics.homelab`)"
        - "traefik.http.routers.victoriametrics.entrypoints=websecure"
        - "traefik.http.routers.victoriametrics.tls.certresolver=cloudflare"
    volumes:
      - victoria-data:/victoria
      - ./config/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
    command:
      - '--storageDataPath=/victoria'
      - '--promscrape.config=/etc/prometheus/prometheus.yml'
      - '--retentionPeriod=30d'
      - '--storage.minFreeDiskSpaceBytes=5GB'
      - '--search.maxPointsPerTimeseries=30000'
      - '--search.latencyOffset=30s'
      - '--httpListenAddr=:8428'
    environment:
      - TZ=America/Sao_Paulo
    networks:
      - homelab-net
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:8428/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

networks:
  homelab-net:
    external: true

volumes:
  victoria-data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /srv/docker/observability/victoria
EOF
```

**Step 2: Ensure volume directory exists**
```bash
ssh eduardo@192.168.31.6 "sudo mkdir -p /srv/docker/observability/victoria && sudo chown -R 1000:1000 /srv/docker/observability/victoria"
```

**Step 3: Deploy monitoring stack**
```bash
cd ~/homelab/stacks/observability-stack
docker stack deploy -c monitoring.yml observability
```

**Step 4: Verify VictoriaMetrics running**
```bash
docker service ps observability_victoria-metrics
docker service logs observability_victoria-metrics --tail 50
```

**Step 5: Test VictoriaMetrics API**
```bash
# Find VictoriaMetrics task
VM_TASK=$(docker ps -q -f name=observability_victoria-metrics | head -1)

# Test health endpoint
docker exec $VM_TASK wget -qO- http://localhost:8428/health

# Test metrics endpoint
docker exec $VM_TASK wget -qO- http://localhost:8428/metrics | grep -i "vm_"

# Check targets
docker exec $VM_TASK wget -qO- http://localhost:8428/api/v1/targets | jq .
```

Expected: JSON output showing active targets

**Step 6: Verify metrics ingestion**
```bash
# Query for node-exporter metrics
docker exec $VM_TASK wget -qO- "http://localhost:8428/api/v1/query?query=up{job='node-exporter'}" | jq .

# Query for cadvisor metrics
docker exec $VM_TASK wget -qO- "http://localhost:8428/api/v1/query?query=up{job='cadvisor'}" | jq .
```

Expected: `{"resultType":"vector","result":[{"metric":...,"value":[...,"1"]}]}`

**Acceptance:**
- [ ] VictoriaMetrics running on Xeon01
- [ ] Health check passing
- [ ] Targets discovered via Swarm SD
- [ ] Metrics being ingested (query returns data)
- [ ] Volume persisting data

---

#### Task 1.5: Deploy Grafana with Provisioning

**Files:**
- Create: `stacks/observability-stack/config/grafana/datasources/datasources.yml`
- Create: `stacks/observability-stack/config/grafana/dashboards/dashboards.yml`

**Step 1: Create datasource provisioning**
```bash
cat > ~/homelab/stacks/observability-stack/config/grafana/datasources/datasources.yml << 'EOF'
apiVersion: 1

datasources:
  - name: VictoriaMetrics
    type: prometheus
    access: proxy
    url: http://victoria-metrics:8428
    isDefault: true
    editable: true
    jsonData:
      timeInterval: "15s"
      queryTimeout: "60s"
      httpMethod: "POST"
EOF
```

**Step 2: Create dashboard provisioning**
```bash
cat > ~/homelab/stacks/observability-stack/config/grafana/dashboards/dashboards.yml << 'EOF'
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
      foldersFromFilesStructure: false
EOF
```

**Step 3: Download community dashboards**
```bash
mkdir -p ~/homelab/stacks/observability-stack/config/grafana/dashboards/files

# Docker Swarm monitoring dashboard (18509)
wget -O ~/homelab/stacks/observability-stack/config/grafana/dashboards/files/swarm-monitoring.json \
  https://grafana.com/api/dashboards/18509/revisions/1/download

# Node exporter full (1860)
wget -O ~/homelab/stacks/observability-stack/config/grafana/dashboards/files/node-exporter-full.json \
  https://grafana.com/api/dashboards/1860/revisions/29/download

# Docker containers (179)
wget -O ~/homelab/stacks/observability-stack/config/grafana/dashboards/files/docker-containers.json \
  https://grafana.com/api/dashboards/179/revisions/10/download
```

**Step 4: Add Grafana to monitoring.yml**
```bash
cat >> ~/homelab/stacks/observability-stack/monitoring.yml << 'EOF'

  grafana:
    image: grafana/grafana:11.3.1
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
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.grafana.rule=Host(`grafana.homelab`)"
        - "traefik.http.routers.grafana.entrypoints=websecure"
        - "traefik.http.routers.grafana.tls.certresolver=cloudflare"
    environment:
      - GF_SECURITY_ADMIN_USER=${ADMIN_USER:-admin}
      - GF_SECURITY_ADMIN_PASSWORD__FILE=/run/secrets/grafana_admin_password
      - GF_SERVER_ROOT_URL=https://grafana.homelab
      - GF_INSTALL_PLUGINS=
      - GF_ANALYTICS_REPORTING_ENABLED=false
      - GF_ANALYTICS_CHECK_FOR_UPDATES=false
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_SERVER_SERVE_FROM_SUB_PATH=true
      - TZ=America/Sao_Paulo
    secrets:
      - grafana_admin_password
    volumes:
      - grafana-data:/var/lib/grafana
      - ./config/grafana/datasources:/etc/grafana/provisioning/datasources:ro
      - ./config/grafana/dashboards:/etc/grafana/provisioning/dashboards:ro
      - ./config/grafana/dashboards/files:/var/lib/grafana/dashboards:ro
    networks:
      - homelab-net
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:3000/api/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

volumes:
  grafana-data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /srv/docker/observability/grafana
EOF
```

**Step 5: Create Grafana volume directory**
```bash
ssh eduardo@192.168.31.6 "sudo mkdir -p /srv/docker/observability/grafana && sudo chown -R 1000:1000 /srv/docker/observability/grafana"
```

**Step 6: Redeploy stack with Grafana**
```bash
cd ~/homelab/stacks/observability-stack
docker stack deploy -c monitoring.yml observability
```

**Step 7: Verify Grafana running**
```bash
docker service ps observability_grafana
docker service logs observability_grafana --tail 50
```

**Step 8: Access Grafana and verify**
```bash
# Check DNS resolution
docker exec $(docker ps -q -f name=observability_victoria-metrics | head -1) \
  wget -qO- http://grafana:3000/api/health

# Test from host
curl -k https://grafana.homelab/api/health
```

Expected: `{"commit":"...","database":"ok","version":"11.3.1"}`

**Step 9: Login and explore**
1. Navigate to https://grafana.homelab
2. Login: admin / <your password>
3. Check: Configuration → Data Sources → VictoriaMetrics
4. Click "Test" - should show green "OK"
5. Browse: Dashboards → Browse
6. Open "Docker Swarm Monitoring" dashboard
7. Verify data appearing

**Acceptance:**
- [ ] Grafana accessible via HTTPS
- [ ] VictoriaMetrics datasource provisioned and testing OK
- [ ] Community dashboards imported
- [ ] Metrics data visible in dashboards
- [ ] User can login and navigate

---

#### Task 1.6: Validate End-to-End Metrics Pipeline

**Files:**
- Test: Existing deployment

**Step 1: Verify host metrics collection**
```bash
# Query node-exporter metrics
curl -G 'http://localhost:8428/api/v1/query' \
  --data-urlencode 'query=node_cpu_seconds_total{mode!="idle"}' | jq .

# Check for both nodes
curl -G 'http://localhost:8428/api/v1/query' \
  --data-urlencode 'query=count(up{job="node-exporter"})' | jq .
```

Expected: Result shows 2 nodes

**Step 2: Verify container metrics**
```bash
# Query container count
curl -G 'http://localhost:8428/api/v1/query' \
  --data-urlencode 'query=count(container_last_seen)' | jq .

# Check for specific containers
curl -G 'http://localhost:8428/api/v1/query' \
  --data-urlencode 'query=container_memory_usage_bytes{name="grafana"}' | jq .
```

**Step 3: Verify in Grafana**
1. Open "Node Exporter Full" dashboard
2. Select each node (pop-os, Xeon01)
3. Verify CPU, memory, disk, network metrics showing data
4. Open "Docker Containers" dashboard
5. Verify container list showing
6. Check resource usage per container

**Acceptance:**
- [ ] Host metrics from both nodes visible
- [ ] Container metrics visible
- [ ] No gaps in data (check last 15 minutes)
- [ ] Dashboards load without errors
- [ ] Time range queries work

---

### Phase 2: Alerting + On-Call Readiness (1 day)

**Goals:**
- Deploy Alertmanager
- Configure critical alert rules
- Setup Telegram/Email notifications
- Validate alert delivery

**Milestone:** Functional alerting with P0/P1 notifications working

**Tasks:**

#### Task 2.1: Deploy Alertmanager

**Files:**
- Create: `stacks/observability-stack/config/alertmanager/alertmanager.yml`

**Step 1: Create Alertmanager config**
```bash
cat > ~/homelab/stacks/observability-stack/config/alertmanager/alertmanager.yml << 'EOF'
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
        severity: critical
      receiver: 'critical'
      continue: false
    - match:
        severity: warning
      receiver: 'warning'
    - match:
        tier: p0
      receiver: 'critical'
      continue: false
    - match:
        tier: p1
      receiver: 'critical'
      continue: false
    - match:
        tier: p2
      receiver: 'warning'
      continue: false

receivers:
  - name: 'default'
    telegram_configs:
      - bot_token: 'YOUR_BOT_TOKEN'
        chat_id: 'YOUR_CHAT_ID'
        send_resolved: true
        parse_mode: 'HTML'

  - name: 'critical'
    telegram_configs:
      - bot_token: 'YOUR_BOT_TOKEN'
        chat_id: 'YOUR_CHAT_ID'
        send_resolved: true
        parse_mode: 'HTML'
        message: |
          <b>🚨 CRITICAL ALERT</b>

          <b>Alert:</b> {{ .GroupLabels.alertname }}
          <b>Severity:</b> {{ .CommonLabels.severity }}
          <b>Instance:</b> {{ .CommonLabels.instance }}

          {{ range .Alerts }}
          <b>Description:</b> {{ .Annotations.description }}
          <b>Summary:</b> {{ .Annotations.summary }}
          {{ end }}

          <a href="https://grafana.homelab">View in Grafana</a>

  - name: 'warning'
    telegram_configs:
      - bot_token: 'YOUR_BOT_TOKEN'
        chat_id: 'YOUR_CHAT_ID'
        send_resolved: true
        parse_mode: 'HTML'

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
EOF
```

**Step 2: Update alertmanager.yml with real secrets**
```bash
# Read secrets and update config
BOT_TOKEN=$(grep telegram_bot_token ~/homelab/stacks/observability-stack/secrets/secrets.yml | awk '{print $2}')
CHAT_ID=$(grep telegram_chat_id ~/homelab/stacks/observability-stack/secrets/secrets.yml | awk '{print $2}')

sed -i "s|YOUR_BOT_TOKEN|$BOT_TOKEN|g" ~/homelab/stacks/observability-stack/config/alertmanager/alertmanager.yml
sed -i "s|YOUR_CHAT_ID|$CHAT_ID|g" ~/homelab/stacks/observability-stack/config/alertmanager/alertmanager.yml
```

**Step 3: Add Alertmanager to monitoring.yml**
```bash
cat >> ~/homelab/stacks/observability-stack/monitoring.yml << 'EOF'

  alertmanager:
    image: prom/alertmanager:v0.28.1
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
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.alertmanager.rule=Host(`alerts.homelab`)"
        - "traefik.http.routers.alertmanager.entrypoints=websecure"
        - "traefik.http.routers.alertmanager.tls.certresolver=cloudflare"
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
      - '--web.external-url=https://alerts.homelab'
      - '--cluster.listen-address=0.0.0.0:9094'
    environment:
      - TZ=America/Sao_Paulo
    volumes:
      - alertmanager-data:/alertmanager
      - ./config/alertmanager/alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro
    networks:
      - homelab-net
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:9093/-/healthy || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  alertmanager-data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /srv/docker/observability/alertmanager
EOF
```

**Step 4: Create Alertmanager volume**
```bash
# On pop-os (manager)
sudo mkdir -p /srv/docker/observability/alertmanager
sudo chown -R 1000:1000 /srv/docker/observability/alertmanager
```

**Step 5: Deploy updated stack**
```bash
cd ~/homelab/stacks/observability-stack
docker stack deploy -c monitoring.yml observability
```

**Step 6: Verify Alertmanager**
```bash
docker service ps observability_alertmanager
docker service logs observability_alertmanager --tail 50

# Test from host
curl -k https://alerts.homelab/-/healthy
```

Expected: `OK` status

**Acceptance:**
- [ ] Alertmanager running on manager node
- [ ] Config loaded without errors
- [ ] Web UI accessible
- [ ] Receivers configured

---

#### Task 2.2: Create Critical Alert Rules

**Files:**
- Create: `stacks/observability-stack/config/prometheus/alerts.yml`

**Step 1: Create alert rules file**
```bash
cat > ~/homelab/stacks/observability-stack/config/prometheus/alerts.yml << 'EOF'
groups:
  # Critical Service Alerts (P0)
  - name: critical_service_down
    interval: 30s
    rules:
      - alert: ServiceDown
        expr: up{job=~"node-exporter|cadvisor|victoria-metrics|grafana|alertmanager"} == 0
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

      - alert: DiskFull
        expr: |
          (1 - (node_filesystem_avail_bytes{fstype!="tmpfs",fstype!="overlay"} / node_filesystem_size_bytes)) * 100 > 90
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
            3. Find memory hogs: docker stats --no-stream

  # High Severity Alerts (P1)
  - name: high_resource_usage
    interval: 30s
    rules:
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
            3. Consider adding memory or reducing container limits

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

  # Medium Severity Alerts (P2)
  - name: capacity_warnings
    interval: 1m
    rules:
      - alert: DiskSpaceWarning
        expr: |
          (1 - (node_filesystem_avail_bytes{fstype!="tmpfs",fstype!="overlay"} / node_filesystem_size_bytes)) * 100 > 80
        for: 15m
        labels:
          severity: info
          tier: p2
        annotations:
          summary: "Disk {{ $labels.device }} on {{ $labels.instance }} is {{ $value }}% full"
          description: "Disk usage exceeds 80%. Plan cleanup or expansion."

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
            3. Reload nginx: nginx -s reload
EOF
```

**Step 2: Update VictoriaMetrics config to load alerts**
```bash
# Edit monitoring.yml to add alert rules
# Add to victoria-metrics command section:
#   - '--rule=/etc/prometheus/alerts.yml'

# Or update prometheus.yml to include:
# rule_files:
#   - '/etc/prometheus/alerts.yml'

# For VictoriaMetrics, use remote write config or separate vmalert
cat >> ~/homelab/stacks/observability-stack/config/prometheus/prometheus.yml << 'EOF'

# Alert rules (loaded by vmalert or separate service)
rule_files:
  - '/etc/prometheus/alerts.yml'
EOF
```

**Step 3: Mount alert rules in VictoriaMetrics**
```bash
# Edit monitoring.yml victoria-metrics section
# Update volumes: line to include alert rules
# Add: - ./config/prometheus/alerts.yml:/etc/prometheus/alerts.yml:ro
```

**Step 4: Deploy vmalert for rule evaluation (alternative)**
```bash
cat >> ~/homelab/stacks/observability-stack/monitoring.yml << 'EOF'

  vmalert:
    image: victoriametrics/vmalert:v1.107.0
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.labels.database == true
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M
    command:
      - '--rule=/etc/prometheus/alerts.yml'
      - '--datasource.url=http://victoria-metrics:8428'
      - '--notifier.url=http://alertmanager:9093'
      - '--remoteWrite.url=http://victoria-metrics:8428'
      - '--evaluationInterval=30s'
    environment:
      - TZ=America/Sao_Paulo
    volumes:
      - ./config/prometheus/alerts.yml:/etc/prometheus/alerts.yml:ro
    networks:
      - homelab-net
    restart: unless-stopped
    depends_on:
      - victoria-metrics
      - alertmanager
EOF
```

**Step 5: Redeploy with alerting**
```bash
cd ~/homelab/stacks/observability-stack
docker stack deploy -c monitoring.yml observability
```

**Step 6: Verify vmalert running**
```bash
docker service ps observability_vmalert
docker service logs observability_vmalert --tail 50
```

**Step 7: Check alerts in Alertmanager UI**
```bash
# Access Alertmanager UI
curl -k https://alerts.homelab/api/v2/alerts | jq .
```

**Acceptance:**
- [ ] vmalert running and evaluating rules
- [ ] Alert rules loaded without errors
- [ ] Alerts visible in Alertmanager UI
- [ ] No alerts firing in healthy state

---

#### Task 2.3: Test Alert Delivery

**Files:**
- Test: Existing deployment

**Step 1: Generate test alert**
```bash
# Trigger ServiceDown alert by stopping node-exporter
docker service scale observability_node-exporter=0

# Wait 2 minutes for alert to fire
sleep 120

# Check Alertmanager for firing alerts
curl -k https://alerts.homelab/api/v2/alerts | jq '.data.alerts[] | select(.state=="firing")'
```

**Step 2: Verify Telegram notification received**
- Check Telegram for alert message
- Verify message format (HTML parsing)
- Verify includes runbook link

**Step 3: Restore service**
```bash
docker service scale observability_node-exporter=1

# Wait for resolution
sleep 30

# Check for resolved alert
curl -k https://alerts.homelab/api/v2/alerts | jq '.data.alerts[] | select(.labels.alertname=="ServiceDown")'
```

**Step 4: Verify resolution notification**
- Check Telegram for "resolved" message

**Step 5: Test critical alert (optional - use caution)**
```bash
# Generate a high CPU alert (optional)
# Run stress on one node
ssh eduardo@192.168.31.6 "stress --cpu 2 --timeout 300s &"

# Monitor for HighCPUSaturation alert
# Should fire after 10 minutes

# Kill stress when alert received
pkill stress
```

**Acceptance:**
- [ ] Test alert generated correctly
- [ ] Telegram notification received
- [ ] Message includes all relevant details
- [ ] Resolution notification sent
- [ ] Grafana link in notification works

---

#### Task 2.4: Create Alert Runbook Documentation

**Files:**
- Create: `docs/observability/runbooks/`

**Step 1: Create runbooks directory**
```bash
mkdir -p ~/homelab/docs/observability/runbooks
```

**Step 2: Create critical runbooks**
(See "Operational Readiness Pack" section below for full runbooks)

**Acceptance:**
- [ ] Runbooks created for all P0 alerts
- [ ] Runbooks tested during alert validation
- [ ] Runbooks accessible from team

---

### Phase 3: Centralized Logs + Retention (1 day)

**Goals:**
- Deploy Loki log aggregation
- Deploy Promtail log collectors
- Configure log retention
- Validate log pipeline

**Milestone:** Centralized logging with 7-day retention

**Tasks:**

#### Task 3.1: Deploy Loki Backend

**Files:**
- Create: `stacks/observability-stack/logging.yml`
- Create: `stacks/observability-stack/config/loki/config.yml`

**Step 1: Create Loki config**
```bash
cat > ~/homelab/stacks/observability-stack/config/loki/config.yml << 'EOF'
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096

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
    - from: 2024-01-01
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
  reject_old_samples: true
  reject_old_samples_max_age: 168h

chunk_store_config:
  max_look_back_period: 168h

table_manager:
  retention_deletes_enabled: true
  retention_period: 168h
EOF
```

**Step 2: Create logging stack compose**
```bash
cat > ~/homelab/stacks/observability-stack/logging.yml << 'EOF'
version: '3.8'

services:
  loki:
    image: grafana/loki:3.2.1
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
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
    command:
      - '-config.file=/etc/loki/local-config.yaml'
    environment:
      - TZ=America/Sao_Paulo
    volumes:
      - loki-data:/loki
      - ./config/loki/config.yml:/etc/loki/local-config.yaml:ro
    networks:
      - homelab-net
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:3100/ready || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

networks:
  homelab-net:
    external: true

volumes:
  loki-data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /srv/docker/observability/loki
EOF
```

**Step 3: Create Loki volume**
```bash
ssh eduardo@192.168.31.6 "sudo mkdir -p /srv/docker/observability/loki && sudo chown -R 1000:1000 /srv/docker/observability/loki"
```

**Step 4: Deploy logging stack**
```bash
cd ~/homelab/stacks/observability-stack
docker stack deploy -c logging.yml observability-logs
```

**Step 5: Verify Loki running**
```bash
docker service ps observability-logs_loki
docker service logs observability-logs_loki --tail 50

# Test Loki API
curl -G http://localhost:3100/ready
curl http://localhost:3100/loki/api/v1/labels
```

Expected: `ready` response and empty label list

**Acceptance:**
- [ ] Loki running on Xeon01
- [ ] Health check passing
- [ ] API responding
- [ ] Volume persisting data

---

#### Task 3.2: Deploy Promtail Log Collectors

**Files:**
- Create: `stacks/observability-stack/config/promtail/config.yml`

**Step 1: Create Promtail config**
```bash
cat > ~/homelab/stacks/observability-stack/config/promtail/config.yml << 'EOF'
server:
  http_listen_port: 9080

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  # Docker container logs
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
      - source_labels: ['__meta_docker_container_label_com_docker_swarm_task_name']
        target_label: task
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
          container:

  # System logs (journald)
  - job_name: systemd
    journal:
      max_age: 7d
      labels:
        job: systemd
        node: ${HOSTNAME}
    relabel_configs:
      - source_labels: ['__journal__systemd_unit']
        target_label: unit
      - source_labels: ['__journal__hostname']
        target_label: hostname
      - source_labels: ['__journal_priority_keyword']
        target_label: level
    pipeline_stages:
      - regex:
          expression: '(?P<service_name>[a-z0-9_-]+)\.service'
          source: unit
      - labels:
          service:
          unit:
EOF
```

**Step 2: Add Promtail to agents.yml**
```bash
cat >> ~/homelab/stacks/observability-stack/agents.yml << 'EOF'

  promtail:
    image: grafana/promtail:3.2.1
    deploy:
      mode: global
      resources:
        limits:
          memory: 256M
        reservations:
          memory: 128M
    environment:
      - HOSTNAME={{.Node.Hostname}}
    volumes:
      - /var/log:/var/log:ro
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./config/promtail/config.yml:/etc/promtail/config.yml:ro
      - promtail-positions:/tmp
    command:
      - '-config.file=/etc/promtail/config.yml'
    networks:
      - homelab-net
    restart: unless-stopped

volumes:
  promtail-positions:
    driver: local
EOF
```

**Step 3: Redeploy agents with Promtail**
```bash
cd ~/homelab/stacks/observability-stack
docker stack deploy -c agents.yml observability
```

**Step 4: Verify Promtail running**
```bash
docker service ps observability_promtail
docker service logs observability_promtail --tail 50
```

Expected: Promtail connecting to Loki

**Step 5: Verify log ingestion**
```bash
# Query Loki for recent logs
curl -G http://localhost:3100/loki/api/v1/query \
  --data-urlencode 'query={service="grafana"}' \
  --data-urlencode 'limit=10' | jq .

# Check labels
curl http://localhost:3100/loki/api/v1/labels | jq .
```

Expected: Labels showing containers/services

**Acceptance:**
- [ ] Promtail running on all nodes
- [ ] Logs being sent to Loki
- [ ] Labels properly set
- [ ] Query API returning data

---

#### Task 3.3: Configure Grafana Loki Datasource

**Files:**
- Modify: `stacks/observability-stack/config/grafana/datasources/datasources.yml`

**Step 1: Add Loki datasource**
```bash
cat >> ~/homelab/stacks/observability-stack/config/grafana/datasources/datasources.yml << 'EOF'

  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    isDefault: false
    editable: true
    jsonData:
      maxLines: 1000
      derivedFields:
        - datasourceUid: victoria-metrics
          matcherRegex: "traceID=(\\w+)"
          name: TraceID
          url: $${__value.raw}
          urlDisplayLabel: "View Trace"
EOF
```

**Step 2: Redeploy Grafana**
```bash
cd ~/homelab/stacks/observability-stack
docker stack deploy -c monitoring.yml observability
```

**Step 3: Verify Loki datasource in Grafana**
1. Navigate to Grafana → Configuration → Data Sources
2. Find "Loki" datasource
3. Click "Test"
4. Should show green "OK"

**Step 4: Test log queries**
1. In Grafana, go to Explore
2. Select Loki datasource
3. Run query: `{service="grafana"} |= "error"`
4. Verify logs appear

**Acceptance:**
- [ ] Loki datasource added to Grafana
- [ ] Datasource testing OK
- [ ] Log queries working
- [ ] Logs visible in Grafana

---

#### Task 3.4: Validate End-to-End Log Pipeline

**Files:**
- Test: Existing deployment

**Step 1: Generate test logs**
```bash
# Generate logs in a container
docker exec $(docker ps -q -f name=observability_grafana | head -1) \
  sh -c 'for i in $(seq 1 10); do echo "Test log entry $i - $(date)"; sleep 1; done'
```

**Step 2: Query logs in Loki**
```bash
# Wait 30 seconds for ingestion
sleep 30

# Query for test logs
curl -G http://localhost:3100/loki/api/v1/query \
  --data-urlencode 'query={service="grafana"} |= "Test log entry"' \
  --data-urlencode 'limit=20' | jq .
```

Expected: Test log entries returned

**Step 3: Query in Grafana**
1. Navigate to Grafana → Explore → Loki
2. Query: `{service="grafana"} |= "Test log entry"`
3. Verify logs appear with correct timestamps

**Step 4: Verify retention**
```bash
# Check retention configuration
curl http://localhost:3100/loki/api/v1/labels | jq .

# Verify old logs being cleaned (after 7 days)
# For now, just verify retention is configured
docker exec $(docker ps -q -f name=observability-logs_loki | head -1) \
  cat /etc/loki/local-config.yaml | grep retention
```

Expected: `retention_period: 168h`

**Acceptance:**
- [ ] Test logs generated and ingested
- [ ] Logs queryable in Loki API
- [ ] Logs visible in Grafana
- [ ] Retention configured to 7 days
- [ ] No log gaps in first hour

---

### Phase 4: Refinement (1-2 days)

**Goals:**
- Implement SLO-style alerts
- Add noise reduction rules
- Create capacity planning dashboards
- Optimize resource usage

**Milestone:** Production-ready observability with minimal noise

**Tasks:**

#### Task 4.1: Implement SLO-Style Alerts

**Files:**
- Create: `stacks/observability-stack/config/prometheus/slo-alerts.yml`

**Step 1: Create SLO alert rules**
```bash
cat > ~/homelab/stacks/observability-stack/config/prometheus/slo-alerts.yml << 'EOF'
groups:
  - name: availability_slos
    interval: 1m
    rules:
      # Service availability SLO
      - alert: ServiceAvailabilitySLO
        expr: |
          (
            sum(rate(up{job=~".*"}[5m])) /
            count(up{job=~".*"})
          ) < 0.99
        for: 5m
        labels:
          severity: warning
          tier: p1
          slo: availability
        annotations:
          summary: "Service availability below 99% SLO"
          description: "{{ $value | humanizePercentage }} of services are up"

      # Disk availability SLO
      - alert: DiskSpaceSLO
        expr: |
          (
            sum(node_filesystem_avail_bytes) /
            sum(node_filesystem_size_bytes)
          ) < 0.10
        for: 5m
        labels:
          severity: critical
          tier: p0
          slo: disk_space
        annotations:
          summary: "Less than 10% disk space available cluster-wide"
          description: "Only {{ $value | humanizePercentage }} free"

  - name: latency_slos
    interval: 30s
    rules:
      # Overlay network latency SLO
      - alert: NetworkLatencySLO
        expr: |
          histogram_quantile(0.95,
            sum(rate(swarm_network_latency_seconds_bucket[5m])) by (le)
          ) > 0.1
        for: 10m
        labels:
          severity: warning
          tier: p2
          slo: network_latency
        annotations:
          summary: "95th percentile network latency exceeds 100ms SLO"
          description: "p95 latency is {{ $value }}s"

  - name: capacity_planning
    interval: 1h
    rules:
      # Predict when disk will be full
      - alert: DiskWillFillIn7Days
        expr: |
          predict_linear(node_filesystem_avail_bytes[1h], 7*24*3600) < 0
        labels:
          severity: info
          tier: p3
        annotations:
          summary: "Disk {{ $labels.device }} will be full in 7 days"
          description: "Plan disk expansion or cleanup"

      # Predict when memory will be exhausted
      - alert: MemoryWillExhaustIn7Days
        expr: |
          predict_linear(node_memory_MemAvailable_bytes[1h], 7*24*3600) < 0
        labels:
          severity: info
          tier: p3
        annotations:
          summary: "Memory on {{ $labels.instance }} will be exhausted in 7 days"
          description: "Plan memory upgrade or workload reduction"
EOF
```

**Step 2: Update vmalert to load SLO rules**
```bash
# Edit monitoring.yml vmalert section
# Add to command: '--rule=/etc/prometheus/slo-alerts.yml'
# Add to volumes: - ./config/prometheus/slo-alerts.yml:/etc/prometheus/slo-alerts.yml:ro
```

**Step 3: Redeploy with SLO alerts**
```bash
cd ~/homelab/stacks/observability-stack
docker stack deploy -c monitoring.yml observability
```

**Acceptance:**
- [ ] SLO alert rules loaded
- [ ] No SLO alerts firing in healthy state
- [ ] SLO alerts documented

---

#### Task 4.2: Add Noise Reduction Rules

**Files:**
- Modify: `stacks/observability-stack/config/alertmanager/alertmanager.yml`

**Step 1: Add inhibition rules**
```bash
# Edit alertmanager.yml and add to inhibit_rules section:
cat >> ~/homelab/stacks/observability-stack/config/alertmanager/alertmanager.yml << 'EOF'

  # If disk is full, inhibit high memory usage (often related)
  - source_match:
      alertname: 'DiskFull'
    target_match:
      alertname: 'HighMemoryUsage'
    equal: ['instance']

  # If node is down, inhibit all resource alerts
  - source_match:
      alertname: 'NodeDown'
    target_match_re:
      severity: '(warning|info)'
    equal: ['instance']

  # If service is restarting, inhibit service-specific alerts
  - source_match:
      alertname: 'ServiceRestartingTooFrequently'
    target_match_re:
      alertname: '.+'
    equal: ['service']

  # During deployment windows, inhibit non-critical alerts
  # (Use deployment label on services)
  - source_match:
      deployment: 'active'
    target_match_re:
      tier: '(p2|p3)'
    equal: ['cluster']
EOF
```

**Step 2: Test inhibition rules**
```bash
# Trigger a ServiceDown alert
docker service scale observability_grafana=0

# Wait for alert
sleep 120

# Check Alertmanager - should not see Grafana-specific alerts
curl -k https://alerts.homelab/api/v2/alerts | jq .

# Restore
docker service scale observability_grafana=1
```

**Acceptance:**
- [ ] Inhibition rules loaded
- [ ] Tested inhibition working
- [ ] Noise reduced in alerts

---

#### Task 4.3: Create Capacity Planning Dashboards

**Files:**
- Create: `stacks/observability-stack/config/grafana/dashboards/files/capacity-planning.json`

**Step 1: Create capacity planning dashboard**
(Use Grafana UI to build, then export JSON)

**Key panels:**
1. Resource trends (CPU, RAM, disk over 30d)
2. Growth rate (prediction charts)
3. Service count trend
4. Storage breakdown by service
5. Network traffic trends
6. Alerts frequency over time

**Step 2: Import dashboard**
```bash
# Place JSON file in dashboards/files directory
cp capacity-planning.json ~/homelab/stacks/observability-stack/config/grafana/dashboards/files/

# Restart Grafana to reload
docker service update --force observability_grafana
```

**Step 3: Verify dashboard**
1. Open Grafana
2. Navigate to "Capacity Planning" dashboard
3. Verify all panels showing data
4. Check time ranges work (7d, 30d)

**Acceptance:**
- [ ] Capacity dashboard created
- [ ] All panels functional
- [ ] Predictions showing
- [ ] Used for planning decisions

---

#### Task 4.4: Optimize Resource Usage

**Files:**
- Test: Existing deployment
- Modify: `stacks/observability-stack/monitoring.yml`, `agents.yml`

**Step 1: Monitor current usage**
```bash
# Check observability stack resource usage
docker stats --no-stream $(docker ps -q -f name=observability)

# Check over time
docker stats $(docker ps -q -f name=observability) --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"
```

**Step 2: Adjust limits if needed**
```bash
# Edit compose files to optimize:
# - Reduce VictoriaMetrics cache if RAM constrained
# - Reduce Promtail memory if logs light
# - Adjust Loki retention if disk tight
```

**Step 3: Validate after adjustments**
```bash
# Re-deploy with new limits
docker stack deploy -c monitoring.yml observability
docker stack deploy -c agents.yml observability

# Monitor for stability
docker service ps observability_victoria-metrics
docker service logs observability_victoria-metrics --tail 100
```

**Acceptance:**
- [ ] Resource usage within budget (4-8GB RAM)
- [ ] No OOM kills
- [ ] Storage growth predictable
- [ ] Query performance acceptable

---

### Phase 5: Distributed Tracing (Optional, 1 day)

**Goals:**
- Deploy Tempo tracing backend
- Deploy OpenTelemetry collectors
- Instrument sample applications
- Validate trace pipeline

**Milestone:** End-to-end tracing with Tempo + Grafana

**Tasks:**

#### Task 5.1: Deploy Tempo Backend

**Files:**
- Create: `stacks/observability-stack/tracing.yml`
- Create: `stacks/observability-stack/config/tempo/config.yml`

**Step 1: Create Tempo config**
```bash
cat > ~/homelab/stacks/observability-stack/config/tempo/config.yml << 'EOF'
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
EOF
```

**Step 2: Create tracing stack**
```bash
cat > ~/homelab/stacks/observability-stack/tracing.yml << 'EOF'
version: '3.8'

services:
  tempo:
    image: grafana/tempo:2.6.1
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
    environment:
      - TZ=America/Sao_Paulo
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
    healthcheck:
      test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:3200/ready || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

networks:
  homelab-net:
    external: true

volumes:
  tempo-data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /srv/docker/observability/tempo
EOF
```

**Step 3: Deploy tracing stack**
```bash
cd ~/homelab/stacks/observability-stack
docker stack deploy -c tracing.yml observability-traces
```

**Acceptance:**
- [ ] Tempo running on Xeon01
- [ ] Health check passing
- [ ] API responding

---

#### Task 5.2: Deploy OpenTelemetry Collectors

**Files:**
- Create: `stacks/observability-stack/config/otel-collector/config.yml`

**Step 1: Create OTEL collector config**
```bash
cat > ~/homelab/stacks/observability-stack/config/otel-collector/config.yml << 'EOF'
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
EOF
```

**Step 2: Add OTEL collector to agents.yml**
```bash
cat >> ~/homelab/stacks/observability-stack/agents.yml << 'EOF'

  otel-collector:
    image: otel/opentelemetry-collector:0.111.0
    deploy:
      mode: global
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M
    command:
      - '--config=/etc/otelcol/config.yml'
    volumes:
      - ./config/otel-collector/config.yml:/etc/otelcol/config.yml:ro
    networks:
      - homelab-net
    restart: unless-stopped
    depends_on:
      - tempo
EOF
```

**Step 3: Redeploy agents**
```bash
cd ~/homelab/stacks/observability-stack
docker stack deploy -c agents.yml observability
```

**Acceptance:**
- [ ] OTEL collectors running
- [ ] Connecting to Tempo
- [ ] No connection errors

---

#### Task 5.3: Configure Grafana Tempo Datasource

**Files:**
- Modify: `stacks/observability-stack/config/grafana/datasources/datasources.yml`

**Step 1: Add Tempo datasource**
```bash
cat >> ~/homelab/stacks/observability-stack/config/grafana/datasources/datasources.yml << 'EOF'

  - name: Tempo
    type: tempo
    access: proxy
    url: http://tempo:3200
    isDefault: false
    editable: true
    jsonData:
      tracesToLogs:
        datasourceUid: 'Loki'
      search:
        hide: false
      nodeGraph:
        enabled: true
EOF
```

**Step 2: Redeploy Grafana**
```bash
docker stack deploy -c monitoring.yml observability
```

**Step 3: Verify Tempo datasource**
1. Grafana → Configuration → Data Sources
2. Test Tempo datasource
3. Should show "OK"

**Acceptance:**
- [ ] Tempo datasource configured
- [ ] Testing OK
- [ ] Trace search working

---

#### Task 5.4: Validate Trace Pipeline

**Files:**
- Test: Existing deployment

**Step 1: Generate test traces**
```bash
# Use OTEL demo or instrument a sample service
# For now, verify Tempo is accepting traces
curl -X POST http://localhost:4318/v1/traces \
  -H "Content-Type: application/json" \
  -d '{
    "resourceSpans": [{
      "resource": {"attributes": [{"key": "service.name", "value": {"stringValue": "test-service"}}]},
      "scopeSpans": [{
        "scope": {"name": "test"},
        "spans": [{
          "traceId": "4bf92f3577b34da6a3ce929d0e0e4736",
          "spanId": "00f067aa0ba902b7",
          "name": "test-span",
          "startTimeUnixNano": "1595816564000000000",
          "endTimeUnixNano": "1595816565000000000"
        }]
      }]
    }]
  }'
```

**Step 2: Query traces in Tempo**
```bash
# Search for traces
curl -G http://localhost:3200/api/search --data-urlencode 'tags=service.name=test-service' | jq .
```

**Step 3: View traces in Grafana**
1. Grafana → Explore → Tempo
2. Search for `test-service`
3. Click into trace
4. Verify span details

**Acceptance:**
- [ ] Test traces ingested
- [ ] Traces queryable
- [ ] Tempo datasource functional
- [ ] Trace-to-logs working

---

## Prioritized Backlog

| Priority | Task | Owner Role | Effort | Dependencies | Acceptance Criteria |
|----------|------|------------|--------|--------------|---------------------|
| **P0** | **Phase 0: Prerequisites** | | | | |
| P0 | 0.1 Validate node labels | SRE | 30m | None | Labels present on both nodes |
| P0 | 0.2 Verify overlay network | SRE | 15m | None | homelab-net exists and attachable |
| P0 | 0.3 Validate storage availability | SRE | 30m | None | 100GB+ available on Xeon01 |
| P0 | 0.4 Configure secrets management | SRE | 1h | None | Secrets directory created, git ignores |
| P0 | 0.5 Create Docker Swarm secrets | SRE | 30m | 0.4 | Secrets deployed to Swarm |
| **P0** | **Phase 1: Metrics** | | | | |
| P0 | 1.1 Create stack directory | SRE | 15m | None | Directory structure complete |
| P0 | 1.2 Deploy global agents | SRE | 1h | 0.2 | Agents running on all nodes |
| P0 | 1.3 Configure VM scrape config | SRE | 1h | 1.2 | Config validated, Swarm SD enabled |
| P0 | 1.4 Deploy VictoriaMetrics | SRE | 2h | 1.2, 1.3 | VM running, ingesting metrics |
| P0 | 1.5 Deploy Grafana | SRE | 2h | 1.4 | Grafana accessible, dashboards loaded |
| P0 | 1.6 Validate metrics pipeline | SRE | 1h | 1.5 | End-to-end metrics flowing |
| **P1** | **Phase 2: Alerting** | | | | |
| P1 | 2.1 Deploy Alertmanager | SRE | 2h | Phase 1 complete | Alertmanager running, configured |
| P1 | 2.2 Create alert rules | SRE | 2h | 2.1 | P0/P1 alerts loaded |
| P1 | 2.3 Test alert delivery | SRE | 1h | 2.2 | Telegram notifications working |
| P1 | 2.4 Document runbooks | SRE | 2h | 2.2 | Runbooks created for P0 alerts |
| **P1** | **Phase 3: Logging** | | | | |
| P1 | 3.1 Deploy Loki | SRE | 2h | Phase 1 complete | Loki running, API responding |
| P1 | 3.2 Deploy Promtail | SRE | 1h | 3.1 | Promtail on all nodes, sending logs |
| P1 | 3.3 Configure Loki datasource | SRE | 30m | 3.2 | Grafana Loki datasource working |
| P1 | 3.4 Validate log pipeline | SRE | 1h | 3.3 | End-to-end logs flowing |
| **P2** | **Phase 4: Refinement** | | | | |
| P2 | 4.1 Implement SLO alerts | SRE | 2h | Phase 2 complete | SLO rules loaded and working |
| P2 | 4.2 Add noise reduction | SRE | 1h | 4.1 | Inhibition rules tested |
| P2 | 4.3 Create capacity dashboards | SRE | 3h | Phase 1 complete | Capacity dashboard functional |
| P2 | 4.4 Optimize resources | SRE | 2h | All phases | Resource usage within budget |
| **P3** | **Phase 5: Tracing (Optional)** | | | | |
| P3 | 5.1 Deploy Tempo | SRE | 2h | Phase 1 complete | Tempo running |
| P3 | 5.2 Deploy OTEL collectors | SRE | 1h | 5.1 | Collectors deployed |
| P3 | 5.3 Configure Tempo datasource | SRE | 30m | 5.2 | Grafana Tempo datasource working |
| P3 | 5.4 Validate trace pipeline | SRE | 1h | 5.3 | End-to-end traces flowing |

**Execution Order:**
1. Complete Phase 0 (prerequisites) - blocks everything
2. Complete Phase 1 (metrics) - foundation for everything
3. Execute Phase 2 (alerting) in parallel with Phase 3 (logging) - independent after Phase 1
4. Complete Phase 4 (refinement) after 2 and 3 - builds on them
5. Phase 5 (tracing) is optional, can be done anytime after Phase 1

---

## Risk Register

| ID | Risk | Impact | Probability | Mitigation | Swarm-Specific |
|----|------|--------|-------------|------------|----------------|
| **R1** | **VictoriaMetrics OOM kills data loss** | High | Medium | Set 5GB min free space, aggressive retention, monitor VM metrics | Yes: Swarm placement on storage node |
| **R2** | **Manager failure takes down Alertmanager** | High | Low | Deploy Alertmanager on manager (for quorum awareness), backup configs | Yes: Swarm manager quorum dependency |
| **R3** | **Overlay network partition breaks metrics** | High | Low | Monitor overlay health, agents cache locally, retry logic | Yes: Swarm overlay networking |
| **R4** | **Disk exhaustion crashes all backends** | High | Medium | 80% warning alerts, automated cleanup, 20% reserved space | Yes: Shared storage constraint |
| **R5** | **Observability stack SPOF affects monitoring** | Medium | Medium | Document manual restart, consider HA for critical components | Yes: Swarm single replica |
| **R6** | **Alertmanager notification spam** | Medium | Medium | Inhibition rules, rate limiting, test all alerts before production | Yes: Swarm task restart noise |
| **R7** | **Resource starvation affects workloads** | Medium | Low | Set resource limits, placement constraints, monitor observability metrics | Yes: Swarm resource contention |
| **R8** | **Loki log ingestion overload** | Medium | Low | Rate limiting, sampling, drop debug logs, monitor ingestion rate | Yes: High container count |
| **R9** | **Grafana dashboard corruption** | Low | Low | Backup dashboards, version control, export snapshots | No: General risk |
| **R10** | **Secrets leak in git** | High | Low | .gitignore enforcement, pre-commit hooks, secret scanning | No: General risk |

### Detailed Mitigations

**R1: VictoriaMetrics OOM**
- Pre-deployment: Calculate expected ingestion (nodes × services × metrics)
- Runtime: Set `--storage.minFreeDiskSpaceBytes=5GB`
- Monitoring: Alert on VM RAM usage >80%, disk >85%
- Response: Automated snapshot before restart

**R2: Manager Failure**
- Pre-deployment: Document manual Alertmanager restart on worker
- Runtime: Backup Alertmanager config and data daily
- Monitoring: Alert on manager node down
- Response: Promote worker to manager if needed, redeploy Alertmanager

**R3: Overlay Partition**
- Pre-deployment: Test overlay resilience (node reboot)
- Runtime: Monitor overlay metrics (dropped packets, errors)
- Monitoring: Alert on overlay errors >1/sec
- Response: Restart overlay on affected nodes

**R4: Disk Exhaustion**
- Pre-deployment: Set 80% warning, 90% critical alerts
- Runtime: Automated daily cleanup of old logs/metrics
- Monitoring: Trend analysis for capacity planning
- Response: Emergency pruning, expand storage

**R5: Observability SPOF**
- Pre-deployment: Document restart procedures
- Runtime: Health checks on all components
- Monitoring: Alert if observability stack down
- Response: Manual restart via docker service update

**R6: Alert Spam**
- Pre-deployment: Test all alerts in staging
- Runtime: Inhibition rules for cascading failures
- Monitoring: Track alert frequency, tune thresholds
- Response: Mute non-critical alerts during incidents

**R7: Resource Starvation**
- Pre-deployment: Set resource limits on all services
- Runtime: Monitor observability stack metrics
- Monitoring: Alert if stack uses >70% of budget
- Response: Scale down retention, increase limits

**R8: Loki Ingestion Overload**
- Pre-deployment: Calculate expected log volume
- Runtime: Rate limit per stream, drop debug logs
- Monitoring: Alert on ingestion failures
- Response: Increase sampling, drop more logs

---

## Operational Readiness Pack

### Top 8 Critical Alert Runbooks

#### 1. ServiceDown (P0)

**Symptom:** `up{job=~"node-exporter|cadvisor|victoria-metrics"} == 0` for 2 minutes

**Impact:** Loss of visibility, alerts not firing

**Diagnosis:**
```bash
# Check if service container exists
docker service ls | grep <service>

# Check service tasks
docker service ps observability_<service> --no-trunc

# Check service logs
docker service logs observability_<service> --tail 100

# Check node health
docker node ls
```

**Resolution:**
1. If service has 0 tasks: `docker service scale observability_<service>=1`
2. If task failed: Check logs for error, then `docker service update --force observability_<service>`
3. If node down: Fix node issue (see NodeDown runbook)
4. If OOM: Increase memory limit in compose file

**Verification:**
```bash
# Wait 2 minutes, check alert resolved
curl -k https://alerts.homelab/api/v2/alerts | jq '.data.alerts[] | select(.labels.alertname=="ServiceDown")'
```

---

#### 2. SwarmManagerQuorumLost (P0)

**Symptom:** Manager count is even or quorum unavailable

**Impact:** Swarm cluster in read-only mode, cannot deploy/update services

**Diagnosis:**
```bash
# Check manager status
docker node ls

# Check manager count
docker node ls --format '{{.Hostname}}: {{.ManagerStatus}}' | grep Leader

# Check which managers are reachable
for node in pop-os Xeon01; do
  docker node inspect $node --format '{{.Status.State}}' 2>/dev/null && echo "$node reachable" || echo "$node unreachable"
done
```

**Resolution:**
1. **DO NOT restart any managers**
2. Identify which manager is down
3. If manager host is up but Docker down: `systemctl restart docker` on that host
4. If manager host is down: Wait for recovery OR demote from surviving manager:
   ```bash
   docker node demote <down-manager>
   ```
5. **LAST RESORT** (all managers down, data loss risk):
   ```bash
   docker swarm init --force-new-cluster
   ```

**Prevention:**
- Always maintain odd number of managers (1 or 3)
- Don't run workloads on managers in production
- Backup Swarm state regularly

---

#### 3. DiskFull (P0)

**Symptom:** Disk usage >90% for 5 minutes

**Impact:** Service crashes, data corruption, writes fail

**Diagnosis:**
```bash
# Check disk usage
df -h

# Find what's using space
du -sh /* 2>/dev/null | sort -hr | head -20

# Check Docker volumes
docker system df -v

# Check log files
find /var/log -type f -size +100M -exec ls -lh {} \;
```

**Resolution:**
1. **Quick wins (do immediately):**
   ```bash
   # Clean Docker
   docker system prune -a --volumes --force

   # Clean journald logs
   journalctl --vacuum-time=7d

   # Clean package cache
   apt clean && apt autoclean
   ```

2. **Investigate:**
   ```bash
   # Find large files
   find / -type f -size +1G 2>/dev/null

   # Check volume usage
   docker system df -v | grep local
   ```

3. **Resolve:**
   - Delete old backups in `/backup`
   - Truncate specific large log files
   - Move data to network storage
   - Expand disk (if possible)

**Verification:**
```bash
# Check disk usage dropped below 90%
df -h | grep -v tmpfs
```

---

#### 4. OOMKillDetected (P0)

**Symptom:** `rate(node_vmstat_oom_kill[5m]) > 0`

**Impact:** Processes being killed, service disruption

**Diagnosis:**
```bash
# Check what was killed
dmesg | grep -i "killed process" | tail -20
journalctl -k | grep -i oom | tail -20

# Check memory usage
free -h

# Check container memory
docker stats --no-stream | sort -k4 -h

# Check system memory
ps aux --sort=-%mem | head -20
```

**Resolution:**
1. **Immediate:** Identify which container/process was killed
2. **Add swap** (temporary relief):
   ```bash
   fallocate -l 4G /swapfile
   chmod 600 /swapfile
   mkswap /swapfile
   swapon /swapfile
   echo '/swapfile none swap sw 0 0' >> /etc/fstab
   ```
3. **Reduce container limits:** Edit compose file, reduce memory limits
4. **Stop memory-heavy services:** Stop non-critical containers
5. **Long-term:** Add physical RAM

**Prevention:**
- Set appropriate memory limits on containers
- Monitor memory usage trends
- Keep 20% headroom

---

#### 5. HighCPUSaturation (P1)

**Symptom:** CPU usage >90% for 10 minutes

**Impact:** Slow response times, throttling

**Diagnosis:**
```bash
# Check per-CPU usage
docker exec $(docker ps -q -f name=node-exporter | head -1) \
  cat /proc/stat | grep cpu

# Check top processes
docker stats --no-stream | sort -k3 -h

# Check system processes
top -b -n 1 | head -20

# Check CPU by container
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}"
```

**Resolution:**
1. **Identify CPU hogs:**
   ```bash
   docker stats --no-stream | sort -k3 -h | head -10
   ```
2. **Consider scaling:**
   - If it's a scalable service: Add replicas
   - If single-instance: Move to less-loaded node
3. **Check for CPU-intensive tasks:**
   - Media transcoding (Jellyfin)
   - Database queries
   - Backup jobs
4. **Reschedule:** Update placement constraints in compose
5. **Scale up:** Add CPU resources (if host at capacity)

---

#### 6. HighMemoryUsage (P1)

**Symptom:** Memory usage >85% for 10 minutes

**Impact:** Risk of OOM kills, performance degradation

**Diagnosis:**
```bash
# Check memory usage
free -h

# Check container memory
docker stats --no-stream | sort -k4 -h

# Check system memory
ps aux --sort=-%mem | head -20

# Check swap usage
free -h | grep Swap
```

**Resolution:**
1. **Identify memory hogs:**
   ```bash
   docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}" | sort -k2 -hr | head -10
   ```
2. **Check for leaks:** Monitor memory growth over time
3. **Reduce limits:** Lower container memory limits if appropriate
4. **Restart bloated containers:** `docker service update --force <service>`
5. **Add memory:** Physical RAM or swap

---

#### 7. ServiceRestartingTooFrequently (P1)

**Symptom:** `rate(swarm_task_restart_total[10m]) > 0.1`

**Impact:** Service instability, potential data loss

**Diagnosis:**
```bash
# Check restart count
docker service ps <service> --no-trunc

# Check service logs
docker service logs <service> --tail 200

# Check service config
docker service inspect <service>

# Check resource limits
docker service inspect <service> --format '{{.Spec.TaskTemplate.Resources}}'
```

**Resolution:**
1. **Check logs for error:** Look for application errors
2. **Check for OOM:** Look for "out of memory" in logs
3. **Check resource limits:** Increase if constrained
4. **Check health check:** Ensure health check is correct
5. **Verify config:** Check environment variables, mounts
6. **Force update:** `docker service update --force <service>`

---

#### 8. DiskSpaceWarning (P2)

**Symptom:** Disk usage >80% for 15 minutes

**Impact:** Approaching critical, need to plan cleanup

**Diagnosis:**
```bash
# Check which disk
df -h | grep -E "(80|90|[1-9][0-9])%"

# Project time to full
# Calculate growth rate from metrics
curl -G 'http://localhost:8428/api/v1/query' \
  --data-urlencode 'query=predict_linear(node_filesystem_avail_bytes[1h], 7*24*3600)' | jq .
```

**Resolution:**
1. **Plan cleanup within 24 hours**
2. **Quick cleanup options:**
   - Docker: `docker system prune -a --volumes`
   - Logs: `journalctl --vacuum-time=3d`
   - Old backups: Delete in `/backup`
3. **Expand disk** (if regularly hitting 80%)
4. **Move data** to network storage

---

### Dashboard Inventory

**Priority 1 (Deploy Immediately):**

1. **Docker Swarm Monitoring** (ID: 18509)
   - **Why:** Overall cluster health, node status, service availability
   - **Key panels:** Node health, service replicas, task states, overlay network metrics
   - **Use case:** Daily overview, triage dashboard

2. **Node Exporter Full** (ID: 1860)
   - **Why:** Detailed host-level metrics for each node
   - **Key panels:** CPU, memory, disk, network, temperatures
   - **Use case:** Investigate host-level issues

3. **Docker Containers** (ID: 179)
   - **Why:** Per-container resource usage
   - **Key panels:** Container CPU, memory, network, I/O
   - **Use case:** Identify resource-hungry containers

**Priority 2 (Create After Phase 3):**

4. **VictoriaMetrics Cluster** (Custom)
   - **Why:** Monitor observability stack health
   - **Key panels:** VM metrics, ingestion rate, storage growth, query performance
   - **Use case:** Ensure observability isn't SPOF

5. **Loki Log Metrics** (Custom)
   - **Why:** Monitor log pipeline health
   - **Key panels:** Ingestion rate, label cardinality, query latency
   - **Use case:** Ensure logs flowing

**Priority 3 (Create During Phase 4):**

6. **Capacity Planning** (Custom)
   - **Why:** Predict resource exhaustion
   - **Key panels:** 30-day trends, predictions, growth rates
   - **Use case:** Planning upgrades/cleanup

7. **Alerting Overview** (Custom)
   - **Why:** Central view of all alerts
   - **Key panels:** Alert frequency by severity, top alerting services, MTTR
   - **Use case:** Improve alert tuning

### Maintenance Schedule

**Daily (Automated):**
- [ ] Check critical alerts via Telegram
- [ ] Verify observability stack services running: `docker service ls | grep observability`
- [ ] Check storage usage: `df -h | grep -E "(victoria|loki|grafana)"`

**Weekly (15 min):**
- [ ] Review Grafana dashboards for anomalies
- [ ] Check Alertmanager for firing alerts
- [ ] Verify backup jobs completed
- [ ] Review disk usage trends

**Monthly (1 hour):**
- [ ] Review and update alert rules (adjust thresholds)
- [ ] Check VictoriaMetrics storage growth, adjust retention if needed
- [ ] Review dashboard performance, optimize slow queries
- [ ] Test restore procedure (restore to test environment)
- [ ] Review and rotate secrets (passwords, API tokens)
- [ ] Update dashboards and documentation

**Quarterly (2 hours):**
- [ ] Full backup audit (verify all backups working)
- [ ] Disaster recovery test (failover to backup)
- [ ] Capacity planning review (plan upgrades)
- [ ] Security audit (check for vulnerabilities, update images)
- [ ] Cost/benefit review (is observability providing value?)

**On-Demand:**
- [ ] After any major incident: Review alert coverage, update runbooks
- [ ] After adding new services: Add monitoring dashboards
- [ ] After infrastructure changes: Update placement constraints

---

## Definition of Done

A phase is complete when ALL of the following are true:

### Phase 0 (Prerequisites) - Complete When:
- [ ] Node labels verified on both nodes
- [ ] Overlay network `homelab-net` exists and is attachable
- [ ] 100GB+ storage available on Xeon01
- [ ] Secrets directory created and gitignored
- [ ] Docker Swarm secrets deployed (telegram, grafana password)

### Phase 1 (Metrics) - Complete When:
- [ ] node-exporter and cadvisor running on ALL nodes
- [ ] VictoriaMetrics running on Xeon01, ingesting metrics
- [ ] Grafana accessible via https://grafana.homelab
- [ ] VictoriaMetrics datasource tests OK in Grafana
- [ ] At least 3 community dashboards imported and showing data
- [ ] No gaps in metrics data (check last 1 hour)
- [ ] Resource usage within budget (4-8GB RAM)

### Phase 2 (Alerting) - Complete When:
- [ ] Alertmanager deployed and accessible via https://alerts.homelab
- [ ] vmalert running and evaluating rules
- [ ] All P0 and P1 alert rules loaded without errors
- [ ] Test alert generated and delivered to Telegram
- [ ] Resolution notification received and verified
- [ ] Runbooks documented for all P0 alerts
- [ ] Inhibition rules tested and working

### Phase 3 (Logging) - Complete When:
- [ ] Loki deployed on Xeon01 and API responding
- [ ] Promtail running on ALL nodes
- [ ] Logs visible in Grafana Explore
- [ ] Test logs generated and ingested successfully
- [ ] Retention configured to 7 days
- [ ] Log query performance acceptable (<5s for 1h range)

### Phase 4 (Refinement) - Complete When:
- [ ] SLO alert rules deployed and documented
- [ ] Noise reduction rules tested and effective
- [ ] Capacity planning dashboard created and functional
- [ ] Resource usage optimized and within budget
- [ ] No persistent noisy alerts (tuned thresholds)

### Phase 5 (Tracing) - Complete When:
- [ ] Tempo deployed and API responding
- [ ] OTEL collectors running on all nodes
- [ ] Tempo datasource configured in Grafana
- [ ] Test traces generated and queryable
- [ ] Trace-to-logs correlation working

### Overall Program - Complete When:
- [ ] All P0 and P1 tasks complete (Phases 0-4)
- [ ] All acceptance criteria met for each phase
- [ ] Documentation complete and up-to-date
- [ ] Team trained on runbooks and dashboards
- [ ] Backup and restore procedures tested
- [ ] Maintenance schedule established
- [ ] No critical bugs or known issues

---

**Plan complete and saved to `docs/plans/2025-01-09-docker-swarm-observability-implementation.md`.**

**Two execution options:**

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

**Which approach?**
