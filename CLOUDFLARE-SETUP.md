# 🌩️'h' Cloudflare Configuration Guide

## Complete Setup for Homelab External Access

---

## 🎯 Overview

Cloudflare Tunnel provides secure, free external access to your homelab services without:

- Opening ports on your router
- Configuring port forwarding
- Managing SSL certificates
- Exposing your public IP

### Benefits

- 🔒 **Secure**: Encrypted tunnel to Cloudflare network
- 🌍 **Global**: Access from anywhere in the world
- 🆓 **Free**: No cost for personal homelab use
- 🔐 **HTTPS**: Automatic SSL certificates
- 🚀 **Fast**: Cloudflare's global network

---

## 📋 Prerequisites

### Before You Start

- [ ]  Cloudflare account (free tier)
- [ ]  Custom domain name (required)
- [ ]  Access to DNS management for your domain
- [ ]  Homelab deployed and running locally

### Required Files

- `cloudflare-tunnel/docker-compose.yml`
- `cloudflare-tunnel/config/tunnel.yml`
- `cloudflare-tunnel/.env` (needs your credentials)

---

## 🚀 Phase 1: Cloudflare Account Setup

### Step 1: Create Cloudflare Account

```bash
# 1. Go to https://dash.cloudflare.com/sign-up
# 2. Sign up for free account
# 3. Verify your email address
# 4. Add your domain to Cloudflare
```

### Step 2: Add Domain to Cloudflare

```bash
# 1. Click "Add a site"
# 2. Enter your domain (e.g., your-homelab.com)
# 3. Select FREE plan ($0/month)
# 4. Follow DNS setup instructions
# 5. Change nameservers to Cloudflare's
# 6. Wait for DNS propagation (5-60 minutes)
```

### Step 3: Verify DNS

```bash
# Check if domain is using Cloudflare
nslookup your-homelab.com
# Should show Cloudflare IP addresses (not your home IP)

# Check Cloudflare status
curl -I https://your-homelab.com
# Should show Cloudflare headers
```

---

## 🌐 Phase 2: Cloudflare Tunnel Setup

### Step 4: Create Tunnel

```bash
# 1. In Cloudflare Dashboard, go to:
#    Zero Trust → Networks → Tunnels

# 2. Click "Create a tunnel"
# 3. Select "Cloudflared" tunnel
# 4. Give it a name: "homelab-tunnel"
# 5. Click "Save tunnel"

# 6. Copy the generated token (important for later!)
#    Format: eyJhIjoiNz... (long string)
```

### Step 5: Install Cloudflared on Homelab Server

```bash
# Connect to your homelab server
ssh root@192.168.31.237

# Download cloudflared
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb

# Install cloudflared
dpkg -i cloudflared-linux-amd64.deb

# Verify installation
cloudflared --version
```

### Step 6: Configure Tunnel on Server

```bash
# Create tunnel directory
mkdir -p /opt/homelab/cloudflare-tunnel
cd /opt/homelab/cloudflare-tunnel

# Authenticate tunnel (optional, using token is easier)
# cloudflared tunnel login

# Use token method instead:
echo "Your token from Cloudflare dashboard >"
# Paste the token
```

---

## ⚙️ Phase 3: Configure Homelab Services

### Step 7: Update Cloudflare Environment File

```bash
# Edit the environment file
nano /opt/homelab/cloudflare-tunnel/.env
```

**Fill in your configuration:**

```bash
# ============================================
# CLOUDFLARE TUNNEL ENVIRONMENT VARIABLES
# ============================================

# Get this from Cloudflare Dashboard > Zero Trust > Networks > Tunnels > Your Tunnel > Token
CLOUDFLARE_TUNNEL_TOKEN=eyJhIjoiNz...YOUR-TOKEN-HERE...

# Alternative method (without token)
# TUNNEL_ID=your-tunnel-id-here
# TUNNEL_NAME=homelab-tunnel
# CLOUDFLARE_ACCOUNT_ID=your-account-id
# CLOUDFLARE_API_TOKEN=your-api-token

# Domain Configuration
DOMAIN=your-homelab-domain.com

# Additional Configuration (optional)
TUNNEL_SECRET=your-32-character-secret
```

