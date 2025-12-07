# 🚀 Homelab Deployment Manual
## Complete Step-by-Step Guide for Proxmox Server 192.168.31.237

---

## 📋 Overview

This manual provides a complete, step-by-step deployment guide for your homelab infrastructure running on Proxmox server `192.168.31.237`.

**Target Configuration:**
- **7 Virtual Machines** with specialized roles
- **46+ Docker services** across 5 stacks
- **6 users** with password management
- **Custom applications** with enterprise security
- **Real-time monitoring** and alerting

---

## 🎯 Prerequisites Checklist

### ✅ Before You Begin
- [ ] Proxmox server running at `192.168.31.237`
- [ ] Ubuntu 22.04 cloud-init template created (VM ID: 9000)
- [ ] SSH key access to Proxmox server
- [ ] Proxmox API token generated
- [ ] Docker installed on local machine
- [ ] Domain name configured (optional but recommended)

### 📁 Required Files Structure
```
homelab/
├── terraform/                    # Infrastructure
├── docker-compose/              # Services
│   ├── databases/
│   ├── monitoring/
│   ├── media/
│   ├── prod-services/
│   ├── books/
│   ├── nginx-proxy/
│   └── security/
├── scripts/                     # Automation
├── cloudflare-tunnel/
└── config/
```

---

## 🛠️ Phase 0: Environment Setup

### Step 1: Connect Docker to Remote Server
```bash
# Create Docker context for Proxmox connection
docker context create homelab-proxmox \
  --docker "host=ssh://root@192.168.31.237"

# Activate the context
docker context use homelab-proxmox

# Verify connection
docker context ls
docker version
```

### Step 2: Configure SSH Access
```bash
# Copy your SSH key to the server (if not already done)
ssh-copy-id root@192.168.31.237

# Test SSH connection
ssh root@192.168.31.237 "echo 'SSH connection successful!'"

# Test Docker connection via SSH
ssh root@192.168.31.237 "docker version"
```

---

## ⚙️ Phase 1: Configuration Files Setup

### Step 3: Configure Terraform Variables
```bash
# Edit Terraform configuration
nano terraform/terraform.tfvars
```

**Critical Configuration:**
```hcl
# Proxmox Connection
proxmox_api_url = "https://192.168.31.237:8006/api2/json"
proxmox_user = "root@pam"  # or your API user
proxmox_api_token_id = "your-token-name"
proxmox_api_token_secret = "your-secret-token"
proxmox_tls_insecure = true

# Domain Configuration
domain = "your-domain.com"  # or "homelab.local"

# Network Configuration
vm_gateway = "192.168.1.1"
vm_dns = "192.168.1.1"

# Storage Configuration
vm_storage_pool = "local-lvm"  # or your storage pool name

# VM Template
vm_template_name = "ubuntu-2204-cloud-init"

# SSH Public Key
ssh_public_keys = [
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... YOUR-PUBLIC-KEY-HERE",
]
```

### Step 4: Configure Environment Files
```bash
# Copy all environment files
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
cp docker-compose/.env.example docker-compose/.env
cp docker-compose/nginx-proxy/.env.example docker-compose/nginx-proxy/.env
cp docker-compose/security/.env.example docker-compose/security/.env
cp cloudflare-tunnel/.env.example cloudflare-tunnel/.env
```

**Edit Main Environment File:**
```bash
nano docker-compose/.env
```

**Essential Variables to Configure:**
```bash
# Domain Configuration
DOMAIN=your-homelab-domain.com
TZ=America/Sao_Paulo

# Database Credentials (CHANGE THESE!)
MYSQL_ROOT_PASSWORD=YourSecureMySQLPassword123!
POSTGRES_PASSWORD=YourSecurePostgresPassword123!
MARIADB_ROOT_PASSWORD=YourSecureMariaDBPassword123!

# Service Credentials (CHANGE THESE!)
NEXTCLOUD_ADMIN_PASSWORD=YourSecureNextcloudPassword123!
VAULT_ROOT_TOKEN=hvs.your-very-secure-vault-root-token-32-chars
VAULT_ADMIN_PASSWORD=YourSecureVaultPassword123!
VAULTWARDEN_ADMIN_TOKEN=your-secure-vaultwarden-token

# Media Directories (ensure these exist on server)
MEDIA_DIR=/media/media
DOWNLOADS_DIR=/media/downloads
BOOKS_DIR=/books
FILES_DIR=/files
PHOTOS_DIR=/photos

# Email Configuration (optional)
GF_SMTP_USER=your-email@gmail.com
GF_SMTP_PASSWORD=your-app-password

# Cloudflare (optional)
CLOUDFLARE_TUNNEL_TOKEN=your-cloudflare-tunnel-token
```

