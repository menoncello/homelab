# Homelab Infrastructure Terraform Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Deploy complete homelab infrastructure on Proxmox cluster using Terraform with monitoring, media services, and book management automation.

**Architecture:** Multi-VM deployment on Proxmox cluster (Helios GPU + Xeon RAM), Docker Compose services per VM, centralized storage, reverse proxy with SSL, monitoring with Prometheus/Grafana.

**Tech Stack:** Proxmox VE 9.1, Terraform, Docker Compose, Ubuntu/Debian, Cloudflare Tunnel, Nginx Proxy Manager, GPU Passthrough.

---

## Task 1: Infrastructure Foundation Setup

**Files:**
- Create: `terraform/main.tf`
- Create: `terraform/variables.tf`
- Create: `terraform/provider.tf`
- Create: `terraform/outputs.tf`
- Create: `terraform/terraform.tfvars.example`

**Step 1: Write provider configuration**

```hcl
# provider.tf
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "~> 3.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "proxmox" {
  pm_api_url = var.proxmox_api_url
  pm_user    = var.proxmox_user
  pm_password = var.proxmox_password
  pm_tls_insecure = true
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
```

**Step 2: Define variables**

```hcl
# variables.tf
variable "proxmox_api_url" {
  description = "Proxmox API URL"
  type        = string
  sensitive   = true
}

variable "proxmox_user" {
  description = "Proxmox API user"
  type        = string
  sensitive   = true
}

variable "proxmox_password" {
  description = "Proxmox API password"
  type        = string
  sensitive   = true
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token"
  type        = string
  sensitive   = true
}

variable "domain" {
  description = "Base domain for services"
  type        = string
  default     = "homelab.local"
}

variable "helios_node" {
  description = "Proxmox node name for Helios server"
  type        = string
  default     = "pve-helios"
}

variable "xeon_node" {
  description = "Proxmox node name for Xeon server"
  type        = string
  default     = "pve-xeon"
}
```

**Step 3: Create example variables file**

```hcl
# terraform.tfvars.example
proxmox_api_url = "https://192.168.31.75:8006/api2/json"
proxmox_user = "root@pam"
proxmox_password = "your_password_here"
cloudflare_api_token = "your_cloudflare_token_here"
domain = "your-domain.com"
helios_node = "pve-helios"
xeon_node = "pve-xeon"
```

**Step 4: Initialize Terraform**

Run: `terraform init`
Expected: SUCCESS - Providers initialized

**Step 5: Commit**

```bash
git add terraform/provider.tf terraform/variables.tf terraform/terraform.tfvars.example
git commit -m "feat: add Terraform provider and variable configuration"
```

---

## Task 2: VM Templates Creation

**Files:**
- Create: `terraform/templates/ubuntu-cloud-init.yaml`
- Create: `terraform/templates/debian-cloud-init.yaml`
- Create: `terraform/modules/vm-template/main.tf`
- Create: `terraform/modules/vm-template/variables.tf`
- Create: `terraform/modules/vm-template/outputs.tf`

**Step 1: Write Ubuntu cloud-init template**

```yaml
# terraform/templates/ubuntu-cloud-init.yaml
#cloud-config
package_update: true
package_upgrade: true
packages:
  - curl
  - wget
  - git
  - vim
  - htop
  - docker.io
  - docker-compose
  - qemu-guest-agent

runcmd:
  - systemctl enable docker
  - systemctl start docker
  - systemctl enable qemu-guest-agent
  - systemctl start qemu-guest-agent
  - usermod -aG docker ubuntu

write_files:
  - path: /etc/ssh/sshd_config
    content: |
      PasswordAuthentication no
      PubkeyAuthentication yes
      PermitRootLogin no
    append: true

  - path: /etc/motd
    content: |
      ========================================
      Homelab VM - Managed by Terraform
      ========================================
```

**Step 2: Write VM template module**

```hcl
# terraform/modules/vm-template/main.tf
resource "proxmox_vm_qemu" "vm" {
  name        = var.vm_name
  target_node = var.target_node
  clone       = var.clone_template

  cores       = var.cpu_cores
  memory      = var.memory_mb
  balloon     = var.memory_mb

  os_type     = "cloud-init"
  cloudinit_cdrom_storage = var.storage_pool

  boot {
    type = "order"
    order = ["scsi0", "ide2"]
  }

  disk {
    slot    = "scsi0"
    type    = "disk"
    storage = var.storage_pool
    size    = "${var.disk_size_gb}G"
    cache   = "writeback"
    iothread = true
  }

  network {
    model   = "virtio"
    bridge  = "vmbr0"
    tag     = var.vlan_tag
  }

  ipconfig0 = "ip=${var.ip_address}/24,gw=192.168.31.1"

  lifecycle {
    ignore_changes = [cloudinit_cdrom_storage]
  }
}

data "template_file" "cloudinit" {
  template = file("${path.module}/../../templates/${var.cloudinit_template}")
}

resource "proxmox_cloud_init_disk" "ci" {
  name    = "${var.vm_name}-cloudinit"
  vm_id   = proxmox_vm_qemu.vm.vm_id
  storage = var.storage_pool

  sshuser_keys = var.ssh_public_keys

  user_data = data.template_file.cloudinit.rendered
}
```

**Step 3: Add template variables**

```hcl
# terraform/modules/vm-template/variables.tf
variable "vm_name" {
  description = "VM name"
  type        = string
}

variable "target_node" {
  description = "Proxmox target node"
  type        = string
}

variable "clone_template" {
  description = "Template to clone from"
  type        = string
  default     = "ubuntu-2204-cloudinit"
}

variable "cpu_cores" {
  description = "Number of CPU cores"
  type        = number
}

variable "memory_mb" {
  description = "Memory in MB"
  type        = number
}

variable "disk_size_gb" {
  description = "Disk size in GB"
  type        = number
}

variable "storage_pool" {
  description = "Storage pool name"
  type        = string
}

variable "ip_address" {
  description = "Static IP address"
  type        = string
}

variable "vlan_tag" {
  description = "VLAN tag"
  type        = number
  default     = 30
}

variable "cloudinit_template" {
  description = "Cloud-init template file"
  type        = string
  default     = "ubuntu-cloud-init.yaml"
}

variable "ssh_public_keys" {
  description = "SSH public keys"
  type        = list(string)
}
```

**Step 4: Add module outputs**

```hcl
# terraform/modules/vm-template/outputs.tf
output "vm_id" {
  value = proxmox_vm_qemu.vm.vm_id
}

output "vm_ip" {
  value = var.ip_address
}

output "vm_name" {
  value = proxmox_vm_qemu.vm.name
}
```

**Step 5: Commit**

```bash
git add terraform/templates/ terraform/modules/vm-template/
git commit -m "feat: add VM templates and cloud-init configuration"
```

---

## Task 3: Infrastructure VMs

