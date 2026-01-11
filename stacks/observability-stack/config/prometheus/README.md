# VictoriaMetrics Scrape Configuration

This directory contains the Prometheus-compatible configuration for VictoriaMetrics scrape targets.

## File Structure

```
config/prometheus/
├── prometheus.yml          # Main scrape configuration
└── README.md              # This file
```

## Configuration Overview

### Global Settings

- **Scrape Interval:** 15 seconds
- **Evaluation Interval:** 15 seconds
- **External Labels:**
  - `cluster: homelab`
  - `env: production`
  - `datacenter: home`

### Scrape Jobs

#### 1. Docker Swarm Service Discovery (`dockerswarm`)

Discovers and scrapes all Docker Swarm services labeled with `prometheus.io.scrape=true`.

**Configuration:**
- **SD Mechanism:** Docker Swarm API via unix socket
- **Role:** tasks (container instances)
- **Refresh Interval:** 30 seconds

**Relabel Configs:**
1. Filter services with `prometheus.io.scrape=true`
2. Extract job name from service name (strips `observability_` prefix)
3. Set instance label from node hostname
4. Set service label from service name
5. Map prometheus.io port labels to container ports
6. Apply all prometheus.io labels as metric labels

**Service Labeling Example:**
```yaml
services:
  node-exporter:
    deploy:
      labels:
        prometheus.io.scrape: "true"
        prometheus.io.port: "9100"
        prometheus.io.path: "/metrics"
```

#### 2. VictoriaMetrics Self-Monitoring (`victoriametrics`)

Static configuration for VictoriaMetrics own metrics.

**Configuration:**
- **Target:** localhost:8428
- **Labels:**
  - `instance: xenon01`

## Usage

### Mounting in Docker Compose

```yaml
volumes:
  - ./config/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
```

### Command Line Flag

```yaml
command:
  - "-promscrape.config=/etc/prometheus/prometheus.yml"
```

## Validation

Validate the configuration syntax:

```bash
# Using Python (macOS/NixOS compatible)
python3 -c "
import yaml
config = yaml.safe_load(open('config/prometheus/prometheus.yml'))
print('Config is valid!')
print(f'Jobs: {[c[\"job_name\"] for c in config[\"scrape_configs\"]]}')
"

# Using promtool (Linux)
docker run --rm -v $(pwd)/config/prometheus:/workdir \
  prom/prometheus:latest promtool check config /workdir/prometheus.yml
```

## Troubleshooting

### Services Not Being Scraped

1. Check service labels:
   ```bash
   docker service inspect observability_node-exporter --format '{{json .Spec.Labels}}'
   ```

2. Verify scrape configuration:
   ```bash
   docker logs observability_victoriametrics -f | grep scrape
   ```

3. Test service discovery:
   ```bash
   curl http://localhost:9100/metrics
   ```

### Relabel Config Debugging

To see what labels are being applied:

1. Check VictoriaMetrics logs for relabel trace
2. Use `http://victoriametrics:8428/victoriametrics/vmui` to explore targets
3. Query `up{job="dockerswarm"}` to see discovered targets

## Adding New Services

To enable scraping for a new service:

1. Add labels to service in docker-compose.yml:
   ```yaml
   deploy:
     labels:
       prometheus.io.scrape: "true"
       prometheus.io.port: "PORT"
       prometheus.io.path: "/metrics"
   ```

2. Redeploy the service:
   ```bash
   docker stack deploy -c docker-compose.yml observability
   ```

3. Wait up to 30s for SD refresh
4. Verify in VictoriaMetrics UI

## Reference

- [VictoriaMetrics Service Discovery](https://docs.victoriametrics.com/vmagent.html#kubernetes-service-discoveries)
- [Prometheus relabel_config](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#relabel_config)
- [Docker Swarm SD configs](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#dockerswarm_sd_config)

---

**Last Updated:** 2025-01-09
**Maintained by:** @eduardo
