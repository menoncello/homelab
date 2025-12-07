# 🚀 Homelab Deployment Guide
## Step-by-Step Deployment Instructions

### 📋 Prerequisites Checklist

Before starting deployment, ensure you have:

#### 1. **Proxmox Environment**
- [ ] Proxmox VE server installed and running
- [ ] Proxmox API access enabled
- [ ] Network connectivity to Proxmox server
- [ ] Sufficient storage space (500GB+ recommended)

#### 2. **Local Environment**
- [ ] Terraform installed (v1.0+)
- [ ] Docker and Docker Compose installed
- [ ] SSH access to Proxmox server
- [ ] Ubuntu 22.04 ISO image in Proxmox

#### 3. **API Credentials**
- [ ] Proxmox user with API permissions
- [ ] API token ID and secret generated
- [ ] Domain name configured (if using external access)

---

## 🎯 Phase 1: Environment Setup

### Step 1: Configure Terraform Variables
```bash
# Navigate to terraform directory
cd terraform

# Copy and edit variables file
cp terraform.tfvars.example terraform.tfvars

# Edit with your Proxmox details
nano terraform.tfvars
```

**Required Variables:**
```hcl
# Proxmox Connection
proxmox_api_url = "https://your-proxmox-server:8006/api2/json"
proxmox_user = "root@pam"
proxmox_password = "your-password"
proxmox_api_token_id = "your-token-id"
proxmox_api_token_secret = "your-token-secret"
proxmox_tls_insecure = true

# Network Configuration
domain = "your-domain.com"
vm_gateway = "192.168.1.1"
vm_dns = "192.168.1.1"

# VM Resources
vm_storage_pool = "local-lvm"
vm_template_name = "ubuntu-2204-cloud-init"
```

### Step 2: Configure Docker Environment
```bash
# Navigate to docker-compose directory
cd docker-compose

# Create environment file
cp .env.example .env

# Edit environment variables
nano .env
```

**Required Environment Variables:**
```bash
# Domain Configuration
DOMAIN=your-domain.com
TZ=America/Sao_Paulo

# Database Credentials
MYSQL_ROOT_PASSWORD=your-mysql-password
POSTGRES_PASSWORD=your-postgres-password

# Application Credentials
GRAFANA_ADMIN_PASSWORD=your-grafana-password
NEXTCLOUD_ADMIN_PASSWORD=your-nextcloud-password
```

---

## 🏗️ Phase 2: Infrastructure Deployment

### Step 3: Create Ubuntu Cloud-Init Template

**IMPORTANT:** You must create the Ubuntu cloud-init template manually in Proxmox first:

1. **Download Ubuntu 22.04 Cloud Image:**
   ```bash
   # Download on Proxmox server
   wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
   ```

2. **Create VM Template in Proxmox:**
   - Create new VM (ID: 9000)
   - Use downloaded cloud image
   - Configure Cloud-Init settings
   - Install QEMU Guest Agent
   - Convert to template

3. **Or Use Script (Alternative):**
   ```bash
   # If you have the template creation script
   ./scripts/create-ubuntu-template.sh
   ```

### Step 4: Deploy Infrastructure
```bash
# From project root
./scripts/homelab.sh deploy infra
```

**What this does:**
- Initializes Terraform
- Creates all 7 VMs
- Configures networking
- Sets up cloud-init

**Expected Output:**
```
✅ Infrastructure deployment completed
📊 VMs created: 7/7
🌐 Network configured
```

---

## 🐳 Phase 3: Services Deployment

### Step 5: Deploy All Services
```bash
# Deploy complete stack
./scripts/homelab.sh deploy services
```

**Or deploy in phases:**
```bash
# Deploy databases first
./scripts/deployment/deploy.sh stacks databases

# Then monitoring
./scripts/deployment/deploy.sh stacks monitoring

# Then media services
./scripts/deployment/deploy.sh stacks media

# Then productivity
./scripts/deployment/deploy.sh stacks prod-services

# Finally books
./scripts/deployment/deploy.sh stacks books
```

### Step 6: Configure Reverse Proxy
```bash
# Deploy nginx-proxy
./scripts/homelab.sh deploy nginx-proxy

# Deploy Cloudflare tunnel (for external access)
./scripts/homelab.sh deploy cloudflare
```

---

## 🔧 Phase 4: Configuration & Verification