**Files:**
- Create: `terraform/vms/main.tf`
- Create: `terraform/vms/variables.tf`
- Create: `terraform/vms/outputs.tf`

**Step 1: Write infrastructure VMs**

```hcl
# terraform/vms/main.tf
module "infra_monitoring" {
  source = "../modules/vm-template"

  vm_name        = "infra-monitoring"
  target_node   = var.xeon_node
  cpu_cores      = 2
  memory_mb      = 4096
  disk_size_gb   = 80
  storage_pool   = "local-zfs"
  ip_address     = "192.168.31.201"
  cloudinit_template = "ubuntu-cloud-init.yaml"
  ssh_public_keys = var.ssh_public_keys
}

module "media_server" {
  source = "../modules/vm-template"

  vm_name        = "media-server"
  target_node   = var.helios_node
  cpu_cores      = 4
  memory_mb      = 16384
  disk_size_gb   = 200
  storage_pool   = "local-zfs"
  ip_address     = "192.168.31.151"
  cloudinit_template = "ubuntu-cloud-init.yaml"
  ssh_public_keys = var.ssh_public_keys
}

module "prod_services" {
  source = "../modules/vm-template"

  vm_name        = "prod-services"
  target_node   = var.xeon_node
  cpu_cores      = 4
  memory_mb      = 16384
  disk_size_gb   = 200
  storage_pool   = "local-zfs"
  ip_address     = "192.168.31.202"
  cloudinit_template = "ubuntu-cloud-init.yaml"
  ssh_public_keys = var.ssh_public_keys
}

module "databases" {
  source = "../modules/vm-template"

  vm_name        = "databases"
  target_node   = var.xeon_node
  cpu_cores      = 4
  memory_mb      = 32768
  disk_size_gb   = 300
  storage_pool   = "local-zfs"
  ip_address     = "192.168.31.203"
  cloudinit_template = "ubuntu-cloud-init.yaml"
  ssh_public_keys = var.ssh_public_keys
}

module "books_server" {
  source = "../modules/vm-template"

  vm_name        = "books-server"
  target_node   = var.xeon_node
  cpu_cores      = 4
  memory_mb      = 8192
  disk_size_gb   = 500
  storage_pool   = "local-zfs"
  ip_address     = "192.168.31.205"
  cloudinit_template = "ubuntu-cloud-init.yaml"
  ssh_public_keys = var.ssh_public_keys
}

# Gaming VM with GPU passthrough
resource "proxmox_vm_qemu" "gaming_vm" {
  name        = "gaming-vm"
  target_node = var.helios_node
  clone       = "win11-template"

  cores       = 6
  memory      = 24576

  machine     = "q35"
  bios        = "ovmf"
  cpu         = "host"

  disk {
    slot    = "scsi0"
    type    = "disk"
    storage = "local-zfs"
    size    = "500G"
    cache   = "writeback"
  }

  network {
    model   = "virtio"
    bridge  = "vmbr0"
  }

  ipconfig0 = "ip=192.168.31.152/24,gw=192.168.31.1"

  # GPU Passthrough
  hostpci {
    host = "01:00.0"  # RTX 3070
    rom  = "true"
    pcie = "true"
  }

  # Additional GPU components
  hostpci {
    host = "01:00.1"
    rom  = "true"
    pcie = "true"
  }

  # VNC Display
  vga {
    type = "virtio"
  }

  args = "-cpu 'host,kvm=on,+topoext,hv_relaxed,hv_spinlocks=0x1fff,hv_vapic,hv_time,hv_vendor_id=0x6b74'"
}

# Home Assistant LXC
resource "proxmox_container" "home_assistant" {
  target_node = var.xeon_node
  hostname    = "home-assistant"
  ostemplate   = "local:vztmpl/homeassistant-amd64-*.tar.zst"

  cores       = 1
  memory      = 2048

  network {
    name   = "eth0"
    bridge = "vmbr0"
    ip     = "192.168.31.204/24"
    gw     = "192.168.31.1"
  }

  mount {
    mp    = "/config"
    type  = "volume"
    volume = "local-zfs:16"
  }

  unprivileged = true
}
```

**Step 2: Add VM variables**

```hcl
# terraform/vms/variables.tf
variable "helios_node" {
  description = "Helios Proxmox node"
  type        = string
}

variable "xeon_node" {
  description = "Xeon Proxmox node"
  type        = string
}

variable "ssh_public_keys" {
  description = "SSH public keys for VMs"
  type        = list(string)
}
```

**Step 3: Add VM outputs**

```hcl
# terraform/vms/outputs.tf
output "infra_monitoring_ip" {
  value = module.infra_monitoring.vm_ip
}

output "media_server_ip" {
  value = module.media_server.vm_ip
}

output "prod_services_ip" {
  value = module.prod_services.vm_ip
}

output "databases_ip" {
  value = module.databases.vm_ip
}

output "books_server_ip" {
  value = module.books_server.vm_ip
}

output "gaming_vm_ip" {
  value = "192.168.31.152"
}

output "home_assistant_ip" {
  value = "192.168.31.204"
}
```

**Step 4: Commit**

```bash
git add terraform/vms/
git commit -m "feat: add infrastructure VMs and gaming VM with GPU passthrough"
```

---

## Task 4: Docker Compose Services

**Files:**
- Create: `docker-compose/monitoring/docker-compose.yml`
- Create: `docker-compose/media/docker-compose.yml`
- Create: `docker-compose/books/docker-compose.yml`
- Create: `docker-compose/prod-services/docker-compose.yml`
- Create: `docker-compose/databases/docker-compose.yml`

**Step 1: Write monitoring stack**

```yaml
# docker-compose/monitoring/docker-compose.yml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./config/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=30d'
      - '--web.enable-lifecycle'
    restart: unless-stopped

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    volumes:
      - grafana_data:/var/lib/grafana
      - ./config/grafana/provisioning:/etc/grafana/provisioning
      - ./config/grafana/dashboards:/var/lib/grafana/dashboards
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_ALLOW_SIGN_UP=false
    restart: unless-stopped

  alertmanager:
    image: prom/alertmanager:latest
    container_name: alertmanager
    ports:
      - "9093:9093"
    volumes:
      - ./config/alertmanager.yml:/etc/alertmanager/alertmanager.yml
      - alertmanager_data:/alertmanager
    restart: unless-stopped

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    restart: unless-stopped

  uptime-kuma:
    image: louislam/uptime-kuma:latest
    container_name: uptime-kuma
    ports:
      - "3001:3001"
    volumes:
      - uptime_kuma_data:/app/data
    restart: unless-stopped

volumes:
  prometheus_data:
  grafana_data:
  alertmanager_data:
  uptime_kuma_data:

networks:
  default:
    name: monitoring
```

**Step 2: Write media stack**