### Step 8: Configure Tunnel Services

```bash
# Edit tunnel configuration
nano /opt/homelab/cloudflare-tunnel/config/tunnel.yml
```

**Complete tunnel configuration:**

```yaml
# ============================================
# HOMELAB CLOUDFLARE TUNNEL CONFIGURATION
# ============================================

tunnel: YOUR-TUNNEL-ID-FROM-DASHBOARD
credentials-file: /etc/cloudflared/credentials.json

# Tunnel configuration
ingress:
  # ============================================
  # CORE SERVICES
  # ============================================

  # Grafana - Monitoring Dashboard
  - hostname: grafana.your-homelab-domain.com
    service: http://192.168.31.201:3000
  - hostname: stats.your-homelab-domain.com
    service: http://192.168.31.201:3000

  # Vaultwarden - Password Manager
  - hostname: vaultwarden.your-homelab-domain.com
    service: http://192.168.31.200:8080
  - hostname: passwords.your-homelab-domain.com
    service: http://192.168.31.200:8080

  # Nginx Proxy Manager
  - hostname: proxy.your-homelab-domain.com
    service: http://192.168.31.200:81
  - hostname: domains.your-homelab-domain.com
    service: http://192.168.31.200:81

  # Nextcloud - File Storage
  - hostname: cloud.your-homelab-domain.com
    service: http://192.168.31.202:8081
  - hostname: files.your-homelab-domain.com
    service: http://192.168.31.202:8081

  # ============================================
  # MEDIA SERVICES
  # ============================================

  # Jellyfin - Media Server
  - hostname: jellyfin.your-homelab-domain.com
    service: http://192.168.31.151:8096
  - hostname: media.your-homelab-domain.com
    service: http://192.168.31.151:8096
  - hostname: movies.your-homelab-domain.com
    service: http://192.168.31.151:8096
  - hostname: tv.your-homelab-domain.com
    service: http://192.168.31.151:8096

  # ============================================
  # PRODUCTIVITY SERVICES
  # ============================================

  # GitLab - Code Repository
  - hostname: git.your-homelab-domain.com
    service: http://192.168.31.202:8888
  - hostname: code.your-homelab-domain.com
    service: http://192.168.31.202:8888

  # OnlyOffice Document Server
  - hostname: office.your-homelab-domain.com
    service: http://192.168.31.202:8082

  # ============================================
  # BOOKS & READING
  # ============================================

  # Calibre-Web - E-Books
  - hostname: books.your-homelab-domain.com
    service: http://192.168.31.204:8083
  - hostname: ebooks.your-homelab-domain.com
    service: http://192.168.31.204:8083

  # Kavita - Manga/Comics
  - hostname: comics.your-homelab-domain.com
    service: http://192.168.31.204:5000

  # Audiobookshelf - Audio Books
  - hostname: audio.your-homelab-domain.com
    service: http://192.168.31.204:13378
  - hostname: audiobooks.your-homelab-domain.com
    service: http://192.168.31.204:13378

  # ============================================
  # DEVELOPMENT & MONITORING
  # ============================================

  # Portainer - Docker Management
  - hostname: docker.your-homelab-domain.com
    service: https://192.168.31.200:9443
  - hostname: containers.your-homelab-domain.com
    service: https://192.168.31.200:9443

  # Uptime Kuma - Status Page
  - hostname: status.your-homelab-domain.com
    service: http://192.168.31.201:3001
  - hostname: uptime.your-homelab-domain.com
    service: http://192.168.31.201:3001

  # Prometheus - Metrics
  - hostname: metrics.your-homelab-domain.com
    service: http://192.168.31.201:9090

  # AlertManager - Alerts
  - hostname: alerts.your-homelab-domain.com
    service: http://192.168.31.201:9093

  # ============================================
  # ADMINISTRATION
  # ============================================

  # HashiCorp Vault
  - hostname: vault.your-homelab-domain.com
    service: http://192.168.31.200:8200
  - hostname: secrets.your-homelab-domain.com
    service: http://192.168.31.200:8200

  # Homelab Main Dashboard
  - hostname: dashboard.your-homelab-domain.com
    service: http://192.168.31.201:3000
  - hostname: home.your-homelab-domain.com
    service: http://192.168.31.201:3000

  # ============================================
  # CATCH-ALL (for testing)
  # ============================================

  # Main domain redirect to dashboard
  - hostname: your-homelab-domain.com
    service: http://192.168.31.201:3000

  # Default service (catch-all)
  - service: http_status:404
```