**Configure Security Environment:**
```bash
nano docker-compose/security/.env
```

```bash
# Vault Configuration
VAULT_ROOT_TOKEN=hvs.your-super-secure-vault-root-token-here
VAULT_ADMIN_USERNAME=admin
VAULT_ADMIN_PASSWORD=YourSecureVaultAdminPassword123!

# Domain
DOMAIN=your-homelab-domain.com

# Backup Configuration
VAULT_BACKUP_SCHEDULE="0 2 * * *"
VAULT_BACKUP_RETENTION=30
```

---

## 🏗️ Phase 2: Infrastructure Deployment

### Step 5: Validate Terraform Configuration
```bash
# Navigate to Terraform directory
cd terraform

# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Check plan (dry run)
terraform plan
```

### Step 6: Deploy Virtual Machines
```bash
# Apply Terraform configuration
terraform apply

# Type 'yes' when prompted to confirm
# This will create all 7 VMs:
# - monitoring-vm (192.168.31.201)
# - media-server (192.168.31.151)
# - prod-services (192.168.31.202)
# - databases (192.168.31.203)
# - books (192.168.31.204)
# - storage (192.168.31.205)
# - devops (192.168.31.206)

# Verify VM creation
terraform state list
```

### Step 7: Verify VM Deployment
```bash
# Check VMs via SSH
ssh root@192.168.31.237 "qm list"

# Or via Proxmox Web UI
echo "Access Proxmox: https://192.168.31.237:8006"
echo "Check Datacenter → qemu → All VMs should be running"

# Verify VM network connectivity
ssh root@192.168.31.237 "for ip in 201 151 202 203 204 205 206; do ping -c 1 192.168.31.\$ip; done"
```

---

## 🐳 Phase 3: Docker Services Deployment

### Step 8: Transfer Files to Server
```bash
# Create homelab directory on server
ssh root@192.168.31.237 "mkdir -p /opt/homelab"

# Transfer all Docker-related files
rsync -av --progress \
  --exclude='.git' \
  --exclude='terraform' \
  --exclude='.DS_Store' \
  ./ root@192.168.31.237:/opt/homelab/

# Verify transfer
ssh root@192.168.31.237 "ls -la /opt/homelab/"
```

### Step 9: Deploy Services in Dependency Order
```bash
# Connect to server
ssh root@192.168.31.237

# Navigate to homelab directory
cd /opt/homelab

# Make scripts executable
chmod +x scripts/**/*.sh

# 1. Deploy Databases First (CRITICAL)
echo "🗄️ Deploying databases..."
docker-compose -f docker-compose/databases/docker-compose.yml up -d

# Wait for databases to be ready
echo "⏳ Waiting for databases to initialize (120 seconds)..."
sleep 120

# Check database health
docker-compose -f docker-compose/databases/docker-compose.yml ps
```

### Step 10: Deploy Core Services
```bash
# 2. Deploy Monitoring Stack
echo "📊 Deploying monitoring..."
docker-compose -f docker-compose/monitoring/docker-compose.yml up -d

# Wait for monitoring
echo "⏳ Waiting for monitoring services (60 seconds)..."
sleep 60

# 3. Deploy Security Stack
echo "🔐 Deploying security services..."
docker-compose -f docker-compose/security/docker-compose.yml up -d

# Wait for security services
echo "⏳ Waiting for security services (60 seconds)..."
sleep 60

# 4. Setup HashiCorp Vault
echo "🏗️ Setting up Vault..."
./docker-compose/security/scripts/setup-vault.sh

# 5. Deploy Reverse Proxy
echo "🌐 Deploying reverse proxy..."
docker-compose -f docker-compose/nginx-proxy/docker-compose.yml up -d
```