```yaml
# docker-compose/media/docker-compose.yml
version: '3.8'

services:
  jellyfin:
    image: jellyfin/jellyfin:latest
    container_name: jellyfin
    ports:
      - "8096:8096"
    volumes:
      - jellyfin_config:/config
      - jellyfin_cache:/cache
      - /media/media:/media
      - /media/media2:/media2
    environment:
      - JELLYFIN_PublishedServerUrl=https://jellyfin.${DOMAIN}
    devices:
      - /dev/dri:/dev/dri
    restart: unless-stopped

  sonarr:
    image: lscr.io/linuxserver/sonarr:latest
    container_name: sonarr
    ports:
      - "8989:8989"
    volumes:
      - sonarr_config:/config
      - /media/media/tv:/tv
      - /media/downloads:/downloads
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Sao_Paulo
    restart: unless-stopped

  radarr:
    image: lscr.io/linuxserver/radarr:latest
    container_name: radarr
    ports:
      - "7878:7878"
    volumes:
      - radarr_config:/config
      - /media/media/movies:/movies
      - /media/downloads:/downloads
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Sao_Paulo
    restart: unless-stopped

  prowlarr:
    image: lscr.io/linuxserver/prowlarr:latest
    container_name: prowlarr
    ports:
      - "9696:9696"
    volumes:
      - prowlarr_config:/config
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Sao_Paulo
    restart: unless-stopped

  qbittorrent:
    image: lscr.io/linuxserver/qbittorrent:latest
    container_name: qbittorrent
    ports:
      - "8080:8080"
    volumes:
      - qbittorrent_config:/config
      - /media/downloads:/downloads
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Sao_Paulo
      - WEBUI_PORT=8080
    restart: unless-stopped

  bazarr:
    image: lscr.io/linuxserver/bazarr:latest
    container_name: bazarr
    ports:
      - "6767:6767"
    volumes:
      - bazarr_config:/config
      - /media/media/movies:/movies
      - /media/media/tv:/tv
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Sao_Paulo
    restart: unless-stopped

volumes:
  jellyfin_config:
  jellyfin_cache:
  sonarr_config:
  radarr_config:
  prowlarr_config:
  qbittorrent_config:
  bazarr_config:

networks:
  default:
    name: media
```

**Step 3: Write books stack**

```yaml
# docker-compose/books/docker-compose.yml
version: '3.8'

services:
  kavita:
    image: kizaing/kavita:latest
    container_name: kavita
    ports:
      - "5000:5000"
    volumes:
      - /books:/books
      - /manga:/manga
    restart: unless-stopped

  audiobookshelf:
    image: ghcr.io/advplyr/audiobookshelf:latest
    container_name: audiobookshelf
    ports:
      - "13378:80"
    volumes:
      - /audiobooks:/audiobooks
      - /podcasts:/podcasts
      - /config/metadata:/metadata
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Sao_Paulo
    restart: unless-stopped

  stacks:
    image: zelest/stacks:latest
    container_name: stacks
    ports:
      - "7788:7788"
    volumes:
      - stacks_config:/opt/stacks/config
      - /books/downloads:/opt/stacks/download
      - stacks_logs:/opt/stacks/logs
    environment:
      - USERNAME=admin
      - PASSWORD=${STACKS_PASSWORD}
      - SOLVERR_URL=flaresolverr:8191
      - TZ=America/Sao_Paulo
    restart: unless-stopped

  flaresolverr:
    image: ghcr.io/flaresolverr/flaresolverr:latest
    container_name: flaresolverr
    ports:
      - "8191:8191"
    environment:
      - LOG_LEVEL=info
    restart: unless-stopped

  piper-tts:
    image: ghcr.io/drewthomasson/ebook2audiobook-piper-tts:latest
    container_name: piper-tts
    volumes:
      - /books:/input
      - /audiobooks/converted:/output
    environment:
      - PIPER_VOICE=pt_BR-faber-medium
      - PIPER_SPEED=1.0
      - PIPER_NOISE_SCALE=0.667
    restart: unless-stopped

  homarr:
    image: ghcr.io/ajnart/homarr:latest
    container_name: homarr
    ports:
      - "7575:7575"
    volumes:
      - homarr_config:/app/data/configs
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - TZ=America/Sao_Paulo
    restart: unless-stopped

volumes:
  stacks_config:
  stacks_logs:
  homarr_config:

networks:
  default:
    name: books
```

**Step 4: Write prod services stack**

```yaml
# docker-compose/prod-services/docker-compose.yml
version: '3.8'

services:
  nextcloud:
    image: nextcloud:latest
    container_name: nextcloud
    ports:
      - "8081:80"
    volumes:
      - nextcloud_data:/var/www/html
      - /files:/var/www/html/data
    environment:
      - MYSQL_HOST=databases:3306
      - MYSQL_DATABASE=nextcloud
      - MYSQL_USER=nextcloud
      - MYSQL_PASSWORD=${NEXTCLOUD_DB_PASSWORD}
      - NEXTCLOUD_ADMIN_USER=admin
      - NEXTCLOUD_ADMIN_PASSWORD=${NEXTCLOUD_ADMIN_PASSWORD}
    restart: unless-stopped

  gitea:
    image: gitea/gitea:latest
    container_name: gitea
    ports:
      - "3000:3000"
      - "222:22"
    volumes:
      - gitea_data:/data
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    environment:
      - USER_UID=1000
      - USER_GID=1000
      - GITEA__database__DB_TYPE=mysql
      - GITEA__database__HOST=databases:3306
      - GITEA__database__NAME=gitea
      - GITEA__database__USER=gitea
      - GITEA__database__PASSWD=${GITEA_DB_PASSWORD}
    restart: unless-stopped

volumes:
  nextcloud_data:
  gitea_data:

networks:
  default:
    name: prod-services
```

**Step 5: Write databases stack**

```yaml
# docker-compose/databases/docker-compose.yml
version: '3.8'

services:
  mysql:
    image: mysql:8.0
    container_name: mysql
    ports:
      - "3306:3306"
    volumes:
      - mysql_data:/var/lib/mysql
      - ./config/mysql/init.sql:/docker-entrypoint-initdb.d/init.sql
    environment:
      - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
      - MYSQL_PASSWORD=${MYSQL_PASSWORD}
    command: --default-authentication-plugin=mysql_native_password
    restart: unless-stopped

  postgresql:
    image: postgres:15
    container_name: postgresql
    ports:
      - "5432:5432"
    volumes:
      - postgresql_data:/var/lib/postgresql/data
    environment:
      - POSTGRES_DB=${POSTGRES_DB}
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    container_name: redis
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    command: redis-server --appendonly yes
    restart: unless-stopped

volumes:
  mysql_data:
  postgresql_data:
  redis_data:

networks:
  default:
    name: databases
```

**Step 6: Commit**

```bash
git add docker-compose/
git commit -m "feat: add Docker Compose services for all homelab stacks"
```

