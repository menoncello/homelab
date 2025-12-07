# 📋 Homelab Prerequisites
## What You Need Before Deployment

### 🔧 Required Software

#### On Your Local Machine:
- **Terraform** (v1.0+) - Infrastructure provisioning
  ```bash
  # Install Terraform
  curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
  sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
  sudo apt-get update && sudo apt-get install terraform
  ```

- **Docker** & **Docker Compose** - Container management
  ```bash
  # Install Docker
  curl -fsSL https://get.docker.com -o get-docker.sh
  sudo sh get-docker.sh

  # Install Docker Compose
  sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
  ```

- **Git** - Version control
  ```bash
  sudo apt-get install git
  ```

#### On Proxmox Server:
- **Proxmox VE** (v7.0+) - Virtualization platform
- **QEMU Guest Agent** - For VM management
- **Cloud-Init Support** - For VM initialization

### 🏗️ Proxmox Setup Requirements

#### 1. **Create Proxmox User with API Permissions**
```bash
# In Proxmox web UI:
# Datacenter → Permissions → Users → Create
# Username: homelab-api
# Realm: Proxmox VE authentication server
# Password: [your-secure-password]
```

#### 2. **Generate API Token**
```bash
# Datacenter → Permissions → API Tokens → Add
# User: homelab-api
# Token ID: homelab-token
# Uncheck "Privilege Separation"
```

#### 3. **Set User Permissions**
```bash
# Add user to these roles:
# - Datacenter → Permissions → Add → User Permission
# Path: / (Datacenter)
# User: homelab-api
# Role: PVEVMUser (or custom role with these permissions:)
#   - VM.Audit
#   - VM.Clone
#   - VM.Config.CDROM
#   - VM.Config.CPU
#   - VM.Config.Disk
#   - VM.Config.Memory
#   - VM.Config.Network
#   - VM.Config.Options
#   - VM.Migrate
#   - VM.PowerMgmt
#   - VM.Snapshot
#   - VM.Snapshot.Rollback
#   - VM.Console
#   - VM.Monitor
```

#### 4. **Network Configuration**
```bash
# Ensure your Proxmox network can handle:
# - 7 VMs with static IPs (192.168.31.201-207 range)
# - Internet access for all VMs
# - Firewall rules for required ports (if needed)
```

#### 5. **Storage Requirements**
```bash
# Minimum storage recommendations:
# - System storage: 100GB+
# - VM storage: 500GB+ (for all VMs)
# - Backup storage: 200GB+ (for backups)
```

### 🖥️ Ubuntu Cloud-Init Template

**CRITICAL:** You must create an Ubuntu 22.04 cloud-init template in Proxmox BEFORE running Terraform.

#### Method 1: Manual Template Creation
```bash
# 1. Download Ubuntu Cloud Image
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img

# 2. Create new VM in Proxmox Web UI
# - VM ID: 9000
# - Name: ubuntu-2204-cloud-init
# - OS: Do not use any media
# - System: Q35 Machine, BIOS OVMF (UEFI)
# - Hard Disk: 32GB (or larger)
# - CPU: 2 cores
# - Memory: 2048MB
# - Network: vmbr0

# 3. Import cloud image to VM disk
qm importdisk 9000 jammy-server-cloudimg-amd64.img local-lvm

# 4. Configure VM
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0
qm set 9000 --ide2 local-lvm:cloudinit
qm set 9000 --boot c --bootdisk scsi0
qm set 9000 --serial0 socket --vga serial0

# 5. Install QEMU Guest Agent
qm set 9000 --agent 1

# 6. Convert to template
qm template 9000
```

#### Method 2: Using Provided Script
```bash
# If you have the template creation script
./scripts/create-ubuntu-template.sh
```

### 🌐 Network Configuration

#### Required IP Addresses:
```bash
# Your VMs will use these IPs:
# - monitoring-vm:    192.168.31.201
# - media-server:     192.168.31.151
# - prod-services:    192.168.31.202
# - databases:        192.168.31.203
# - books:            192.168.31.204
# - storage:          192.168.31.205
# - devops:           192.168.31.206
# - nginx-proxy:      192.168.31.200
```