### Step 7: Run Health Checks
```bash
# Check all services status
./scripts/homelab.sh status

# Run health checks
./scripts/homelab.sh monitor health
```

### Step 8: Access Services

**Local Access URLs:**
- **Grafana**: http://192.168.31.201:3000 (admin/admin)
- **Jellyfin**: http://192.168.31.151:8096
- **Nextcloud**: http://192.168.31.202:8081
- **Nginx Proxy Manager**: http://192.168.31.200:81 (admin@example.com/admin)

**External Access (if Cloudflare configured):**
- **Your services will be available via your domain**

### Step 9: Initial Configuration

**Grafana Setup:**
1. Login with admin/admin
2. Change password
3. Import dashboards from config/grafana/dashboards/

**Nextcloud Setup:**
1. Create admin account
2. Configure storage
3. Install apps from config/nextcloud/apps/

**Jellyfin Setup:**
1. Add media libraries
2. Configure metadata
3. Set up users

---

## 🔒 Phase 5: Security & Backup

### Step 10: Configure Security
```bash
# Change default passwords
nano docker-compose/.env

# Update firewall rules
./scripts/maintenance/system-maintenance.sh security

# Generate SSL certificates (if not using Cloudflare)
./scripts/deployment/deploy.sh ssl
```

### Step 11: Create First Backup
```bash
# Create complete backup
./scripts/homelab.sh backup

# Verify backup
ls -la /opt/homelab-backups/
```

---

## 📊 Phase 6: Monitoring & Maintenance

### Step 12: Set Up Monitoring
```bash
# Open monitoring dashboard
./scripts/homelab.sh monitor

# Configure alerts
# Edit SLACK_WEBHOOK_URL or DISCORD_WEBHOOK_URL in scripts/monitoring/monitoring.sh
```

### Step 13: Schedule Maintenance
```bash
# Set up cron jobs for automated maintenance
crontab -e

# Add these lines:
0 2 * * * /path/to/homelab/scripts/homelab.sh backup
0 3 * * 0 /path/to/homelab/scripts/homelab.sh maintenance
0 4 * * * /path/to/homelab/scripts/homelab.sh update clean
```

---

## 🛠️ Common Commands Reference

### Service Management
```bash
# View status
./scripts/homelab.sh status

# View logs
./scripts/homelab.sh logs [service-name]

# Restart service
./scripts/homelab.sh restart [service-name]

# Stop service
./scripts/homelab.sh stop [service-name]
```

### Updates & Maintenance
```bash
# Update all services
./scripts/homelab.sh update

# Update specific stack
./scripts/homelab.sh update monitoring

# Run maintenance
./scripts/homelab.sh maintenance

# Clean unused resources
./scripts/homelab.sh update clean
```

### Backup & Restore
```bash
# Create backup
./scripts/homelab.sh backup

# Restore from backup
./scripts/homelab.sh restore backup-name

# List available backups
ls /opt/homelab-backups/
```

---

## 🚨 Troubleshooting

### Common Issues

**1. Terraform Permission Errors**
```bash
# Check Proxmox user permissions
# Ensure user has: VM.Audit, VM.Config.Disk, VM.Config.CPU, VM.Config.Memory
```

**2. Docker Service Not Starting**
```bash
# Check logs
./scripts/homelab.sh logs service-name

# Check disk space
./scripts/homelab.sh maintenance disk
```

**3. Network Connectivity Issues**
```bash
# Check VM networking
ssh root@vm-ip "ip a"

# Check DNS resolution
nslookup your-domain.com
```

**4. Service Health Check Fails**
```bash
# Manual health check
curl http://service-ip:port

# Restart affected services
./scripts/homelab.sh restart service-name
```

### Getting Help

1. **Check logs**: `./scripts/homelab.sh logs`
2. **Run diagnostics**: `./scripts/homelab.sh config doctor`
3. **Check system resources**: `./scripts/homelab.sh monitor system`
4. **Review documentation**: Check individual README files in each directory

---

## ✅ Success Criteria

Your deployment is successful when:

- [ ] All 7 VMs are running in Proxmox
- [ ] Docker containers are running without errors
- [ ] All services are accessible via their URLs
- [ ] Monitoring dashboard shows healthy services
- [ ] Backup has been created successfully
- [ ] External access (if configured) is working

---

**🎉 Once complete, your homelab will be running with 46+ services, automated backups, monitoring, and external access!**