---

## Task 5: Reverse Proxy & SSL

**Files:**
- Create: `docker-compose/nginx-proxy/docker-compose.yml`
- Create: `nginx-proxy/config/nginx.conf`
- Create: `cloudflare-tunnel/docker-compose.yml`

**Step 1: Write Nginx Proxy Manager**

```yaml
# docker-compose/nginx-proxy/docker-compose.yml
version: '3.8'

services:
  npm:
    image: 'jc21/nginx-proxy-manager:latest'
    container_name: nginx-proxy-manager
    ports:
      - '80:80'     # Public HTTP Port
      - '443:443'   # Public HTTPS Port
      - '81:81'     # Admin Web Port
    volumes:
      - npm_data:/data
      - npm_letsencrypt:/etc/letsencrypt
      - ./config/nginx.conf:/etc/nginx/conf.d/custom.conf
    restart: unless-stopped

volumes:
  npm_data:
  npm_letsencrypt:
```

**Step 2: Write custom Nginx config**

```nginx
# nginx-proxy/config/nginx.conf
# Custom configuration for homelab services
server {
    listen 80;
    server_name ${DOMAIN};
    return 301 https://$server_name$request_uri;
}

# Large file uploads for media services
client_max_body_size 100M;

# API timeouts
proxy_connect_timeout 60s;
proxy_send_timeout    60s;
proxy_read_timeout    60s;

# WebSocket support
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
```

**Step 3: Write Cloudflare Tunnel**

```yaml
# cloudflare-tunnel/docker-compose.yml
version: '3.8'

services:
  cloudflared:
    image: cloudflare/cloudflared:latest
    container_name: cloudflared
    restart: unless-stopped
    command: tunnel --no-autoupdate run --token ${CLOUDFLARE_TUNNEL_TOKEN}
```

**Step 4: Commit**

```bash
git add docker-compose/nginx-proxy/ cloudflare-tunnel/
git commit -m "feat: add reverse proxy with SSL and Cloudflare Tunnel"
```

---

## Task 6: Configuration Files

**Files:**
- Create: `config/prometheus.yml`
- Create: `config/alertmanager.yml`
- Create: `config/grafana/provisioning/datasources/prometheus.yml`
- Create: `config/grafana/provisioning/dashboards/dashboard.yml`
- Create: `config/grafana/dashboards/homelab.json`
- Create: `.env.example`

**Step 1: Write Prometheus config**

```yaml
# config/prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "rules/*.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets:
        - 'node-exporter:9100'

  - job_name: 'docker-containers'
    static_configs:
      - targets: ['cadvisor:8080']

  - job_name: 'proxmox'
    static_configs:
      - targets:
        - '192.168.31.75:9221'  # Helios
        - '192.168.31.208:9221' # Xeon
    scrape_interval: 60s
    metrics_path: /pve
```

**Step 2: Write Alertmanager config**

```yaml
# config/alertmanager.yml
global:
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'your-email@gmail.com'
  smtp_auth_username: 'your-email@gmail.com'
  smtp_auth_password: 'your-app-password'

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'web.hook'

receivers:
  - name: 'web.hook'
    email_configs:
      - to: 'admin@${DOMAIN}'
        subject: '[Homelab Alert] {{ .GroupLabels.alertname }}'
        body: |
          {{ range .Alerts }}
          Alert: {{ .Annotations.summary }}
          Description: {{ .Annotations.description }}
          {{ end }}
    webhook_configs:
      - url: 'http://uptime-kuma:3001/api/push/9c3b3c4e-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
        send_resolved: true

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'dev', 'instance']
```

**Step 3: Write Grafana datasources**

```yaml
# config/grafana/provisioning/datasources/prometheus.yml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true

  - name: Prometheus-Homelab
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    database: prometheus
```

**Step 4: Create environment variables template**

```bash
# .env.example
# Database Credentials
MYSQL_ROOT_PASSWORD=your_secure_mysql_root_password
MYSQL_PASSWORD=your_secure_mysql_password
NEXTCLOUD_DB_PASSWORD=your_secure_nextcloud_db_password
GITEA_DB_PASSWORD=your_secure_gitea_db_password

POSTGRES_DB=homelab
POSTGRES_USER=homelab
POSTGRES_PASSWORD=your_secure_postgres_password

# Service Credentials
NEXTCLOUD_ADMIN_PASSWORD=your_secure_nextcloud_admin_password
STACKS_PASSWORD=your_secure_stacks_password

# Cloudflare
CLOUDFLARE_TUNNEL_TOKEN=your_cloudflare_tunnel_token
CLOUDFLARE_API_TOKEN=your_cloudflare_api_token

# Domain
DOMAIN=your-homelab-domain.com

# Proxmox
PROXMOX_API_URL=https://your-proxmox-ip:8006/api2/json
PROXMOX_USER=root@pam
PROXMOX_PASSWORD=your_proxmox_password
```

**Step 5: Commit**

```bash
git add config/ .env.example
git commit -m "feat: add Prometheus, Alertmanager, and Grafana configuration"
```

---

## Task 7: Deployment Scripts

**Files:**
- Create: `scripts/deploy.sh`
- Create: `scripts/setup-ssh.sh`
- Create: `scripts/backup.sh`
- Create: `scripts/update.sh`

**Step 1: Write main deployment script**

```bash
#!/bin/bash
# scripts/deploy.sh

set -e

echo "🚀 Starting Homelab Deployment..."

# Load environment variables
if [ ! -f .env ]; then
    echo "❌ .env file not found. Copy .env.example and configure it."
    exit 1
fi

source .env

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform is not installed"
    exit 1
fi

# Initialize Terraform
echo "📦 Initializing Terraform..."
cd terraform
terraform init

# Plan Terraform deployment
echo "📋 Planning infrastructure changes..."
terraform plan -out=tfplan

# Apply Terraform
echo "🏗️  Applying infrastructure changes..."
terraform apply tfplan

cd ..

# Deploy Docker services
echo "🐳 Deploying Docker services..."

# Function to deploy to VM
deploy_to_vm() {
    local vm_name=$1
    local vm_ip=$2
    local compose_file=$3

    echo "📦 Deploying $vm_name to $vm_ip..."

    # Copy Docker Compose files
    scp -o StrictHostKeyChecking=no -r docker-compose/$compose_file ubuntu@$vm_ip:/tmp/docker-compose.yml

    # Create necessary directories
    ssh -o StrictHostKeyChecking=no ubuntu@$vm_ip "mkdir -p /media /books /audiobooks /downloads"

    # Deploy services
    ssh -o StrictHostKeyChecking=no ubuntu@$vm_ip "cd /tmp && docker-compose up -d"

    echo "✅ $vm_name deployed successfully"
}

# Deploy services to VMs
deploy_to_vm "infra-monitoring" "$(cd terraform && terraform output -raw infra_monitoring_ip)" "monitoring/docker-compose.yml"
deploy_to_vm "media-server" "$(cd terraform && terraform output -raw media_server_ip)" "media/docker-compose.yml"
deploy_to_vm "prod-services" "$(cd terraform && terraform output -raw prod_services_ip)" "prod-services/docker-compose.yml"
deploy_to_vm "databases" "$(cd terraform && terraform output -raw databases_ip)" "databases/docker-compose.yml"
deploy_to_vm "books-server" "$(cd terraform && terraform output -raw books_server_ip)" "books/docker-compose.yml"

echo "✅ Homelab deployment completed successfully!"
echo "🌐 Access your services:"
echo "   Grafana: http://$(cd terraform && terraform output -raw infra_monitoring_ip):3000"
echo "   Jellyfin: http://$(cd terraform && terraform output -raw media_server_ip):8096"
echo "   Kavita: http://$(cd terraform && terraform output -raw books_server_ip):5000"
echo "   Nextcloud: http://$(cd terraform && terraform output -raw prod_services_ip):8081"
```