### Step 9: Deploy Cloudflare Tunnel

```bash
# Navigate to cloudflare directory
cd /opt/homelab

# Deploy tunnel service
docker-compose -f cloudflare-tunnel/docker-compose.yml up -d

# Check tunnel status
docker-compose -f cloudflare-tunnel/docker-compose.yml logs -f

# Verify tunnel is running
docker ps | grep cloudflared
```

---

## 🔧 Phase 4: Configure Cloudflare DNS

### Step 10: Create DNS Records

```bash
# In Cloudflare Dashboard → DNS → Records

# Create CNAME records for your services:
# ---------------------------------------
# grafana          → your-tunnel-id.cfargotunnel.com
# vaultwarden     → your-tunnel-id.cfargotunnel.com
# jellyfin         → your-tunnel-id.cfargotunnel.com
# nextcloud        → your-tunnel-id.cfargotunnel.com
# gitlab           → your-tunnel-id.cfargotunnel.com
# books            → your-tunnel-id.cfargotunnel.com
# status           → your-tunnel-id.cfargotunnel.com
# docker           → your-tunnel-id.cfargotunnel.com
# vault            → your-tunnel-id.cfargotunnel.com
# dashboard        → your-tunnel-id.cfargotunnel.com
# movies           → your-tunnel-id.cfargotunnel.com
# cloud            → your-tunnel-id.cfargotunnel.com
# files            → your-tunnel-id.cfargotunnel.com
# media            → your-tunnel-id.cfargotunnel.com
# proxy            → your-tunnel-id.cfargotunnel.com
# stats            → your-tunnel-id.cfargotunnel.com
# passwords        → your-tunnel-id.cfargotunnel.com
# domains          → your-tunnel-id.cfargotunnel.com
# code             → your-tunnel-id.cfargotunnel.com
# office           → your-tunnel-id.cfargotunnel.com
# ebooks           → your-tunnel-id.cfargotunnel.com
# comics           → your-tunnel-id.cfargotunnel.com
# audio            → your-tunnel-id.cfargotunnel.com
# audiobooks       → your-tunnel-id.cfargotunnel.com
# containers       → your-tunnel-id.cfargotunnel.com
# uptime           → your-tunnel-id.cfargotunnel.com
# metrics          → your-tunnel-id.cfargotunnel.com
# alerts           → your-tunnel-id.cfargotunnel.com
# secrets          → your-tunnel-id.cfargotunnel.com
# home             → your-tunnel-id.cfargotunnel.com
# tv               → your-tunnel-id.cfargotunnel.com
```

### Step 11: Alternative Method (Automatic DNS)

```bash
# For automatic DNS creation, use this in tunnel.yml:
# This will automatically create DNS records

# Quick setup (after creating tunnel):
cloudflared tunnel route dns homelab-tunnel your-homelab-domain.com

# This creates wildcard DNS record
# All subdomains will automatically point to your tunnel
```

---

## ✅ Phase 5: Testing and Verification

### Step 12: Test Services