### Step 11: Deploy Application Services
```bash
# Deploy remaining stacks in parallel
echo "🚀 Deploying application services..."

# Start all application stacks simultaneously
docker-compose -f docker-compose/prod-services/docker-compose.yml up -d &
PROD_PID=$!

docker-compose -f docker-compose/media/docker-compose.yml up -d &
MEDIA_PID=$!

docker-compose -f docker-compose/books/docker-compose.yml up -d &
BOOKS_PID=$!

# Wait for all to complete
echo "⏳ Waiting for application stacks to deploy..."
wait $PROD_PID $MEDIA_PID $BOOKS_PID

# Deploy Cloudflare Tunnel (if configured)
if [ -f "cloudflare-tunnel/docker-compose.yml" ]; then
    echo "🌍 Deploying Cloudflare Tunnel..."
    cd cloudflare-tunnel
    docker-compose up -d
    cd ..
fi
```

---

## 🔧 Phase 4: Configuration and Verification

### Step 12: Verify All Services
```bash
# Check all containers are running
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Check stack health
./scripts/homelab.sh status

# Run comprehensive health check
./scripts/monitoring/monitoring.sh health
```

### Step 13: Configure Core Services

#### **Configure Vaultwarden (Password Manager):**
```bash
# Get server IP
SERVER_IP=$(hostname -I | awk '{print $1}')

echo "🔐 Configure Vaultwarden:"
echo "1. Access: http://$SERVER_IP:8080"
echo "2. Click 'Create account'"
echo "3. Setup admin account"
echo "4. Invite 5 additional users"
echo "5. Enable 2FA for all users"

# Open in browser (if on machine with display)
# firefox http://$SERVER_IP:8080 &
```

#### **Configure Grafana:**
```bash
echo "📊 Configure Grafana:"
echo "1. Access: http://$SERVER_IP:3000"
echo "2. Login: admin / admin"
echo "3. Change password immediately"
echo "4. Import dashboards from /opt/homelab/config/grafana/dashboards/"
echo "5. Configure data sources (Prometheus, Loki)"

# Import default dashboards
curl -X POST \
  http://admin:admin@$SERVER_IP:3000/api/dashboards/db \
  -H 'Content-Type: application/json' \
  -d @config/grafana/dashboards/system-overview.json
```

#### **Configure Nginx Proxy Manager:**
```bash
echo "🌐 Configure Nginx Proxy Manager:"
echo "1. Access: http://$SERVER_IP:81"
echo "2. Email: admin@example.com"
echo "3. Password: admin"
echo "4. Change credentials immediately"
echo "5. Add proxy hosts for your services"
```

#### **Configure Nextcloud:**
```bash
echo "☁️ Configure Nextcloud:"
echo "1. Access: http://$SERVER_IP:8081"
echo "2. Create admin account"
echo "3. Configure storage"
echo "4. Install recommended apps"
echo "5. Setup user accounts for 6 people"
```

### Step 14: Generate Service Access Report
```bash
# Create deployment report
cat > /tmp/homelab-deployment-report.md << EOF
# 🎉 Homelab Deployment Complete!

## 📋 Service Access URLs

### 🏠 Local Access
- **Grafana**: http://$SERVER_IP:3000 (admin/admin)
- **Vaultwarden**: http://$SERVER_IP:8080
- **Nginx Proxy Manager**: http://$SERVER_IP:81 (admin@example.com/admin)
- **Vault**: http://$SERVER_IP:8200
- **Nextcloud**: http://$SERVER_IP:8081
- **Jellyfin**: http://$SERVER_IP:8096
- **Prometheus**: http://$SERVER_IP:9090
- **AlertManager**: http://$SERVER_IP:9093

### 🔧 Management URLs
- **Portainer**: http://$SERVER_IP:9443
- **Uptime Kuma**: http://$SERVER_IP:3001
- **Vault UI**: http://$SERVER_IP:8000 (if enabled)

### 📊 Monitoring
- **System Dashboard**: Grafana → Dashboard → System Overview
- **Container Metrics**: Grafana → Dashboard → Docker
- **Service Health**: http://$SERVER_IP:3001/status

## 👥 User Setup
1. **Vaultwarden**: Create accounts for all 6 users
2. **Nextcloud**: Setup user accounts and storage quotas
3. **Enable 2FA**: Mandatory for all users
4. **Training**: Complete security training for all users

## 🔒 Security Configuration
- **Vault**: Token saved in /tmp/vault-root-token.txt
- **AppRole Credentials**: Saved in /tmp/vault-approles.txt
- **Backup**: First backup created in /opt/homelab-backups/

## 📝 Next Steps
1. Configure reverse proxy for external access
2. Setup SSL certificates
3. Configure monitoring alerts
4. Schedule regular backups
5. Complete user onboarding

EOF

echo "✅ Deployment report saved to /tmp/homelab-deployment-report.md"
cat /tmp/homelab-deployment-report.md
```