**Step 2: Write SSH setup script**

```bash
#!/bin/bash
# scripts/setup-ssh.sh

set -e

SSH_KEY=~/.ssh/id_rsa_homelab.pub

if [ ! -f $SSH_KEY ]; then
    echo "🔑 Generating SSH key for homelab..."
    ssh-keygen -t ed25519 -f ~/.ssh/id_rsa_homelab -C "homelab-key"
fi

echo "📤 Copying SSH key to clipboard..."
pbcopy < $SSH_KEY
echo "SSH key copied to clipboard. Add this to your Proxmox templates."

# Function to setup SSH on VM
setup_vm_ssh() {
    local vm_ip=$1

    echo "🔧 Setting up SSH for VM at $vm_ip..."

    ssh-keyscan -H $vm_ip >> ~/.ssh/known_hosts
    ssh-copy-id -i $SSH_KEY ubuntu@$vm_ip
}

# Setup SSH for all VMs
if [ "$1" = "--all" ]; then
    IPs=(
        "$(cd terraform && terraform output -raw infra_monitoring_ip)"
        "$(cd terraform && terraform output -raw media_server_ip)"
        "$(cd terraform && terraform output -raw prod_services_ip)"
        "$(cd terraform && terraform output -raw databases_ip)"
        "$(cd terraform && terraform output -raw books_server_ip)"
    )

    for ip in "${IPs[@]}"; do
        setup_vm_ssh $ip
    done

    echo "✅ SSH setup completed for all VMs"
fi
```

**Step 3: Write backup script**

```bash
#!/bin/bash
# scripts/backup.sh

set -e

BACKUP_DIR="/backup/$(date +%Y%m%d)"
mkdir -p $BACKUP_DIR

echo "📦 Starting homelab backup..."

# Backup Terraform state
echo "💾 Backing up Terraform state..."
cp terraform/terraform.tfstate $BACKUP_DIR/

# Backup Docker volumes
BACKUP_VMS=(
    "infra-monitoring:prometheus_data,grafana_data,alertmanager_data"
    "media-server:jellyfin_config,sonarr_config,radarr_config"
    "prod-services:nextcloud_data,gitea_data"
    "databases:mysql_data,postgresql_data,redis_data"
    "books-server:stacks_config,homarr_config"
)

for vm_config in "${BACKUP_VMS[@]}"; do
    IFS=':' read -r vm_name volumes <<< "$vm_config"

    echo "📦 Backing up $vm_name volumes: $volumes"

    IFS=',' read -ra VOLUME_ARRAY <<< "$volumes"
    for volume in "${VOLUME_ARRAY[@]}"; do
        vm_ip=$(cd terraform && terraform output -raw "${vm_name//\-/_}_ip")

        ssh ubuntu@$vm_ip "docker run --rm -v $volume:/data -v $BACKUP_DIR:/backup alpine tar czf /backup/$volume.tar.gz -C /data ."
    done
done

echo "✅ Backup completed to $BACKUP_DIR"
```

**Step 4: Write update script**

```bash
#!/bin/bash
# scripts/update.sh

set -e

echo "🔄 Updating homelab services..."

# Update all Docker containers
UPDATE_VMS=(
    "infra-monitoring"
    "media-server"
    "prod-services"
    "databases"
    "books-server"
)

for vm_name in "${UPDATE_VMS[@]}"; do
    vm_ip=$(cd terraform && terraform output -raw "${vm_name//\-/_}_ip")

    echo "🔄 Updating services on $vm_name ($vm_ip)..."

    ssh ubuntu@$vm_ip "cd /tmp && docker-compose pull && docker-compose up -d"

    echo "✅ $vm_name updated"
done

# Clean up unused images
echo "🧹 Cleaning up unused Docker images..."
for vm_name in "${UPDATE_VMS[@]}"; do
    vm_ip=$(cd terraform && terraform output -raw "${vm_name//\-/_}_ip")

    ssh ubuntu@$vm_ip "docker image prune -f"
done

echo "✅ Homelab update completed"
```

**Step 5: Make scripts executable**

```bash
chmod +x scripts/*.sh
```

**Step 6: Commit**

```bash
git add scripts/
git commit -m "feat: add deployment, backup, and maintenance scripts"
```

---

## Task 8: Documentation

**Files:**
- Create: `README.md`
- Create: `docs/setup-guide.md`
- Create: `docs/troubleshooting.md`
- Create: `docs/architecture.md`

**Step 1: Write main README**

```markdown
# Homelab Infrastructure

Complete homelab automation using Proxmox, Terraform, and Docker.

## 🏗️ Architecture

- **Infrastructure**: Proxmox VE 9.1 cluster (2 nodes)
- **Deployment**: Terraform + Docker Compose
- **Services**: Media, Books, Productivity, Monitoring
- **Access**: Cloudflare Tunnel + Nginx Proxy Manager

## 🚀 Quick Start

1. Clone repository:
   ```bash
   git clone <repository-url>
   cd homelab
   ```

2. Configure environment:
   ```bash
   cp .env.example .env
   # Edit .env with your credentials
   ```

3. Deploy infrastructure:
   ```bash
   ./scripts/deploy.sh
   ```

## 📋 Services Overview

| Service | VM | Port | Description |
|---------|----|-----|-------------|
| Grafana | infra-monitoring | 3000 | Monitoring dashboard |
| Jellyfin | media-server | 8096 | Media streaming |
| Sonarr | media-server | 8989 | TV automation |
| Radarr | media-server | 7878 | Movie automation |
| Kavita | books-server | 5000 | Ebook management |
| Audiobookshelf | books-server | 13378 | Audiobook server |
| Nextcloud | prod-services | 8081 | File sharing |
| Gitea | prod-services | 3000 | Git hosting |

## 📚 Documentation

- [Setup Guide](docs/setup-guide.md)
- [Architecture](docs/architecture.md)
- [Troubleshooting](docs/troubleshooting.md)

## 🔧 Maintenance

```bash
# Update all services
./scripts/update.sh