```bash
# Test main services
curl -I https://grafana.your-homelab-domain.com
curl -I https://vaultwarden.your-homelab-domain.com
curl -I https://jellyfin.your-homelab-domain.com
curl -I https://nextcloud.your-homelab-domain.com

# Check tunnel status
cloudflared tunnel info homelab-tunnel

# Monitor tunnel logs
docker logs -f cloudflared
```

### Step 13: Configure SSL (Automatic)

```bash
# SSL is automatically handled by Cloudflare!
# All services get HTTPS certificates automatically

# Verify SSL
curl -I https://grafana.your-homelab-domain.com
# Should show 200 OK with SSL headers

# Check certificate details
openssl s_client -connect grafana.your-homelab-domain.com:443 -servername grafana.your-homelab-domain.com
```

---

## 🔒 Phase 6: Security Configuration

### Step 14: Cloudflare Security Settings

```bash
# In Cloudflare Dashboard → SSL/TLS:

# 1. Set encryption mode to "Full (strict)"
#    This ensures end-to-end encryption

# 2. Enable "Always Use HTTPS"
#    Redirects all HTTP to HTTPS

# 3. Configure "Authenticated Origin Pulls"
#    Adds additional security layer

# 4. Set "Minimum TLS Version" to 1.2
#    Modern security standards
```

### Step 15: Access Control (Optional)

```bash
# In Cloudflare Dashboard → Zero Trust → Access:

# 1. Create Access policies for sensitive services
# 2. Require 2FA for admin services
# 3. Limit access by country/IP if needed
# 4. Set up session timeouts
```

### Step 16: Cloudflare Firewall Rules

```bash
# In Cloudflare Dashboard → Security → WAF:

# 1. Enable "High Security Setting"
# 2. Block common attack patterns
# 3. Rate limit sensitive endpoints
# 4. Enable Bot Fight Mode
```

---

## 📊 Service URLs After Configuration

### 🏠 Main Access URLs

```bash
# Dashboard & Monitoring
https://your-homelab-domain.com          # Main Dashboard (Grafana)
https://home.your-homelab-domain.com      # Dashboard (alternative)
https://dashboard.your-homelab-domain.com # Dashboard (alternative)
https://stats.your-homelab-domain.com     # Grafana
https://status.your-homelab-domain.com    # Uptime Kuma

# Password & Security
https://vaultwarden.your-homelab-domain.com # Password Manager
https://passwords.your-homelab-domain.com  # Password Manager (alt)
https://vault.your-homelab-domain.com      # HashiCorp Vault
https://secrets.your-homelab-domain.com    # HashiCorp Vault (alt)

# Media & Entertainment
https://jellyfin.your-homelab-domain.com   # Media Server
https://media.your-homelab-domain.com      # Media Server (alt)
https://movies.your-homelab-domain.com     # Movies (alias)
https://tv.your-homelab-domain.com         # TV Shows (alias)

# Productivity & Files
https://nextcloud.your-homelab-domain.com  # File Storage
https://cloud.your-homelab-domain.com      # File Storage (alt)
https://files.your-homelab-domain.com     # File Storage (alt)
https://git.your-homelab-domain.com       # Code Repository
https://code.your-homelab-domain.com      # Code Repository (alt)
https://office.your-homelab-domain.com    # Documents

# Books & Reading
https://books.your-homelab-domain.com      # E-Books
https://ebooks.your-homelab-domain.com     # E-Books (alt)
https://comics.your-homelab-domain.com     # Comics/Manga
https://audio.your-homelab-domain.com     # Audio Books
https://audiobooks.your-homelab-domain.com # Audio Books (alt)

# Administration
https://docker.your-homelab-domain.com    # Docker Management
https://containers.your-homelab-domain.com # Docker Management (alt)
https://proxy.your-homelab-domain.com     # Proxy Manager
https://domains.your-homelab-domain.com   # Proxy Manager (alt)
```

### 🔧 Technical URLs