#### Port Requirements:
```bash
# Ensure these ports are open:
# - 22 (SSH) for all VMs
# - 80/443 (HTTP/HTTPS) for web services
# - 81 (Nginx Proxy Manager)
# - 3000 (Grafana)
# - 8096 (Jellyfin)
# - 8081 (Nextcloud)
# - 9090 (Prometheus)
```

### 🔑 DNS & Domain (Optional but Recommended)

#### For External Access:
```bash
# 1. Domain name (example.com)
# 2. Cloudflare account (for tunnel)
# 3. SSL certificates (automatic with Nginx Proxy Manager)
```

### 📊 Hardware Requirements

#### Proxmox Server Minimum Specs:
- **CPU**: 8+ cores (16+ recommended)
- **RAM**: 32GB+ (64GB+ recommended)
- **Storage**: 1TB+ SSD/NVMe
- **Network**: Gigabit Ethernet

#### Resource Allocation After Deployment:
```
VMs Total Resources:
- CPU Cores: 42/Total (6 per VM average)
- RAM: 136GB/Total (distributed across VMs)
- Storage: 700GB+ for VMs + applications
```

### 🔒 Security Considerations

#### Before Deployment:
```bash
# 1. Change default Proxmox passwords
# 2. Enable Proxmox firewall if desired
# 3. Configure SSH key authentication
# 4. Update all systems
# 5. Backup current Proxmox configuration
```

#### Service Passwords:
```bash
# You'll need to configure these in docker-compose/.env:
# - MySQL root password
# - PostgreSQL password
# - Grafana admin password
# - Nextcloud admin password
# - Bitwarden admin password
# - And other service credentials
```

### 📝 Environment Variables Template

Create `terraform/terraform.tfvars`:
```hcl
# Proxmox Configuration
proxmox_api_url = "https://your-proxmox-server:8006/api2/json"
proxmox_user = "homelab-api@pve"
proxmox_password = "your-api-password"
proxmox_api_token_id = "homelab-token!api-token-id"
proxmox_api_token_secret = "your-api-token-secret"
proxmox_tls_insecure = true

# Network Configuration
vm_gateway = "192.168.1.1"
vm_dns = "192.168.1.1"
domain = "your-domain.com"

# Storage Configuration
vm_storage_pool = "local-lvm"
vm_template_name = "ubuntu-2204-cloud-init"
vm_ci_user = "ubuntu"
vm_ssh_public_key = "ssh-rsa your-public-key"
```

Create `docker-compose/.env`:
```bash
# Domain & Timezone
DOMAIN=your-domain.com
TZ=America/Sao_Paulo

# Database Credentials
MYSQL_ROOT_PASSWORD=your-secure-mysql-password
POSTGRES_PASSWORD=your-secure-postgres-password

# Service Credentials
GRAFANA_ADMIN_PASSWORD=your-grafana-password
NEXTCLOUD_ADMIN_PASSWORD=your-nextcloud-password

# Cloudflare (optional)
CLOUDFLARE_TUNNEL_TOKEN=your-tunnel-token
```

### ✅ Validation Checklist

Before running deployment, verify:

- [ ] Proxmox server is running and accessible
- [ ] API user has correct permissions
- [ ] Ubuntu cloud-init template exists (ID: 9000)
- [ ] Terraform and Docker are installed locally
- [ ] Network can handle VM IP assignments
- [ ] Sufficient storage space available
- [ ] API credentials are correct
- [ ] Environment variables are configured
- [ ] Domain name is configured (if using external access)

### 🚀 Ready to Deploy?

Once all prerequisites are met, you can deploy with:

```bash
# Deploy everything
./scripts/homelab.sh deploy

# Or follow the step-by-step guide
cat DEPLOYMENT-GUIDE.md
```

---

**⚠️ Important:** Do not skip the Ubuntu cloud-init template creation step - it's required for automated VM provisioning!