# Create backup
./scripts/backup.sh

# SSH setup
./scripts/setup-ssh.sh --all
```
```

**Step 2: Write setup guide**

```markdown
# Setup Guide

## Prerequisites

- Proxmox VE 9.1 cluster configured
- Terraform >= 1.6.0
- Docker & Docker Compose
- Ubuntu 22.04 Cloud-Init templates

## 1. Proxmox Setup

### Create Ubuntu Cloud-Init Template

1. Download Ubuntu 22.04 Cloud Image:
   ```bash
   wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
   ```

2. Create VM in Proxmox:
   - ID: 9000
   - Name: ubuntu-2204-cloudinit
   - OS: Linux 6.x
   - Storage: local-zfs
   - CPU: 2 cores
   - Memory: 2GB
   - Disk: 8GB

3. Import cloud image and create template

### Configure Network

Create VLAN-aware bridge:
```bash
# In Proxmox shell
pveumctl modify vmbr0 --bridge vlan_aware 1
```

## 2. Terraform Configuration

1. Copy and configure `.env`:
   ```bash
   cp .env.example .env
   # Edit with your credentials
   ```

2. Initialize Terraform:
   ```bash
   cd terraform
   terraform init
   ```

## 3. Storage Setup

### NFS Server (Optional)

For shared storage across VMs:

```bash
# On storage VM
sudo apt install nfs-kernel-server
sudo mkdir -p /media/{movies,tv,books,downloads}
sudo chown -R nobody:nogroup /media

# Add to /etc/exports
/media 192.168.31.0/24(rw,sync,no_subtree_check)
```

### Mount NFS on VMs

Add to `/etc/fstab` on each VM:
```
192.168.31.x:/media /media nfs defaults 0 0
```

## 4. GPU Passthrough (Media Server)

### Proxmox Configuration

1. Enable IOMMU in `/etc/default/grub`:
   ```
   GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on"
   ```

2. Blacklist GPU drivers:
   ```bash
   echo "blacklist nouveau" >> /etc/modprobe.d/blacklist.conf
   echo "blacklist nvidia" >> /etc/modprobe.d/blacklist.conf
   ```

3. Update initramfs and reboot

### Verify GPU Passthrough

```bash
# In VM
lspci -nnk | grep -i nvidia
```

## 5. Domain & SSL

### Cloudflare Setup

1. Create Cloudflare account
2. Add domain
3. Generate API token
4. Create tunnel for external access

### Configure DNS Records

```
grafana.your-domain.com -> Cloudflare Tunnel
jellyfin.your-domain.com -> Cloudflare Tunnel
...
```

## 6. Security Hardening

### Firewall Rules

```bash
# On each VM
sudo ufw enable
sudo ufw allow ssh
sudo ufw allow from 192.168.31.0/24
```

### SSH Configuration

```bash
# Disable password authentication
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart ssh
```
```

**Step 3: Write troubleshooting guide**

```markdown
# Troubleshooting

## Common Issues

### Terraform Issues

**Error: API connection failed**
```bash
# Check Proxmox API access
curl -k -X POST https://your-proxmox:8006/api2/json/access/ticket \
  -d "username=root@pam&password=your_password"
```

**Error: Template not found**
- Verify cloud-init template exists
- Check template name matches configuration

### Docker Issues

**Container won't start**
```bash
# Check logs
docker logs container_name

# Check resources
docker stats

# Clean up
docker system prune -a
```

**Network issues**
```bash
# Check networks
docker network ls
docker network inspect network_name

# Recreate network
docker network create --driver bridge network_name
```

### Service-Specific Issues

#### Jellyfin

**No hardware acceleration**
```bash
# Check GPU access in container
docker exec jellyfin nvidia-smi

# Verify device mapping
docker inspect jellyfin | grep Devices
```

#### Media Automation

**Sonarr/Radarr not downloading**
- Check indexer configuration
- Verify download client connection
- Check folder permissions

#### Books Server

**Stacks Cloudflare errors**
- Verify FlareSolverr is running
- Check proxy configuration
- Review logs for authentication issues

**Piper TTS not working**
```bash
# Check voice model
docker exec piper-tts ls /app/piper_checkpoints

# Test conversion
docker exec piper-tts echo "test" | piper --model pt_BR-faber-medium --output_file test.wav
```

### Monitoring Issues

**Prometheus not scraping**
```bash
# Check targets
curl http://target:port/metrics

# Check configuration
docker exec prometheus promtool check config /etc/prometheus/prometheus.yml
```

### Performance Issues

**High CPU usage**
```bash
# Check container usage
docker stats --no-stream

# Identify resource-intensive containers
docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"
```

**Storage full**
```bash
# Check usage
df -h
docker system df

# Clean up
docker volume prune
docker system prune -a --volumes
```

## Debug Commands

### Network Connectivity

```bash
# Test service reachability
nc -zv target_ip port

# Trace network path
traceroute target_ip

# Check DNS
nslookup domain_name
```

### Service Status

```bash
# Check all services
docker-compose ps

# Restart service
docker-compose restart service_name

# Force recreate
docker-compose up -d --force-recreate service_name
```

### Log Analysis

```bash
# Real-time logs
docker logs -f container_name

# Last 100 lines
docker logs --tail 100 container_name

# Filter logs
docker logs container_name | grep ERROR
```

## Recovery Procedures

### VM Recovery

```bash
# Restore from backup
terraform plan -destroy
terraform apply
# Then
terraform apply
```

### Database Recovery

```bash
# Restore MySQL
docker exec mysql mysql -u root -p database_name < backup.sql

# Restore PostgreSQL
docker exec postgresql psql -U username -d database_name < backup.sql
```

### Container Recovery

```bash
# Stop and remove
docker-compose down

# Start fresh
docker-compose up -d --force-recreate
```
```

**Step 4: Write architecture documentation**