---

## 🔒 Phase 5: Security and Backup

### Step 15: Create Initial Backup
```bash
# Create comprehensive backup
cd /opt/homelab
./scripts/homelab.sh backup

# Verify backup was created
ls -la /opt/homelab-backups/

# Test backup integrity
./scripts/backup/verify-backup.sh $(ls -t /opt/homelab-backups/ | head -1 | sed 's/.tar.gz//')
```

### Step 16: Configure Security
```bash
# Review Vault credentials
echo "🔐 Vault Credentials:"
cat /tmp/vault-root-token.txt
cat /tmp/vault-approles.txt

# Secure Vault files
chmod 600 /tmp/vault-*.txt
mv /tmp/vault-*.txt /opt/homelab/.secrets/

# Configure firewall rules
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw allow 81/tcp    # Nginx Proxy Manager
ufw allow 3000/tcp  # Grafana
ufw allow 8200/tcp  # Vault
ufw allow 8080/tcp  # Vaultwarden
ufw --force enable

# Setup log rotation
echo "/opt/homelab-backups/*/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
}" > /etc/logrotate.d/homelab
```

### Step 17: Setup Monitoring and Alerts
```bash
# Configure monitoring alerts
echo "📊 Setting up monitoring alerts..."

# Edit alert configuration
nano docker-compose/monitoring/config/alertmanager.yml

# Add your notification channels (Slack/Discord/Email)
# Example for Slack:
#   slack_configs:
#     - api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'
#       channel: '#homelab-alerts'
#       send_resolved: true

# Reload alertmanager configuration
docker-compose -f docker-compose/monitoring/docker-compose.yml restart alertmanager
```

---

## ✅ Phase 6: Validation and Testing

### Step 18: Complete System Validation
```bash
# Run comprehensive health check
cd /opt/homelab

# Test all services
./scripts/homelab.sh status

# Run monitoring dashboard
./scripts/homelab.sh monitor system

# Generate comprehensive report
./scripts/monitoring/monitoring.sh report

# Test database connections
echo "🗄️ Testing database connections..."
docker exec mysql mysql -u root -p -e "SHOW DATABASES;"
docker exec postgres psql -U postgres -c "\l"

# Test Vault operations
echo "🏗️ Testing Vault operations..."
VAULT_ADDR="http://localhost:8200"
VAULT_TOKEN=$(cat /opt/homelab/.secrets/vault-root-token.txt)
vault kv put secret/test key=value
vault kv get secret/test
```

### Step 19: Performance Validation
```bash
# Check system resources
echo "💾 System Resources:"
free -h
df -h
docker stats --no-stream

# Check network connectivity
echo "🌐 Network Connectivity:"
for port in 3000 8080 8200 8096 9090; do
    if nc -z localhost $port; then
        echo "✅ Port $port is open"
    else
        echo "❌ Port $port is closed"
    fi
done

# Check service health
echo "🏥 Service Health:"
curl -s http://localhost:3000/api/health || echo "Grafana: Not responding"
curl -s http://localhost:8200/v1/sys/health || echo "Vault: Not responding"
curl -s http://localhost:8080 || echo "Vaultwarden: Not responding"
```