```bash
# Technical & Monitoring
https://metrics.your-homelab-domain.com   # Prometheus Metrics
https://alerts.your-homelab-domain.com    # Alert Manager

# Local-only (not exposed via tunnel)
# http://192.168.31.200:81                 # Nginx Proxy Manager (local only)
# http://192.168.31.201:9090              # Prometheus (local only)
# http://192.168.31.201:9093              # AlertManager (local only)
```

---

## 🚨 Troubleshooting

### Common Issues and Solutions

#### **Tunnel Not Starting**

```bash
# Check tunnel logs
docker logs cloudflared

# Verify token is correct
echo $CLOUDFLARE_TUNNEL_TOKEN
# Should start with "eyJhIjoi..."

# Check network connectivity
curl https://api.cloudflare.com/client/v4/user/tokens/verify \
  -H "Authorization: Bearer YOUR_TOKEN"
```

#### **Services Not Accessible**

```bash
# Check service is running locally
curl http://192.168.31.201:3000  # Grafana
curl http://192.168.31.151:8096  # Jellyfin

# Check tunnel configuration
docker exec -it cloudflared cat /etc/cloudflared/config.yml

# Restart tunnel
docker-compose restart cloudflared
```

#### **DNS Not Working**

```bash
# Check DNS propagation
nslookup grafana.your-homelab-domain.com
# Should return Cloudflare IPs

# Clear local DNS cache
sudo dscacheutil -flushcache  # macOS
sudo systemd-resolve --flush-caches  # Linux

# Verify tunnel routing
cloudflared tunnel info homelab-tunnel
```

#### **SSL Certificate Issues**

```bash
# Check SSL mode in Cloudflare Dashboard
# Should be "Full (strict)" for maximum security

# Test SSL connection
openssl s_client -connect your-homelab-domain.com:443

# Force SSL renewal (if needed)
# In Cloudflare Dashboard → SSL/TLS → Edge Certificates
```

---

## 📋 Maintenance

### Regular Tasks

```bash
# Monthly: Check tunnel status
cloudflared tunnel list

# Quarterly: Update cloudflared
docker pull cloudflare/cloudflared:latest
docker-compose restart cloudflared

# Annually: Review access logs
# Cloudflare Dashboard → Analytics → Logs
```

### Backup Configuration

```bash
# Backup tunnel configuration
cp /opt/homelab/cloudflare-tunnel/config/tunnel.yml /backup/
cp /opt/homelab/cloudflare-tunnel/.env /backup/

# Store backup securely
# Never commit .env with real token to version control
```

---

## 🎯 Success Criteria

### ✅ Configuration Complete When:

- [ ]  Cloudflare tunnel is running and connected
- [ ]  All services accessible via HTTPS URLs
- [ ]  DNS records properly configured
- [ ]  SSL certificates active for all services
- [ ]  Security settings configured in Cloudflare
- [ ]  Access controls implemented (if desired)
- [ ]  Backup of configuration files created

### 🎉 Expected Results:

- **Secure HTTPS access** to all homelab services
- **No open ports** on your home router
- **Global accessibility** from anywhere
- **Automatic SSL** certificate management
- **DDoS protection** from Cloudflare
- **Performance optimization** through CDN

---

## 📚 Additional Resources

### Documentation

- [Cloudflare Tunnel Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/tunnel-guide/)
- [Cloudflared Documentation](https://github.com/cloudflare/cloudflared)
- [Cloudflare Zero Trust](https://www.cloudflare.com/products/zero-trust/)

### Advanced Configuration

- [Multiple Tunnels](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/tunnel-guide/remote/)
- [Load Balancing](https://developers.cloudflare.com/load-balancing/)
- [Argo Tunnel](https://www.cloudflare.com/products/argo-tunnel/)

### Community Support

- [Cloudflare Community](https://community.cloudflare.com/)
- [r/cloudflare](https://reddit.com/r/cloudflare)
- [Homelab Discord](https://discord.gg/homelab)

---

**🚀 Your homelab will be securely accessible from anywhere in the world with enterprise-grade security!**