```markdown
# Architecture Overview

## Infrastructure Layout

```
┌─────────────────────────────────────────────────────────────┐
│                    Home Network (192.168.31.0/24)          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────────┐         ┌──────────────────────┐ │
│  │   pve-helios         │         │    pve-xeon         │ │
│  │   (GPU Server)       │         │   (RAM Server)       │ │
│  │   i7 RTX3070         │         │   Xeon 96GB RAM      │ │
│  │                      │         │                      │ │
│  │  ┌────────────────┐  │         │  ┌────────────────┐  │ │
│  │  │ media-server   │  │         │  │ infra-monitoring│  │ │
│  │  │ Jellyfin/Arrs  │  │         │  │ Prometheus/...  │  │ │
│  │  └────────────────┘  │         │  └────────────────┘  │ │
│  │  ┌────────────────┐  │         │  ┌────────────────┐  │ │
│  │  │ gaming-vm      │  │         │  │ prod-services  │  │ │
│  │  │ Windows+GPU    │  │         │  │ Nextcloud/Gitea│  │ │
│  │  └────────────────┘  │         │  └────────────────┘  │ │
│  │                      │         │  ┌────────────────┐  │ │
│  │                      │         │  │ databases      │  │ │
│  │                      │         │  │ MySQL/Postgres │  │ │
│  │                      │         │  └────────────────┘  │ │
│  │                      │         │  ┌────────────────┐  │ │
│  │                      │         │  │ books-server   │  │ │
│  │                      │         │  │ Kavita/Stacks  │  │ │
│  │                      │         │  └────────────────┘  │ │
│  └──────────────────────┘         └──────────────────────┘ │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Management Layer                            │ │
│  │ - Terraform (Infrastructure as Code)                     │ │
│  │ - Docker Compose (Service Orchestration)                │ │
│  │ - Nginx Proxy Manager (Reverse Proxy)                   │ │
│  │ - Cloudflare Tunnel (External Access)                   │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Service Distribution

### Media Services (Helios - GPU Optimized)
- **Jellyfin**: Media streaming with hardware transcoding
- **Sonarr**: TV series automation
- **Radarr**: Movie automation
- **Prowlarr**: Indexer management
- **QBittorrent**: Download client
- **Bazarr**: Subtitle automation

### Infrastructure Services (Xeon - RAM Optimized)
- **Prometheus**: Metrics collection
- **Grafana**: Visualization dashboards
- **Alertmanager**: Alert management
- **Uptime Kuma**: Service monitoring
- **Node Exporter**: System metrics

### Productivity Services (Xeon)
- **Nextcloud**: File sharing/collaboration
- **Gitea**: Git repository hosting
- **PostgreSQL/MySQL**: Database backends

### Knowledge Management (Xeon)
- **Kavita**: Ebook/manga management
- **Audiobookshelf**: Audiobook server
- **Stacks**: Anna's Archive automation
- **FlareSolverr**: Cloudflare bypass
- **Piper TTS**: Text-to-speech conversion

### Specialized Services
- **Gaming VM** (Helios): Windows gaming with GPU passthrough
- **Home Assistant** (LXC): Smart home automation

## Data Flow

```
Internet → Cloudflare Tunnel → Nginx Proxy → Services

Media Pipeline:
  Anna's Archive → Stacks → Kavita → Piper TTS → Audiobookshelf → Playback

Monitoring Pipeline:
  Services → Prometheus → Grafana → Alertmanager → Notifications

Automation Pipeline:
  Sonarr/Radarr → Indexers → Download Clients → Media Organization
```

## Storage Architecture

### Local Storage
- **Fast SSD**: VM disks, databases
- **Large HDD**: Media files, downloads

### Shared Storage Options
- **NFS**: Cross-VM file sharing
- **Local**: VM-specific storage with replication

### Backup Strategy
- **Daily**: Incremental backups
- **Weekly**: Full backups
- **Off-site**: Critical data to external location

## Security Model

### Network Isolation
- VLAN segmentation for service categories
- Firewall rules limiting cross-VLAN traffic
- VPN or tunnel for external access

### Access Control
- SSH key authentication only
- Service-specific user accounts
- API tokens for automation

### Data Protection
- Regular encrypted backups
- SSL/TLS termination at reverse proxy
- No direct internet exposure for internal services

## Monitoring & Observability

### Metrics Collection
- **System**: CPU, memory, disk, network
- **Applications**: Service-specific metrics
- **Infrastructure**: Proxmox cluster metrics

### Alerting
- **Critical**: Service down, resource exhaustion
- **Warning**: High usage, performance degradation
- **Info**: Deployments, configuration changes

### Visualization
- **Dashboards**: System overview, service health
- **Historical**: Trend analysis, capacity planning
- **Real-time**: Current state, active issues
```

**Step 5: Create main .gitignore**

```gitignore
# .gitignore
# Terraform
*.tfstate
*.tfstate.*
.terraform/
.terraform.lock.hcl
terraform.tfvars
tfplan

# Environment variables
.env
*.env
.env.local

# Cloud credentials
cloudflare-token.txt
proxmox-credentials.txt

# Logs
*.log
logs/

# OS
.DS_Store
Thumbs.db

# IDE
.vscode/
.idea/
*.swp
*.swo

# Backup files
*.bak
*.backup
backup/

# Temporary files
tmp/
temp/
.cache/

# Docker volumes (when mounted locally)
volumes/
data/
```

**Step 6: Commit all documentation**

```bash
git add README.md docs/ .gitignore
git commit -m "feat: add comprehensive documentation"
```

---

## Task 9: Testing & Validation

**Files:**
- Create: `tests/infrastructure_test.sh`
- Create: `tests/service_test.sh`
- Create: `tests/load_test.sh`

**Step 1: Write infrastructure tests**

```bash
#!/bin/bash
# tests/infrastructure_test.sh

set -e

echo "🧪 Testing Infrastructure..."

# Test Terraform configuration
echo "📋 Testing Terraform configuration..."
cd terraform
terraform validate
terraform plan -detailed-exitcode
if [ $? -eq 0 ]; then
    echo "✅ Terraform configuration is valid"
else
    echo "❌ Terraform configuration has errors"
    exit 1
fi

# Test VM connectivity
echo "🔌 Testing VM connectivity..."
VMs=(
    "infra-monitoring:22"
    "media-server:22"
    "prod-services:22"
    "databases:22"
    "books-server:22"
)

for vm_config in "${VMs[@]}"; do
    IFS=':' read -r vm_name port <<< "$vm_config"

    vm_ip=$(terraform output -raw "${vm_name//\-/_}_ip")

    if nc -z -w3 $vm_ip $port; then
        echo "✅ $vm_name ($vm_ip:$port) is reachable"
    else
        echo "❌ $vm_name ($vm_ip:$port) is not reachable"
        exit 1
    fi
done

cd ..
echo "✅ Infrastructure tests passed"
```

**Step 2: Write service tests**

```bash
#!/bin/bash
# tests/service_test.sh

set -e

echo "🧪 Testing Services..."

# Load VM IPs
source <(cd terraform && terraform output -json | jq -r 'to_entries[] | "\(.key | ascii_upcase)=\(.value)"')

# Test service endpoints
declare -A SERVICES=(
    ["INFRA_MONITORING_IP"]="3000:Grafana:admin:admin"
    ["INFRA_MONITORING_IP"]="9090:Prometheus::"
    ["INFRA_MONITORING_IP"]="3001:Uptime Kuma::"
    ["MEDIA_SERVER_IP"]="8096:Jellyfin::"
    ["MEDIA_SERVER_IP"]="8989:Sonarr::"
    ["MEDIA_SERVER_IP"]="7878:Radarr::"
    ["PROD_SERVICES_IP"]="8081:Nextcloud::"
    ["PROD_SERVICES_IP"]="3000:Gitea::"
    ["BOOKS_SERVER_IP"]="5000:Kavita::"
    ["BOOKS_SERVER_IP"]="13378:Audiobookshelf::"
    ["BOOKS_SERVER_IP"]="7788:Stacks::"
)