---

## 🚨 Troubleshooting Guide

### Common Issues and Solutions

#### **Terraform Issues:**
```bash
# Error: Connection refused
# Solution: Check Proxmox API URL and token
curl -k https://192.168.31.237:8006/api2/json/version

# Error: Template not found
# Solution: Ensure Ubuntu template exists with ID 9000
qm list | grep 9000

# Error: Permission denied
# Solution: Check Proxmox user permissions
pveum user list
```

#### **Docker Issues:**
```bash
# Container not starting
docker-compose logs [service-name]

# Network issues
docker network ls
docker network inspect homelab-network

# Resource issues
docker system df
docker system prune -f
```

#### **Service Access Issues:**
```bash
# Port blocked
ufw status
ufw allow [port]/tcp

# Service not responding
docker exec -it [container-name] bash
ps aux

# DNS issues
nslookup your-domain.com
cat /etc/resolv.conf
```

#### **Performance Issues:**
```bash
# High CPU usage
docker stats
top

# High memory usage
free -h
docker system events

# Disk space issues
df -h
docker system df
docker volume ls
```

---

## 📚 Maintenance Guide

### Daily Tasks (Automated)
```bash
# Add to crontab:
0 2 * * * /opt/homelab/scripts/homelab.sh backup
0 3 * * * /opt/homelab/scripts/monitoring/monitoring.sh health
0 4 * * * /opt/homelab/scripts/homelab.sh update clean
```

### Weekly Tasks
```bash
# Manual review:
# 1. Check backup integrity
# 2. Review monitoring alerts
# 3. Update services if needed
# 4. Check security logs
# 5. Validate user access
```

### Monthly Tasks
```bash
# Maintenance:
# 1. Full system security scan
# 2. Performance review
# 3. User training refresh
# 4. Documentation update
# 5. Backup verification
```

---

## 🎯 Success Criteria

### Deployment Success Indicators:
- [ ] All 7 VMs running in Proxmox
- [ ] All 46+ Docker containers running
- [ ] All web services accessible
- [ ] Monitoring dashboards populated
- [ ] Initial backup completed
- [ ] Security scan passed
- [ ] User accounts created (6 total)
- [ ] External access configured (if required)

### Performance Baselines:
- **System Response**: < 2 seconds
- **Service Uptime**: > 99%
- **Backup Success**: 100%
- **Security Alerts**: 0 critical
- **User Satisfaction**: All 6 users onboarded

---

## 🆘 Support and Escalation

### Internal Support Team:
1. **Infrastructure Owner**: Proxmox & VM issues
2. **Services Owner**: Docker & applications
3. **Security Owner**: Vault & access control
4. **Monitoring Owner**: Alerts & dashboards
5. **User Support**: Training & helpdesk

### Emergency Contacts:
- **Critical Issues**: Immediate response required
- **High Priority**: Response within 1 hour
- **Normal Issues**: Response within 24 hours

### Documentation References:
- [DEPLOYMENT-GUIDE.md](./DEPLOYMENT-GUIDE.md)
- [PREREQUISITES.md](./PREREQUISITES.md)
- [SECURITY-PLAYBOOK.md](./docker-compose/security/SECURITY-PLAYBOOK.md)
- [IMPLEMENTATION-COMPLETE.md](./IMPLEMENTATION-COMPLETE.md)

---

## 🎉 Completion Checklist

### Final Validation:
- [ ] All services deployed and running
- [ ] Users configured and trained
- [ ] Monitoring and alerts active
- [ ] Backup system operational
- [ ] Security measures implemented
- [ ] Documentation completed
- [ ] Maintenance schedule configured
- [ ] Success metrics met

### Next Steps:
1. **User Onboarding**: Complete training for all 6 users
2. **Custom Apps**: Deploy your custom applications using Vault for secrets
3. **External Access**: Configure domain names and SSL certificates
4. **Automation**: Set up cron jobs for maintenance
5. **Monitoring**: Configure alert thresholds and notifications

---

**🚀 Your enterprise-grade homelab is now fully operational!**

*For ongoing support and updates, refer to the comprehensive documentation in this repository.*