for service_config in "${!SERVICES[@]}"; do
    vm_ip=${!service_config}
    IFS=':' read -r port service username password <<< "${SERVICES[$service_config]}"

    echo "🔍 Testing $service on $vm_ip:$port"

    if curl -s -o /dev/null -w "%{http_code}" $vm_ip:$port | grep -q "200\|403"; then
        echo "✅ $service is responding"

        # Test authentication if credentials provided
        if [ -n "$username" ] && [ -n "$password" ]; then
            if curl -s -o /dev/null -u "$username:$password" -w "%{http_code}" $vm_ip:$port | grep -q "200"; then
                echo "✅ $service authentication working"
            else
                echo "⚠️ $service authentication may need configuration"
            fi
        fi
    else
        echo "❌ $service is not responding"
        exit 1
    fi

    sleep 1  # Rate limiting
done

echo "✅ Service tests passed"
```

**Step 3: Write load tests**

```bash
#!/bin/bash
# tests/load_test.sh

echo "🚀 Running Load Tests..."

# Install Apache Bench if not available
if ! command -v ab &> /dev/null; then
    echo "Installing Apache Bench..."
    sudo apt-get update && sudo apt-get install -y apache2-utils
fi

# Test endpoints
ENDPOINTS=(
    "$(cd terraform && terraform output -raw infra_monitoring_ip):3000"
    "$(cd terraform && terraform output -raw media_server_ip):8096"
    "$(cd terraform && terraform output -raw books_server_ip):5000"
)

for endpoint in "${ENDPOINTS[@]}"; do
    echo "📊 Load testing http://$endpoint"

    # Run 100 requests, 10 concurrent
    result=$(ab -n 100 -c 10 http://$endpoint/ 2>&1)

    if echo "$result" | grep -q "Failed requests:        0"; then
        echo "✅ Load test passed for $endpoint"
        echo "$result" | grep "Requests per second"
    else
        echo "❌ Load test failed for $endpoint"
        echo "$result" | grep "Failed requests"
    fi

    echo "---"
done

echo "✅ Load tests completed"
```

**Step 4: Make tests executable**

```bash
chmod +x tests/*.sh
```

**Step 5: Run tests**

```bash
./tests/infrastructure_test.sh
./tests/service_test.sh
./tests/load_test.sh
```

**Step 6: Commit**

```bash
git add tests/
git commit -m "feat: add comprehensive testing suite"
```

---

## Task 10: Final Integration

**Files:**
- Modify: `terraform/main.tf` - Add final module calls
- Create: `Makefile`
- Create: `VERSION`

**Step 1: Update main Terraform file**

```hcl
# terraform/main.tf
# Add to main.tf (append after existing content)

# Call all VM modules
module "vms" {
  source = "./vms"

  helios_node = var.helios_node
  xeon_node = var.xeon_node
  ssh_public_keys = var.ssh_public_keys
}

# Cloudflare DNS records for services
resource "cloudflare_record" "services" {
  for_each = {
    grafana = module.vms.infra_monitoring_ip
    jellyfin = module.vms.media_server_ip
    kavita = module.vms.books_server_ip
    nextcloud = module.vms.prod_services_ip
    gitea = module.vms.prod_services_ip
    audiobooks = module.vms.books_server_ip
  }

  zone_id = data.cloudflare_zone.main.id
  name    = each.key
  value   = each.value
  type    = "A"
  ttl     = 300
  proxied = true
}

data "cloudflare_zone" "main" {
  name = var.domain
}

# Output all service URLs
output "service_urls" {
  value = {
    grafana    = "https://grafana.${var.domain}"
    jellyfin   = "https://jellyfin.${var.domain}"
    kavita     = "https://kavita.${var.domain}"
    nextcloud  = "https://nextcloud.${var.domain}"
    gitea      = "https://gitea.${var.domain}"
    audiobooks = "https://audiobooks.${var.domain}"
    homarr     = "https://dashboard.${var.domain}"
  }
}
```

**Step 2: Create Makefile**

```makefile
# Makefile
.PHONY: deploy destroy test backup update clean help

# Default target
help:
	@echo "Available commands:"
	@echo "  deploy     - Deploy complete infrastructure"
	@echo "  destroy    - Destroy all infrastructure"
	@echo "  test       - Run all tests"
	@echo "  backup     - Create backup"
	@echo "  update     - Update all services"
	@echo "  plan       - Show Terraform plan"
	@echo "  clean      - Clean up temporary files"

deploy:
	@echo "🚀 Deploying homelab infrastructure..."
	./scripts/deploy.sh

destroy:
	@echo "💥 Destroying infrastructure..."
	cd terraform && terraform destroy -auto-approve

test:
	@echo "🧪 Running tests..."
	./tests/infrastructure_test.sh
	./tests/service_test.sh

test-load:
	@echo "🚀 Running load tests..."
	./tests/load_test.sh

backup:
	@echo "💾 Creating backup..."
	./scripts/backup.sh

update:
	@echo "🔄 Updating services..."
	./scripts/update.sh

plan:
	@echo "📋 Showing Terraform plan..."
	cd terraform && terraform plan

clean:
	@echo "🧹 Cleaning up..."
	find . -name "*.log" -delete
	find . -name "*.tmp" -delete
	docker system prune -f

init:
	@echo "📦 Initializing..."
	cd terraform && terraform init
	./scripts/setup-ssh.sh --all

validate:
	@echo "✅ Validating Terraform..."
	cd terraform && terraform validate

format:
	@echo "🎨 Formatting Terraform..."
	cd terraform && terraform fmt -recursive
```

**Step 3: Create version file**

```bash
# VERSION
1.0.0
```

**Step 4: Final commit**

```bash
git add terraform/main.tf Makefile VERSION
git commit -m "feat: complete homelab infrastructure with Terraform and Docker"
git tag -a v1.0.0 -m "Initial release of homelab infrastructure"
```

---

## Plan Complete!

**Plan complete and saved to `docs/plans/2025-12-07-homelab-terraform-implementation.md`.**

**Two execution options:**

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

**Which approach?**

If you choose **Subagent-Driven**, I'll use the **superpowers:subagent-driven-development** skill to implement this step-by-step with fresh subagents for each task and code review between them.

If you choose **Parallel Session**, you'll open a new session in a git worktree and use **superpowers:executing-plans** to run the entire plan with checkpoints.

**Ready to implement your complete homelab infrastructure?**